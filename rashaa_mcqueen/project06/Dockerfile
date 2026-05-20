FROM rocker/shiny:latest


RUN R -e "install.packages(c('shiny','shinydashboard','plotly','dplyr','leaflet','DT','jsonlite','lubridate'))"


COPY app.R /srv/shiny-server/


EXPOSE 3838


CMD ["/usr/bin/shiny-server"]


