library(shiny)
library(tidyverse)

# source functions script
source("ipcc-c-model-functions.R")

# define UI for data upload app ----
ui <- fluidPage(
  
  # app theme and styling
  theme = shinythemes::shinytheme("lumen"),
  shinyWidgets::chooseSliderSkin("Nice"),
  shinybusy::add_busy_spinner(position = "top-right", height = "80px", width = "80px"),
  
  # app title ----
  titlePanel("IPCC (2019) steady state soil C model for Bush Estate Farm"),
  # app subtitle
  h4(HTML("Prepared for MSc Soils and Sustainability Environmental Modelling Practical<br/> ")),
  
  
  # sidebar layout
  sidebarLayout(
    
    # sidebar panel
    sidebarPanel(
      
      titlePanel(title = "Data input"),
      h4(HTML("Baseline scenario (modification optional; defaults to base data)<br/> ")),
      
      # Input: Select a file ----
      fileInput(inputId = "crop_data_bl",
                label = "Crop input data file",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv"),
                placeholder = "bush-estate-barley-crop-data-1980-2070.csv"),
      
      # Input: Select a file ----
      fileInput(inputId = "manure_data_bl",
                label = "Manure input data file",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv"),
                placeholder = "bush-estate-manure-application-1980-2070.csv"),
      
      h4(HTML("Modified scenario (defaults to no scenario)<br/> ")),
      
      # select crop data file for modified scenario
      fileInput(inputId = "crop_data_mod",
                label = "Crop input data file",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv")),
      
      # select crop data file for modified scenario
      fileInput(inputId = "manure_data_mod",
                label = "Manure input data file",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv")),
      
      # run app
      titlePanel(title = "Run model"),
      actionButton(inputId = "run_model",
                   label = "Click to run model"),
      

      h4(HTML(" ")),
      h4(HTML("Export model run as .csv file<br/> ")),
      
      # Output: Download a file ----
      downloadButton(outputId = "download_file",
                     label = "Export .csv",
                     class= "action"),
      
      # CSS style for the download button ----
      tags$style(type='text/css', "#downloadFile { width:100%; margin-top: 35px;}"),
      
    ),
    
    # Main panel for displaying outputs ----
    mainPanel(
      
      h4(HTML("Annual C stock time series for Bush Estate farm")),
      plotOutput(outputId = "main_plot"),
      
      h4(HTML(" ")),
      h4(HTML("C stock changes for Bush Estate farm (all values in tonnes / ha)")),
      tableOutput(outputId = "main_table"),
      
      h4(HTML(" ")),
      h4(HTML("Summarised C stock change per decade for Bush Estate farm")),
      plotOutput(outputId = "second_plot")

    )
  )
)


# Define server logic to read selected file ----
server <- function(input, output) {
  
  model <- reactiveValues(baseline_data = read_rds("model-scenarios/scenario-baseline.rds"),
                          modified_data = NULL,
                          output_csv = NULL)
  
  # only run baseline model if there's been a change to inputs
  # and assume default inputs if any are undefined
  observeEvent(input$run_model, {
    crop_input <- input$crop_data_bl$datapath
    manure_input <- input$manure_data_bl$datapath
    
    if(!is.null(crop_input) | !is.null(manure_input)){
      crop_data <- ifelse(!is.null(crop_input), crop_input, "model-data/bush-estate-barley-crop-data-1980-2070.csv")
      manure_data <- ifelse(!is.null(manure_input), manure_input, "model-data/bush-estate-manure-application-1980-2070.csv")
      
      model$baseline_data <- build_model(clim_data = "model-data/bush-estate-1980-2070-climvars-100-samples.rds",
                                         crop_data = crop_data,
                                         manure_data = manure_data)
    }

  })
  
  # only run this one if there's been a change to both outputs, otherwise leave NULL or in previous version
  observeEvent(input$run_model, {
    crop_input <- input$crop_data_mod$datapath
    manure_input <- input$manure_data_mod$datapath
    
    if(!is.null(crop_input) & !is.null(manure_input)){
      crop_data <- crop_input
      manure_data <- manure_input
      
      model$modified_data <- build_model(clim_data = "model-data/bush-estate-1980-2070-climvars-100-samples.rds",
                                         crop_data = crop_data,
                                         manure_data = manure_data)
    }
  })
  
  # run csv output generator whenever run button is pressed
  observeEvent(input$run_model, {
    model$output_csv <- build_output(df_bl = model$baseline_data,
                                     df_mod = model$modified_data)
  })
  
  output$main_plot <- renderPlot({
    ts_plot(model$baseline_data, model$modified_data)
  })
  
  output$second_plot <- renderPlot({
    stockchange_plot(model$baseline_data, model$modified_data)
  })

  output$main_table <- renderTable({
    stockchange_table(model$baseline_data, model$modified_data)
  })
  
  # Download handler in Server
  output$download_file <- downloadHandler(
    filename = function() {
      paste0("ipcc-c-model-run-", Sys.Date(), ".csv")
    },
    content = function(con) {
      dataProcessed <- build_output(df_bl = model$baseline_data,
                                    df_mod = model$modified_data)
      write_csv(dataProcessed, con)
    }
  )
  
}

# Create Shiny app ----
shinyApp(ui, server)