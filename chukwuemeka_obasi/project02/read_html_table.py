import csv

def read_html(filename):
    f = open(filename, "r", encoding="utf-8")
    html = f.read()
    f.close()
    return html

def parse_table(html):
    stack = []
    rows = []
    row = []
    cell = ""
    i = 0

    while i < len(html):
        if html[i] == "<":
            i += 1
            tag = ""

            while html[i] != ">":
                tag += html[i]
                i += 1

            tag = tag.strip().lower()

            if tag.startswith("tr"):
                stack.append("tr")
                row = []

            elif tag.startswith("td") or tag.startswith("th"):
                stack.append("td")
                cell = ""

            elif tag == "/td" or tag == "/th":
                if len(stack) > 0 and stack[-1] == "td":
                    stack.pop()
                    row.append(cell.strip())

            elif tag == "/tr":
                if len(stack) > 0 and stack[-1] == "tr":
                    stack.pop()
                    if len(row) > 0:
                        rows.append(row)

        else:
            if len(stack) > 0 and stack[-1] == "td":
                cell += html[i]

        i += 1

    return rows

def main():
    html = read_html("ProgrammingLanguages.html")
    rows = parse_table(html)

    out = open("output.csv", "w", newline="", encoding="utf-8")
    writer = csv.writer(out)
    writer.writerows(rows)
    out.close()

    print("output.csv created")

main()