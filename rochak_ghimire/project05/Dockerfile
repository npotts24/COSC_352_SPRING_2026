FROM r-base:4.3.2

LABEL maintainer="Rochak Ghimire"
LABEL description="Baltimore Homicide Multi-Year Trend Analysis"

RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c( \
    'rvest','dplyr','stringr','lubridate', \
    'ggplot2','tidyr','purrr'), \
    repos='https://cloud.r-project.org')"

WORKDIR /app

COPY histogram.R .

CMD ["Rscript", "histogram.R"]
