# Transformaci\u00f3n del \u00e1rbol de presentaci\u00f3n: conserva los mismos controles,
# identificadores, valores, condiciones y dependencias de Shiny.
ui_subblock <- function(title, ...) tags$section(class = "ui-subblock",
  tags$h3(class = "ui-subblock-title", title), ...)

ui_has_class <- function(node, class) inherits(node, "shiny.tag") &&
  class %in% strsplit(node$attribs$class %||% "", "\\s+")[[1]]

ui_has_id <- function(node, id) {
  if (inherits(node, "shiny.tag")) {
    if (identical(node$attribs$id, id)) return(TRUE)
    return(any(vapply(node$children, ui_has_id, TRUE, id = id)))
  }
  if (is.list(node)) return(any(vapply(node, ui_has_id, TRUE, id = id)))
  FALSE
}

ui_group_children <- function(children, starts, grid = FALSE) {
  positions <- vapply(names(starts), function(id) {
    found <- which(vapply(children, ui_has_id, TRUE, id = id))
    if (length(found)) found[1] else NA_integer_
  }, 1L)
  present <- which(!is.na(positions))
  if (!length(present)) return(children)
  present <- present[order(positions[present])]
  present <- present[!duplicated(positions[present])]
  positions <- positions[present]; titles <- unname(starts[present])
  positions[1] <- 1L
  ends <- c(positions[-1] - 1L, length(children))
  lapply(seq_along(positions), function(i) {
    content <- children[seq.int(positions[i], ends[i])]
    if (grid) content <- list(tags$div(class = "network-controls", `data-compartment-grid` = "true", content))
    ui_subblock(titles[i], content)
  })
}

ui_panel_groups <- function(node) {
  # Cada lista empieza en un control o resultado ya existente. Solo se
  # enmarcan sus hermanos; nunca se mueven controles a otra condici\u00f3n.
  rules <- list(
    list(key = "file", starts = c(file = "Archivo y formato", demo = "Ejemplo de pr\u00e1ctica / opcional")),
    list(key = "file_summary", starts = c(file_summary = "Comprobar la importaci\u00f3n", inspect_load = "Inspeccionar y continuar")),
    list(key = "mapping_ui", starts = c(mapping_ui = "Asignar las columnas", inspect_prepare = "Comprobar documentos")),
    list(key = "question", starts = c(question = "Pregunta y procedencia", dedup = "Filtros, duplicados y muestra", authors_sep = "Separar y unificar metadatos", remove_boilerplate = "Limpieza del texto de origen")),
    list(key = "min_chars", starts = c(help_tokens = "Entender la selecci\u00f3n", min_chars = "Longitud, presencia y tama\u00f1o", min_tfidf = "Criterios avanzados / opcionales", prepare = "Aplicar la preparaci\u00f3n")),
    list(key = "preparation_summary", starts = c(preparation_summary = "Revisar la calidad", table_audit = "Consultar y continuar")),
    list(key = "token_rank_metric", starts = c(token_explanation = "Elegir t\u00e9rminos e indicador", token_selection_note = "Comparar los resultados", token_search = "Buscar y leer documentos")),
    list(key = "run_jsd", starts = c(help_jsd = "Definir los grupos A y B", jsd_weight = "Ponderar y calcular", jsd_state = "Leer la comparaci\u00f3n")),
    list(key = "run_network", starts = c(help_network = "Definir la red y sus filtros", network_definition = "Revisar la definici\u00f3n e inclusi\u00f3n", run_network = "Calcular y comprobar el estado", help_network_roles = "Ajustar el dibujo", network_routes = "Buscar caminos y leer la red", network_lookup = "Examinar nodos y cobertura")),
    list(key = "subgraph_controls", starts = c(help_subgraphs = "Definir la selecci\u00f3n", subgraph_state = "Leer el subgrafo", subgraph_summary = "Comparar indicadores y guardar")),
    list(key = "gram_order", starts = c(help_ngrams = "Elegir expresi\u00f3n e indicador", gram_explanation = "Leer resultados y tabla")),
    list(key = "bibliography_extension", starts = c(help_references = "Elegir qu\u00e9 consultar", bibliography_extension_note = "Leer cobertura y resultados")),
    list(key = "keywords_fields", starts = c(keywords_availability = "Comprobar campos y cobertura", keywords_result = "Explorar palabras clave")),
    list(key = "run_density", starts = c(density_rep = "Elegir la representaci\u00f3n", umap_neighbors = "Definir vecinos y densidad", density_seed = "Fijar la semilla y calcular")),
    list(key = "run_kselect", starts = c(help_kselect = "Qu\u00e9 se compara: soluciones con distinto n\u00famero de temas", kselect_min = "Definir soluciones y calcular", kselect_state = "Leer la comparaci\u00f3n y elegir k")),
    list(key = "run_lda", starts = c(model_dimensions = "Revisar la decisi\u00f3n sobre el n\u00famero de temas", k = "Definir el ajuste y calcular", lda_alpha_mode = "Preferencia previa de mezcla de temas / avanzado")),
    list(key = "run_pca", starts = c(pca_terms = "Definir opciones y calcular")),
    list(key = "pca_search", starts = c(pca_state = "Comprobar el resultado", pca_search = "Elegir documentos y ejes", pca_views = "Leer gr\u00e1ficos y tablas")),
    list(key = "run_ca", starts = c(ca_terms = "Definir opciones y calcular")),
    list(key = "wiki_advanced_fields", starts = c(wiki_advanced_fields = "Elegir el texto de las fichas", wiki_mode = "Definir el \u00edndice y crearlo", wiki_state = "Explorar y leer las fichas")),
    list(key = "prompt_key", starts = c(prompt_key = "Elegir tarea y aportar contexto", include_text = "Revisar, copiar y guardar")))
  for (rule in rules) if (ui_has_id(node, rule$key)) {
    node$children <- c(node$children[1], ui_group_children(node$children[-1], rule$starts))
    break
  }
  node
}

ui_compartments <- function(ui) {
  steps <- c(load = "01 / Datos", prepare = "02 / Preparaci\u00f3n", explore = "03 / Indicadores",
    models = "04 / Modelos", export = "05 / Entrega")
  counts <- setNames(integer(length(steps)), names(steps))
  walk <- function(node, step = NULL, block = NULL, counter = NULL) {
    if (inherits(node, "shiny.tag")) {
      value <- node$attribs[["data-value"]]
      if (ui_has_class(node, "tab-pane") && !is.null(value) && value %in% names(steps)) step <- value
      if (ui_has_class(node, "panel-card") && !is.null(step)) {
        counts[[step]] <<- counts[[step]] + 1L
        block <- paste0(substr(steps[[step]], 1, 2), ".", sprintf("%02d", counts[[step]]))
        node <- ui_panel_groups(node)
        node$attribs[["data-block-number"]] <- block
        node$attribs[["aria-label"]] <- paste("Bloque", block)
        title <- node$children[[1]]
        title$children <- c(list(tags$span(class = "block-number", block)), title$children)
        node$children[[1]] <- title
        node$children <- append(node$children, list(tags$p(class = "block-context", steps[[step]])), after = 1L)
        counter <- new.env(parent = emptyenv()); counter$n <- 0L
      } else if (!is.null(block) && (ui_has_class(node, "ui-subblock") || ui_has_class(node, "option-group"))) {
        counter$n <- counter$n + 1L
        number <- paste0(block, ".", sprintf("%02d", counter$n))
        headings <- which(vapply(node$children, function(child) inherits(child, "shiny.tag") && child$name == "h3", TRUE))
        if (length(headings)) {
          h <- headings[1]
          # Sustituye solo la numeraci\u00f3n local antigua de los option-group.
          heading <- node$children[[h]]
          if (length(heading$children) && is.character(heading$children[[1]]))
            heading$children[[1]] <- sub("^[0-9]+ / ", "", heading$children[[1]])
          heading$children <- c(list(tags$span(class = "subblock-number", number)), heading$children)
          node$children[[h]] <- heading
        }
        node$attribs[["data-subblock-number"]] <- number
        block <- number
        counter <- new.env(parent = emptyenv()); counter$n <- 0L
      }
      if (ui_has_class(node, "network-controls") && is.null(node$attribs[["data-compartment-grid"]])) {
        node$attribs$class <- "network-control-groups"
        node$children <- ui_group_children(node$children, c(network_type = "Entidades y relaci\u00f3n", network_presence = "Tama\u00f1o y filtros", network_seed = "Comunidades y cobertura"), grid = TRUE)
      }
      node$children <- lapply(node$children, walk, step = step, block = block, counter = counter)
      return(node)
    }
    if (is.list(node)) {
      node[] <- lapply(node, walk, step = step, block = block, counter = counter)
      return(node)
    }
    node
  }
  walk(ui)
}
