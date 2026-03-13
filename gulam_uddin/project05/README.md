Baltimore City Homicide Histogram (2025)
Chosen Statistic

This project analyzes the distribution of Baltimore City homicides by month for the year 2025.

Why This Is Interesting

Seasonal variation in homicide rates can influence police resource allocation. If certain months show spikes in violence, law enforcement agencies can increase patrols and intervention programs during those periods.

Data Source

Data scraped from:
https://chamspage.blogspot.com/

Specifically:
2025 Baltimore City Homicide List

Cleaning Decisions

Parsed dates using lubridate::mdy

Removed rows with invalid or missing dates

Extracted month from parsed date

Grouped incidents by month

How to Run
./run.sh

This will:

Build the Docker container

Run the R script

Print the tabular histogram to stdout

Save histogram.png inside the container

Assumptions

The first HTML table contains the homicide list

The date column contains parsable month/day/year format

Rows with missing dates are excluded