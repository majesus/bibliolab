# Lectura inmediata, una sola versión por documento. Módulo de sesión.
inspector_mapping <- reactive({
  req(rv$raw); guessed <- guess_columns(rv$raw); chosen <- analysis_settings()$mapping
  for (f in names(guessed)) if (!nzchar(chosen[[f]] %||% "") || !chosen[[f]] %in% names(rv$raw)) chosen[[f]] <- guessed[[f]]
  chosen
})
open_inspector <- function() {
  if (is.null(rv$raw)) { showNotification("Carga un archivo o la práctica para leer documentos.", type = "warning"); return() }
  scopes <- c("Archivo importado · todas las filas" = "raw")
  if (!is.null(rv$prepared) && !stale()) scopes <- c(scopes, "Corpus preparado · después de filtros" = "prepared")
  showModal(modalDialog(title = "Lectura de documentos", size = "l", easyClose = TRUE,
    tags$div(class = "inspector-shell",
      tags$p(class = "reading-intro", "El primer documento se abre automáticamente. Busca por título o ID para cambiar de lectura; elige una versión para comprobar cómo se transforma el mismo texto."),
      tags$div(class = "inspector-grid", tags$aside(class = "inspector-controls",
        selectInput("inspect_scope", "Documentos que deseas leer", scopes, selected = "raw"),
        uiOutput("inspect_version_ui"),
        conditionalPanel("input.inspect_scope == 'raw' && input.inspect_version == 'original'", uiOutput("inspect_column_ui")),
        uiOutput("inspect_document_ui"),
        tags$div(class = "figure-tools", actionButton("inspect_prev", "← Anterior", class = "btn-quiet"), actionButton("inspect_next", "Siguiente →", class = "btn-quiet")),
        uiOutput("inspect_info")),
        tags$div(class = "inspector-text", uiOutput("inspect_reading")))), footer = modalButton("Cerrar lectura")))
}
observeEvent(input$inspect_load, open_inspector())
observeEvent(input$inspect_prepare, open_inspector())
output$inspect_column_ui <- renderUI({
  req(rv$raw); m <- inspector_mapping()
  selectInput("inspect_column", "Columna que estás leyendo", c("Sin texto asignado" = "", setNames(names(rv$raw), names(rv$raw))), selected = m$text)
})
output$inspect_version_ui <- renderUI({
  req(rv$raw); scope <- input$inspect_scope %||% "raw"; choices <- c("Texto original" = "original")
  if (scope == "raw") {
    if (any(nzchar(mapped(rv$raw, inspector_mapping(), "translated")))) choices <- c(choices, "Traducción importada" = "translated")
  } else {
    p <- current()
    if (any(nzchar(p$documents$translated))) choices <- c(choices, "Traducción importada" = "translated")
    if (any(!is.na(rv$corpus$units$lemmatized) & nzchar(rv$corpus$units$lemmatized))) choices <- c(choices, "Lemas antes de filtros" = "lemmatized")
    choices <- c(choices, "Texto limpio para analizar" = "cleaned")
  }
  selectInput("inspect_version", "Versión disponible", choices, selected = "original")
})
inspected_data <- reactive({
  req(rv$raw); version <- input$inspect_version %||% "original"; scope <- input$inspect_scope %||% "raw"
  if (scope == "raw" || is.null(rv$prepared) || stale()) {
    m <- inspector_mapping()
    if (version == "original" && !is.null(input$inspect_column) && input$inspect_column %in% names(rv$raw)) m$text <- input$inspect_column
    text <- mapped(rv$raw, m, if (version == "translated") "translated" else "text")
    data.frame(doc_id = sprintf("D%05d", seq_len(nrow(rv$raw))), original_id = mapped(rv$raw, m, "id"), title = mapped(rv$raw, m, "title"), texto = text)
  } else {
    p <- current(); d <- p$documents
    text <- if (version == "translated") d$translated else d$text
    if (version %in% c("cleaned", "lemmatized")) {
      u <- rv$corpus$units
      validate(need(version != "lemmatized" || any(!is.na(u$lemmatized)), "Activa lematización y prepara el corpus para consultar los lemas."))
      parts <- split(u[[version]], u$doc_id)
      text <- vapply(d$doc_id, function(id) paste(parts[[id]][!is.na(parts[[id]])], collapse = "\n\n"), "")
    }
    data.frame(doc_id = d$doc_id, original_id = d$original_id, title = d$title, texto = text)
  }
})
output$inspect_document_ui <- renderUI({
  d <- inspected_data(); labels <- paste(d$doc_id, d$original_id, ifelse(nzchar(d$title), substr(d$title, 1, 110), "Sin título"), sep = " · ")
  selected <- isolate(input$inspect_document %||% d$doc_id[1]); if (!selected %in% d$doc_id) selected <- d$doc_id[1]
  session$onFlushed(function(){updateSelectizeInput(session,"inspect_document",choices=setNames(d$doc_id,labels),selected=selected,server=TRUE)},once=TRUE)
  selectizeInput("inspect_document", "Buscar documento · escribe título o ID", choices = NULL,
    options = predictive_options())
})
for (button in c("inspect_prev", "inspect_next")) local({ id <- button; step <- if (id == "inspect_prev") -1L else 1L
  observeEvent(input[[id]], { d <- inspected_data(); pos <- match(input$inspect_document %||% d$doc_id[1], d$doc_id); if (is.na(pos)) pos <- 1L
    updateSelectizeInput(session, "inspect_document", selected = d$doc_id[max(1L, min(nrow(d), pos + step))]) })
})
output$inspect_info <- renderUI({
  d <- inspected_data(); pos <- match(input$inspect_document %||% d$doc_id[1], d$doc_id); if (is.na(pos)) pos <- 1L
  hint(paste("Documento", pos, "de", nrow(d), "·", sum(nzchar(d$texto)), "con texto en esta versión."))
})
output$inspect_reading <- renderUI({
  d <- inspected_data(); pos <- match(input$inspect_document %||% d$doc_id[1], d$doc_id); if (is.na(pos)) pos <- 1L
  tags$article(class = "document-reading", tags$p(class = "eyebrow", paste(d$doc_id[pos], "· ID original", d$original_id[pos])),
    tags$h3(if (nzchar(d$title[pos])) d$title[pos] else "Documento sin título"),
    if (nzchar(d$texto[pos])) tags$p(d$texto[pos]) else tags$p(class = "empty-help", "Este documento no contiene texto en la versión elegida. Puedes leer otro documento o elegir otra columna/versión. Sus metadatos siguen disponibles para los indicadores."))
})
