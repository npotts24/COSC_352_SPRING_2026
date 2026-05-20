# Install packages if missing (for safety inside Docker)
packages <- c("rvest", "dplyr", "stringr", "ggplot2", "lubridate", "httr")
installed <- rownames(installed.packages())
for (p in packages) {
  if (!(p %in% installed)) {
      install.packages(p, repos="https://cloud.r-project.org")
        }
        }

        library(rvest)
        library(dplyr)
        library(stringr)
        library(ggplot2)
        library(lubridate)
        library(httr)

        url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

        cat("Fetching data...\n")

        page <- read_html(url)

        tables <- html_table(page, fill = TRUE)

        if (length(tables) == 0) {
          stop("No tables found on page.")
          }

          data <- tables[[1]]

          # Clean column names
          colnames(data) <- make.names(colnames(data))

          # Extract Age (age is usually inside victim name column)
          data$Age <- str_extract(data[[1]], "\\d{1,2}")

          data$Age <- as.numeric(data$Age)

          # Remove NA ages
          data <- data %>% filter(!is.na(Age))

          cat("Total victims with age data:", nrow(data), "\n\n")

          # ---- HISTOGRAM STATISTIC ----
          # Age Distribution (interesting demographic insight)

          hist_data <- hist(data$Age, plot = FALSE, breaks = seq(0, 80, by = 5))

          # Print tabular histogram to stdout
          hist_table <- data.frame(
            AgeRange = paste(head(hist_data$breaks, -1),
                               tail(hist_data$breaks, -1),
                                                  sep = "-"),
                                                    Count = hist_data$counts
                                                    )

                                                    print(hist_table)

                                                    # Save plot
                                                    plot <- ggplot(data, aes(x = Age)) +
                                                      geom_histogram(binwidth = 5, fill = "red", color = "black") +
                                                        labs(
                                                            title = "Distribution of Victim Ages (Baltimore 2025)",
                                                                x = "Age",
                                                                    y = "Number of Victims"
                                                                      ) +
                                                                        theme_minimal()

                                                                        ggsave("histogram.png", plot, width = 8, height = 6)

                                                                        cat("\nHistogram saved as histogram.png\n")