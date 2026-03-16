FROM r-base:4.3.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages(c('shiny', 'shinydashboard', 'rvest', 'dplyr', 'stringr', 'ggplot2', 'lubridate', 'plotly', 'DT'), repos='https://cloud.r-project.org/', quiet=TRUE)"

WORKDIR /app
COPY app.R .

EXPOSE 3838

CMD ["Rscript", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]
