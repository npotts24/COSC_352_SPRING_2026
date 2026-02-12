#!/usr/bin/env node
/**
 * html-table-to-csv.js
 * Parses HTML (from file or string) and extracts all tables into CSV.
 *
 * Usage:
 *   node html-table-to-csv.js [input.html] [output.csv]
 *   node html-table-to-csv.js Compare_programming_lang_table.html output.csv
 * If no args: reads from stdin, writes first table to stdout.
 */

const fs = require('fs');

/**
 * Decode common HTML entities to plain text.
 */
function decodeEntities(str) {
  return String(str)
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, code) => String.fromCharCode(parseInt(code, 16)));
}

/**
 * Extract text from HTML, clean whitespace.
 */
function getText(html) {
  if (!html || typeof html !== 'string') return '';
  let text = html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return decodeEntities(text);
}

/**
 * Find the position of the matching closing tag for an opening tag at startIndex.
 */
function findMatchingCloseTag(html, tagName, startIndex) {
  const openMark = '<' + tagName;
  const closeMark = '</' + tagName + '>';
  const openLen = openMark.length;
  const closeLen = closeMark.length;
  let depth = 0;
  let pos = startIndex;
  const lower = html.toLowerCase();
  const tagLower = tagName.toLowerCase();

  while (pos < html.length) {
    const nextOpen = lower.indexOf('<' + tagLower, pos);
    const nextClose = lower.indexOf('</' + tagLower + '>', pos);
    if (nextClose === -1) return -1;

    const useOpen = nextOpen !== -1 && nextOpen < nextClose;
    if (useOpen) {
      depth++;
      pos = nextOpen + openLen;
    } else {
      depth--;
      if (depth === 0) return nextClose;
      pos = nextClose + closeLen;
    }
  }
  return -1;
}

/**
 * Extract content of a single cell (th/td) and stop at first </th> or </td>.
 */
function getCellContent(rowHtml, startPos, tagName) {
  const closeTag = '</' + tagName + '>';
  const closePos = rowHtml.toLowerCase().indexOf(closeTag.toLowerCase(), startPos);
  if (closePos === -1) return '';
  const contentStart = rowHtml.indexOf('>', startPos) + 1;
  return rowHtml.substring(contentStart, closePos);
}

/**
 * Parse one table HTML string into a 2D array of cell texts.
 * Handle colspan by repeating the cell value.
 */
function parseTable(tableHtml) {
  const rows = [];
  const tableLower = tableHtml.toLowerCase();
  let pos = 0;

  while (pos < tableHtml.length) {
    const trOpen = tableLower.indexOf('<tr', pos);
    if (trOpen === -1) break;

    const trClose = tableLower.indexOf('</tr>', trOpen);
    if (trClose === -1) break;

    const rowHtml = tableHtml.substring(trOpen, trClose + 5);
    const rowCells = [];
    let cellPos = 0;
    const rowLower = rowHtml.toLowerCase();

    while (cellPos < rowHtml.length) {
      const thOpen = rowLower.indexOf('<th', cellPos);
      const tdOpen = rowLower.indexOf('<td', cellPos);
      let openTag = 'th';
      let openPos = thOpen;
      if (tdOpen !== -1 && (thOpen === -1 || tdOpen < thOpen)) {
        openTag = 'td';
        openPos = tdOpen;
      }
      if (openPos === -1) break;

      const cellContent = getCellContent(rowHtml, openPos, openTag);
      const text = getText(cellContent);

      const tagMatch = rowHtml.substring(openPos).match(/<t[hd][^>]*>/i);
      let colspan = 1;
      if (tagMatch) {
        const co = tagMatch[0].match(/colspan\s*=\s*["']?(\d+)/i);
        if (co) colspan = Math.max(1, parseInt(co[1], 10));
      }
      for (let c = 0; c < colspan; c++) rowCells.push(text);
      cellPos = openPos + 1;
    }

    rows.push(rowCells);
    pos = trClose + 5;
  }

  return rows;
}

/**
 * Convert a 2D array of cell strings to a single CSV string.
 * Escapes double quotes by doubling them, wraps field in quotes if it contains comma, quote, or newline.
 */
function toCSV(rows) {
  function escape(field) {
    const s = String(field).trim();
    if (/[",\r\n]/.test(s) || s.includes('"')) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  }
  return rows.map(row => row.map(escape).join(',')).join('\n');
}

/**
 * Extract all <table>...</table> substrings from HTML.
 */
function extractTables(html) {
  const tables = [];
  const lower = html.toLowerCase();
  let pos = 0;

  while (pos < html.length) {
    const tableOpen = lower.indexOf('<table', pos);
    if (tableOpen === -1) break;

    const closePos = findMatchingCloseTag(html, 'table', tableOpen);
    if (closePos === -1) break;

    tables.push(html.substring(tableOpen, closePos + '</table>'.length));
    pos = closePos + 1;
  }
  return tables;
}

/**
 * Main: read HTML, parse tables, write out CSV.
 */
function main() {
  const args = process.argv.slice(2);
  let html;
  let outputPath = 'output.csv';

  if (args.length >= 1) {
    const inputPath = args[0];
    try {
      html = fs.readFileSync(inputPath, 'utf8');
    } catch (e) {
      console.error('Error reading file:', e.message);
      process.exit(1);
    }
    if (args.length >= 2) outputPath = args[1];
  } else {
    html = fs.readFileSync(0, 'utf8');
  }

  const tables = extractTables(html);
  if (tables.length === 0) {
    console.error('No tables found in the HTML.');
    process.exit(1);
  }

  const basePath = outputPath.replace(/\.csv$/i, '');

  tables.forEach((tableHtml, i) => {
    const rows = parseTable(tableHtml);
    const csv = toCSV(rows);
    const path = tables.length === 1 ? outputPath : `${basePath}-${i + 1}.csv`;
    if (args.length === 0) {
      process.stdout.write(csv);
      if (i < tables.length - 1) process.stdout.write('\n\n');
    } else {
      fs.writeFileSync(path, csv, 'utf8');
      console.log('Wrote', path, `(${rows.length} rows)`);
    }
  });
}

main();
