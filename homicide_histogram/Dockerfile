FROM r-base:4.4.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('rvest','dplyr','stringr','lubridate','ggplot2','tidyr'), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY histogram.R /app/histogram.R

CMD ["Rscript", "/app/histogram.R"]
