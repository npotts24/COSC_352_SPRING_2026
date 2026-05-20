FROM r-base:4.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages('shiny',         repos='https://cloud.r-project.org'); library(shiny)"
RUN R -e "install.packages('shinydashboard',repos='https://cloud.r-project.org'); library(shinydashboard)"
RUN R -e "install.packages('plotly',        repos='https://cloud.r-project.org'); library(plotly)"
RUN R -e "install.packages('DT',            repos='https://cloud.r-project.org'); library(DT)"
RUN R -e "install.packages('rvest',         repos='https://cloud.r-project.org'); library(rvest)"
RUN R -e "install.packages('dplyr',         repos='https://cloud.r-project.org'); library(dplyr)"
RUN R -e "install.packages('tidyr',         repos='https://cloud.r-project.org'); library(tidyr)"
RUN R -e "install.packages('stringr',       repos='https://cloud.r-project.org'); library(stringr)"
RUN R -e "install.packages('lubridate',     repos='https://cloud.r-project.org'); library(lubridate)"
RUN R -e "install.packages('readr',         repos='https://cloud.r-project.org'); library(readr)"

RUN mkdir -p /srv/app
COPY app.R /srv/app/app.R

WORKDIR /srv/app
EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/srv/app', host='0.0.0.0', port=3838)"]