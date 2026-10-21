# Separate state: neither modifies nor invalidates existing analyses.
thematic_fit <- reactiveVal(NULL)
thematic_signature <- reactiveVal(NULL)
thematic_settings <- reactive(list(field = input$thematic_field %||% "keywords",
  min_presence = input$thematic_presence %||% 2L, max_terms = input$thematic_terms %||% 100L,
  min_shared = input$thematic_shared %||% 1L, resolution = input$thematic_resolution %||% 1,
  seed = input$thematic_seed %||% 2026L))
# Observe actual prepared objects so replacing or re-preparing a corpus invalidates
# this result even when the input settings return to their former values.
observeEvent(list(rv$prepared, rv$corpus), {
  thematic_fit(NULL); thematic_signature(NULL)
}, ignoreNULL = FALSE, priority = 100)
thematic_current <- reactive({
  current()
  if (is.null(thematic_fit()) || !identical(thematic_signature(), thematic_settings())) return(NULL)
  thematic_fit()
})
output$thematic_input_coverage <- renderUI({
  p <- current()
  if (identical(input$thematic_field %||% "keywords", "keywords")) {
    n <- sum(nzchar(clean_value(p$documents$keywords)))
    hint(paste(n, "de", nrow(p$documents), "documentos preparados tienen contenido en el campo de palabras clave.",
      if (!n) "Asigna un campo con datos en 02 o elige vocabulario preparado." else
        "Comprueba su origen y separador en 02. Este campo es independiente de los filtros de vocabulario del texto."))
  } else hint(paste(length(rv$corpus$vocabulary), "términos retenidos en la preparación. Se agregan las frases al documento antes de contar copresencias."))
})
observeEvent(input$run_thematic, task("Calculando comunidades y medidas de Callon…", {
  p <- current()
  thematic_fit(NULL); thematic_signature(NULL)
  s <- thematic_settings()
  fit <- run_thematic_map(rv$corpus, p, s)
  thematic_fit(fit); thematic_signature(s)
  showNotification(paste(nrow(fit$themes), "temas calculados. Revisa los términos y la cobertura."), type = "message")
}))
output$thematic_state <- renderUI({
  fit <- thematic_current()
  if (is.null(fit)) return(empty_help("Pulsa Calcular mapa temático. Si cambias el corpus o los parámetros, vuelve a calcular."))
  tagList(tags$p(class = "chart-caption", thematic_reading(fit)),
    tags$details(tags$summary("Método y cortes de esta ejecución"), tags$p(fit$method),
      tags$p(paste("Mediana de centralidad:", signif(fit$cuts[[1]], 5), "/ mediana de densidad:", signif(fit$cuts[[2]], 5)))))
})
output$thematic_plot <- renderPlot({
  fit <- thematic_current(); validate(need(!is.null(fit), "Calcula el mapa con el corpus y los parámetros actuales."))
  thematic_plot(fit, compact = isTRUE((session$clientData$output_thematic_plot_width %||% 1000) < 600))
}, height = function() if (isTRUE((session$clientData$output_thematic_plot_width %||% 1000) < 600)) 640L else 800L, res = 110)
thematic_table <- function(key) {
  fit <- thematic_current(); validate(need(!is.null(fit), "Calcula un mapa vigente."))
  d <- fit[[key]]
  labels <- c(tema = "Tema", terminos = "Términos", centralidad = "Centralidad de Callon", densidad = "Densidad de Callon",
    etiqueta = "Términos principales", documentos = "Documentos / no exclusivos por tema", cuadrante = "Posición respecto a las medianas",
    termino = "Término", etapa = "Etapa", cantidad = "Cantidad", estado = "Estado", from = "Término A", to = "Término B", coincidencias = "Documentos compartidos", peso = "Índice de equivalencia")
  for (key in intersect(names(d), names(labels))) names(d)[names(d) == key] <- labels[[key]]
  d
}
thematic_table_keys <- c(themes = "themes", terms_table = "terms", coverage = "coverage", selection = "selection", edges = "edges")
for (key in names(thematic_table_keys)) local({
  id <- key; kind <- thematic_table_keys[[key]]
  output[[paste0("thematic_", id)]] <- table_render(function() thematic_table(kind))
})
observeEvent(input$help_thematic, open_help("thematic"))
output$download_thematic <- downloadHandler(filename = "bibliolab_mapa_tematico.zip", content = function(file) {
  fit <- thematic_current(); validate(need(!is.null(fit), "Calcula un mapa vigente antes de descargar."))
  directory <- tempfile("mapa_tematico_"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  write_thematic_bundle(directory, fit)
  zip::zipr(file, list.files(directory, full.names = TRUE))
})
