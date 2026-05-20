FROM r-base:4.3.3

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev

RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2'), repos='https://cloud.r-project.org/')"

WORKDIR /app

COPY histogram.R .

CMD ["Rscript", "histogram.R"]