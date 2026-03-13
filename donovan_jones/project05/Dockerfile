FROM r-base:latest

RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev

RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2'), repos='https://cloud.r-project.org/')"

WORKDIR /app

COPY histogram.R .

CMD ["Rscript", "histogram.R"]