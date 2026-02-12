HTML Table Parser

This project contains a Python script that extracts all HTML tables from a webpage (or local HTML file) and saves them as CSV files. It is Dockerized for easy execution.

Files

table_to_DFS_to_CSV.py — Python script that parses HTML tables.
Dockerfile — Builds a Docker container to run the script.
.gitignore — Ignores temporary and unnecessary files.
How to Run

1. Build Docker Image

docker build -t html_table_parser .
docker run table-parser https://en.wikipedia.org/wiki/Comparison_of_programming_languages
