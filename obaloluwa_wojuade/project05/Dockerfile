FROM r-base:4.5.1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -q -e "install.packages(c('rvest','dplyr','stringr','lubridate','ggplot2','tidyr'), repos='https://cloud.r-project.org')"

COPY histogram.R /app/histogram.R

CMD ["Rscript", "histogram.R"]
