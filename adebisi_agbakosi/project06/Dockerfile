FROM rocker/shiny:latest

# Install system dependencies for R packages (xml2 is needed for rvest)
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('shinydashboard', 'tidyverse', 'plotly', 'DT', 'rvest'), repos='https://cran.rstudio.com/')"

# Copy app into the image
COPY app.R /srv/shiny-server/

# Expose port
EXPOSE 3838

# Start shiny server
CMD ["/usr/bin/shiny-server"]