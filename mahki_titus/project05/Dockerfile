FROM r-base:4.4.0

WORKDIR /app

COPY histogram.R .

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        ca-certificates \
        libcurl4 \
        libcurl4-openssl-dev \
        libxml2-dev \
        libssl-dev && \
    rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('rvest','dplyr','stringr','ggplot2'), repos='https://cloud.r-project.org')"

CMD ["Rscript", "histogram.R"]


