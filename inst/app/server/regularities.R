# Solo lectura sobre la ejecución vigente. No modifica rv$bib ni rv$corpus.
regularities_current <- reactive({
  p <- current()
  biblio_regularities(p, rv$corpus, rv$bib)
})
regularity_display <- function(d) {
  labels <- c(documentos_por_autor = "Documentos por autor", autores = "Autores observados",
    porcentaje_autores = "Autores (%)", autores_referencia = "Autores / referencia 1/x²",
    documentos_con_datos = "Documentos con datos", documentos_totales = "Documentos preparados",
    zona = "Zona", fuentes = "Fuentes", porcentaje_documentos = "Documentos con fuente (%)",
    fuentes_relativas_nucleo = "Fuentes / fuentes del núcleo", multiplicador_anterior = "Fuentes / zona anterior",
    fuente = "Fuente", rango = "Rango", documentos_acumulados = "Documentos acumulados",
    porcentaje_apariciones = "Apariciones (%)", frecuencia_referencia = "Apariciones / referencia 1/rango")
  for (name in intersect(names(d), names(labels))) names(d)[names(d) == name] <- labels[[name]]
  d
}
output$regularities_coverage <- table_render(function() regularity_display(regularities_current()$cobertura))
output$lotka_table <- table_render(function() regularity_display(regularities_current()$lotka))
output$bradford_zones <- table_render(function() regularity_display(regularities_current()$bradford$zonas))
output$bradford_sources <- table_render(function() regularity_display(regularities_current()$bradford$fuentes))
output$zipf_table <- table_render(function() regularity_display(regularities_current()$zipf))
for (kind in c("lotka", "bradford", "zipf")) local({
  key <- kind
  output[[paste0(key, "_plot")]] <- renderPlot({
    fit <- regularities_current()
    width <- session$clientData[[paste0("output_", key, "_plot_width")]] %||% 1000
    graph <- regularity_plot(fit, key, compact = isTRUE(width < 600), canvas_width = width)
    validate(need(!is.null(graph), switch(key,
      lotka = "No hay autores reconocidos. Revisa su columna y separador en 02.",
      bradford = "No hay fuentes reconocidas. Asigna su columna en 02.",
      zipf = "No quedan palabras tras la limpieza. Revisa las opciones de 02.")))
    graph
  }, height = function() {
    width <- session$clientData[[paste0("output_", key, "_plot_width")]] %||% 1000
    if (isTRUE(width < 600)) 560L else 760L
  }, res = 110)
})
output$lotka_reading <- renderUI(tags$p(class = "chart-caption", regularity_reading(regularities_current(), "lotka")))
output$zipf_reading <- renderUI(tags$p(class = "chart-caption", regularity_reading(regularities_current(), "zipf")))
output$bradford_reading <- renderUI({
  fit <- regularities_current()$bradford
  if (!nrow(fit$fuentes)) return(empty_help("Asigna una columna de fuentes para formar las zonas."))
  tagList(tags$p(class = "chart-caption", regularity_reading(regularities_current(), "bradford")),
    if (any(fit$zonas$fuentes == 0)) empty_help("Hay al menos una zona vacía: una fuente alcanza más de un corte o el corpus tiene muy pocas fuentes. No interpretes una razón de Bradford."),
    if (fit$empates) hint("Hay fuentes empatadas en un corte. El desempate por nombre fija una asignación reproducible, pero no indica mayor relevancia de una fuente."))
})
output$download_regularities <- downloadHandler(
  filename = function() "bibliolab_regularidades.zip",
  content = function(file) {
    tables <- regularity_tables(regularities_current())
    directory <- tempfile("regularidades_"); dir.create(directory)
    on.exit(unlink(directory, recursive = TRUE), add = TRUE)
    for (name in names(tables)) safe_csv(tables[[name]], file.path(directory, paste0(name, ".csv")))
    writeLines(c("Regularidades descriptivas de la preparación vigente.",
      "Lotka: exponente 2 sobre 1..máxima productividad, normalizado al total de autores.",
      "Bradford: primera fuente que alcanza cada tercio, sin dividir fuentes; empates por nombre.",
      "Zipf: exponente 1 sobre todo el vocabulario evaluado tras la limpieza, normalizado a sus apariciones.",
      "Las referencias no son ajustes ni contrastes estadísticos. Comprueba cobertura y tablas."),
      file.path(directory, "LEEME.txt"), useBytes = TRUE)
    zip::zipr(file, list.files(directory, full.names = TRUE))
  })
