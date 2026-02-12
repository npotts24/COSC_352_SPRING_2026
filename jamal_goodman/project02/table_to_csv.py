from __future__ import annotations

import argparse
import csv
import html
import os
import re
import sys
import urllib.request
import urllib.parse
from html.parser import HTMLParser
from typing import List, Optional, Dict, Any


WHITESPACE_RE = re.compile(r"\s+")
BRACKETED_REF_RE = re.compile(r"\[\s*\d+\s*\]")  # Wikipedia-style [1], [23], etc.


def clean_text(s: str) -> str:
    """Normalize whitespace, decode HTML entities, and remove common footnote markers like [1]."""
    s = html.unescape(s)
    s = WHITESPACE_RE.sub(" ", s).strip()
    s = BRACKETED_REF_RE.sub("", s).strip()
    return s


class TableHTMLParser(HTMLParser):
    """
    Minimal, generic HTML table parser using only the standard library.

    Captures:
    - tables -> rows -> cells
    - distinguishes headers (<th>) vs data (<td>) by tagging, but output is just text.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=False)
        self.tables: List[Dict[str, Any]] = []

        self._in_table = False
        self._in_tr = False
        self._in_td = False
        self._in_th = False
        self._in_caption = False

        self._current_table: Optional[Dict[str, Any]] = None
        self._current_row: Optional[List[Dict[str, str]]] = None
        self._current_cell_text_parts: List[str] = []

    def handle_starttag(self, tag: str, attrs: List[tuple]) -> None:
        tag = tag.lower()

        if tag == "table":
            self._in_table = True
            attr_dict = {k.lower(): (v if v is not None else "") for k, v in attrs}
            self._current_table = {
                "attrs": attr_dict,
                "caption": "",
                "rows": [],  # list of rows; each row is list of {"type": "th"/"td", "text": "..."}
            }
            return

        if not self._in_table:
            return

        if tag == "caption":
            self._in_caption = True
            self._current_cell_text_parts = []
            return

        if tag == "tr":
            self._in_tr = True
            self._current_row = []
            return

        if tag == "td":
            self._in_td = True
            self._current_cell_text_parts = []
            return

        if tag == "th":
            self._in_th = True
            self._current_cell_text_parts = []
            return

        # Treat <br> as a space inside cells/caption
        if tag == "br" and (self._in_td or self._in_th or self._in_caption):
            self._current_cell_text_parts.append(" ")

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()

        if tag == "table":
            if self._current_table is not None:
                self.tables.append(self._current_table)
            self._in_table = False
            self._current_table = None
            self._in_tr = self._in_td = self._in_th = self._in_caption = False
            self._current_row = None
            self._current_cell_text_parts = []
            return

        if not self._in_table or self._current_table is None:
            return

        if tag == "caption":
            text = clean_text("".join(self._current_cell_text_parts))
            self._current_table["caption"] = text
            self._in_caption = False
            self._current_cell_text_parts = []
            return

        if tag == "td" and self._in_td and self._current_row is not None:
            text = clean_text("".join(self._current_cell_text_parts))
            self._current_row.append({"type": "td", "text": text})
            self._in_td = False
            self._current_cell_text_parts = []
            return

        if tag == "th" and self._in_th and self._current_row is not None:
            text = clean_text("".join(self._current_cell_text_parts))
            self._current_row.append({"type": "th", "text": text})
            self._in_th = False
            self._current_cell_text_parts = []
            return

        if tag == "tr" and self._in_tr and self._current_row is not None:
            # Store row if it has any cells
            if len(self._current_row) > 0:
                self._current_table["rows"].append(self._current_row)
            self._in_tr = False
            self._current_row = None
            return

    def handle_data(self, data: str) -> None:
        if not self._in_table:
            return
        if self._in_td or self._in_th or self._in_caption:
            self._current_cell_text_parts.append(data)

    def handle_entityref(self, name: str) -> None:
        # Preserve entities; we'll unescape in clean_text()
        if self._in_td or self._in_th or self._in_caption:
            self._current_cell_text_parts.append(f"&{name};")

    def handle_charref(self, name: str) -> None:
        if self._in_td or self._in_th or self._in_caption:
            self._current_cell_text_parts.append(f"&#{name};")


def read_html(source: str, user_agent: str = "table_to_csv.py (standard library)") -> str:
    """Read HTML from a URL (http/https) or local file path."""
    parsed = urllib.parse.urlparse(source)
    if parsed.scheme in ("http", "https"):
        req = urllib.request.Request(
            source,
            headers={"User-Agent": user_agent, "Accept": "text/html,application/xhtml+xml"},
        )
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            # Try charset from headers; fallback to utf-8 with replacement
            content_type = resp.headers.get("Content-Type", "")
            m = re.search(r"charset=([A-Za-z0-9_\-]+)", content_type, re.IGNORECASE)
            encoding = m.group(1) if m else "utf-8"
            return raw.decode(encoding, errors="replace")
    else:
        with open(source, "rb") as f:
            raw = f.read()
        # Most saved web pages are utf-8; use replacement for safety
        return raw.decode("utf-8", errors="replace")


def table_headers(table: Dict[str, Any]) -> List[str]:
    """Return header texts if the first row is primarily <th>, else empty list."""
    rows = table.get("rows", [])
    if not rows:
        return []
    first = rows[0]
    th_count = sum(1 for c in first if c["type"] == "th")
    if th_count >= max(1, len(first) // 2):
        return [c["text"] for c in first]
    return []


def score_table_for_languages(table: Dict[str, Any]) -> int:
    """
    Heuristic scoring to auto-pick a "programming languages" table on Wikipedia-like pages.
    Generic enough to still be useful elsewhere.
    """
    rows = table.get("rows", [])
    if len(rows) < 3:
        return -999  # too small

    attrs = table.get("attrs", {})
    cls = (attrs.get("class") or "").lower()
    caption = (table.get("caption") or "").lower()
    headers = [h.lower() for h in table_headers(table)]

    score = 0

    # Wikipedia tables often use class="wikitable"
    if "wikitable" in cls:
        score += 10

    # Caption hints
    if "language" in caption:
        score += 8
    if "programming" in caption:
        score += 6

    # Header hints
    header_hits = 0
    for key in ("language", "name", "designed", "designer", "appeared", "year", "paradigm"):
        if any(key in h for h in headers):
            header_hits += 1
    score += header_hits * 6

    # Prefer larger tables (often the main comparison table)
    score += min(25, len(rows))

    return score


def pick_table(tables: List[Dict[str, Any]], forced_index: Optional[int]) -> int:
    """Choose table index either by user-provided index or by heuristic scoring."""
    if not tables:
        raise ValueError("No tables found in the HTML.")

    if forced_index is not None:
        if forced_index < 0 or forced_index >= len(tables):
            raise ValueError(f"--table index out of range. Found {len(tables)} tables.")
        return forced_index

    # Auto-pick by score
    best_i = 0
    best_s = -10**9
    for i, t in enumerate(tables):
        s = score_table_for_languages(t)
        if s > best_s:
            best_s = s
            best_i = i
    return best_i


def table_to_matrix(table: Dict[str, Any]) -> List[List[str]]:
    """Convert parsed table structure into a rectangular matrix of strings."""
    rows = table.get("rows", [])
    matrix: List[List[str]] = []
    max_cols = 0
    for r in rows:
        row_text = [c["text"] for c in r]
        matrix.append(row_text)
        max_cols = max(max_cols, len(row_text))

    # Pad ragged rows so CSV columns align
    for r in matrix:
        if len(r) < max_cols:
            r.extend([""] * (max_cols - len(r)))

    return matrix


def write_csv(matrix: List[List[str]], out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        for row in matrix:
            w.writerow(row)


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Parse an HTML table from a URL or file and write it to CSV (standard library only)."
    )
    ap.add_argument("source", help="URL (http/https) or local path to an .html file")
    ap.add_argument("-o", "--out", default="table.csv", help="Output CSV filename (default: table.csv)")
    ap.add_argument("--table", type=int, default=None, help="Force a specific table index (0-based).")
    ap.add_argument("--list", action="store_true", help="List tables found (index, caption, size) and exit.")
    args = ap.parse_args(argv)

    html_text = read_html(args.source)
    parser = TableHTMLParser()
    parser.feed(html_text)
    tables = parser.tables

    if not tables:
        print("No <table> elements found. If the site uses JavaScript to load tables, download the rendered HTML and parse the file.", file=sys.stderr)
        return 2

    if args.list:
        for i, t in enumerate(tables):
            cap = t.get("caption") or ""
            rows = len(t.get("rows") or [])
            headers = table_headers(t)
            cols_guess = len(headers) if headers else (len((t.get("rows") or [])[0]) if rows else 0)
            cls = (t.get("attrs", {}).get("class") or "")
            print(f"[{i}] rows={rows} cols≈{cols_guess} class='{cls}' caption='{cap[:120]}'")
        return 0

    chosen_i = pick_table(tables, args.table)
    chosen = tables[chosen_i]

    matrix = table_to_matrix(chosen)
    write_csv(matrix, args.out)

    cap = chosen.get("caption") or ""
    print(f"Wrote table index {chosen_i} ({len(matrix)} rows) to: {args.out}")
    if cap:
        print(f"Caption: {cap}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))