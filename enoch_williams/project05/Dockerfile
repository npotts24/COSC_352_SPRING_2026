FROM r-base:4.3.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /project

# Copy the R script into the container
COPY histogram.R /project/histogram.R

# Install R packages from CRAN
RUN R -e "install.packages(c('rvest', 'dplyr', 'stringr', 'ggplot2', 'lubridate', 'tidyr'), repos='http://cran.r-project.org')"

# Make script executable
RUN chmod +x /project/histogram.R

# Run the script when container starts
CMD ["Rscript", "/project/histogram.R"]
