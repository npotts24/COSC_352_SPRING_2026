FROM r-base:4.3.3

# System dependencies for rvest / xml2 / curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN packages (pinned via CRAN snapshot for reproducibility)
RUN Rscript -e " \
  options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/2024-06-01')); \
  install.packages(c('rvest','dplyr','stringr','ggplot2','lubridate','httr'), \
                   dependencies = TRUE) \
"

# Create output directory
RUN mkdir -p /output

COPY histogram.R /app/histogram.R

WORKDIR /app

CMD ["Rscript", "histogram.R"]
