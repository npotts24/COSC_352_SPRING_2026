FROM r-base:latest

WORKDIR /app
RUN R -e "install.packages(c('xml2','rvest','dplyr','stringr','lubridate','tidyr','ggplot2','httr'), repos='https://cloud.r-project.org')"

COPY histogram.R /app/histogram.R

# Run the script by default
CMD ["Rscript", "/app/histogram.R"]