FROM r-base:4.3.3

RUN apt-get update && apt-get install -y \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages(c('rvest','dplyr','stringr','lubridate'), repos='https://cloud.r-project.org', quiet=TRUE)"

WORKDIR /app
COPY histogram.R .

CMD ["Rscript", "histogram.R"]
