FROM r-base:4.3.2

# Set working directory
WORKDIR /app

# Install system dependencies needed for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('rvest', 'dplyr', 'stringr', 'ggplot2', 'lubridate'), repos='https://cloud.r-project.org/')"

# Copy R script to container
COPY histogram.R /app/

# Make script executable
RUN chmod +x /app/histogram.R

# Run the R script
CMD ["Rscript", "/app/histogram.R"]