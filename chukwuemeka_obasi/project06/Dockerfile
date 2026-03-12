FROM --platform=linux/amd64 rocker/shiny:latest

RUN R -e "install.packages(c('shiny','plotly','dplyr','leaflet','lubridate'), repos='https://cloud.r-project.org/')"

COPY app.R /srv/shiny-server/

EXPOSE 3838