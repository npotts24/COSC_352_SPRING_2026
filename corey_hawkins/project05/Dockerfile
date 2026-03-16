FROM r-base:latest

# sets the working directory in the container

WORKDIR /app

# run command

RUN R -e "install.packages(c('rvest', 'dplyr', 'ggplot2', 'lubridate', 'stringr'), repos='http://cran.us.r-project.org')"

# copies the R script
COPY histogram.R .

# Command to run the R script when the container launches

CMD ["Rscript", "histogram.R"]
