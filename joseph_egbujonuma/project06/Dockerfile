FROM rocker/shiny:latest

RUN install2.r --error \
    shinydashboard plotly leaflet dplyr lubridate readr rvest scales

WORKDIR /srv/shiny-server
COPY app.R ./

RUN mkdir -p data

EXPOSE 3838