FROM r-base:4.3.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages from CRAN
RUN R -e "install.packages(c('rvest', 'dplyr', 'stringr', 'lubridate'), repos='https://cran.rstudio.com/')"

# Set working directory
WORKDIR /app

# Copy R script
COPY histogram.R /app/

# Make script executable
RUN chmod +x histogram.R

# Run the script
CMD ["Rscript", "histogram.R"]
