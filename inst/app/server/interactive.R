# Figuras con lectura por cursor: etiquetas reducidas, información completa.
output$token_interactive <- plotly::renderPlotly({
  current(); d <- token_view_base(); validate(need(nrow(d)>0, "No hay términos en este estado del vocabulario. Elige Evaluado o Solo retenido, o revisa los filtros de Preparación."))
  d$hover <- paste0(escape_html(d$termino), "<br>Documentos: ", d$documentos, " (", d$porcentaje_documentos, "%)<br>Apariciones: ", d$frecuencia,
    "<br>TF-IDF medio: ", signif(d$tfidf_medio, 4), "<br>Entropía: ", round(d$entropia, 3), "<br>", escape_html(d$motivo_exclusion))
  focus<-input$token_focus %||% ""
  chart <- plotly::plot_ly()
  for (kept in c(TRUE, FALSE)) {
    part <- d[d$incluido == kept, ]; if (!nrow(part)) next
    chart <- plotly::add_trace(chart, data = part, x = ~porcentaje_documentos, y = ~tfidf_medio, type = "scatter", mode = "markers",
      name = if (kept) "Retenido" else "Excluido", text = ~hover, hoverinfo = "text",
      marker = list(color = if (kept) "#c7281e" else "#aaa", size = 7, opacity = .72))
  }
  if(focus %in% d$termino) {part<-d[d$termino==focus,];chart<-plotly::add_trace(chart,data=part,x=~porcentaje_documentos,y=~tfidf_medio,type="scatter",mode="markers",name=paste("Localizado:",focus),text=~hover,hoverinfo="text",marker=list(size=15,symbol="circle-open",color="#161616",line=list(width=2)))}
  plotly::config(plotly::layout(chart, font = list(family = "Arial, Helvetica, sans-serif", size = 14, color = "#161616"), paper_bgcolor = "white", plot_bgcolor = "white",
    xaxis = list(tickangle=90,title=list(text="Presencia en documentos (%)",standoff=24),automargin=TRUE,range=c(-2,103)), yaxis=list(tickangle=0,title=list(text="TF-IDF medio por unidad",standoff=24),automargin=TRUE,rangemode="tozero"),
    legend=list(orientation="h",y=1.12,x=0),margin=list(l=100,r=45,t=65,b=95)), displaylogo = FALSE)
})
output$ca_interactive <- plotly::renderPlotly({
  fit <- ca_current(); validate(need(!is.null(fit), "Calcula correspondencias para explorar los términos."))
  ordination_widget(fit$terms,fit$dimensions,focus=input$ca_focus %||% "")
})
output$ca_expanded<-plotly::renderPlotly({f<-ca_current();validate(need(!is.null(f),"Calcula correspondencias con parámetros vigentes."));ordination_widget(f$terms,f$dimensions,focus=input$expanded_ca_focus %||% input$ca_focus %||% "",max_labels=input$expanded_ca_labels %||% 40L,label_canvas=c(max(300,(session$clientData$output_ca_expanded_width %||% 1200)-170),max(250,(session$clientData$output_ca_expanded_height %||% 750)-115)))})
density_membership_graph <- reactive({
  fit <- density_current(); validate(need(!is.null(fit), "Calcula UMAP y HDBSCAN para estudiar el grado de pertenencia.")); d <- density_display(fit)
  d <- d[d$grupo > 0, ]; validate(need(nrow(d)>0, "No hay grupos asignados para resumir el grado de pertenencia."))
  ggplot2::ggplot(d, ggplot2::aes(grupo_label, membresia)) + ggplot2::geom_boxplot(fill = "#eee", outlier.shape = NA, width = .55) +
    ggplot2::geom_jitter(alpha = .4, size = 1.6, colour = "#c7281e", position = ggplot2::position_jitter(width = .12, height = 0, seed = 2026)) +
    ggplot2::coord_flip() + ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::labs(x = NULL, y = "Pertenencia al grupo (HDBSCAN) · no es probabilidad temática", title = "Distribución del grado de pertenencia por grupo") + plot_theme()
})
output$density_membership_plot <- renderPlot(density_membership_graph(), res = 96)

output$ca_search <- renderUI({ fit <- ca_current(); if (is.null(fit)) return(NULL)
  selectizeInput("ca_focus", "Localizar un término · útil cuando varios puntos coinciden", c("Vista general" = "", setNames(fit$terms$termino, fit$terms$termino)), selected = "")
})
output$ca_detail <- renderUI({ fit <- ca_current(); req(!is.null(fit)); term <- input$ca_focus %||% ""; if (!term %in% fit$terms$termino) return(hint("Pasa el cursor o busca un término. Los términos con perfiles idénticos pueden coincidir en el plano; la tabla permite consultar todos."))
  d <- fit$terms[fit$terms$termino == term, ]
  tags$p(class = "chart-caption", sprintf("%s · cos² %.3f · contribución eje 1 %.2f%% · contribución eje 2 %.2f%% · masa %.4f. Cos² indica calidad de representación; contribución indica participación en el eje.", term, d$cos2_plano, d$contribucion_eje_1, d$contribucion_eje_2, d$masa))
})

token_view_base<-reactive({current();filter_term_table(rv$corpus$terms,status=input$token_rank_status %||% "all")})
token_view<-reactive({current();term_view_data(rv$corpus$terms,input$token_rank_metric %||% "frecuencia",input$token_rank_status %||% "all",input$token_rank_n %||% 12,compare_states=TRUE)})
token_display_metric<-reactive({m<-input$token_rank_metric %||% "frecuencia";if(startsWith(m,"tfidf_"))m else "tfidf_medio"})
token_bars_graph<-reactive({current();d<-token_view();validate(need(nrow(d)>0,"No hay términos en este estado del vocabulario. Cambia a Evaluado o Solo retenido, o revisa los filtros de Preparación."));term_comparison_figure(d,if(isTRUE(rv$prepared$config$split_sentences)) "frase" else "documento",token_display_metric())})
output$token_bars<-renderPlot(token_bars_graph(),height=function() max(460,nrow(token_view())*32+175),res=96)
output$token_search<-renderUI({d<-token_view_base();selected<-isolate(input$token_focus %||% "");if(!selected %in% d$termino)selected<-""
  session$onFlushed(function(){updateSelectizeInput(session,"token_focus",choices=c("Seleccionar un término"="",setNames(d$termino,d$termino)),selected=selected,server=TRUE)},once=TRUE)
  selectizeInput("token_focus","Localizar un término / ver sus cifras y posición en el mapa",choices=NULL,selected=NULL,options=list(maxOptions=100))})
output$token_focus_detail<-renderUI({d<-token_view_base();term<-input$token_focus %||% "";if(!term %in% d$termino) return(hint("Si necesitas una palabra fuera de las barras, selecciónala aquí para consultar sus valores. En Explorar mapa se marca su posición con un contorno, sin escribir sobre otros puntos."))
  a<-d[d$termino==term,];tags$p(class="chart-caption",paste0(term,": ",a$frecuencia," apariciones en ",a$documentos," documentos (",a$porcentaje_documentos,"% del corpus). TF-IDF medio ",swiss_number(a$tfidf_medio),". ",a$motivo_exclusion,". Estas cifras describen el corpus, no relevancia científica automática."))})
output$tokens_visible<-table_render(function(){current();d<-token_view();d[intersect(c("termino","documentos","frecuencia","tfidf_medio","tfidf_sd","tfidf_median","tfidf_mad","tfidf_q25","tfidf_q75","tfidf_q90","tfidf_present_median","bm25_medio","entropia","incluido"),names(d))]})
output$token_selection_note<-renderUI({current();d<-token_view();all<-rv$corpus$terms;m<-input$token_rank_metric %||% "frecuencia";tags$p(class="chart-caption",paste("Evaluados:",nrow(all),"/ retenidos:",sum(all$incluido),"/ excluidos:",sum(!all$incluido),".",if(!any(!all$incluido))"Evaluado y Solo retenido coinciden porque no hay términos excluidos con estas reglas." else if((input$token_rank_status %||% "all")=="all") "Las barras muestran rankings separados: hasta el máximo elegido de cada estado. Así los excluidos no desaparecen detrás de los retenidos más frecuentes." else "La selección corresponde solo al estado elegido.",nrow(d),"términos mostrados de",nrow(token_view_base()),"; orden:",names(term_metric_choices())[match(m,term_metric_choices())],". El mapa muestra todos los términos del estado elegido."))})
output$token_explanation<-renderUI(tagList(tags$div(class="concept-grid",
  tags$section(tags$h3("Frecuencia / cuánto se repite"),tags$p("Cuenta apariciones. Diez repeticiones en un solo resumen suman diez, aunque solo exista un documento.")),
  tags$section(tags$h3("Presencia / en cuántos textos"),tags$p("Cuenta documentos distintos. Esas diez repeticiones en el mismo resumen cuentan como presencia en un documento.")),
  tags$section(tags$h3("Especificidad / qué textos distingue"),tags$p("TF-IDF pondera el uso relativo en un texto y la rareza entre textos. Un término compartido por todos distingue poco; esto no implica que carezca de importancia para el estudio."))),
  tags$p("La media de TF-IDF es una forma de resumir pesos, no una convención obligatoria. Mediana y percentiles globales incluyen ceros y pueden empatar en cero en vocabularios dispersos; los resúmenes con peso positivo describen solo las unidades donde el peso es mayor que cero. Compara siempre presencia. El estadístico de Preparación conserva la elección que usaste al seleccionar vocabulario."),
  tags$p("Las tres barras de una fila corresponden al mismo término y tienen escalas distintas. La tercera usa el estadístico TF-IDF elegido; al ordenar por frecuencia o presencia muestra la media global. El mapa utiliza la media global para mantener su definición y muestra todos los términos del estado elegido.")))
output$tfidf_zero_note<-renderUI({tx<-tfidf_zero_diagnosis(rv$corpus$terms);if(is.null(tx))return(NULL);tags$p(class="parameter-note",tx)})