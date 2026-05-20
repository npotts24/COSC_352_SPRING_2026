FROM rocker/shiny:latest

RUN apt-get update && apt-get install -y \
    libssl-dev libxml2-dev libcurl4-openssl-dev libgdal-dev libfontconfig1-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('shinydashboard', 'plotly', 'dplyr', 'rvest', 'stringr'), repos='https://cran.rstudio.com/')"

RUN rm -rf /srv/shiny-server/*
COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server/

EXPOSE 3838

# Switch back to the standard server mode now that we found the error
CMD ["/usr/bin/shiny-server"]