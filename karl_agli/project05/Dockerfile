# Dockerfile for Project 5 - Baltimore Homicide Data Analysis
# Builds an R environment and runs histogram.R

FROM r-base:4.3.2

# Install system dependencies for R packages (rvest needs libxml2, libcurl)
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

# Install required R packages from CRAN
RUN Rscript -e "\
  install.packages(c( \
    'rvest', \
    'dplyr', \
    'stringr', \
    'ggplot2', \
    'lubridate', \
    'tidyr' \
  ), repos='https://cloud.r-project.org', quiet=TRUE) \
"

# Copy R script into the container
WORKDIR /app
COPY histogram.R .

# Run the script when the container starts
CMD ["Rscript", "histogram.R"]
