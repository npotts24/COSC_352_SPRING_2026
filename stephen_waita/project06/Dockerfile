FROM rocker/shiny

RUN R -e "install.packages(c('shiny','ggplot2','dplyr'), repos='https://cloud.r-project.org')"

COPY app.R /srv/shiny-server/

EXPOSE 3838