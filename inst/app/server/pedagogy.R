analysis_gate <- function(button) {
  if(!is.null(rv$prepared) && !stale()) return(NULL)
  tags$section(class="analysis-gate",tags$h3(if(is.null(rv$prepared)) "Falta preparar el corpus" else "Hay cambios pendientes de preparar"),
    tags$p("Puedes recorrer las pantallas y sus guías. Para calcular resultados fiables necesitas confirmar las columnas y pulsar Preparar corpus en 02. Allí se aplican filtros, duplicados y vocabulario; 03 y 04 utilizan esa misma ejecución."),
    actionButton(button,"Ir a 02 / Preparación",class="btn-next"))
}
output$analysis_gate<-renderUI(analysis_gate("prepare_from_indicators"))
output$model_gate<-renderUI(analysis_gate("prepare_from_models"))
observeEvent(input$prepare_from_indicators,updateTabsetPanel(session,"steps",selected="prepare"))
observeEvent(input$prepare_from_models,updateTabsetPanel(session,"steps",selected="prepare"))
observeEvent(input$help_jsd_weight, {
  doc <- help_document("jsd_weight")
  showModal(modalDialog(title = if (is.null(doc)) "Cómo pesa cada documento / elegir con criterio" else doc$meta$titulo, size = "l", easyClose = TRUE,
    help_modal_body("jsd_weight"),
    tags$div(class = "lesson help-doc", radioButtons("jsd_weight_choice", "Opción para esta comparación", c("Tokens agrupados" = "tokens", "Documentos equilibrados" = "documents"), selected = input$jsd_weight %||% "tokens")),
    footer = tagList(modalButton("Cancelar"), actionButton("apply_jsd_weight", "Aplicar esta opción", class = "btn-primary"))))
})
observeEvent(input$apply_jsd_weight,{req(input$jsd_weight_choice %in% c("tokens","documents"));updateSelectInput(session,"jsd_weight",selected=input$jsd_weight_choice);removeModal()})
output$ngrams_visible<-table_render(function(){head(gram_data(),25)})
model_comparison_data<-reactive({p<-current();model_comparison_table(lda_current(),density_current(),pca_current(),ca_current(),p,pca_axes())})
output$model_comparison<-table_render(function(){model_comparison_data()[c("metodo","documentos_modelo","resultado","hallazgos","diagnosticos_observados")]})
output$model_comparison_details<-table_render(model_comparison_data)
output$bibliography_extension_table<-table_render(function(){current();d<-rv$bib$extensiones[[input$bibliography_extension %||% "cobertura"]];if(identical(input$bibliography_extension %||% "cobertura","cobertura"))names(d)[names(d)=="total"]<-"Documentos preparados / total";d})
output$bibliography_extension_note<-renderUI({current();tags$p(class="chart-caption",switch(input$bibliography_extension %||% "cobertura",
  referencias="Cada referencia cuenta una vez por documento citante. Identificación exacta tras normalizar espacios y mayúsculas; las variantes pueden dividir una misma obra. No son citas recibidas.",
  concentracion_fuentes="Ordenamos fuentes desde la que tiene más documentos. Sumamos sus documentos hasta cada posición y dividimos entre todos los documentos con fuente conocida. Ejemplo: de 100 documentos con fuente, la primera revista tiene 30 y la segunda 20; la curva marca 30 % en posición 1 y 50 % en posición 2. Los documentos sin fuente quedan fuera del denominador. Una subida rápida describe concentración en esta búsqueda; no prueba la ley de Bradford ni calidad de revistas.",
  citas_cohorte="Citas divididas por la media de citas válidas del mismo año y corpus. Solo se calcula con al menos cinco registros válidos y media positiva. No normaliza por disciplina; los valores ausentes no son cero.",
  "Cobertura tras preparar el corpus. Si no hay referencias citadas, no se pueden construir cocitación ni acoplamiento. La ausencia de un metadato no demuestra ausencia de una relación."))})
output$source_point_control<-renderUI({current();d<-rv$bib$extensiones$concentracion_fuentes;if(!nrow(d))return(empty_help("Asigna una columna de fuente para ver su concentración."));selected<-isolate(input$source_point %||% d$posicion[which(d$porcentaje_acumulado>=80)[1]])
  selectInput("source_point","Marcar una fuente / también puedes pulsar un punto de la curva",setNames(d$posicion,paste0(d$posicion," · ",display_label(d$elemento,"source"))),selected=selected)})
output$source_concentration<-plotly::renderPlotly({current();d<-rv$bib$extensiones$concentracion_fuentes;validate(need(nrow(d)>0,"Asigna una columna de fuente para ver su concentración."));source_concentration_widget(d,as.integer(input$source_point %||% 1L))})
observeEvent({if(is.null(input[["plotly_click-source_concentration"]]))NULL else plotly::event_data("plotly_click",source="source_concentration",priority="event")},{e<-plotly::event_data("plotly_click",source="source_concentration",priority="event");if(!is.null(e$customdata))updateSelectInput(session,"source_point",selected=as.character(e$customdata[1]))},ignoreInit=TRUE)
output$source_point_reading<-renderUI({current();d<-rv$bib$extensiones$concentracion_fuentes;if(!nrow(d))return(NULL);i<-match(as.integer(input$source_point %||% 1),d$posicion);if(is.na(i))return(NULL)
  k<-vapply(c(50,80),function(p)d$posicion[which(d$porcentaje_acumulado>=p)[1]],1L)
  hint(sprintf("Punto elegido: %d fuentes (%.1f %% de %d fuentes) acumulan %.2f %% de los documentos con fuente. Para alcanzar al menos el 50 %% hacen falta %d fuentes; para el 80 %%, %d. Las líneas 50 %% y 80 %% son referencias descriptivas, no umbrales universales ni una prueba de Bradford. El 80/20 se puede contrastar leyendo qué proporción de fuentes alcanza el 80 %% en tu corpus.",d$posicion[i],100*d$posicion[i]/nrow(d),nrow(d),d$porcentaje_acumulado[i],k[1],k[2]))})
output$download_skills<-downloadHandler(filename="skills_bibliometria.zip",content=function(file){
  root<-system.file("skills",package="bibliolab");zip::zipr(file,list.files(root),root=root)
})

output$gram_explanation<-renderUI({d<-gram_data();metric<-input$gram_metric %||% "documentos";tags$p(class="chart-caption",paste(switch(metric,
  documentos="Presencia cuenta documentos distintos que contienen la expresión, aunque se repita en cada uno. El ranking muestra cuáles están más extendidas por el corpus. Consulta apariciones para distinguir extensión y repetición.",
  frecuencia="Apariciones suma todas las repeticiones. Una expresión repetida mucho en un solo documento puede subir en este ranking aunque tenga poca presencia. Compara documentos y concentración antes de generalizar.",
  tfidf_medio="Uso local es la proporción de esa expresión entre todas las expresiones de la misma longitud de un documento. Rareza es log(N/df): N documentos activos y df documentos que contienen la expresión. Multiplicamos ambos y calculamos la media, incluidos ceros. Un texto atípico puede modificarla; compara mediana, MAD y presencia en la tabla. No mide importancia científica.",
  tfidf_mediana="Mediana de los pesos TF-IDF entre documentos activos para esta longitud, incluidos ceros. Es 0 cuando la expresión falta en más de la mitad. Revisa presencia y la mediana con peso positivo de la tabla antes de interpretar empates.",
  tfidf_q75="Percentil 75 de los pesos TF-IDF entre documentos activos, incluidos ceros (tipo 7 de R). Es menos sensible a un peso extremo que la media, pero puede valer 0 en expresiones raras. Consulta presencia y MAD en la tabla.",
  concentracion="Concentración es uno menos entropía normalizada. Cerca de uno, las apariciones se acumulan en pocos documentos; cerca de cero, se reparten de forma uniforme entre el corpus preparado. Complementa frecuencia y presencia, no mide calidad."),
  if(nrow(d))paste("De",nrow(d),"expresiones que cumplen la presencia mínima,",sum(d[[metric]]>0),"tienen este indicador mayor que cero y",sum(d[[metric]]==0),"valen cero. Se muestran hasta 25; los ceros tienen un punto y su cifra, aunque no tengan barra.") else "No hay expresiones que cumplan la presencia mínima.",
  if(metric %in% c("tfidf_mediana","tfidf_q75"))"Mediana y percentil se calculan para cada expresión entre documentos, no entre las expresiones del ranking. No filtran el 50 % o el 75 % de los términos. Ejemplo: una expresión con pesos 0, 0, 0, 0, 0, 0, 0, 0,2 en ocho documentos tiene mediana 0 y percentil 75 igual a 0. Sigue siendo un resultado válido y conserva su fila. Los empates se ordenan por presencia y después alfabéticamente." else ""))})

output$model_route_card<-renderUI({
  id<-input$model_route;routes<-model_routes()
  if(is.null(id)||!length(id)||!id %in% names(routes))return(hint("Elige una pregunta para ver su ruta. Los controles de cada an\u00e1lisis est\u00e1n en las pesta\u00f1as siguientes."))
  r<-routes[[id]]
  tags$section(class="route-card",tags$h3(r$question),
    tags$p(tags$strong("Qu\u00e9 devuelve. "),r$returns),tags$p(tags$strong("Qu\u00e9 decisi\u00f3n exige. "),r$decision),tags$p(tags$strong("Qu\u00e9 no permite concluir. "),r$limit),
    tags$div(class="figure-tools",if(is.null(r$tabs))actionButton("finish_models",r$labels,class="btn-next")
      else lapply(seq_along(r$tabs),function(i)actionButton(paste0("model_route_go_",i),r$labels[i],class="btn-next"))))
})
for(i in 1:2)local({k<-i;observeEvent(input[[paste0("model_route_go_",k)]],{
  if(!isTRUE(input[[paste0("model_route_go_",k)]]>0))return()
  r<-model_routes()[[input$model_route %||% ""]]
  if(is.null(r)||is.null(r$tabs)||k>length(r$tabs))return()
  updateTabsetPanel(session,"model_method",selected=r$tabs[k])
})})
observeEvent(input$reset_density_advanced,{
  updateNumericInput(session,"lsa_dims",value=30);updateNumericInput(session,"umap_dims",value=5)
  updateNumericInput(session,"umap_min_dist",value=0);updateSelectInput(session,"umap_epochs",selected="300")
})
