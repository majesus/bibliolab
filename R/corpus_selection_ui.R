corpus_selection_ui <- function() panel("Filtrar el corpus: qu\u00e9 se gana y qu\u00e9 se pierde",
  tags$p(class = "selection-intro", "Cada filtro es una decisi\u00f3n: comb\u00ednalos y observa cu\u00e1ntos registros quedan y cu\u00e1les se dejan fuera."),
  ui_subblock("Observar el efecto de las decisiones", uiOutput("selection_dashboard")),
  ui_subblock("Elegir periodo, duplicados y muestra",
    tags$div(class = "selection-controls-grid",
      tags$div(checkboxInput("year_filter", "Limitar por a\u00f1o", FALSE), conditionalPanel("input.year_filter",
        fluidRow(column(6, numericInput("year_min", "Desde", 2015, 1500, 2200)), column(6, numericInput("year_max", "Hasta", 2026, 1500, 2200)))),
        checkboxInput("selection_exclude_year", "Excluir el a\u00f1o en curso", FALSE)),
      tags$div(checkboxInput("dedup", "Excluir duplicados \u00b7 DOI, t\u00edtulo o texto", TRUE),
        hint("Se conserva el criterio de duplicados seguros de Bibliolab. Las coincidencias ambiguas no se eliminan autom\u00e1ticamente.")),
      tags$div(sliderInput("sample_pct", "Muestra (%)", 1, 100, 100, step = 1), numericInput("sample_seed", "Semilla de la muestra", 2026, 1, 2147483647)))),
  ui_subblock("Elegir documentos y metadatos",
    checkboxGroupInput("selection_types", "Tipos documentales permitidos / sin marcar: todos", choices = character(), inline = TRUE),
    hint("Una celda puede indicar varios tipos documentales, como Article y Review: se conserva un registro si coincide con cualquiera de los tipos elegidos. Acceso anticipado se trata aparte como estado de publicaci\u00f3n."),
    tags$div(class = "selection-controls-grid",
      selectizeInput("selection_sources", "Revistas / fuentes / vac\u00edo: todas", choices = NULL, multiple = TRUE),
      selectizeInput("selection_languages", "Idiomas declarados / vac\u00edo: todos", choices = NULL, multiple = TRUE),
      selectizeInput("selection_countries", "Pa\u00edses expl\u00edcitos / vac\u00edo: todos", choices = NULL, multiple = TRUE)),
    uiOutput("selection_metadata_controls"),
    checkboxInput("selection_text", "Exigir texto no vac\u00edo en el campo asignado para analizar", FALSE),
    hint("Tener texto no vac\u00edo no garantiza conservar vocabulario despu\u00e9s de la limpieza. Este panel cuenta documentos; el control de vocabulario se consulta tras preparar."),
    checkboxInput("value_filter", "A\u00f1adir un filtro por valor exacto", FALSE), conditionalPanel("input.value_filter", uiOutput("filter_ui"), textInput("filter_value", "Valor", "")),
    tags$details(tags$summary("Comprobar campos de los filtros / Scopus y Web of Science"),
      uiOutput("selection_field_controls"), uiOutput("selection_compatibility")),
    tags$div(class = "selection-presets", actionButton("selection_preset_text", "Con DOI y resumen", class = "btn-quiet"),
      actionButton("selection_preset_review", "Solo revisiones", class = "btn-quiet"),
      actionButton("selection_reset", "Restablecer selecci\u00f3n", class = "btn-quiet"))),
  ui_subblock("Leer el corpus resultante", uiOutput("selection_reading"),
    tags$details(tags$summary("Resumen por tipo, idioma y pa\u00eds del corpus que queda"), uiOutput("selection_breakdowns")),
    tags$div(class = "figure-tools", downloadButton("download_selection", "Descargar selecci\u00f3n y exclusiones")),
    hint("La vista previa utiliza las mismas decisiones que Preparar corpus. Las opciones se aplican al pulsar ese bot\u00f3n, al final de 02. Cambiarlas deja pendientes los an\u00e1lisis anteriores.")),
  class = "corpus-selection-card")

selection_format <- function(x, digits = 0L) ifelse(is.na(x), "\u2014", formatC(x, format = "f", digits = digits, big.mark = ".", decimal.mark = ","))

selection_year <- function(x) vapply(x, function(y) if (is.na(y)) "\u2014" else formatC(y, format = "f", digits = if (y == floor(y)) 0L else 1L, decimal.mark = ",", big.mark = ""), "")

selection_annual_ui <- function(selection) {
  d <- selection$annual
  if (!nrow(d)) return(hint("No hay a\u00f1os v\u00e1lidos para dibujar la distribuci\u00f3n anual."))
  years <- sort(unique(d$ano)); kept <- d$registros[d$estado == "Quedan"]; omitted <- d$registros[d$estado == "Excluidos"]
  total <- kept + omitted; top <- max(total, 1)
  width <- 800; height <- 170; left <- 25; base <- 130; cell <- 750/length(years)
  bars <- lapply(seq_along(years), function(i) {
    h <- 100*total[i]/top; kh <- 100*kept[i]/top; x <- left+(i-1)*cell
    tags$g(tags$title(paste(years[i], ":", kept[i], "quedan;", omitted[i], "excluidos")),
      tags$rect(x = x, y = base-h, width = max(.2, cell*.83), height = h, fill = "#d8d8d8"),
      tags$rect(x = x, y = base-kh, width = max(.2, cell*.83), height = kh, fill = "#cf103b"))
  })
  ticks <- unique(round(seq(1, length(years), length.out = min(6, length(years)))))
  tags$div(class = "selection-annual", tags$p(class = "selection-kicker", "Registros por a\u00f1o \u00b7 rojo: quedan; gris: excluidos"),
    tags$svg(xmlns = "http://www.w3.org/2000/svg", viewBox = paste(0, 0, width, height), role = "img",
      `aria-label` = "Distribuci\u00f3n anual de los registros retenidos y excluidos; las cantidades exactas se incluyen en la descarga.",
      tags$line(x1 = left, x2 = 778, y1 = base, y2 = base, stroke = "#999", `stroke-width` = .5), bars,
      lapply(ticks, function(i) tags$text(x = left+(i-.5)*cell, y = 150, `text-anchor` = "middle", `font-size` = 12, fill = "#555", years[i]))),
    hint(paste("Sin a\u00f1o v\u00e1lido:", selection$missing_year[["quedan"]], "retenidos y", selection$missing_year[["excluidos"]], "excluidos; no aparecen en las barras.")))
}

selection_dashboard_ui <- function(prepared) {
  f <- prepared$selection; s <- f$summary
  tile <- function(value, label, accent = FALSE) tags$div(class = paste("selection-stat", if (accent) "accent"), tags$strong(value), tags$span(label))
  steps <- f$steps[f$steps$activo, , drop = FALSE]
  tagList(tags$div(class = "selection-stats",
    tile(selection_format(s$retained), "Registros que quedan", TRUE), tile(selection_format(s$excluded), "Excluidos"),
    tile(paste0(selection_format(s$retained_pct, 1), " %"), "Del corpus inicial"),
    tile(if (is.na(s$doi_abstract_pct)) "No disponible" else paste0(selection_format(s$doi_abstract_pct, 1), " %"), "De los que quedan: DOI y resumen")),
    tags$div(class = "selection-table-scroll", tags$table(class = "selection-step-table",
      tags$thead(tags$tr(lapply(c("Paso / en este orden", "Quedan", "Excluidos", "A\u00f1o mediano de excluidos", "Citas medianas de excluidos"), tags$th))),
      tags$tbody(lapply(seq_len(nrow(steps)), function(i) tags$tr(
        tags$td(steps$paso[i]),
        tags$td(tags$span(class = "selection-bar", tags$span(style = paste0("width:", if (s$initial) 100*steps$quedan[i]/s$initial else 0, "%"))), selection_format(steps$quedan[i])),
        tags$td(if (i == 1 || !steps$excluidos[i]) "\u2014" else selection_format(steps$excluidos[i])),
        tags$td(selection_year(steps$ano_mediano_excluidos[i])), tags$td(selection_format(steps$citas_medianas_excluidos[i], 1))))))),
    selection_annual_ui(f))
}

selection_reading_ui <- function(prepared) {
  f <- prepared$selection; s <- f$summary
  tags$div(class = "selection-reading",
    tags$p(tags$strong("Lectura. "), paste0("Quedan ", selection_format(s$retained), " de ", selection_format(s$initial), " registros (", selection_format(s$retained_pct, 1), " %). "),
      if (s$retained == 0) "La selecci\u00f3n est\u00e1 vac\u00eda: ampl\u00eda los criterios antes de preparar el corpus." else
        paste0("A\u00f1o mediano: ", selection_year(s$median_year_kept), " en lo retenido y ", selection_year(s$median_year_excluded), " en lo excluido. Citas medianas: ", selection_format(s$median_citations_kept, 1), " frente a ", selection_format(s$median_citations_excluded, 1), ".")),
    tags$p(tags$strong("Corpus que queda. "), paste(s$sources, "fuentes distintas;", s$kept_with_text, "registros con texto no vac\u00edo;", s$kept_with_year, "con a\u00f1o v\u00e1lido y", s$kept_with_citations, "con citas v\u00e1lidas.",
      "Periodo:", selection_year(s$year_min), "a", selection_year(s$year_max), ".")),
    tags$p(class = "hint", paste("Las medianas excluyen los datos ausentes: entre los excluidos hay", s$excluded_with_year, "a\u00f1os y", s$excluded_with_citations,
      "recuentos de citas v\u00e1lidos. Los ausentes no se convierten en cero. Las diferencias son descriptivas; no prueban sesgo estad\u00edstico ni causalidad.")),
    tags$p(tags$strong("Decisi\u00f3n y coste. "), if (s$excluded) "Los registros descartados dejan de contribuir a los indicadores y modelos. Revisa sus motivos en la descarga y justifica los criterios seg\u00fan la pregunta de investigaci\u00f3n." else "No se excluyen registros con estas opciones. Revisa la cobertura antes de a\u00f1adir exigencias de metadatos."))
}
