library(shiny)
library(leaflet)
library(DT)
library(dplyr)
library(lubridate)

metadata_raw <- readRDS("~/Desktop/IOF/STAT545/PartB/sampling_qc_app/metadata_raw.rds")
sample_data <- readRDS("~/Desktop/IOF/STAT545/PartB/sampling_qc_app/sample_data.rds")

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
               div(class = "help-text", "Use the dropdown to select a month and see sampling details for each site."),
               checkboxInput("color_code", "Color-code sites by sampling completeness", FALSE)
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

server <- function(input, output, session) {
  
  # Update month dropdown with abbreviated month choices
  observe({
    updateSelectInput(session, "month", choices = c("May", "Jun", "Jul", "Aug", "Sep"))
  })
  
  # Reactive data based on month selection for map plotting
  reactive_data <- reactive({
    sample_data %>% filter(month == input$month)
  })
  
  # Reactive data for filtering the raw metadata table
  reactive_raw_data <- reactive({
    metadata_raw %>% filter(month == input$month)
  })
  
  # Determine marker color based on sampling_completeness
  marker_colors <- reactive({
    if (input$color_code) {
      reactive_data() %>%
        mutate(color = case_when(
          sampling_completeness == "Complete" ~ "#28a745",  # Green
          sampling_completeness %in% c("Undersampled", "Oversampled") ~ "#dc3545",  # Red
          TRUE ~ "#6c757d"  # Default: Grey for unknown
        ))
    } else {
      reactive_data() %>% mutate(color = "#2c3e50")  # Default dark blue
    }
  })
  
  # Render Map
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      fitBounds(-57, 46, -53, 48) # Approximate coordinates for south coast of Newfoundland
  })
  
  # Update Map with filtered data
  observe({
    map_data <- marker_colors()
    
    # Update map markers with color-coding
    leafletProxy("map", data = map_data) %>%
      clearMarkers() %>%
      addCircleMarkers(
        ~lon, ~lat, 
        popup = ~paste0("Site: ", site_id,
                        "<br>Replicates at surface: ", Surface,
                        "<br>Replicates at 10m: ", replicates_10m,
                        "<br>Replicates at 100m: ", replicates_100m,
                        "<br>Sampling completeness: ", sampling_completeness),
        layerId = ~site_id,  # Assign each marker a unique layerId based on site_id
        radius = 5,
        color = ~color,  # Dynamically set color
        fillOpacity = 0.7
      )
  })
  
  # Highlight samples in the data table when a site is selected
  observeEvent(input$map_marker_click, {
    click <- input$map_marker_click
    if (!is.null(click)) {
      # Find the site_id for the clicked marker
      selected_site_id <- reactive_data() %>%
        filter(lon == click$lng & lat == click$lat) %>%
        pull(site_id)
      
      # Get row indices for the matching site_id in the raw metadata table
      selected_rows <- which(reactive_raw_data()$site_id == selected_site_id)
      
      # Update the DataTable selection
      proxy <- dataTableProxy("data_table")
      selectRows(proxy, selected_rows)
    }
  })
  
  # Display site information upon selection
  output$siteInfo <- renderText({
    req(input$map_marker_click)
    click <- input$map_marker_click
    
    # Find the clicked site based on lat/lng
    site_info <- reactive_data() %>%
      filter(lon == click$lng & lat == click$lat)
    
    paste0(
      "Site: ", site_info$site_id,
      "\nReplicates at surface: ", site_info$Surface,
      "\nReplicates at 10m: ", site_info$replicates_10m,
      "\nReplicates at 100m: ", site_info$replicates_100m,
      "\nSampling completeness: ", site_info$sampling_completeness
    )
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
