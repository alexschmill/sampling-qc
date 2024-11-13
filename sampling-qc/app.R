library(shiny)
library(leaflet)
library(DT)
library(dplyr)

# UI
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { font-family: Arial, sans-serif; }
      .container { max-width: 90%; margin-top: 20px; }
      #siteInfo { margin-top: 15px; font-size: 1.1em; font-weight: bold; }
      .title-panel { font-size: 1.5em; font-weight: bold; color: #2c3e50; text-align: center; }
      .help-text { font-size: 0.9em; color: #7f8c8d; }
    "))
  ),
  
  div(class = "container",
      div(class = "title-panel", "Sample Coverage Exploration"),
      
      fluidRow(
        column(3,
               selectInput("month", "Select Month", choices = NULL),
               div(class = "help-text", "Use the dropdown to select a month and see sampling details for each site.")
        ),
        column(9,
               leafletOutput("map", height = "500px")
        )
      ),
      
      fluidRow(
        column(12,
               textOutput("siteInfo"),
               DTOutput("data_table")
        )
      )
  )
)

# Server
server <- function(input, output, session) {
  
  # Update month dropdown with ordered month choices from May to September
  observe({
    updateSelectInput(session, "month", choices = c("May", "June", "July", "August", "September"))
  })
  
  # Reactive data based on month selection for map plotting
  reactive_data <- reactive({
    sample_data %>% filter(month == input$month)
  })
  
  # Reactive data for filtering the raw metadata table
  reactive_raw_data <- reactive({
    metadata_raw %>% filter(month == input$month)
  })
  
  # Render Map
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      fitBounds(-57, 46, -53, 48) # Approximate coordinates for south coast of Newfoundland
  })
  
  # Update Map with filtered data
  observe({
    map_data <- reactive_data()
    
    # Only proceed if map_data is not empty
    if (nrow(map_data) > 0) {
      leafletProxy("map", data = map_data) %>%
        clearMarkers() %>%
        addCircleMarkers(
          ~lon, ~lat, 
          popup = ~paste0("Site: ", site_id,
                          "<br>Replicates at 10m: ", replicates_10m,
                          "<br>Replicates at 100m: ", replicates_100m),
          layerId = ~site_id,  # Assign each marker a unique layerId based on site_id
          radius = 5,
          color = "#2c3e50",  # Dark blue color for markers
          fillOpacity = 0.7
        )
    } else {
      print("No data available for the selected month.")  # Debugging message
    }
  })
  
  # Display site information upon selection
  output$siteInfo <- renderText({
    req(input$map_marker_click)
    click <- input$map_marker_click
    
    # Find the clicked site based on lat/lng, in case id is unavailable
    site_info <- reactive_data() %>%
      filter(lon == click$lng & lat == click$lat)
    
    if (nrow(site_info) > 0) {
      paste0(
        "Site: ", site_info$site_id,
        "\nReplicates at 10m: ", site_info$replicates_10m,
        "\nReplicates at 100m: ", site_info$replicates_100m
      )
    } else {
      "No data available for this site."
    }
  })
  
  # Render dynamic data table filtered by selected month and show all rows
  output$data_table <- renderDT({
    datatable(
      reactive_raw_data(),
      options = list(pageLength = -1)  # Show all rows by default
    )
  })
}

# Run the App
shinyApp(ui, server)
