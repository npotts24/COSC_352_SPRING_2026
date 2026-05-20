FROM r-base:4.4.1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny', 'shinydashboard', 'dplyr', 'ggplot2', 'plotly', 'DT', 'lubridate'), repos='https://cloud.r-project.org')"

COPY app.R /app/app.R

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app/app.R', host='0.0.0.0', port=3838)"]