selection_fields <- reactive({
  if (is.null(rv$raw)) return(selection_defaults()$fields)
  guesses <- selection_columns(rv$raw)
  setNames(lapply(names(guesses), function(key) input[[paste0("selection_col_", key)]] %||% guesses[[key]]), names(guesses))
})
selection_settings <- reactive(list(fields = selection_fields(), types = sort(input$selection_types %||% character()),
  sources = sort(input$selection_sources %||% character()), languages = sort(input$selection_languages %||% character()),
  countries = sort(input$selection_countries %||% character()), doi = isTRUE(input$selection_doi),
  abstract = isTRUE(input$selection_abstract), text = isTRUE(input$selection_text),
  exclude_current_year = isTRUE(input$selection_exclude_year), early = input$selection_early %||% "all"))
output$selection_field_controls <- renderUI({
  req(rv$raw); fields <- selection_columns(rv$raw)
  labels <- c(document_type = "Tipo documental / Document Type o DT", abstract = "Resumen / Abstract o AB",
    language = "Idioma declarado / Language o LA", country = "País / columna explícita; no direcciones libres",
    early_access = "Estado o fecha de acceso anticipado / opcional")
  tags$div(class = "selection-controls-grid", lapply(names(fields), function(key)
    selectInput(paste0("selection_col_", key), labels[[key]], c("No asignar" = "", setNames(names(rv$raw), names(rv$raw))), selected = fields[[key]])))
})
selection_values <- reactive({
  req(rv$raw); fields <- selection_fields()
  get <- function(key) if ((fields[[key]] %||% "") %in% names(rv$raw)) clean_value(rv$raw[[fields[[key]]]]) else rep("", nrow(rv$raw))
  types <- sort(unique(unlist(selection_types(get("document_type")))), method = "radix")
  sources <- mapped(rv$raw, list(source = if ((input$col_source %||% "") %in% names(rv$raw)) input$col_source else ""), "source")
  list(types = setdiff(types, "Acceso anticipado / estado"), sources = sort(unique(sources[selection_present(sources)]), method = "radix"),
    languages = sort(unique(unlist(selection_tokens(get("language")))), method = "radix"),
    countries = sort(unique(unlist(selection_tokens(get("country")))), method = "radix"))
})
observe({
  values <- selection_values()
  updateCheckboxGroupInput(session, "selection_types", choices = values$types, selected = intersect(isolate(input$selection_types), values$types))
  for (key in c("sources", "languages", "countries")) updateSelectizeInput(session, paste0("selection_", key),
    choices = values[[key]], selected = intersect(isolate(input[[paste0("selection_", key)]]), values[[key]]), server = TRUE)
})
output$selection_metadata_controls <- renderUI({
  req(rv$raw); fields <- selection_fields()
  checkbox <- function(id, label, available) tags$fieldset(disabled = if (!available) "disabled" else NULL,
    checkboxInput(id, paste0(label, if (!available) " / campo no asignado" else ""), available && isTRUE(isolate(input[[id]]))))
  types_column <- fields$document_type %||% ""
  has_early <- nzchar(fields$early_access %||% "") || (types_column %in% names(rv$raw) && any(grepl("early access|article in press", tolower(rv$raw[[types_column]]))))
  tags$div(class = "selection-controls-grid",
    checkbox("selection_doi", "Exigir DOI informado", nzchar(input$col_doi %||% "")),
    checkbox("selection_abstract", "Exigir resumen informado", nzchar(fields$abstract %||% "")),
    tags$fieldset(disabled = if (!has_early) "disabled" else NULL,
      selectInput("selection_early", "Acceso anticipado / estado", c("Sin restricción" = "all", "Solo acceso anticipado" = "only", "Excluir acceso anticipado" = "exclude"),
        selected = if (has_early) isolate(input$selection_early %||% "all") else "all")))
})
observeEvent(rv$raw, {
  updateCheckboxGroupInput(session, "selection_types", selected = character())
  for (key in c("sources", "languages", "countries")) updateSelectizeInput(session, paste0("selection_", key), selected = character())
  for (key in c("selection_doi", "selection_abstract", "selection_text", "selection_exclude_year")) updateCheckboxInput(session, key, value = FALSE)
  updateSelectInput(session, "selection_early", selected = "all")
}, ignoreNULL = TRUE, priority = 110)
selection_data <- reactive({
  if (is.null(rv$raw)) return(list(message = "Carga un archivo de Scopus o WoS, o el ejemplo, en 01. Después revisa la correspondencia de campos."))
  tryCatch({
    s <- settings()
    if (!nzchar(s$mapping$text)) return(list(message = "Asigna el campo de texto para previsualizar la selección. Los demás filtros pueden dejarse sin restricción."))
    list(prepared = selection_preview(rv$raw, s$mapping, s$config))
  }, error = function(e) list(message = conditionMessage(e)))
})
selection_view <- debounce(selection_data, 180)
output$selection_dashboard <- renderUI({
  state <- selection_view()
  if (!is.null(state$message)) return(empty_help(state$message))
  selection_dashboard_ui(state$prepared)
})
output$selection_reading <- renderUI({
  state <- selection_view(); if (!is.null(state$message)) return(hint(state$message))
  selection_reading_ui(state$prepared)
})
output$selection_breakdowns <- renderUI({
  state <- selection_view(); if (!is.null(state$message)) return(NULL)
  f <- state$prepared$selection
  tags$div(class = "selection-controls-grid", lapply(c(types = "Tipos documentales", languages = "Idiomas declarados", countries = "Países explícitos"), function(title) {
    key <- names(c(types = "Tipos documentales", languages = "Idiomas declarados", countries = "Países explícitos"))[match(title, c("Tipos documentales", "Idiomas declarados", "Países explícitos"))]
    tags$section(tags$h4(title), if (!nrow(f[[key]])) hint("No informado en el corpus que queda.") else HTML(html_table(f[[key]], max_rows = 12)))
  }))
})
output$selection_compatibility <- renderUI({
  req(rv$raw); fields <- selection_fields()
  missing <- names(fields)[!nzchar(unlist(fields))]
  tagList(hint("Se utilizan los campos asignados, no el nombre de la base como criterio. En WoS, ID significa Keywords Plus: no se trata como identificador; UT y el EID de Scopus se reconocen por separado. Acceso anticipado puede coexistir con Artículo o Revisión."),
    hint("El país solo se filtra si existe una columna explícita: no se deduce automáticamente de direcciones o afiliaciones. Las citas son las de la columna elegida; los recuentos de WoS y Scopus no son intercambiables."),
    if (length(missing)) hint(paste("Campos auxiliares sin asignar:", paste(missing, collapse = ", "), ". Sus filtros deben permanecer sin restricción.")))
})
observeEvent(input$selection_reset, {
  updateCheckboxInput(session, "year_filter", value = FALSE); updateCheckboxInput(session, "value_filter", value = FALSE)
  updateCheckboxInput(session, "dedup", value = TRUE); updateSliderInput(session, "sample_pct", value = 100)
  updateCheckboxGroupInput(session, "selection_types", selected = character())
  for (key in c("sources", "languages", "countries")) updateSelectizeInput(session, paste0("selection_", key), selected = character())
  for (key in c("selection_doi", "selection_abstract", "selection_text", "selection_exclude_year")) updateCheckboxInput(session, key, value = FALSE)
  updateSelectInput(session, "selection_early", selected = "all")
})
observeEvent(input$selection_preset_text, {
  if (!nzchar(input$col_doi %||% "") || !nzchar(selection_fields()$abstract)) {
    showNotification("Asigna DOI y resumen antes de activar esta decisión.", type = "warning"); return()
  }
  updateCheckboxInput(session, "selection_doi", value = TRUE); updateCheckboxInput(session, "selection_abstract", value = TRUE)
})
observeEvent(input$selection_preset_review, {
  if (!"Revisión" %in% selection_values()$types) { showNotification("No hay revisiones reconocidas en el campo asignado.", type = "warning"); return() }
  updateCheckboxGroupInput(session, "selection_types", selected = "Revisión")
})
output$download_selection <- downloadHandler(filename = "bibliolab_seleccion_corpus.zip", content = function(file) {
  state <- selection_data(); validate(need(is.null(state$message), state$message %||% "Revisa los filtros."))
  prepared <- state$prepared; f <- prepared$selection
  directory <- tempfile("seleccion_"); dir.create(directory); on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  selection_export(directory, prepared, rv$raw)
  zip::zipr(file, list.files(directory, full.names = TRUE))
})
