# CEDAR application, using R Shiny
# server.R  
# data and processing

#' @import htmlwidgets
#' @import shiny
#' @import plyr
#' @import ggplot2


#library(htmlwidgets)
#library(cedar)
#library(shiny)
#library(plyr)

# change file size limit to 50mb
options(shiny.maxRequestSize = 50*1024^2)

# see the file global.R, which creates starting values for each new session of this shiny app 
# TODO : put this in global.R?

# gm <- mapper(x=d, lensefun=simple_lense, partition_count=NULL, overlap=NULL, partition_method="single", index_method="gap", lenseparam="rw")

####### server
shinyServer(function(input, output, session) {

  # observers, selections
  selectedDataSet <- observe({
    input$dataSelection
    if(is.null(input$dataSelection)){
      d <<- datasets[[1]] }
    else {
      d <<- datasets[[input$dataSelection]] }
    updateCheckboxGroupInput(session, inputId = "selectedColumns", choices = names(d), selected = names(d), inline=TRUE)
    updateSelectInput(session, inputId = "selectedVar",choices = names(d))
    updateSelectInput(session, inputId = "filterVar",  choices = names(d))
    updateSelectInput(session, inputId = "lense2filterVar",  choices = names(d))
    return(d)
  })
  
  #select columns to analyze
  observe({
    input$selectedColumns
    updateSelectInput(session, inputId = "filterVar",  choices = input$selectedColumns)
    updateSelectInput(session, inputId = "lense2filterVar",  choices = input$selectedColumns)
    
  })
  
  # observe({
  #   input$factorTextData
  #   if( input$factorTextData){
  #     updateCheckboxGroupInput(session, inputId = "selectedColumns", choices = names(d), selected = names(d[, sapply(d, is.numeric)]), inline=TRUE)
  #   }
  #  })
  
  newData <- observeEvent(input$uploadDataAction,{
    inFile <- input$file1
    if (is.null(inFile))
      return(NULL)
    dataName = input$newDataName
    newData <- read.csv(inFile$datapath, header = input$header,
             sep = input$sep, quote = input$quote, stringsAsFactors = FALSE)

    
    datasets[[dataName]] <<- newData
    dataChoices <<- names(datasets)
    updateSelectInput(session, inputId = "dataSelection",choices = names(datasets))
    updateCollapse(session, "uploadDataCollapse", close = "Click to Upload Data")
  })
  
  
  
  output$downloadMapper <- downloadHandler(
    filename = function() { paste(input$dataSelection, '.mapper', '.rds', sep='') },
    content = function(file) {
      saveRDS(gm, file=file)
    }
  )
  
  # these function interrogate the 'd' data object which is not the same as the datamapper data gm$d, but it used when the button is pressed
  selectedDataSet <- eventReactive(input$dataSelection,{d})
  dataRowCount <- eventReactive(input$dataSelection, { return(nrow(d))})
  dataVarCount <- eventReactive(input$dataSelection, { length(names(d))})
  
  # this sends an array of means for each node,
  # from the gm$d data frame column
  # of the selected variable to Shiny via the session object
  
  # selectedVar ==> color and data exploration variable 
  selectedVariable <- reactive({ 
    if(is.null(input$selectedVar)){ v = colnames(selectedDataSet())[1]}
    else{ v = input$selectedVar}
    return(v)
  })
  
  
  # when a var is selected, save if it's continuos or categorical
  # future: change this to return the class of variable vs binary categorical yes/no
  output$selectedIsCategorical <- reactive({ 
    input$runMapper
    input$selectedVar
    if(is.null(input$selectedVar)){ return(FALSE)}
    else {return(is.categorical(gm,selectedVariable())) }
  }) 

  outputOptions(output, "selectedIsCategorical", suspendWhenHidden = FALSE)
  
  selectedCategory <- reactive({
    if( is.categorical(gm,selectedVariable()) ){ input$categoricalVar }
    else{ NULL }
  })
  
  observe({
    selectedVariable
    if (is.categorical(gm,selectedVariable())){
      updateSelectInput(session, inputId = "categoricalVar",  label = "Category", colCategories(gm,selectedVariable()))  
    }
  })
  
  # Server->Javascript
  # when a new variable is selected in the selectVar select box input,
  # collects mean values of that variable from all nodes, and sends those values
  # to the cedar_graph widget via sendCustomMessage, and the javascript is updated
  # there and the (D3.js) nodes are updated and recolored, etc
  observe({
    input$selectedVar
    
    # formerly, when allowing for lense values to be used
    # print(selectedVariable() %in% c(colnames(gm$d),lenseChoices))
    if (selectedVariable() %in% c(colnames(gm$d))) {      
      vals = nodePrep(gm,selectedVariable(), selectedCategory())$values
      session$sendCustomMessage(type='nodevalues',message = vals)
    } 
  })
  
  ####TODO error obj varname not found
  histVals <- reactive({
       input$showHist
       if(!is.null(input$nodelist)){
         varname = selectedVariable()
         nodedata(gm, as.numeric(input$nodelist),varname)
       } else {
         c(0)
       }
           
       varname = selectedVariable()
       nodes <- input$nodelist
       if (is.numeric(gm$d[,varname])){       
         varplot <- hist(
           # nodePrep(gm,selectedVariable())$values,
           nodedata(gm, gm$nodes[nodes], varname),
           main="Data from Selected Nodes",
           ylab="Frequency",
           xlab=paste0("data for ",varname )
         )
       } else {
         varplot <- factorBarPlot(gm, varname, input$nodelist)
       }
       return(varplot)
      
    
     })
    
  output$nodeHist1 <- renderPlot({histVals()[1]})
  #showBarPlot <- eventReactive(input$showHist,{ 

     #barplot, compatible with factors
      #return(factorBarPlot(gm, selectedVariable()))
  #    factorBarPlot(gm, selectedVariable(), group_id = 1)

         # hist(
        #       nodePrep(gm,selectedVariable())$values, 
       #       main="Data from Selected Nodes",
       #       ylab="Frequency",
       #       xlab=paste0("data for ",selectedVariable() )
         #     )

 #   })
#  output$nodeHist2 <- renderPlot({histVals()[2]})
    #showBarPlot <- eventReactive(input$showHist,{ 
    
    #barplot, compatible with factors
    #return(factorBarPlot(gm, selectedVariable()))
  #  factorBarPlot(gm, selectedVariable(), group_id = 2)
    
    # hist(
    #       nodePrep(gm,selectedVariable())$values, 
    #       main="Data from Selected Nodes",
    #       ylab="Frequency",
    #       xlab=paste0("data for ",selectedVariable() )
    #     )
    
#  })

  
  # javascript => server
  # input$nodelist is created by the Javascript HTMLWidget on selection events
  # ( e.g. currently using the D3.js dispatch feature)
  # this wraps that input in reactive context to return 0 when no selection made 
    # note this is changed on Shiny.onInputChange("nodelist", nodelist);

  # when group 1 button is clicked, 
  # send javascript message to cedargraph widget 
  # then get the currently selected nodes
  # and store (Or add to ) the list in the mapper object 
  observeEvent(input$grp1set,{
    if(!is.null(input$nodelist)) {
        session$sendCustomMessage(type='setgroup1',message=array(input$nodelist) )
        group_id <- "1"
        # combine the list of nodes with any that may be present
        gm[["groups"]] <<- setgroup.mapper(gm, as.numeric(input$nodelist),group_id)
    }    
      
  })
  
  observeEvent(input$grp1clear,{
    group_id <- "1"
    session$sendCustomMessage(type='unsetgroup',message=group_id  )
    gm$groups[[group_id]] <<- NULL
  })
  
  # when 'group 2' button is clicked, return currently selected nodes
  # and store the list in the mapper object 
  observeEvent(input$grp2set,{
    if(!is.null(input$nodelist)) {
      session$sendCustomMessage(type='setgroup2',message=array(input$nodelist) )
      group_id <- "2"
      # combine the list of nodes with any that may be present
      gm[["groups"]] <<- setgroup.mapper(gm, as.numeric(input$nodelist),group_id)
    }
  })
  
  observeEvent(input$grp2clear,{
    group_id <- "2"
    session$sendCustomMessage(type='unsetgroup',message=group_id  )
    gm$groups[[group_id]] <<- NULL
  })
  
  # remove selected elements from list when button pressed
  # if none selected, then skip
  observeEvent(input$grp1remove,{
    if(length(input$nodelist)>0){
      session$sendCustomMessage(type='removefromgroup1',message=input$nodelist  )
      group_id <- "1"
      gm$groups[[group_id]] <<- setdiff(gm$groups[[group_id]], as.numeric(input$nodelist))
    }
  })
  
  observeEvent(input$grp2remove,{
    if(length(input$nodelist)>0){
      session$sendCustomMessage(type='removefromgroup2',message=input$nodelist  )
      group_id <- "2"
      gm$groups[[group_id]] <<- setdiff(gm$groups[[group_id]], as.numeric(input$nodelist))
    }
  })
  
  group1Length <- reactive({
    input$runMapper
    input$grp1set
    input$grp1remove
    input$grp1clear
    
    length(unlist(gm$groups[["1"]]))
  })
  
  group2Length <- reactive({
    input$runMapper
    input$grp2set
    input$grp2remove
    input$grp2clear
    length(unlist(gm$groups[["2"]]))
  })
  


  # graph widget, but only if the mapper object has been created via button
  output$cgplot <- renderCedarGraph({
    input$runMapper
    graphdata <-isolate(
      list(graph_nodes = nodePrep(gm,input$selectedVar), graph_links = linkPrep(gm))
    )
    print("rendering graph")
    cedarGraph(graphdata$graph_links, graphdata$graph_nodes,"500","500")
  })
  
  # button to create mapper, which takes a while
  observeEvent(input$runMapper, {
    updateTabItems(session, "tabs", selected = "graph")
    
   # convert categorical data to factor

    #factorVars <- convertColsToFactors(gm$d)
    factorCols <- list()
    factorCols <- names(d[, ! sapply(d, is.numeric)])
    d[factorCols] <- lapply(d[factorCols], factor)
    
 #   factorCols <- c(names(d[, sapply(d, is.factor)]), names(d[, ! sapply(d, is.numeric)]))
  #  factorCols <- names(d[, sapply(d, is.factor)])

    selected_cols <- input$selectedColumns

    # add selected lense function(s) to choices of coloring variable
    # temporarily disabled
    # choices = c(names(d),input$lenseFunctionSelection)
    #if(!is.null(input$lense2FunctionSelection) && input$lense2FunctionSelection != "none"){
    #  choices = c(choices, input$lense2FunctionSelection)
    #}
    
    # stick with dataset column names
    choices = c(names(d))    
    updateSelectInput(session, inputId = "selectedVar",  label = "Color by", choices) 
    
    progress <- shiny::Progress$new()
    progress$set(message = "Calculating Clustering", value = 0)
    on.exit(progress$close())
    updateProgress <- function(value = NULL, detail = NULL) {
      if (is.null(value)) {
        value <- progress$getValue()
        value <- value + (progress$getMax() - value) / 5 }
      progress$set(value = value, detail = detail)
    }
    
    # store n bins for equalization
    equalize_bins = c(input$binCountEqualize1, input$binCountEqualize2)
    lenselist = list()  # lenses varname currently used for lense table 
    equalizeLenses = list() # list of booleans indicating whether to equalize the lense values for each lense
    lense_fun <- lense.projection
    if(! is.null(input$lenseFunctionSelection)) {
      # selected the string of function name, and 'get' the actual function identifier
      fname = get(lenses[input$lenseFunctionSelection,]$fun)
      f = match.fun(fname)
      if (is.function(f)){ 
          lense_fun <- f
          lenseParam <- as.numeric(input$lenseParam)
          equalizeLenses[[1]] <- input$equalizeLens1
          if(input$lenseFunctionSelection == "Projection"){lenseParam <- input$filterVar}
          # test for NA in lenseparam WHEN the lense needs a param
          lenselist[[1]] <- lense(lensefun = lense_fun,  lenseparam = lenseParam,
                     partition_count=as.numeric(input$partitionCountSelection),
                     overlap = as.numeric(input$overlapSelection)/100.0)
      }
      else {
        # pop-up warning message; function doesn't exis
        stop("error in filter function selection")
      }
    }
    
    
    if(!is.null(input$lense2FunctionSelection) && input$lense2FunctionSelection != "none") {
      # selected the string of function name, and 'get' the actual function identifier
      fname = get(lenses[input$lense2FunctionSelection,]$fun)
      f = match.fun(fname)
      if (is.function(f)){
        # test for NA in lenseparam WHEN the lense needs a param
        lense2_fun <- f
        lense2Param <- as.numeric(input$lense2Param)
        equalizeLenses[[2]] <- input$equalizeLens2
        if(input$lense2FunctionSelection == "Projection"){lense2Param <- input$lense2filterVar}
        lenselist[[2]] <- lense(lensefun = lense2_fun,  lenseparam = lense2Param,
                             partition_count=as.numeric(input$lense2partitionCountSelection),
                             overlap = as.numeric(input$lense2overlapSelection)/100.0)
      }
      else {
        # pop-up warning message; function doesn't exist
        stop("error in filter function selection")
      }
    }
    
    gm <<- mapper(dataset = as.data.frame(d), lenses = lenselist,
                  cluster_method="single",
                  bin_count = as.numeric(input$binCountSelection),
                  normalize_data = input$normalizeOption,
                  equalize_lenses = equalizeLenses,
                  selected_cols = selected_cols,
                  equalize_bins = equalize_bins)
    gm <<- mapper.run(gm)
    
#    gm<<- makemapper(dataset = as.data.frame(d), 
#                          lensefun = lense_fun, 
#                          partition_count=as.numeric(input$partitionCountSelection),
#                          overlap = as.numeric(input$overlapSelection)/100.0, 
#                          lenseparam = lenseParam,
#                          lense2fun = lense2_fun, 
#                          lense2partition_count=as.numeric(input$lense2partitionCountSelection),
#                          lense2overlap = as.numeric(input$lense2overlapSelection)/100.0, 
#                          lense2param = lense2Param,
#                         # lensevals = data.frame(mapper.lense.calculate(gm)$values), #data.frame(gm$lensefun(gm)), # new filter coloring
#                          selected_cols = selected_cols,
#                          bin_count = as.numeric(input$binCountSelection),
#                          normalize_data = input$normalizeOption,
#                          progressUpdater = NULL)  #updateProgress
    return(gm)
  })
  
  testy <- eventReactive(input$runTest,{
      # updateTabItems(session, "tabs", selected = "resulttable")
      return(kstable(gm))
      })
  
  createVarTable <- eventReactive(input$runTest,{
      return(varTable(gm))
      })
  
  output$hypTestTable <- renderTable({testy()}, caption=paste0("2-side Kolmogorov-Smirnov Test by node groups"),digits=7) 
  
  # TODO add reactivity to redraw when data changes..
  
  output$varianceTable <- renderTable({createVarTable()}, caption=paste0("Std mean/variance of data in select nodes"),digits=4)
  
  ########### outputs
  output$dataname          <- renderText(input$dataSelection)
  output$dataRowCount      <- renderText({ prettyNum(dataRowCount()) })
  output$dataVarCount      <- renderText({ prettyNum(dataVarCount()) })
  output$dataColumnNames   <- renderPrint({ names(gm$d)})
  output$dataset           <- renderDataTable({selectedDataSet()})
  output$nodeCount         <- renderText({length(gm$nodes)})
  output$graphNodeCount     <- renderText({prettyNum(length(gm$nodes))})
  output$selectedNodeCount <- renderText({prettyNum(length(as.numeric(input$nodelist)))})
  output$group1Count       <- renderText({group1Length()})
  output$group2Count       <- renderText({group2Length()})
  output$gmPartitionCount  <- renderText({
        input$runMapper
        gm$partition_count
        })

  # collect all the parameters into single HTML string for display and mapper is run
  output$gmParameters  <- renderTable({
    input$runMapper
    ptable<-data.frame( "D1" = c(gm$lenses[[1]]$n, 
         gm$lenses[[1]]$o,
         gm$bin_count,
         input$lenseFunctionSelection,
         paste(gm$lenses[[1]]$lenseparam," "),
         length(gm$nodes)),
         row.names = c("partitions","overlap","bin count","filter","param","nodes")
    )
    if(length(gm$lenses)>1) {
      ptable = data.frame(ptable,
                          "D2" = c(gm$lenses[[2]]$n,  
                                  gm$lenses[[2]]$o, 
                                  gm$bin_count, 
                                  input$lense2FunctionSelection, 
                                  paste(gm$lenses[[2]]$lenseparam," "), 
                                  length(gm$nodes)), 
                          row.names = c("partitions","overlap","bin count","filter","param","nodes") )
      }
    ptable
    })
                          
  output$gmOverlap   <- renderText({
              input$runMapper
              gm$lenses[[1]]$o})
  
  output$gmBinCount <-  renderText({
              input$runMapper
              gm$bin_count})
  
  
  ### Lense/Filter parameter selection
  # these functions lookup the info about the selected lense from global lense table, 
  # which is built in the lense.functions file
  # and creates custom input UI with labels based on lense table.  
  # the 'renderUI' function is labelled as 'experimental' in the Shiny help 
  
  # reactively  look up the description of the lense functions when new function is selected
  #lenseParamDescription <- reactive({
  #  lenses[lenses$fun==input$lenseFunctionSelection,]$desc
  # })
  # build the textInput server side and send it to the UI
  output$lenseParamInput <- renderUI(
    # param_text = lenses[lenses$Name==input$lenseFunctionSelection,]$params

    if( (lenses[input$lenseFunctionSelection,]$params)  != ""){
          textInput("lenseParam", 
              label = lenses[lenses$Name==input$lenseFunctionSelection,"desc"], 
              placeholder=lenses[lenses$Name==input$lenseFunctionSelection,]$params)
    } else {
          p("No parameter needed")  # lenses[lenses$Name==input$lenseFunctionSelection,]$desc
      }
  )
  
  output$lense2ParamInput <- renderUI(
    # param_text = lenses[lenses$Name==input$lenseFunctionSelection,]$params
    
    if( (lenses[input$lense2FunctionSelection,]$params)  != ""){
      textInput("lense2Param", 
                label = lenses[lenses$Name==input$lense2FunctionSelection,"desc"], 
                placeholder=lenses[lenses$Name==input$lense2FunctionSelection,]$params)
    } else {
      p("No parameter needed")  # lenses[lenses$Name==input$lenseFunctionSelection,]$desc
    }
  )
  
  output$lensesigma <- renderText(input$lensesigma)
  # output from ACE code editor
  # TODO : secure this function; check session$host=='localhost'?
  output$eval_output <- renderPrint({
    input$eval
    return(isolate(eval(parse(text=input$rcode))))
  }) 
  
  # output$sessionInfo <- renderPrint({ session })
})
