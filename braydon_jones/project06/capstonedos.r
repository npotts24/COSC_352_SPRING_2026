# Part 1 Pipeline
library(shiny)
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
        year = as.numeric(str_extract(date, "\\d{4}")),
        method = case_when(
            str_detect(str_to_lower(data), "shot|shooting|gun") ~ "Shooting",
            str_detect(str_to_lower(data), "stab") ~ "Stabbing",
            str_detect(str_to_lower(data), "blunt") ~ "Blunt Force Trauma",
            str_detect(str_to_lower(data), "strangle|asphyxiation") ~ "Strangulation",
            TRUE ~ "Unknown"
        )
    ) %>%
    filter(!is.na(year))

ui <- fluidPage(
    sidebarLayout(
        sidebarPanel(
            h4("Years"),
            selectInput(
                "year", "Year",
                choices = sort(unique(extracted$year)),
                selected = max(extracted$year),
                multiple = TRUE
            ),
            h4("Homicide Method"),
            checkboxGroupInput(
                "method", "Homicide Method",
                choices = sort(unique(extracted$method)),
                selected = unique(extracted$method)
            )
        ),
        mainPanel(
            plotOutput("yearPlot"),
            plotOutput("methodPlot")
        )
    )
)

server <- function(input, output, session) {
    filtered <- reactive({
        extracted %>%
            filter(
                year %in% input$year,
                method %in% input$method
            )
    })
    
    # Creates the histogram graph
    output$yearPlot <- renderPlot({
        ggplot(extracted, aes(x=year)) + 
        geom_histogram(binwidth = 1, fill = "blue", color = "black") +
            labs(
                title = "Homicides Per Year in Baltimore",
                x = "Year",
                y = "Number of Homicides"
            ) +
            theme_minimal()
    })

    # Creates bar chart
    output$methodPlot <- renderPlot({
        ggplot(filtered(), aes(x=method)) + 
        geom_bar(fill = "red") +
            labs(
                title = "Homicide Methods",
                x = "Method",
                y = "Count"
            ) +
            theme_minimal()
    })
}
shinyApp(ui, server)
