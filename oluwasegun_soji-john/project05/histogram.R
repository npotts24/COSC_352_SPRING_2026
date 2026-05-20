suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(ggplot2)
})

# Required year (2025) + one extra year for more context.
sources <- c(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html"
)

read_one_year <- function(url, year_num) {
  cat("Reading", year_num, "from", url, "\n")
  page <- tryCatch(read_html(url), error = function(e) NULL)

  if (is.null(page)) {
    warning("Could not open page: ", url, call. = FALSE)
    return(data.frame())
  }

  rows <- page %>%
    html_elements("table tr") %>%
    html_text2() %>%
    str_squish()

  rows <- rows[str_detect(rows, "^(\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\b")]

  if (length(rows) == 0) {
    warning("No rows matched expected format for year ", year_num, call. = FALSE)
    return(data.frame())
  }

  data.frame(
    case_number = str_match(rows, "^((?:\\d{3}|XXX))")[, 2],
    date_text = str_match(rows, "^(?:\\d{3}|XXX)\\s+(\\d{1,2}/\\d{1,2}/\\d{2})")[, 2],
    name = str_trim(str_match(
      rows,
      "^(?:\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\s+(.+?)\\s+\\d{1,3}\\b"
    )[, 2]),
    age = as.integer(str_match(
      rows,
      "^(?:\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\s+.+?\\s+(\\d{1,3})\\b"
    )[, 2]),
    year = year_num,
    stringsAsFactors = FALSE
  ) %>%
    mutate(date = as.Date(date_text, format = "%m/%d/%y")) %>%
    filter(!is.na(date), !is.na(name), !is.na(age), age > 0, age < 110) %>%
    distinct(year, case_number, .keep_all = TRUE)
}

all_rows <- bind_rows(
  lapply(names(sources), function(y) read_one_year(sources[[y]], as.integer(y)))
)

if (nrow(all_rows) == 0) {
  stop("No data parsed. Check internet access or page format.")
}

breaks <- seq(0, 100, by = 5)
hist_data <- hist(all_rows$age, breaks = breaks, right = FALSE, plot = FALSE)

table_output <- data.frame(
  Age_Bin = paste0(
    sprintf("%02d", head(hist_data$breaks, -1)),
    "-",
    sprintf("%02d", tail(hist_data$breaks, -1) - 1)
  ),
  Count = hist_data$counts,
  stringsAsFactors = FALSE
)

cat("\nBaltimore Homicide Victim Age Histogram (2024 + 2025)\n")
cat("=====================================================\n")
cat("Total parsed victims:", nrow(all_rows), "\n\n")
print(table_output, row.names = FALSE)

plot <- ggplot(all_rows, aes(x = age)) +
  geom_histogram(
    binwidth = 5,
    boundary = 0,
    closed = "left",
    fill = "#2b7a78",
    color = "white"
  ) +
  labs(
    title = "Baltimore Homicide Victim Age Distribution (2024 + 2025)",
    x = "Victim age",
    y = "Number of victims (5-year bins)"
  ) +
  theme_minimal()

ggsave("victim_age_histogram.png", plot, width = 9, height = 6, dpi = 300)
cat("\nSaved: victim_age_histogram.png\n")
