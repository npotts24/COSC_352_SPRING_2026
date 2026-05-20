2025 Baltimore Homicide Age Analysis
COSC 352 – Project 05
Grace Joseph
________________________________________
Overview

This project scrapes publicly available homicide data from the 2025 Baltimore City Homicide List and analyzes the age distribution of victims.

The goal of this assignment is to demonstrate:
•	Web scraping using rvest
•	HTML table parsing
•	Data cleaning and transformation
•	Data visualization using ggplot2
•	Reproducible execution using Docker

The final output includes both a histogram visualization and a grouped frequency table of victim ages.
________________________________________
DATA SOURCE

The dataset is scraped directly from:
https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html

The webpage contains a structured HTML table listing homicide victims along with additional information such as:
•	Incident number
•	Date
•	Location
•	Age
•	Notes

The project extracts and analyzes the Age column (Column 4).
________________________________________
METHOLOGY

1. Web Scraping

The webpage is accessed using:
read_html()
html_table()
The first table on the page contains the homicide records.

2. DATA CLEANING

The Age column required cleaning before analysis:
•	Removed blank entries
•	Removed entries containing "mo" (infants listed in months)
•	Converted values to numeric
•	Removed NA values after conversion
This ensures only valid numeric ages are included in the analysis.

3. VISUALIZATION
A histogram is created using ggplot2 with a bin width of 5 years to display the distribution of victim ages.
Additionally, a grouped frequency table is generated using:
cut()
count()
to provide a tabular histogram.
________________________________________
RESULTS

The distribution shows:
•	The highest concentration of victims falls between 25–35 years old
•	The majority of victims are between 20–40 years old
•	Very few victims are above age 60

This indicates a strong concentration of homicides among young adults.
________________________________________
RUNNING  PROJECT

This project is containerized using Docker to ensure reproducibility.

Build and Run using entry:
.\run.sh

The container will:
1.	Scrape the webpage
2.	Clean the data
3.	Generate a histogram
4.	Print a grouped frequency table
________________________________________
TECHNOLOGIES USED

•	R (4.3.2)
•	rvest
•	dplyr
•	stringr
•	ggplot2
•	Docker
________________________________________
REPRODUCTIBILITY

All dependencies are installed within the Docker container.

No local R environment configuration is required.

The analysis is fully reproducible by rebuilding and running the Docker image.
________________________________________
CONCLUSION

This project demonstrates a complete data pipeline:
Web scraping → Parsing → Cleaning → Analysis → Visualization → Containerization

It highlights how real-world web data can be transformed into structured insights using reproducible computational tools.
