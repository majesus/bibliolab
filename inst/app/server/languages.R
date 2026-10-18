# CLD2 solo depende del archivo y texto, nunca de settings(): no hay ciclo reactivo.
language_estimates<-reactive({
  if(!identical(input$lemma_language,"column") || identical(input$language_detection,FALSE)) return(NULL)
  req(rv$raw,nzchar(input$col_text %||% ""))
  withProgress(message="Estimando idiomas por documento…",value=.1,estimate_text_languages(mapped(rv$raw,list(text=input$col_text),"text"),execution=execution_settings(),progress=function(stage,current,total) setProgress(value=.1+.8*current/max(1,total))))
})
language_route<-reactive({req(rv$raw);mapping<-list(text=input$col_text %||% "",language=input$col_language %||% "")
  route_document_languages(rv$raw,mapping,rv$language_overrides,language_estimates())
})
language_review<-reactive({req(rv$raw);r<-language_route();d<-language_diagnostics(rv$raw,analysis_settings()$mapping,r$overrides)
  cbind(d,r$audit[setdiff(names(r$audit),c("fila","codigo_aplicado"))])
})
language_review_visible<-reactive({d<-language_review();filter<-input$language_review_filter %||% "pending"
  if(filter=="pending") d<-d[d$requiere_revision,] else if(filter=="conflict") d<-d[d$discrepancia,]
  d
})
observeEvent(input$col_text,{
  current<-input$col_text %||% ""
  if(!is.null(rv$language_text_column) && !identical(current,rv$language_text_column) && length(rv$language_overrides)) {
    rv$language_overrides<-character()
    showNotification("Cambió el texto analizado: se actualizan las estimaciones y se retiran las correcciones de la columna anterior.",type="message")
  }
  rv$language_text_column<-current
},ignoreNULL=TRUE,priority=100)
required_languages<-reactive({
  if(identical(input$lemma_language,"column")) {d<-language_review();return(sort(unique(d$codigo[nzchar(d$codigo)&nzchar(trimws(d$texto_ejemplo))])))}
  lang<-input$lemma_language %||% "es";if(lang %in% names(language_models())) lang else character()
})
output$language_routing<-renderUI({
  if(!identical(input$lemma_language,"column")) return(hint("Si todos los textos están en el idioma elegido, se aplica ese modelo a todos. Si hay varios idiomas, cambia a Varios idiomas: se estimarán automáticamente por documento."))
  if(is.null(rv$raw)) return(hint("Importa el archivo antes de estimar idiomas."))
  d<-language_review();known<-d$codigo[nzchar(d$codigo)];counts<-table(known)
  tagList(tags$p("CLD2 estima localmente el idioma de cada texto seleccionado. Asigna los casos fiables, compatibles y con al menos 90% del texto clasificado en una lengua. Una etiqueta reconocida del CSV se conserva; las correcciones manuales tienen prioridad."),
    tags$p(if(length(counts)) paste(paste(language_labels()[names(counts)],as.integer(counts),sep=": "),collapse=" / ") else "Aún no hay idiomas asignados."),
    hint(paste(sum(d$origen_idioma=="CLD2 automático"),"asignaciones automáticas /",sum(d$requiere_revision),"textos pendientes /",sum(d$discrepancia),"discrepancias con la estimación. Revisión de la entrada antes de filtros; solo los documentos incluidos con texto necesitan modelo.")),
    actionButton("review_languages","Revisar idiomas / solo pendientes",class="btn-quiet"))
})
observeEvent(input$review_languages,{
  req(rv$raw)
  showModal(modalDialog(title="Varios idiomas / estimar y revisar",size="l",easyClose=TRUE,
    tags$p(class="modal-lead","CLD2 asigna automáticamente los textos claros. Aquí revisas solo los pendientes: selecciona sus filas, elige el idioma y pulsa Asignar. El filtro también permite consultar todas las asignaciones y las discrepancias."),
    checkboxInput("language_detection","Completar idiomas automáticamente con CLD2",!identical(input$language_detection,FALSE)),
    tags$details(tags$summary("Cómo se decide el idioma / prioridades y límites"),
      tags$p("El idioma corresponde al texto seleccionado, que puede ser una traducción del resumen. Se mantienen las etiquetas reconocidas del archivo y, por encima de ellas, tus correcciones. CLD2 puede detectar lenguas que no tienen lematizador aquí: no se sustituyen por español ni se aplica otro modelo. Un texto breve, incierto o con mezcla importante necesita revisión."),
      tags$p("CLD2 funciona en este ordenador: no envía resúmenes a Google. Su indicador fiable es una regla del detector. El porcentaje refleja la parte del texto clasificado en la lengua dominante; no es una probabilidad de que haya acertado. La app exige al menos 40 letras y 90% de predominio. Revisa una muestra de los automáticos, además de los pendientes. Si un resumen mezcla lenguas, revisa su contenido antes de forzar una etiqueta.")),
    tags$div(class="row control-row",column(6,selectInput("language_column_choice","Columna con etiquetas de idioma / opcional",c("Sin columna / usar estimación automática"="",setNames(language_columns(rv$raw),language_columns(rv$raw))),selected=input$col_language %||% "")),
      column(6,selectInput("language_review_filter","Qué filas quieres revisar",c("Solo pendientes de asignación"="pending","Discrepancias de etiquetas o correcciones frente a CLD2"="conflict","Todas las filas"="all"),selected=input$language_review_filter %||% "pending"))),uiOutput("language_review_message"),
    tags$div(class="row control-row",column(5,selectInput("language_assign","Idioma de las filas seleccionadas",language_choices())),column(7,tags$div(class="figure-tools",actionButton("apply_language_rows","Asignar a filas seleccionadas",class="btn-primary"),actionButton("clear_language_rows","Quitar corrección manual",class="btn-primary")))),
    hint("Selecciona una o varias filas. Buscar, filtrar y ordenar conserva los números originales. Quitar una corrección recupera la etiqueta del archivo o la asignación automática, si existe."),
    DT::DTOutput("language_review_table"),footer=modalButton("Cerrar revisión")))
})
observeEvent(input$language_column_choice,{
  if(!is.null(rv$raw) && input$language_column_choice %in% c("",names(rv$raw))) updateSelectInput(session,"col_language",selected=input$language_column_choice)
},ignoreInit=TRUE)
output$language_review_message<-renderUI({d<-language_review_visible();if(!nrow(d)) hint("No hay filas para este filtro. Si elegiste pendientes, todos los textos tienen un idioma asignado. Elige Todas las filas para revisar una muestra de las asignaciones.") else hint(paste(nrow(d),"filas con este filtro. Buscar dentro de la tabla permite localizar documentos concretos."))})
output$language_review_table<-table_render(function(){d<-language_review_visible();cols<-c("fila","id","idioma_csv","idioma_reconocido","origen_idioma","idioma_estimado","estado_estimacion","porcentaje_texto_clasificado","texto_ejemplo");d[intersect(cols,names(d))]},selection="multiple")
observeEvent(input$apply_language_rows,{
  rows<-input$language_review_table_rows_selected %||% integer();d<-language_review_visible();rows<-rows[rows>=1 & rows<=nrow(d)]
  if(!length(rows)) {showNotification("Selecciona las filas de la tabla a las que quieres asignar un idioma.",type="warning");return()}
  req(input$language_assign %in% names(language_models()))
  keys<-as.character(d$fila[rows]);values<-rv$language_overrides;values[keys]<-input$language_assign;rv$language_overrides<-values[order(as.integer(names(values)))];rv$language_text_column<-input$col_text
  showNotification(paste(length(rows),"filas corregidas. Pulsa Preparar corpus para aplicar la revisión."),type="message")
})
observeEvent(input$clear_language_rows,{
  rows<-input$language_review_table_rows_selected %||% integer();d<-language_review_visible();rows<-rows[rows>=1 & rows<=nrow(d)]
  if(!length(rows)) return()
  rv$language_overrides<-rv$language_overrides[!names(rv$language_overrides) %in% as.character(d$fila[rows])]
})
observeEvent(input$download_required_models,task("Preparando los modelos de los idiomas asignados…",{
  langs<-required_languages()
  if(!length(langs)) abort_user("Primero estima o revisa los idiomas. En Varios idiomas abre Revisar idiomas; después vuelve al gestor de modelos.")
  for(lang in langs) download_language_model(lang)
  rv$models_revision<-rv$models_revision+1L
  showNotification("Modelos necesarios preparados. Vuelve a 02 y pulsa Preparar corpus.",type="message")
}))
