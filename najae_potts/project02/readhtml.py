import urllib.request
from html.parser import HTMLParser

# 1. Define your custom parser (same as before)
class DataExtractor(HTMLParser):
    def handle_data(self, data):
        if data.strip():
            print(f"Found Text: {data.strip()}")

# 2. Fetch the website content
url = "https://en.wikipedia.org/wiki/Comparison_of_programming_languages"
try:
    # Adding a User-Agent header helps avoid being blocked by some sites
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        html_content = response.read().decode('utf-8')
except Exception as e:
    print(f"Error fetching page: {e}")
    html_content = ""

# 3. Parse the data
if html_content:
    parser = DataExtractor()
    parser.feed(html_content)

