FROM r-base:4.3.2

WORKDIR /app

# Install system dependencies needed for scraping
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('httr','rvest','xml2','dplyr','ggplot2','stringr'), repos='https://cloud.r-project.org/')"

COPY histogram.R /app/

CMD ["Rscript", "histogram.R"]