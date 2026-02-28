FROM rocker/r-ver:4.4.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev

RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2','lubridate'), repos='https://cloud.r-project.org/')"
RUN useradd -m appuser
WORKDIR /app
COPY histogram.R /app/

USER appuser
CMD ["Rscript", "histogram.R"]