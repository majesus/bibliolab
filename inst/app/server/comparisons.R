comparison_columns <- reactive({
  if (is.null(rv$raw) || is.null(rv$prepared)) return(character())
  p <- rv$prepared; excluded <- unlist(p$mapping[c("text", "title", "id", "doi", "translated", "authors", "year", "citations")])
  cols <- setdiff(names(rv$raw), excluded)
  cols[vapply(cols, function(col) {
    x <- clean_value(rv$raw[[col]][p$documents$source_row]); v <- unique(x[nzchar(x)])
    # El límite de la matriz no impide comparar dos revistas entre cientos.
    known <- col %in% unlist(p$mapping[c("source","language")])
    length(v) >= 2 && (known || length(v) <= 250 || length(v) < .5*sum(nzchar(x)))
  }, TRUE)]
})
output$jsd_modes <- renderUI({
  p <- current(); choices <- character()
  if (length(unique(p$documents$year[!is.na(p$documents$year)])) >= 2) choices <- c(choices, "Períodos y evolución por año" = "year")
  if (length(comparison_columns())) choices <- c(choices, "Categorías de una columna del CSV" = "metadata")
  if(nrow(rv$bib$authors)>=2) choices<-c(choices,"Autores / publicaciones exclusivas de A y B"="authors")
  if(length(unique(p$documents$citations[is.finite(p$documents$citations)]))>=2) choices<-c(choices,"Citas / categorías explícitas"="citations")
  df <- density_current(); lf <- lda_current()
  if (!is.null(df) && length(unique(df$assignments$grupo)) >= 2) choices <- c(choices, "Grupos HDBSCAN vigentes" = "density")
  if (!is.null(lf)) choices <- c(choices, "Tema dominante LDA vigente" = "lda")
  if (!length(choices)) return(empty_help("Para comparar necesitas al menos dos años/categorías o calcular un modelo con varios grupos."))
  selected <- input$jsd_mode %||% unname(choices[1]); if (!selected %in% choices) selected <- unname(choices[1])
  selectInput("jsd_mode", "Qué conjuntos deseas comparar", choices, selected = selected)
})
output$jsd_column <- renderUI({
  if(identical(input$jsd_mode,"authors"))return(hint("Exclusivas de A = publicaciones firmadas por A y no por B; exclusivas de B = firmadas por B y no por A. Pueden incluir otros coautores: «exclusiva» no significa autoría individual. Los artículos que firman A y B juntos se excluyen de ambos conjuntos y se cuentan en la auditoría. Revisa homónimos, idioma, año y coautoría; la permutación no elimina esas dependencias."))
  if(identical(input$jsd_mode,"citations"))return(tagList(selectInput("jsd_citation_rule","Cómo formar grupos de citas",c("Cuartiles del corpus / empates pueden reducir grupos"="quartile","Umbral declarado / dos grupos"="cutoff")),conditionalPanel("input.jsd_citation_rule === 'cutoff'",numericInput("jsd_citation_cutoff","Umbral / A ≤ y B >",10,0,10000000)),hint("Las categorías son descriptivas. Citas ausentes quedan fuera; no se consideran cero. Los cuartiles usan tipo 7 de R y no separan valores empatados. La edad de las publicaciones y la cobertura pueden explicar la diferencia.")))
  req(identical(input$jsd_mode, "metadata")); cols <- comparison_columns(); req(length(cols))
  selected <- input$jsd_col %||% rv$prepared$mapping$source; if (!selected %in% cols) selected <- cols[1]
  selectInput("jsd_col", "Columna de categorías", cols, selected = selected)
})
comparison_grouping <- reactive({
  mode <- input$jsd_mode %||% "year"; if (mode == "year") return(NULL)
  if (is.null(rv$prepared)) return(NULL)
  p <- rv$prepared
  if(mode=="authors") {
    sets<-author_sets(p);a<-input$jsd_A %||% "";b<-input$jsd_B %||% "";ia<-vapply(sets,function(x)a %in% x,logical(1));ib<-vapply(sets,function(x)b %in% x,logical(1))
    g<-data.frame(doc_id=p$documents$doc_id,valor=ifelse(ia&!ib,a,ifelse(ib&!ia,b,"")))
    attr(g,"shared_documents")<-sum(ia&ib);return(g)
  }
  if(mode=="citations")return(data.frame(doc_id=p$documents$doc_id,valor=citation_categories(p$documents$citations,input$jsd_citation_rule %||% "quartile",input$jsd_citation_cutoff %||% 10)))
  if (mode == "metadata") {
    col <- input$jsd_col %||% ""; if (!col %in% names(rv$raw)) return(NULL)
    values<-clean_value(rv$raw[[col]][p$documents$source_row])
    if(identical(col,p$mapping$source)&&isTRUE(p$config$normalize_labels)){vm<-variant_map(values,"source");values[nzchar(values)]<-unname(vm$map[values[nzchar(values)]])}
    return(data.frame(doc_id = p$documents$doc_id, valor = values))
  }
  if (mode == "density") {
    fit <- density_current(); if (is.null(fit)) return(NULL)
    return(data.frame(doc_id = fit$assignments$doc_id, valor = ifelse(fit$assignments$grupo == 0, "Sin asignar", paste("Grupo",fit$assignments$grupo))))
  }
  if (mode == "lda") {
    fit <- lda_current(); if (is.null(fit)) return(NULL)
    return(data.frame(doc_id = fit$document_topics$doc_id, valor = paste("Tema", max.col(as.matrix(fit$document_topics[-1]), ties.method = "first"))))
  }
  NULL
})
output$jsd_groups <- renderUI({
  p <- current(); mode <- input$jsd_mode %||% "year"
  if (mode == "year") {
    years <- p$documents$year[!is.na(p$documents$year)]; req(length(unique(years)) >= 2)
    mid <- floor((min(years)+max(years))/2)
    return(fluidRow(column(3,numericInput("jsd_A_min", "A / desde",min(years),1500,2200)), column(3,numericInput("jsd_A_max","A / hasta",mid,1500,2200)),
      column(3,numericInput("jsd_B_min","B / desde",mid+1,1500,2200)), column(3,numericInput("jsd_B_max","B / hasta",max(years),1500,2200))))
  }
  if(mode=="authors")values<-sort(rv$bib$authors$elemento) else {g<-comparison_grouping();if(is.null(g))return(empty_help("Selecciona una columna o calcula el modelo de origen."));values<-sort(unique(g$valor[nzchar(g$valor)]))}
  if (length(values)<2) return(empty_help("Esta agrupación tiene menos de dos categorías. Elige otra columna, regla de citas o modelo."))
  a<-input$jsd_A %||% values[1];b<-input$jsd_B %||% values[2];if(!a %in% values)a<-values[1];if(!b %in% values||b==a)b<-setdiff(values,a)[1]
  fluidRow(column(6,selectizeInput("jsd_A", "A / referencia", values, selected = a,options=predictive_options())), column(6,selectizeInput("jsd_B", "B / comparación", values, selected = b,options=predictive_options())))
})
comparison_settings <- reactive(list(params = list(mode = if((input$jsd_mode %||% "year") %in% c("authors","citations"))"metadata" else input$jsd_mode %||% "year",group_basis=input$jsd_mode %||% "year",citation_rule=if(identical(input$jsd_mode,"citations"))input$jsd_citation_rule %||% "quartile" else NULL,citation_cutoff=if(identical(input$jsd_mode,"citations"))input$jsd_citation_cutoff %||% 10 else NULL, weighting = input$jsd_weight %||% "tokens",
  category_column = input$jsd_col %||% "", category_A = input$jsd_A %||% "", category_B = input$jsd_B %||% "",
  year_A_min = input$jsd_A_min %||% 2019, year_A_max = input$jsd_A_max %||% 2022,
  year_B_min = input$jsd_B_min %||% 2023, year_B_max = input$jsd_B_max %||% 2026, max_groups = 25L,
  uncertainty = isTRUE(input$jsd_uncertainty %||% TRUE), B = 500L, seed = 2026L),
  grouping = comparison_grouping(), origin = if (identical(input$jsd_mode,"density")) density_current()$params else if (identical(input$jsd_mode,"lda")) lda_current()$params else NULL))
comparison_current <- reactive({ current(); if (is.null(rv$comparison) || !identical(rv$comparison_signature, comparison_settings())) return(NULL); rv$comparison })
observeEvent(input$run_jsd, task("Comparando distribuciones y descomponiendo JSD…", {
  if (is.null(rv$prepared) || stale()) abort_user("Prepara un corpus vigente antes de comparar distribuciones.")
  rv$comparison <- NULL; rv$comparison_signature <- NULL; s <- comparison_settings()
  fit <- run_comparison(rv$corpus, rv$prepared, s$params, s$grouping); fit$origin <- s$origin
  if(identical(input$jsd_mode,"authors")){shared<-attr(s$grouping,"shared_documents") %||% 0;fit$audit<-rbind(fit$audit,data.frame(indicador="Documentos firmados por A y B / excluidos de ambos",valor=shared));fit$issues<-c(fit$issues,paste("Comparación de autores con conjuntos disjuntos:",shared,"documentos compartidos excluidos. La matriz se limita a los dos autores seleccionados. Revisa homónimos y dependencia por coautoría."))}
  rv$comparison <- fit; rv$comparison_signature <- s
  showNotification(sprintf("JSD %.4f bits. Comprueba cobertura y palabras que explican la diferencia.",fit$jsd),type="message")
}))
output$jsd_state <- renderUI({
  fit <- comparison_current(); if (is.null(fit)) return(empty_help("Define A y B y pulsa Comparar. Al cambiar corpus, grupos o parámetros, vuelve a calcular."))
  tagList(tags$p(class="chart-caption",paste(fit$params$label_A,"frente a",fit$params$label_B)),
    tags$div(class="network-metrics", tags$span(tags$strong(swiss_number(fit$jsd)),tags$small("JSD / bits, base 2")),
      tags$span(tags$strong(swiss_number(fit$distancia)),tags$small("Distancia / raíz de JSD")),
      tags$span(tags$strong(fit$audit$valor[3]),tags$small("Documentos en A")),tags$span(tags$strong(fit$audit$valor[4]),tags$small("Documentos en B"))),
    if(!is.null(fit$uncertainty)) {u<-fit$uncertainty
      tags$div(class="network-metrics",tags$span(tags$strong(swiss_number(u$null_mean)),tags$small("JSD esperada por azar (permutación)")),
        tags$span(tags$strong(swiss_number(u$excess)),tags$small("Exceso sobre el azar")),
        tags$span(tags$strong(format(round(u$p_value,3),nsmall=3)),tags$small("p de permutación")),
        tags$span(tags$strong(paste0("[",swiss_number(u$ci[1]),", ",swiss_number(u$ci[2]),"]")),tags$small(paste0("IC bootstrap ",round(100*u$conf),"%"))))
    },
    tags$details(tags$summary("Cobertura y lectura metodológica"), lapply(fit$issues,tags$p)))
})
jsd_graph <- reactive({ f <- comparison_current(); validate(need(!is.null(f),"Calcula una comparación vigente.")); jsd_figure(f) })
jsd_cumulative_graph <- reactive({ f <- comparison_current(); validate(need(!is.null(f),"Calcula una comparación vigente.")); jsd_cumulative_figure(f) })
jsd_matrix_graph <- reactive({ f <- comparison_current(); validate(need(!is.null(f),"Calcula una comparación vigente.")); jsd_matrix_figure(f) })
jsd_time_graph <- reactive({ f <- comparison_current(); validate(need(!is.null(f)&&nrow(f$temporal),"La evolución se habilita al comparar períodos con varios años observados.")); jsd_time_figure(f) })
output$jsd_plot <- renderPlot(jsd_graph(),height=function() 650,res=96)
output$jsd_cumulative <- renderPlot(jsd_cumulative_graph(),res=96)
output$jsd_matrix <- renderPlot(jsd_matrix_graph(),res=96)
output$jsd_time <- renderPlot(jsd_time_graph(),res=96)
output$jsd_time_reading<-renderUI({f<-comparison_current();if(is.null(f))return(hint("Calcula una comparación entre períodos para ver la lectura de cada contraste anual."));caption(jsd_time_reading(f))})
output$jsd_matrix_interactive <- plotly::renderPlotly({
  f <- comparison_current(); validate(need(!is.null(f),"Calcula una comparación JSD vigente."))
  keys <- unique(f$matrix$grupo_A); n <- length(keys)
  z <- matrix(f$matrix$jsd_bits,n,n); info <- matrix("",n,n)
  for (i in seq_len(n)) for (j in seq_len(n)) info[j,i] <- paste0(escape_html(keys[i])," / ",escape_html(keys[j]),
    "<br>JSD: ",swiss_number(z[i,j])," bits<br>Distancia: ",swiss_number(sqrt(z[i,j])),
    "<br>Documentos: ",f$coverage$documentos[i]," / ",f$coverage$documentos[j])
  labels <- if(n>12) sprintf("%02d",seq_len(n)) else substr(keys,1,26)
  chart <- plotly::plot_ly(x=seq_len(n),y=seq_len(n),z=t(z),type="heatmap",text=info,hoverinfo="text",zmin=0,zmax=1,
    colorscale=list(c(0,"#f4f4f2"),c(1,"#c7281e")),colorbar=list(title="JSD / bits",thickness=14))
  plotly::config(plotly::layout(chart,font=list(family="Arial, Helvetica, sans-serif",size=14,color="#161616"),paper_bgcolor="white",
    xaxis=list(tickangle=90,title="",tickvals=seq_len(n),ticktext=escape_html(labels),tickangle=if(n>12)0 else -35,showgrid=FALSE,zeroline=FALSE),
    yaxis=list(tickangle=0,title="",tickvals=seq_len(n),ticktext=escape_html(labels),showgrid=FALSE,zeroline=FALSE,autorange="reversed",scaleanchor="x"),
    margin=list(l=160,r=95,t=30,b=140)),displaylogo=FALSE)
})

pca_settings <- reactive(list(max_terms=input$pca_terms %||% 100L,standardize=isTRUE(input$pca_scale)))
pca_current <- reactive({ current(); if(is.null(rv$pca) || !identical(rv$pca_signature,pca_settings())) return(NULL); rv$pca })
pca_axes<-reactive({f<-pca_current();if(is.null(f))return(c(1L,2L));available<-pca_available_axes(f);a<-as.integer(input$pca_axis_x %||% 1L);b<-as.integer(input$pca_axis_y %||% 2L);if(!a %in% available)a<-available[1];if(!b %in% available||a==b)b<-setdiff(available,a)[1];c(a,b)})
output$pca_axis_controls<-renderUI({f<-pca_current();if(is.null(f))return(NULL);a<-pca_available_axes(f);choices<-setNames(a,sprintf("Componente %d / %.1f %%",a,f$dimensions$porcentaje[a]));selected<-isolate(pca_axes())
  tagList(fluidRow(column(6,selectInput("pca_axis_x","Componente horizontal",choices,selected=selected[1])),column(6,selectInput("pca_axis_y","Componente vertical",choices,selected=selected[2]))),hint("Elige dos componentes diferentes. Documentos, correlaciones, cos², contribuciones y figuras ampliadas usan el mismo par. Cambiar el plano no recalcula el modelo. Solo se ofrecen componentes con variación útil."),hint("Cos²: qué parte de la información de un punto se ve en este plano; si es baja, consulta otros ejes antes de interpretar su posición. Contribución: qué puntos ayudan a construir el contraste de un eje. Estar bien representado, contribuir mucho y ser importante para tu pregunta son cosas distintas."))})
observeEvent(list(input$pca_axis_x,input$pca_axis_y),{f<-pca_current();if(is.null(f))return();a<-pca_axes();if(identical(input$pca_axis_x,input$pca_axis_y))updateSelectInput(session,"pca_axis_y",selected=a[2])},ignoreInit=TRUE)
observeEvent(input$run_pca,task("Calculando ACP sobre TF-IDF y sus indicadores…",{
  if(is.null(rv$prepared)||stale()) abort_user("Prepara un corpus vigente antes de calcular ACP.")
  rv$pca <- NULL; rv$pca_signature <- NULL; s <- pca_settings()
  rv$pca <- run_pca(rv$corpus,rv$prepared,s$max_terms,s$standardize); rv$pca_signature <- s
  showNotification("ACP calculado. Consulta varianza, cos² y contribuciones antes de interpretar el plano.",type="message")
}))
output$pca_state <- renderUI({ f <- pca_current(); if(is.null(f)) return(empty_help("Pulsa Calcular ACP. Los cambios de corpus o parámetros requieren recalcular."))
  above<-if(isTRUE(f$params$baseline$computed)) sprintf(" Componentes por encima del azar (percentil 95 de permutaciones): %d de los %d primeros.",sum(f$dimensions$supera_azar %in% TRUE),sum(!is.na(f$dimensions$supera_azar))) else ""
  hint(sprintf("%d documentos / %d términos con variación / el plano recoge %.1f%% de varianza / centrado: sí / estandarizado: %s.%s",nrow(f$documents),nrow(f$terms),sum(f$dimensions$porcentaje[pca_axes()]),if(f$params$standardize) "sí" else "no",above)) })
output$pca_search <- renderUI({ f <- pca_current(); if(is.null(f)) return(NULL)
  selected<-isolate(input$pca_focus %||% "");session$onFlushed(function(){updateSelectizeInput(session,"pca_focus",choices=c("Vista general"="",setNames(f$documents$doc_id,paste(f$documents$doc_id,substr(f$documents$title,1,80))),setNames(f$terms$termino,f$terms$termino)),selected=selected,server=TRUE)},once=TRUE)
  selectizeInput("pca_focus","Localizar documento o término",choices=NULL,options=predictive_options()) })
pca_documents_graph <- reactive({ f <- pca_current(); validate(need(!is.null(f),"Calcula ACP con parámetros vigentes.")); ordination_figure(pca_plane(f,"documents",pca_axes()),f$dimensions,"ACP / perfiles de documentos",label_field="doc_id") })
pca_terms_graph <- reactive({ f <- pca_current(); validate(need(!is.null(f),"Calcula ACP con parámetros vigentes."));d<-ordination_quadrant(pca_plane(f,"terms",pca_axes()),input$pca_quadrant %||% "all");validate(need(nrow(d)>0,"No hay variables en este cuadrante. Elige otro o Plano completo.")); ordination_figure(d,f$dimensions,"ACP / correlaciones de términos",circle=identical(input$pca_quadrant %||% "all","all"),max_labels=input$pca_labels %||% 16) })
pca_variance_graph <- reactive({ f <- pca_current(); validate(need(!is.null(f),"Calcula ACP con parámetros vigentes.")); variance_figure(f$dimensions,"ACP / varianza por componente") })
ca_variance_graph <- reactive({ f <- ca_current(); validate(need(!is.null(f),"Calcula correspondencias con parámetros vigentes.")); variance_figure(f$dimensions,"Correspondencias / inercia por eje") })
output$pca_documents <- plotly::renderPlotly({ f <- pca_current(); validate(need(!is.null(f),"Calcula ACP para explorar documentos.")); ordination_widget(pca_plane(f,"documents",pca_axes()),f$dimensions,label_field="doc_id",focus=input$pca_focus %||% "") })
output$pca_variables <- plotly::renderPlotly({ f <- pca_current(); validate(need(!is.null(f),"Calcula ACP para explorar variables."));d<-ordination_quadrant(pca_plane(f,"terms",pca_axes()),input$pca_quadrant %||% "all");validate(need(nrow(d)>0,"No hay variables en este cuadrante. Elige otro o Plano completo.")); ordination_widget(d,f$dimensions,focus=input$pca_focus %||% "",circle=identical(input$pca_quadrant %||% "all","all"),max_labels=input$pca_labels %||% 16) })
output$pca_variance <- renderPlot(pca_variance_graph(),res=96)
output$ca_variance <- renderPlot(ca_variance_graph(),res=96)

output$jsd_caption <- renderUI({f<-comparison_current();if(is.null(f)) return(hint("La explicación de la figura aparecerá tras calcular A y B."))
  tagList(tags$p(class="chart-caption",if(f$jsd==0) "Resultado válido: A y B tienen las mismas proporciones en el vocabulario analizado. No se dibujan barras porque ninguna palabra aporta divergencia. Comprueba cobertura y ponderación; igualdad léxica no demuestra igualdad de todo el contenido." else jsd_result_reading(f)),
    tags$div(class="report-sentence",tags$h4("Cómo escribirlo en tu informe"),tags$blockquote(jsd_report_sentence(f)),hint("Las cifras proceden de tu comparación. Revisa que la redacción responda a tu pregunta antes de copiarla.")))
})
