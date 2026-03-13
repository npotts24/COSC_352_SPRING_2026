# install.packages(c("rvest", "dplyr", "ggplot2", "lubridate", "stringr"))

library(rvest)

library(dplyr)

library(ggplot2)

library(lubridate)

library(stringr)




# Base URL for the blog

BLOG_URL <- "https://chamspage.blogspot.com/"

# Specific year to scrape (minimum requirement)

YEAR_TO_SCRAPE <- "2025"

YEAR_URL <- paste0(BLOG_URL, YEAR_TO_SCRAPE, "/01/", YEAR_TO_SCRAPE)

#  Data Scraping and Parsing 

scrape_homicide_data <- function(url) {

  cat("Scraping data from:", url, "\n")

  

  # Read the HTML content of the page

  page <- read_html(url)

  
  # Get all tables on the page

  tables <- page %>% html_nodes("table")

  homicide_data_raw <- NULL


  # sifts through tables to find the one with homicide data

  for (i in 1:length(tables)) {

    table_content <- tables[[i]] %>% html_table(fill = TRUE)

    
