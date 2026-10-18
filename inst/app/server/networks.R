network_entity_names<-reactive({if(is.null(rv$prepared)||is.null(rv$bib))return(character());switch(input$network_type %||% "authors",authors=rv$bib$authors$elemento,words=rv$corpus$vocabulary,sources=rv$bib$sources$elemento,references=sort(unique(unlist(reference_sets(rv$prepared)))),coupling=rv$prepared$documents$doc_id[lengths(reference_sets(rv$prepared))>0])})
network_settings <- reactive(list(type = input$network_type %||% "authors", weighting = if ((input$network_type %||% "authors") %in% c("sources","coupling")) "cosine" else input$network_weight %||% "full",
  min_presence=if(identical(input$network_type,"coupling")) 1L else input$network_presence %||% 1L, max_nodes = input$network_nodes %||% 60L,
  min_shared = input$network_shared %||% 1L, max_edges=input$network_edges %||% 250L, seed=input$network_seed %||% 2026L, community_method=input$network_community %||% "louvain", resolution=if(identical(input$network_community,"walktrap")) 1 else input$network_resolution %||% 1, keyplayers_k=input$network_keyplayers %||% 3L,
  remove_isolates=isTRUE(input$network_remove_isolates),include_nodes=sort(intersect(input$network_include %||% character(),network_entity_names()))))
network_layout<-reactiveVal(NULL)
network_revision<-reactiveVal(0L)
observeEvent(input$network_type,{if(identical(input$network_type,"words")) {
  updateNumericInput(session,"network_nodes",value=30);updateNumericInput(session,"network_presence",value=3);updateNumericInput(session,"network_shared",value=3);updateNumericInput(session,"network_edges",value=120);updateSelectInput(session,"network_weight",selected="association");updateCheckboxInput(session,"network_motion",value=FALSE)
}},ignoreInit=TRUE)
network_current <- reactive({ current(); if (is.null(rv$network) || !identical(rv$network_signature, network_settings())) return(NULL); rv$network })
network_path<-reactive({f<-network_current();if(is.null(f)||!(input$network_path_from %||% "") %in% f$nodes$name||!(input$network_path_to %||% "") %in% f$nodes$name)return(NULL);network_shortest_path(f,input$network_path_from,input$network_path_to)})
output$network_path_controls<-renderUI({f<-network_current();if(is.null(f)||!nrow(f$nodes))return(NULL);choices<-c("Elegir un nodo"="",setNames(f$nodes$name,f$nodes$name));tagList(fluidRow(column(6,selectizeInput("network_path_from","Camino más corto / desde",choices,selected=isolate(input$network_path_from %||% ""))),column(6,selectizeInput("network_path_to","Camino más corto / hasta",choices,selected=isolate(input$network_path_to %||% "")))),hint("Busca dos nodos para ver una ruta con el menor número de conexiones. Por ejemplo, Ana — Bruno — Carla tiene dos pasos; Bruno es el intermediario de esa ruta. Se cuentan pasos, no pesos: una coincidencia fuerte no equivale a un trayecto más largo. Puede haber otras rutas igualmente cortas."))})
output$network_path_reading<-renderUI({p<-network_path();if(is.null(p))return(hint("Selecciona origen y destino incluidos en el grafo. La ruta aparecerá aquí y se marcará en el dibujo."));if(!p$connected)return(caption("No existe un camino entre estos nodos en la red filtrada: pertenecen a componentes distintos. Reducir un umbral puede recuperar conexiones presentes en los datos; ausencia de camino no demuestra ausencia de relación fuera del corpus."))
  intermediaries<-max(0,length(p$nodes)-2)
  caption(paste("Una ruta mínima:",paste(p$nodes,collapse=" → "),".",p$distance,if(p$distance==1)"conexión;" else "conexiones;",intermediaries,if(intermediaries==1)"intermediario." else "intermediarios.","En coautoría cada paso es una colaboración observada; llegar en varios pasos no significa haber coescrito juntos. En otras redes cada paso conserva la definición de la relación elegida. Las rutas dependen de los filtros y no prueban flujo de información ni influencia."))})
output$network_path_table<-table_render(function(){p<-network_path();if(is.null(p))return(data.frame(Estado="Selecciona dos nodos para consultar la ruta."));if(!p$connected)return(data.frame(Estado="Sin camino en la red vigente."));p$steps})
observeEvent(input$run_network, task("Construyendo relaciones y calculando indicadores de red…", {
  if (is.null(rv$prepared) || stale()) abort_user("Prepara un corpus vigente antes de calcular redes.")
  rv$network <- NULL; rv$network_signature <- NULL
  s <- network_settings(); rv$network <- run_network(rv$corpus, rv$prepared, s); rv$network_signature <- s
  network_layout(NULL);network_revision(isolate(network_revision())+1L)
  showNotification(paste(nrow(rv$network$nodes), "nodos y", nrow(rv$network$edges), "conexiones. Revisa definición e indicadores."), type = "message")
}))
output$network_state <- renderUI({
  fit <- network_current(); if (is.null(fit)) return(empty_help("Selecciona el tipo y pulsa Calcular red. Si cambias los parámetros, vuelve a calcular."))
  tagList(tags$p(class = "chart-caption", fit$note), tags$div(class = "network-metrics", lapply(seq_len(5), function(i) tags$span(tags$strong(if (is.na(fit$summary$valor[i])) "—" else format(fit$summary$valor[i], digits = 3)), tags$small(fit$summary$indicador[i])))),
    if (!nrow(fit$edges)) hint("No hay conexiones que superen el umbral. Los puntos aislados son un resultado válido; reduce el umbral para explorar otras relaciones."))
})
make_network_graph <- function(fit) {
  validate(need(!is.null(fit), "Calcula la red con los parámetros actuales."));validate(need(nrow(fit$nodes)>0,"No quedan nodos conectados. Conserva los aislados o reduce el umbral de conexiones.")); d <- fit$nodes; ed <- fit$edges
  ed$x <- d$x[match(ed$from, d$name)]; ed$y <- d$y[match(ed$from, d$name)]
  ed$xend <- d$x[match(ed$to, d$name)]; ed$yend <- d$y[match(ed$to, d$name)]
  d$comunidad <- factor(ifelse(d$comunidad == 0, "Sin comunidad", paste("Comunidad", d$comunidad))); labels <- head(d[order(-d$grado, -d$documentos, d$name), ], 18)
  ggplot2::ggplot(d, ggplot2::aes(x, y)) + ggplot2::geom_segment(data = ed, ggplot2::aes(x, y, xend = xend, yend = yend, linewidth = weight), inherit.aes = FALSE, colour = "#b7b7b7", alpha = .6) +
    ggplot2::scale_linewidth_continuous(range = c(.2, 1.5), guide = "none") + ggplot2::geom_point(ggplot2::aes(size = documentos, colour = comunidad)) +
    label_layer(labels, ggplot2::aes(label = name), size = 3.5, seed = fit$params$seed, repel = list(max.overlaps = Inf)) +
    ggplot2::scale_colour_manual(values = swiss_colours(length(unique(d$comunidad)))) +
    ggplot2::coord_equal() + ggplot2::theme_void(base_size = 13) + ggplot2::theme(legend.position = "bottom") +
    ggplot2::labs(title = switch(fit$params$type, authors = "Red de coautoría", words = "Red de copresencia de palabras", sources = "Afinidad léxica de revistas",references="Red de cocitación de referencias",coupling="Acoplamiento bibliográfico de documentos"), size = "Documentos", colour = "Comunidad", subtitle = paste("Métricas del grafo filtrado ·",if(isTRUE(fit$params$remove_isolates)) "aislados retirados" else "aislados incluidos","· disposición visual"))
}
network_graph<-reactive(make_network_graph(network_current()))
output$network_plot <- renderPlot(network_graph(), res = 120)
make_network_widget<-function(fit) {
  validate(need(!is.null(fit),"Calcula una red para explorar sus relaciones."));validate(need(nrow(fit$nodes)>0,"No quedan nodos conectados. Conserva los aislados o reduce el umbral de conexiones."))
  d<-fit$nodes;d<-d[order(ascii_fold(tolower(d$name))),,drop=FALSE];ed<-fit$edges;palette<-swiss_colours(length(unique(d$comunidad)));colours<-palette[match(d$comunidad,sort(unique(d$comunidad)))]
  path<-network_path();marked<-if(is.null(path))character() else path$nodes
  nodes<-data.frame(id=d$name,label=vapply(d$name,function(x) paste(strwrap(if(nchar(x)>62) paste0(substr(x,1,59),"…") else x,width=24),collapse="\n"),""),
    title=paste0("<strong>",escape_html(d$name),"</strong><br>Documentos: ",d$documentos,"<br>Grado: ",d$grado,"<br>Fuerza: ",round(d$fuerza,4),"<br>Intermediación: ",round(d$intermediacion,4),"<br>Comunidad: ",d$comunidad,"<br>",d$rol_observado),
    color=colours,size=12+14*sqrt(d$documentos/max(d$documentos)),x=d$x*100,y=d$y*100,stringsAsFactors=FALSE)
  # Rotulado como en Lectura enlazada: nombre visible en todos los nodos, con halo blanco para leerlo sobre aristas y colores.
  # Los nodos destacados (mayor presencia o grado) llevan letra mayor; la casilla permite rotular solo estos si la red es densa.
  base_font<-if(nrow(nodes)<=40L) 20 else if(nrow(nodes)<=80L) 16 else 13
  prominent<-rank(-d$documentos,ties.method="first")<=15L|rank(-d$grado,ties.method="first")<=10L|nodes$id %in% marked
  nodes$font.size<-ifelse(prominent,base_font+4,base_font);nodes$font.strokeWidth<-4;nodes$font.strokeColor<-"#ffffff"
  if(!isTRUE(input$network_label_all %||% TRUE)) nodes$label<-ifelse(prominent,nodes$label,"")
  nodes$borderWidth<-ifelse(nodes$id %in% marked,4,0);nodes$color.background<-colours;nodes$color.border<-ifelse(nodes$id %in% marked,"#c7281e",colours)
  saved<-isolate(network_layout());nodes$fixed<-FALSE
  if(length(saved)) for(i in seq_len(nrow(nodes))) {z<-saved[[nodes$id[i]]];if(!is.null(z)){nodes$x[i]<-z$x;nodes$y[i]<-z$y;nodes$fixed[i]<-isTRUE(z$fixed)}}
  edges<-data.frame(from=ed$from,to=ed$to,width=if(nrow(ed)) .6+3*ed$weight/max(ed$weight) else numeric(),title=paste("Coincidencias",ed$coincidencias,"/ peso",signif(ed$weight,4)))
  key<-function(a,b)paste(pmin(a,b),pmax(a,b),sep="\r")
  selected_edges<-if(is.null(path))character() else key(path$edges$from,path$edges$to)
  edges$color<-ifelse(key(edges$from,edges$to) %in% selected_edges,"#c7281e","#b8b8b8");edges$width[key(edges$from,edges$to) %in% selected_edges]<-5
  widget<-visNetwork::visNetwork(nodes,edges,height="670px",width="100%")
  widget<-visNetwork::visNodes(widget,shape="dot",font=list(face="Arial",size=base_font,strokeWidth=4,strokeColor="#ffffff"),borderWidth=0,shadow=FALSE)
  widget<-visNetwork::visEdges(widget,color=list(color="#b8b8b8",highlight="#245579"),smooth=FALSE)
  widget<-visNetwork::visInteraction(widget,dragNodes=TRUE,dragView=TRUE,zoomView=TRUE,hover=TRUE,navigationButtons=TRUE)
  widget<-visNetwork::visOptions(widget,highlightNearest=list(enabled=TRUE,degree=1,hover=FALSE),nodesIdSelection=list(enabled=TRUE,useLabels=TRUE,main="Buscar un nodo"))
  widget<-visNetwork::visLayout(widget,randomSeed=fit$params$seed)
  widget<-visNetwork::visPhysics(widget,enabled=isTRUE(isolate(input$network_motion)),solver="barnesHut",
    barnesHut=list(gravitationalConstant=-1800,centralGravity=.08,springLength=160,springConstant=.025,damping=.65,avoidOverlap=.6),
    stabilization=list(enabled=TRUE,iterations=250),maxVelocity=8,minVelocity=.5)
  visNetwork::visEvents(widget,dragEnd=paste0("function(p){if(!p.nodes.length)return;var net=this;var pin=document.getElementById('network_pin_drag');var fixed=!!(pin&&pin.checked);var pos=net.getPositions();net.body.data.nodes.update(p.nodes.map(function(id){return {id:id,x:pos[id].x,y:pos[id].y,fixed:fixed};}));var saved={};net.body.data.nodes.forEach(function(n){if(pos[n.id])saved[n.id]={x:pos[n.id].x,y:pos[n.id].y,fixed:!!n.fixed};});if(window.Shiny)Shiny.setInputValue('network_layout_saved',{revision:",isolate(network_revision()),",positions:saved},{priority:'event'});}"))
}
network_widget<-reactive(make_network_widget(network_current()))
output$network_interactive<-visNetwork::renderVisNetwork(network_widget())
output$network_expanded<-visNetwork::renderVisNetwork(network_widget())
output$network_conclusions <- table_render(function(){f<-network_current();validate(need(!is.null(f),"Calcula una red vigente."));network_conclusions(f)})
observeEvent(input$table_network, {
  fit <- network_current(); if (is.null(fit)) { showNotification("Calcula una red vigente.", type = "warning"); return() }
  showModal(modalDialog(title = "Red / indicadores y trazabilidad", size = "l", easyClose = TRUE,
    tags$p(class="modal-lead","Empieza por los indicadores globales para conocer el tamaño, componentes y densidad de esta red. Después consulta los nodos y sus conexiones: ahí puedes comprobar qué relaciones sostienen una centralidad alta. Si cambias filtros o extraes un subgrafo, cambia el universo de cálculo y debes volver a interpretar sus cifras."),
    tags$p("Por ejemplo, una autora con muchos colaboradores tendrá un grado alto; otra puede conectar dos equipos y destacar como puente con menos vecinos. La tabla describe esas posiciones, pero no demuestra liderazgo ni prestigio. Auditoría de selección explica qué se conservó, y Entender estos indicadores abre la guía con ejemplos y límites."),
    tags$p(class = "chart-caption", fit$note), selectInput("network_detail", "Tabla", c("Indicadores globales" = "summary", "Indicadores por nodo" = "nodes", "Conexiones y pesos" = "edges", "Auditoría de selección" = "audit", "Cada entidad / inclusión y motivo"="selection", "Colaboración del corpus" = "collaboration", "Key players / cobertura conjunta"="keyplayers")),
    DT::DTOutput("network_table"), actionButton("help_network_table", "Entender estos indicadores", class = "btn-quiet"), footer = modalButton("Cerrar tabla")))
})
observeEvent(input$help_network_table, open_help("networks"))
output$network_table <- table_render(function() { fit <- network_current(); validate(need(!is.null(fit), "Calcula una red vigente."));
  d <- fit[[input$network_detail %||% "summary"]]; if (is.null(d)) return(data.frame(Nota = "El índice de colaboración está disponible en la red de autores."));
  if (identical(input$network_detail, "nodes")) d <- d[setdiff(names(d), c("x", "y"))]; d })

observeEvent(input$network_motion, {
  if(is.null(rv$network)) return()
  for(id in c("network_interactive","network_expanded")) visNetwork::visPhysics(visNetwork::visNetworkProxy(id,session=session),enabled=isTRUE(input$network_motion))
},ignoreInit=TRUE)

observeEvent(input$network_layout_saved,{m<-input$network_layout_saved;if(!identical(as.integer(m$revision),as.integer(isolate(network_revision()))))return()
  f<-network_current();if(is.null(f))return();z<-m$positions
  z<-z[intersect(names(z),f$nodes$name)];z<-Filter(function(v)is.numeric(v$x)&&length(v$x)==1&&is.finite(v$x)&&is.numeric(v$y)&&length(v$y)==1&&is.finite(v$y),z)
  network_layout(z)
})
observeEvent(input$network_release,{f<-network_current();if(is.null(f)||!nrow(f$nodes))return();network_layout(NULL)
  updateCheckboxInput(session,"network_motion",value=TRUE)
  for(id in c("network_interactive","network_expanded"))visNetwork::visUpdateNodes(visNetwork::visNetworkProxy(id,session=session),data.frame(id=f$nodes$name,fixed=FALSE))
})
output$network_layout_reading<-renderUI({f<-network_current();if(is.null(f))return(NULL);z<-network_layout();n<-sum(vapply(z,function(v)isTRUE(v$fixed),TRUE));hint(paste(n,if(n==1L) "nodo fijado" else "nodos fijados","al arrastrar. La vista ampliada recupera las posiciones guardadas durante esta ejecución; recalcular la red inicia otra disposición."))})
output$network_lookup<-renderUI({f<-network_current();if(is.null(f))return(NULL);selected<-isolate(input$network_candidate %||% f$selection$name[1]);if(!selected %in% f$selection$name)selected<-f$selection$name[1]
  session$onFlushed(function(){updateSelectizeInput(session,"network_candidate",choices=setNames(f$selection$name,f$selection$name),selected=selected,server=TRUE)},once=TRUE)
  selectizeInput("network_candidate","Consultar cualquier entidad observada / también las excluidas",choices=NULL,options=list(maxOptions=100))})
output$network_candidate_reading<-renderUI({f<-network_current();if(is.null(f))return(NULL);z<-f$selection[f$selection$name==(input$network_candidate %||% ""),,drop=FALSE];if(!nrow(z))return(NULL)
  hint(paste(z$name,":",z$documentos,if(z$documentos==1L) "documento; posición" else "documentos; posición",z$posicion,"en el orden de selección.",z$motivo,". Buscar un nodo del grafo solo ofrece los incluidos. Para incorporarlo, revisa el umbral o dale prioridad explícita y vuelve a calcular. La prioridad conserva el máximo de nodos y no evita el filtro de aislados."))})
output$network_inclusion_controls<-renderUI({current();f<-rv$network;if(is.null(f)||!identical(f$params$type,input$network_type %||% "authors"))return(NULL)
  selected<-intersect(isolate(input$network_include %||% character()),f$selection$name)
  session$onFlushed(function(){updateSelectizeInput(session,"network_include",choices=setNames(f$selection$name,f$selection$name),selected=selected,server=TRUE)},once=TRUE)
  selectizeInput("network_include","Dar prioridad a entidades concretas / selección explícita",choices=NULL,multiple=TRUE,options=list(closeAfterSelect=TRUE,maxOptions=100))})
output$network_players<-table_render(function(){f<-network_current();validate(need(!is.null(f),"Calcula una red para ver sus candidatos."));f$keyplayers})
output$network_players_reading<-renderUI({f<-network_current();if(is.null(f))return(NULL);d<-f$keyplayers;caption(paste("Aquí puedes consultar los key players según cobertura: hasta",f$params$keyplayers_k,"nodos elegidos para alcanzar vecinos distintos en una conexión, incluyendo los propios nodos elegidos. Ejemplo: si Ana y Bruno comparten los mismos cinco vecinos, escoger ambos añade poco; elegir a Carla puede cubrir otros cinco. La columna Nodos nuevos cubiertos muestra lo que añade cada elección; la última fila muestra la cobertura conjunta, sin duplicar vecinos.",if(nrow(d))paste("En tu red:",paste(d$nodo,collapse=", "),"cubren",tail(d$cubiertos_acumulados,1),"de",nrow(f$nodes),"nodos (",round(tail(d$porcentaje_cubierto,1),1),"%).") else "No hay nodos para seleccionar.","Esta selección es aproximada y depende de la red filtrada; no garantiza el mejor conjunto posible ni demuestra liderazgo."))})

# Quitar aislados es una acción inmediata sobre el último grafo calculado si
# este es el único parámetro modificado; no dispara otros cambios pendientes.
observeEvent(input$network_remove_isolates,{if(is.null(rv$network)||is.null(rv$network_signature)||is.null(rv$prepared)||stale())return();old<-rv$network_signature;now<-network_settings();old$remove_isolates<-now$remove_isolates;if(!identical(old,now))return()
  task("Aplicando filtro de nodos aislados…",{rv$network<-run_network(rv$corpus,rv$prepared,now);rv$network_signature<-now;network_layout(NULL);network_revision(isolate(network_revision())+1L)})
},ignoreInit=TRUE)

output$network_definition<-renderUI(tagList(hint(switch(input$network_type %||% "authors",
  authors="Cada conexión representa documentos firmados por ambos autores. Tener una publicación permite superar presencia mínima = 1, pero el máximo de nodos puede excluirte: primero entran los más presentes y los empates se resuelven alfabéticamente. Consulta cada entidad y su motivo. Revisa homónimos y variantes de nombre.",
  words="Cada conexión representa documentos que contienen ambas palabras retenidas. Repetir una palabra dentro del documento no aumenta esa coincidencia.",
  sources="Las conexiones comparan vocabularios binarios de fuentes: coincidencias = términos distintos compartidos; peso coseno. Es afinidad léxica, no cocitación.",
  references="Los nodos son referencias citadas. Una conexión cuenta documentos que citan las dos obras juntas. Requiere columna Referencias / CR; las variantes de escritura no se fusionan automáticamente.",
  coupling="Los nodos son documentos del corpus con referencias. Una conexión cuenta referencias compartidas y el peso es coseno. Todos los nodos representan una publicación; si hay más del límite, se eligen los de mayor acoplamiento total y solo entran documentos que comparten alguna referencia. Requiere CR con cobertura suficiente.")),if(identical(input$network_weight %||% "association","association")&&!(input$network_type %||% "authors") %in% c("sources","coupling"))hint("Peso elegido: fuerza de asociación. Es el número de coincidencias dividido entre el producto de las presencias de los dos nodos, de modo que un par poco frecuente que casi siempre coincide pesa más que un par muy frecuente que coincide por serlo. Es una normalización por presencia, no una prueba estadística: no calcula valores p ni controla falsos descubrimientos. Para comparar con otras ponderaciones, cambia el peso y observa si las conexiones fuertes se mantienen.")))
