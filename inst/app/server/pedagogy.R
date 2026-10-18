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
  lesson <- enrich_lesson("jsd",lesson_catalog()$jsd)
  showModal(modalDialog(title="Cómo pesa cada documento / elegir con criterio",size="l",easyClose=TRUE,
    tags$div(class="lesson",tags$p(class="modal-lead","Las dos opciones comparan proporciones de palabras. La diferencia está en cuánto aporta un resumen largo frente a uno breve."),
      tags$section(class="choice-card",tags$h3("Tokens agrupados / estudiar el uso total de palabras"),tags$p("Sumamos todas las apariciones del grupo y dividimos por su total. Un documento de 400 palabras aporta cuatro veces más palabras que uno de 100. Úsalo si quieres describir cómo se reparte el vocabulario total del corpus.")),
      tags$section(class="lesson-example",tags$h3("El mismo grupo puede responder a dos preguntas"),tags$p("Un resumen breve contiene educación y salud una vez cada una. Otro contiene educación ocho veces y salud dos. Agrupando tokens, educación tiene 9 de 12 apariciones: 75%. Equilibrando los documentos, promediamos 50% y 80%: educación tiene 65%. Ningún resultado es erróneo: expresan preguntas distintas.")),
      tags$section(class="choice-card",tags$h3("Documentos equilibrados / estudiar el perfil de un documento medio"),tags$p("Primero normalizamos cada documento; después promediamos. Cada documento con vocabulario aporta el mismo peso. Es una primera comparación útil cuando los resúmenes difieren mucho en longitud y te interesa comparar perfiles de publicaciones.")),
      tags$section(class="lesson-example",tags$h3("Por qué una revisión extensa puede invertir la lectura"),tags$p(tail(lesson$example,1)),HTML(html_table(lesson$worked,show_note=FALSE))),
      tags$p("El mismo cambio se verá en la orientación de los shifts: clínica apuntará hacia el conjunto donde tenga mayor proporción. La longitud de su barra indica su parte de la divergencia total, que depende de todas las palabras. No basta este ejemplo para afirmar que su barra será larga o que ha cambiado el interés de toda una disciplina."),
      tags$p("Recomendación: elige según la pregunta, mantén la misma ponderación en A y B y comprueba cobertura. Para el trabajo académico conserva una segunda ejecución con la otra opción si la longitud puede condicionar la interpretación."),
      radioButtons("jsd_weight_choice","Opción para esta comparación",c("Tokens agrupados"="tokens","Documentos equilibrados"="documents"),selected=input$jsd_weight %||% "tokens")),
    footer=tagList(modalButton("Cancelar"),actionButton("apply_jsd_weight","Aplicar esta opción",class="btn-primary"))))
})
observeEvent(input$apply_jsd_weight,{req(input$jsd_weight_choice %in% c("tokens","documents"));updateSelectInput(session,"jsd_weight",selected=input$jsd_weight_choice);removeModal()})
output$ngrams_visible<-table_render(function(){head(gram_data(),25)})
model_comparison_data<-reactive({p<-current();model_comparison_table(lda_current(),density_current(),pca_current(),ca_current(),p,pca_axes())})
output$model_comparison<-table_render(function(){model_comparison_data()[c("metodo","documentos_modelo","resultado","hallazgos","diagnosticos_observados")]})
output$model_comparison_details<-table_render(model_comparison_data)
output$bibliography_extension_table<-table_render(function(){current();d<-rv$bib$extensiones[[input$bibliography_extension %||% "cobertura"]];if(identical(input$bibliography_extension %||% "cobertura","cobertura"))names(d)[names(d)=="total"]<-"Documentos preparados / total";d})
output$bibliography_extension_note<-renderUI({current();tags$p(class="chart-caption",switch(input$bibliography_extension %||% "cobertura",
  referencias="Cada referencia cuenta una vez por documento citante. Identificación exacta tras normalizar espacios y mayúsculas; las variantes pueden dividir una misma obra. No son citas recibidas.",
  concentracion_fuentes="Ordenamos fuentes desde la que tiene más documentos. Sumamos sus documentos hasta cada posición y dividimos entre todos los documentos con fuente conocida. Ejemplo: de 100 documentos con fuente, la primera revista tiene 30 y la segunda 20; la curva marca 30 % en posición 1 y 50 % en posición 2. Los documentos sin fuente quedan fuera del denominador. Una subida rápida describe concentración en esta búsqueda. Para ver las tres zonas de Bradford, abre la pestaña Leyes bibliométricas; ninguna vista prueba la ley ni la calidad de las revistas.",
  citas_cohorte="Citas divididas por la media de citas válidas del mismo año y corpus. Solo se calcula con al menos cinco registros válidos y media positiva. No normaliza por disciplina; los valores ausentes no son cero.",
  "Cobertura tras preparar el corpus. Si no hay referencias citadas, no se pueden construir cocitación ni acoplamiento. La ausencia de un metadato no demuestra ausencia de una relación."))})
output$source_point_control<-renderUI({current();d<-rv$bib$extensiones$concentracion_fuentes;if(!nrow(d))return(empty_help("Asigna una columna de fuente para ver su concentración."));selected<-isolate(input$source_point %||% d$posicion[which(d$porcentaje_acumulado>=80)[1]])
  selectInput("source_point","Marcar una fuente / también puedes pulsar un punto de la curva",setNames(d$posicion,paste0(d$posicion," · ",display_label(d$elemento,"source"))),selected=selected)})
output$source_concentration<-plotly::renderPlotly({current();d<-rv$bib$extensiones$concentracion_fuentes;validate(need(nrow(d)>0,"Asigna una columna de fuente para ver su concentración."));source_concentration_widget(d,as.integer(input$source_point %||% 1L))})
observeEvent({if(is.null(input[["plotly_click-source_concentration"]]))NULL else plotly::event_data("plotly_click",source="source_concentration",priority="event")},{e<-plotly::event_data("plotly_click",source="source_concentration",priority="event");if(!is.null(e$customdata))updateSelectInput(session,"source_point",selected=as.character(e$customdata[1]))},ignoreInit=TRUE)
output$source_point_reading<-renderUI({current();d<-rv$bib$extensiones$concentracion_fuentes;if(!nrow(d))return(NULL);i<-match(as.integer(input$source_point %||% 1),d$posicion);if(is.na(i))return(NULL)
  k<-vapply(c(50,80),function(p)d$posicion[which(d$porcentaje_acumulado>=p)[1]],1L)
  hint(sprintf("Punto elegido: %d fuentes (%.1f %% de %d fuentes) acumulan %.2f %% de los documentos con fuente. Para alcanzar al menos el 50 %% hacen falta %d fuentes; para el 80 %%, %d. Las líneas 50 %% y 80 %% son referencias descriptivas, no umbrales universales ni una prueba de Bradford.",d$posicion[i],100*d$posicion[i]/nrow(d),nrow(d),d$porcentaje_acumulado[i],k[1],k[2]))})
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
