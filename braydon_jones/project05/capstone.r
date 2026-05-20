library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)

# Reads the html file
html <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
reader <- read_html(html)
rows <- reader %>% html_elements("tr") %>% html_text(trim = TRUE) 
# Extract the data by finding the numbered entries
extracted <- tibble(data = rows) %>%
    mutate(
        date = str_extract(data, "\\b\\w+ \\d{4}\\b"),
        year = str_extract(date, "\\d{4}"),
        year = as.numeric(year)
    ) %>%
    filter(!is.na(year))
# Creates the histogram data
year_number <- extracted %>% count(year)
print(year_number)

# Creates the histogram graph
ggplot(extracted, aes(x=year)) +
    geom_histogram(binwidth = 1, fill = "blue", color = "black") + 
    labs(
        title = "Homicides Per Year in Baltimore",
        x = "Year",
        y = "Number of Homicides"
    ) +
    theme_minimal()