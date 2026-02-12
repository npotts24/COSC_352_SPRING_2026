def save_table_to_csv(url, filename):
    request = __import__('urllib.request', fromlist=['request'])
    re = __import__('re')


    #getting the website content
   
    headers = {'User-Agent': 'Mozilla/5.0'}
    req = request.Request(url, headers=headers)
    with request.urlopen(req) as response:
        html = response.read().decode('utf-8')

    #finding the tables in the page

    tables = re.findall(r'<table.*?>(.*?)</table>', html, re.DOTALL)
    if not tables:
        print("No tables found on the page.")
        return
   
    #selecting the largest table
   
    main_table = max(tables, key=len)

    #parse the table rows and cells

    rows = re.findall(r'<tr.*?>(.*?)</tr>', main_table, re.DOTALL)
    csv_data = []

    for row in rows:

        #find all headers and/or data cells
        cells = re.findall(r'<t[dh].*?>(.*?)</t[dh]>', row, re.DOTALL)
        #clean the cell content from HTML tags and extra spaces
        clean_cells = [re.sub(r'<.*?>', '', cell).strip() for cell in cells]
        #escape quotes 
        formatted_cells = ["\"" + c.replace('"', '""') + "\"" for c in clean_cells]
        csv_data.append(','.join(formatted_cells))

    with open(filename, 'w', encoding='utf-8') as f:
        f.write('\n'.join(csv_data))

url = "https://en.wikipedia.org/wiki/Comparison_of_programming_languages"
save_table_to_csv(url, 'programming_languages.csv')
print("file has been saved as programming_languages.csv")