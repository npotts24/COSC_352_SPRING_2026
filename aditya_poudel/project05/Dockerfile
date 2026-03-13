FROM r-base:4.4.2

# System dependencies for rvest/xml2 and ggplot rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN packages (keep it explicit/reproducible)
RUN R -e "install.packages(c('rvest','dplyr','stringr','lubridate','ggplot2','readr'), repos='https://cloud.r-project.org')"

WORKDIR /work

# Copy only the script (repo will also be mounted by run.sh)
COPY histogram.R /work/histogram.R

CMD ["Rscript", "histogram.R"]