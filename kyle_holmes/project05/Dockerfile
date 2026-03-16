FROM rocker/r-ver:4.4.0

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('rvest', 'dplyr', 'stringr', 'ggplot2', 'lubridate'), repos='https://cloud.r-project.org/')"

COPY . /app

WORKDIR /app

CMD ["Rscript", "histogram.R"]
