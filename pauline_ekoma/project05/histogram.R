library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)
library(lubridate)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

#read page
page <- read_html(url)
#extract all table rows
rows <- page %>%
    html_elements("table tr")
#extract text from rows
raw_text <- rows %>%
    html_text(trim=TRUE)
#extract age using regex (age appears inside parenthese)
ages <- str_extract(raw_text, "\\((\\d+)\\)") %>%
    str_remove_all("[()]") %>%
    as.numeric()

ages <- ages[!is.na(ages)]
df <- data.frame(age=ages)

#create histogram bins (5-year bins)
df <- df %>%
    mutate(age_bin = cut(age, breaks = seq(0, 100, by = 5), right = FALSE))
    
#tabular histogram output
hist_table <- df %>%
    group_by(age_bin) %>%
    summarise(count=n()) %>%
    filter(count>0)

#print table to stdout
cat("Victim Age Distribution (5-year bins) - 2025\n")
cat("------------------------------------------------\n")
print(hist_table)

#plot histogram
plot <- ggplot(df, aes(x=age)) +
    geom_histogram(binwidth=5, boundary=0, fill="blue", color="white") +
    labs(title="Distribution of Baltimore Homicide Victim Ages (2025)",
    x="Age",
    y="Number of Victims") +
    theme_minimal()

#save plot
ggsave(filename="/app/histogram.png", plot=plot, width=8, height=5)