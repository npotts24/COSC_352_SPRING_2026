# Use the Rocker project R image (stable R version)
FROM rocker/r-ver:4.3.2

# Set working directory
WORKDIR /project

# Install system dependencies required by R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages from CRAN
RUN R --slave -e "install.packages(c('rvest', 'dplyr', 'stringr', 'ggplot2', 'lubridate', 'tidyr'), repos='https://cloud.r-project.org/')"

# Copy the R script into the container
COPY histogram.R /project/histogram.R

# Make the script executable
RUN chmod +x /project/histogram.R

# Set the default command to run the R script
CMD ["Rscript", "/project/histogram.R"]
