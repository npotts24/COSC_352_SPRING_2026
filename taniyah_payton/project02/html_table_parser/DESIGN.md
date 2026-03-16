# Design Decisions and Technical Notes

## Why Python?
Python was chosen because:
1. Rich standard library (HTMLParser, urllib, csv)
2. Excellent string handling
3. Clear, readable code
4. Cross-platform compatibility

## Architecture Decisions

### 1. HTML Parser Choice
**Decision**: Use `html.parser.HTMLParser` from standard library

**Alternatives considered**:
- BeautifulSoup (requires external library - not allowed)
- regex parsing (fragile and error-prone)
- xml.etree (doesn't handle malformed HTML well)

**Rationale**: HTMLParser is:
- Part of Python standard library
- Robust against malformed HTML
- Event-driven (memory efficient)
- Well-documented and maintained

### 2. State Machine Approach
**Decision**: Track state (in_table, in_row, in_cell) using boolean flags

**Rationale**:
- Handles nested structures correctly
- Easy to understand and maintain
- Efficient memory usage
- Correctly handles malformed HTML

### 3. Multiple Table Handling
**Decision**: Generate separate CSV files for each table

**Alternatives considered**:
- Combine all tables into one CSV (loses structure)
- Ask user which table to extract (not user-friendly)
- Create sheets in Excel file (requires external library)

**Rationale**:
- Preserves table independence
- Clear, predictable output
- Easy to process programmatically
- Follows principle of least surprise

### 4. URL Fetching
**Decision**: Use urllib.request with custom User-Agent header

**Rationale**:
- Standard library (no dependencies)
- Handles HTTP/HTTPS
- Custom headers prevent blocking
- Good error handling capabilities

### 5. Text Normalization
**Decision**: Clean whitespace with regex, preserve cell structure

**Implementation**:
```python
cell_text = re.sub(r'\s+', ' ', cell_text).strip()
```

**Rationale**:
- Removes extra whitespace from HTML formatting
- Preserves actual spaces in content
- Makes CSV cleaner and more readable

### 6. Encoding Handling
**Decision**: Try UTF-8 first, fallback to Latin-1

**Rationale**:
- UTF-8 is most common modern encoding
- Latin-1 covers most legacy content
- Graceful degradation
- Better than crashing on encoding errors

## Error Handling Strategy

### Input Validation
- Check command line arguments
- Verify file existence
- Validate URL format

### Network Errors
- Timeout after 10 seconds
- Handle HTTP errors gracefully
- Informative error messages

### Parsing Errors
- Continue on malformed HTML
- Skip empty tables/rows
- Report issues to stderr

### Output Errors
- Handle file write failures
- Check disk space implicitly
- Preserve partial results

## Performance Considerations

### Memory Usage
- Stream-based parsing (HTMLParser)
- Don't load entire table into memory before writing
- Actually, we do load tables into memory, but could be optimized for very large tables

### Speed
- Single-pass parsing
- Minimal string operations
- Direct CSV writing

### Scalability
- Works with any number of tables
- Handles large tables
- Efficient with multiple small tables

## Testing Strategy

### Unit Testing (Manual)
Tested with:
- Empty tables
- Single row tables
- Tables with headers only
- Mixed th/td elements
- Nested tables
- Malformed HTML

### Integration Testing
Tested with:
- Wikipedia pages (real-world data)
- Local HTML files
- URLs with redirects
- Different encodings

### Edge Cases
- No tables in HTML
- Empty HTML file
- Network timeouts
- Invalid URLs
- Permission errors

## Code Quality Standards

### Comments
- Docstrings for all functions and classes
- Inline comments for complex logic
- Clear variable names (self-documenting)

### Style
- PEP 8 compliant
- Consistent indentation (4 spaces)
- Maximum line length: ~100 characters
- Clear function boundaries

### Error Messages
- User-friendly
- Actionable (suggest solutions)
- Include context (filename, line number if relevant)

## Future Enhancements (Not Implemented)

### Could Add (with standard library):
1. Command-line options (argparse)
   - Select specific table by index
   - Include/exclude headers
   - Custom delimiter

2. Better colspan/rowspan handling
   - Repeat cell content
   - Or merge cells in CSV

3. Table filtering
   - By size (min/max rows)
   - By content (regex matching)
   - By position (first, last, nth)

4. Format preservation
   - Cell alignment
   - Column widths
   - Font styles (metadata)

### Would Require External Libraries:
1. Excel output (openpyxl)
2. Better HTML parsing (BeautifulSoup)
3. JavaScript rendering (Selenium)
4. Advanced cell merging (pandas)

## Lessons Learned

1. **HTMLParser is powerful**: Event-driven parsing handles edge cases well
2. **State machines are clear**: Boolean flags make logic easy to follow
3. **Error handling matters**: Real-world HTML is messy
4. **Documentation is key**: Good docs make code accessible
5. **Test with real data**: Wikipedia provided excellent test cases

## Compatibility

### Python Versions
- Tested: Python 3.6+
- Should work: Python 3.x
- Won't work: Python 2.x (urllib, HTMLParser syntax)

### Operating Systems
- Linux: ✓
- macOS: ✓
- Windows: ✓
- BSD: ✓ (should work)

### Web Compatibility
- Works with: Static HTML tables
- Doesn't work with: JavaScript-rendered content
- Workaround: Download HTML after JS execution
