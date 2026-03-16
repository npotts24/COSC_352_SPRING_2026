FROM rocker/r-ver:4.3.2

# Install system dependencies needed for rvest
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('rvest','dplyr','stringr','lubridate','ggplot2'), repos='https://cloud.r-project.org/')"

WORKDIR /app

COPY histogram.R /app/histogram.R

CMD ["Rscript", "histogram.R"]
