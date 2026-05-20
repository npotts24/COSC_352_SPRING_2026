FROM rocker/shiny:latest

# System dependencies for packages
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app.R /app/

RUN R -e "install.packages(c('shiny','shinydashboard','dplyr','stringr','lubridate','rvest','ggplot2','plotly','DT'), repos='https://cloud.r-project.org')"

EXPOSE 3838
CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]
