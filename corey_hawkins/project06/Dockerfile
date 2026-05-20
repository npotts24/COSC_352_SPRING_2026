# The 'rocker/shiny' image already includes Shiny server.

FROM rocker/shiny:4.3.2

# Set the working directory in the container

WORKDIR /srv/shiny-server/

# Install R packages required for the Shiny app.

# Make sure to update this list based on your actual dependencies.

RUN apt-get update && apt-get install -y --no-install-recommends \

    pandoc \

    && rm -rf /var/lib/apt/lists/*

# Install R packages using install.packages()

RUN R -e "install.packages(c('shiny', 'shinydashboard', 'dplyr', 'lubridate', 'ggplot2', 'plotly', 'readr', 'DT', 'leaflet'), repos = 'http://cran.us.r-project.org')"

# Copy the Shiny application files into the container

COPY . /srv/shiny-server/
# Expose the port Shiny Server runs on

EXPOSE 3838

# Command to run the Shiny Server when the container starts

CMD ["/usr/bin/shiny-server"]
