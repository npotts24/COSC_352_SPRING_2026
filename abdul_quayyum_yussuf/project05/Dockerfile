# Dockerfile for Baltimore homicide histogram project

FROM r-base:4.3.3

# install system libraries needed by some R packages
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# install CRAN packages required by the R script
RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2','lubridate','xml2'), repos='https://cloud.r-project.org')" \
    && R -e "stopifnot(require(rvest), require(xml2), require(dplyr), require(stringr), require(ggplot2), require(lubridate))"

# copy the R script into the image
COPY histogram.R /app/histogram.R
WORKDIR /app

# make the script executable (not strictly necessary, we call via Rscript)
RUN chmod +x /app/histogram.R

# default command runs the histogram script
CMD ["Rscript", "/app/histogram.R"]
