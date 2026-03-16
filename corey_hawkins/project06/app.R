library(shiny)

library(shinydashboard)

library(dplyr)

library(lubridate)

library(ggplot2)

library(plotly)

library(readr)

library(DT)

library(leaflet)

#  Data Loading and Preparation 

tryCatch({

  homicide_data_full <- readRDS("homicide_data.rds")

}, error = function(e) {

  # Fallback or error handling if the file isn't found

  message("Error loading homicide_data.rds: ", e$message)

  message("Creating dummy data for demonstration purposes.")

  set.seed(123) # for reproducibility of dummy data

  num_records <- 100

  homicide_data_full <- data.frame(

    CaseNumber = 1:num_records,

    Date = sample(seq(as.Date('2018-01-01'), as.Date('2023-12-31'), by="day"), num_records, replace = TRUE),

    VictimAge = sample(15:75, num_records, replace = TRUE),

    VictimGender = sample(c("Male", "Female", "Unknown"), num_records, replace = TRUE, prob = c(0.6, 0.35, 0.05)),

    VictimRace = sample(c("Black", "White", "Hispanic", "Other"), num_records, replace = TRUE, prob = c(0.7, 0.2, 0.05, 0.05)),

    Method = sample(c("Shooting", "Stabbing", "Blunt Force", "Strangulation", "Other"), num_records, replace = TRUE, prob = c(0.6, 0.2, 0.1, 0.05, 0.05)),

    Location_Neighborhood = sample(paste0("Neighborhood_", 1:10), num_records, replace = TRUE),

    Location_District = sample(paste0("District_", 1:5), num_records, replace = TRUE),

    Status = sample(c("Closed", "Open", "Unfounded"), num_records, replace = TRUE, prob = c(0.7, 0.25, 0.05)),

    CCTV_Coverage = sample(c("Yes", "No"), num_records, replace = TRUE, prob = c(0.4, 0.6))

  ) %>%

    arrange(Date) %>%

    mutate(

      Year = year(Date),

      Month = month(Date, label = TRUE, abbr = FALSE),

      DayOfWeek = wday(Date, label = TRUE, abbr = FALSE)

    )

  # Ensure the dummy data has latitude/longitude for map

  homicide_data_full$Latitude <- runif(num_records, 39.2, 39.35)

  homicide_data_full$Longitude <- runif(num_records, -76.7, -76.5)

})

# Ensure Date column is in Date format

homicide_data_full$Date <- as.Date(homicide_data_full$Date)

# Prepare for filters

available_years <- sort(unique(year(homicide_data_full$Date)))

available_
