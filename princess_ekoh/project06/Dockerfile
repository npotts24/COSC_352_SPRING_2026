FROM r-base:4.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','shinydashboard','plotly','DT','rvest','dplyr','stringr','lubridate','tidyr','ggplot2'), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY app.R /app/app.R

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]
