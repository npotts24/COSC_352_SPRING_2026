
Baltimore Homicide Dashboard

This project is a simple Shiny dashboard for exploring homicide data.
The goal is to help users look at trends in the data.

Features

The dashboard has filters and charts.

Filters
Year range
Victim age

Charts
Homicides by month
Homicides by method

Summary numbers
Total homicides
Clearance rate
Average victim age

How to run

You need Docker installed.

Steps

Open terminal in this folder

Run

./run_dashboard.sh

Then open a browser and go to

http://localhost:3838

Files

app.R
Main dashboard code

Dockerfile
Creates the environment with R and Shiny

run_dashboard.sh
Builds and runs the dashboard

homicide_data.csv
Data used by the dashboard
