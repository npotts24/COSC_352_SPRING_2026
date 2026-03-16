library(shiny)
library(ggplot2)
library(dplyr)

# Sample homicide-style dataset
data <- data.frame(
  year = sample(2018:2024, 200, replace = TRUE),
  age = sample(15:70, 200, replace = TRUE),
  method = sample(c("Shooting","Stabbing","Other"),200,replace=TRUE),
  cleared = sample(c("Yes","No"),200,replace=TRUE)
)

ui <- fluidPage(

  titlePanel("Baltimore Homicide Analysis Dashboard"),

  sidebarLayout(
    sidebarPanel(

      selectInput("year","Select Year:",
                  choices = sort(unique(data$year)),
                  selected = unique(data$year)[1]),

      sliderInput("age","Victim Age Range:",
                  min=min(data$age),
                  max=max(data$age),
                  value=c(20,60))

    ),

    mainPanel(

      h3("Summary Statistics"),
      textOutput("total"),
      textOutput("clearance"),

      plotOutput("methodPlot"),
      plotOutput("agePlot")

    )
  )
)

server <- function(input, output) {

  filtered <- reactive({

    data %>%
      filter(year == input$year,
             age >= input$age[1],
             age <= input$age[2])

  })

  output$total <- renderText({
    paste("Total Homicides:", nrow(filtered()))
  })

  output$clearance <- renderText({

    rate <- mean(filtered()$cleared=="Yes")*100
    paste("Clearance Rate:", round(rate,2),"%")

  })

  output$methodPlot <- renderPlot({

    ggplot(filtered(), aes(method)) +
      geom_bar(fill="red") +
      labs(title="Homicides by Method",
           x="Method",
           y="Count")

  })

  output$agePlot <- renderPlot({

    ggplot(filtered(), aes(age)) +
      geom_histogram(bins=20, fill="steelblue") +
      labs(title="Victim Age Distribution",
           x="Age",
           y="Frequency")

  })

}

shinyApp(ui, server)