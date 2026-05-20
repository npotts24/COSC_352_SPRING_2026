FROM rocker/shiny:4.3.2

# Install system dependencies for web scraping
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the Shiny app into the container
COPY app.R /app/app.R

# Install additional R packages from CRAN
RUN R -e "install.packages(c('shinydashboard', 'plotly', 'DT', 'dplyr', 'ggplot2', 'lubridate', 'rvest', 'stringr', 'tidyr'), repos='http://cran.r-project.org', dependencies=TRUE)" && \
    echo "Packages installed successfully"

# Expose port 3838 for Shiny
EXPOSE 3838

# Run the Shiny app
CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]