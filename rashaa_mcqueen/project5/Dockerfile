FROM r-base:latest

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY histogram.R /app/

RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2','lubridate','httr'), repos='https://cloud.r-project.org')"

CMD ["Rscript", "histogram.R"]