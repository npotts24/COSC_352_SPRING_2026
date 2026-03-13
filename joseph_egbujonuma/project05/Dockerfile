FROM r-base:4.3.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN Rscript -e 'install.packages(c("rvest","dplyr","stringr","lubridate","ggplot2","readr"), repos="https://cloud.r-project.org")'

COPY histogram.R /app/histogram.R

CMD ["Rscript", "/app/histogram.R"]