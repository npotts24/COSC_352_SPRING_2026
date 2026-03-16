# Baltimore City Homicides – Histogram by Day of Week (2025)

## Statistic Chosen
This project analyzes Baltimore City homicides in 2025 and visualizes the number of homicides by day of the week.

## Why This is Interesting
Violent crime often clusters around weekends. By grouping incidents by weekday, we can determine whether homicides are more frequent on Fridays, Saturdays, or Sundays.

## Data Source
Cham's Page Baltimore Homicide Blog (2025 list)

## Cleaning Decisions
- Automatically detected date column
- Removed rows with invalid or missing dates
- Converted dates to weekday using lubridate

## How to Run
Simply execute:

./run.sh

This builds the Docker image and runs the R script automatically.


