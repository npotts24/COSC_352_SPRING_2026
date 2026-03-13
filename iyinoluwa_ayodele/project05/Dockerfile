FROM r-base:latest
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY histogram.R /app/
RUN Rscript -e "install.packages(c('rvest','dplyr','stringr','lubridate','ggplot2'),repos='https://cloud.r-project.org')"
ENTRYPOINT ["Rscript", "histogram.R"]
