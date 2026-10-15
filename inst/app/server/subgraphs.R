sub_state<-reactiveValues(fit=NULL,parent=NULL,settings=NULL)
subgraph_settings<-reactive(list(method=input$subgraph_method %||% "ego",focus=input$subgraph_focus %||% "",order=input$subgraph_order %||% 1L,selection=sort(input$subgraph_selection %||% character())))
subgraph_current<-reactive({parent<-network_current();if(is.null(parent)||is.null(sub_state$fit)||!identical(parent,sub_state$parent)||!identical(subgraph_settings(),sub_state$settings)) return(NULL);sub_state$fit})
output$subgraph_controls<-renderUI({
  f<-network_current();if(is.null(f)) return(hint("Primero calcula una red vigente. Después podrás extraer parte de ella conservando sus conexiones internas."))
  names<-sort(f$nodes$name)
  tagList(selectInput("subgraph_method","Qué parte quieres estudiar",c("Vecindario de un nodo"="ego","Comunidad del nodo"="community","Componente conectada del nodo"="component","Seleccionar nodos manualmente"="manual")),
    conditionalPanel("input.subgraph_method != 'manual'",selectizeInput("subgraph_focus","Nodo de referencia",setNames(names,names))),
    conditionalPanel("input.subgraph_method == 'ego'",numericInput("subgraph_order","Distancia en conexiones desde ese nodo",1,0,3)),
    conditionalPanel("input.subgraph_method == 'manual'",selectizeInput("subgraph_selection","Nodos que quieres conservar",setNames(names,names),multiple=TRUE)),
    hint("Distancia 1 incluye el nodo y sus vecinos; distancia 2 añade los vecinos de esos vecinos. El subgrafo conserva todas las conexiones entre los nodos seleccionados, no solo los caminos usados para encontrarlos."),
    actionButton("run_subgraph","Extraer y analizar subgrafo",class="btn-primary run-analysis"))
})
observeEvent(input$run_subgraph,task("Extrayendo subgrafo y recalculando sus indicadores…",{
  p<-network_current();if(is.null(p)) abort_user("Calcula primero la red con los parámetros actuales.")
  sub_state$fit<-NULL;sub_state$settings<-NULL;s<-subgraph_settings()
  f<-extract_subgraph(p,s$method,s$focus,s$order,s$selection)
  sub_state$parent<-p;sub_state$settings<-s;sub_state$fit<-f
}))
output$subgraph_state<-renderUI({f<-subgraph_current();if(is.null(f)) return(hint("Extrae un subgrafo. Si modificas su selección o la red de origen, vuelve a extraerlo antes de interpretar o descargar."))
  tagList(tags$p(class="chart-caption",f$note),tags$p(paste(nrow(f$nodes),"nodos y",nrow(f$edges),"conexiones del subgrafo. La red completa se conserva arriba.")))
})
output$subgraph_interactive<-visNetwork::renderVisNetwork(make_network_widget(subgraph_current()))
output$subgraph_summary<-table_render(function(){f<-subgraph_current();validate(need(!is.null(f),"Extrae un subgrafo vigente."));f$summary})
output$subgraph_nodes<-table_render(function(){f<-subgraph_current();validate(need(!is.null(f),"Extrae un subgrafo vigente."));f$nodes[setdiff(names(f$nodes),c("x","y"))]})
output$download_subgraph<-downloadHandler(filename="subgrafo_bibliometria.zip",content=function(file){
  f<-subgraph_current();if(is.null(f)) abort_user("Extrae un subgrafo vigente antes de descargar.")
  root<-tempfile("subgrafo_");dir.create(root);on.exit(unlink(root,recursive=TRUE))
  export_subgraph(root,sub_state$parent,f)
  zip::zipr(file,list.files(root),root=root)
})
