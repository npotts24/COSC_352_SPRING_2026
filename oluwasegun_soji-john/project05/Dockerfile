FROM r-base:4.4.1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2'), repos='https://cloud.r-project.org')"

COPY histogram.R /app/histogram.R

CMD ["Rscript", "histogram.R"]
