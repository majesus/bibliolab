# Selection and descriptive accounting only. No model or lexical calculations.
selection_mapping_ready <- function(d, mapping, fields) all(vapply(fields, function(field) {
  column <- mapping[[field]] %||% ""
  is.character(column) && length(column) == 1L && !is.na(column) && (!nzchar(column) || column %in% names(d))
}, TRUE))

selection_present <- function(x) {
  z <- toupper(clean_value(x))
  !z %in% c("", "NA", "N/A", "NULL", "NONE", "[NOT AVAILABLE]", "NOT AVAILABLE",
    "[NO ABSTRACT AVAILABLE]", "NO ABSTRACT AVAILABLE")
}

selection_columns <- function(d) {
  nm <- gsub("[_ .-]+", " ", tolower(ascii_fold(names(d))))
  aliases <- list(document_type = c("document type", "document types", "dt", "tipo documental", "tipo de documento"),
    abstract = c("abstract", "ab", "abstract text", "resumen"),
    language = c("language of original document", "language", "la", "idioma"),
    country = c("countries/regions", "countries regions", "author countries", "countries", "country", "pais", "paises"),
    early_access = c("publication stage", "early access date", "early access", "ea"))
  lapply(aliases, function(keys) { pos <- match(keys, nm); pos <- pos[!is.na(pos)]; if (length(pos)) names(d)[pos[1]] else "" })
}

selection_tokens <- function(x, type = FALSE) {
  lapply(strsplit(clean_value(x), if (type) "[;,|]" else "[;|]", perl = TRUE), function(z) {
    z <- trimws(z); unique(z[selection_present(z)])
  })
}

selection_types <- function(x) {
  lapply(selection_tokens(x, TRUE), function(z) unique(vapply(z, function(value) {
    key <- tolower(ascii_fold(value))
    if (key %in% c("article", "ar", "articulo", "article in press")) "Art\u00edculo"
    else if (key %in% c("review", "re", "review article", "revision")) "Revisi\u00f3n"
    else if (key %in% c("book chapter", "book chapters", "chapter", "ch", "capitulo", "capitulo de libro")) "Cap\u00edtulo"
    else if (key %in% c("conference paper", "proceedings paper", "cp", "ponencia")) "Ponencia"
    else if (key %in% c("early access", "acceso anticipado")) "Acceso anticipado / estado"
    else value
  }, "")))
}

selection_defaults <- function() list(fields = list(document_type = "", abstract = "", language = "", country = "", early_access = ""),
  types = character(), sources = character(), languages = character(), countries = character(),
  doi = FALSE, abstract = FALSE, text = FALSE, exclude_current_year = FALSE, early = "all")

selection_rules <- function(d, mapping, options, reference_year) {
  if (!is.list(options) || is.null(names(options)) && length(options)) abort_user("La selecci\u00f3n del corpus debe ser una lista con nombres.")
  unknown <- setdiff(names(options), names(selection_defaults()))
  if (length(unknown)) abort_user(paste("Opciones de selecci\u00f3n desconocidas:", paste(unknown, collapse = ", ")))
  p <- utils::modifyList(selection_defaults(), options)
  if (!is.list(p$fields) || any(!names(p$fields) %in% names(selection_defaults()$fields))) abort_user("Revisa los campos de selecci\u00f3n del corpus.")
  for (key in c("doi", "abstract", "text", "exclude_current_year"))
    if (!is.logical(p[[key]]) || length(p[[key]]) != 1L || is.na(p[[key]])) abort_user(paste("La opci\u00f3n", key, "debe ser TRUE o FALSE."))
  for (key in c("types", "sources", "languages", "countries"))
    if (!is.character(p[[key]]) || anyNA(p[[key]])) abort_user(paste("Revisa la selecci\u00f3n de", key))
  if (length(p$early) != 1 || !p$early %in% c("all", "only", "exclude")) abort_user("Estado de publicaci\u00f3n no admitido.")
  get_field <- function(key) {
    col <- p$fields[[key]] %||% ""
    if (!is.character(col) || length(col) != 1L || is.na(col) || nzchar(col) && !col %in% names(d)) abort_user(paste("El campo de", key, "no existe. Revisa su correspondencia."))
    if (!nzchar(col)) rep("", nrow(d)) else clean_value(d[[col]])
  }
  require_field <- function(active, column, label) {
    if (active && !nzchar(column %||% "")) abort_user(paste("Asigna el campo de", label, "antes de exigirlo como filtro."))
  }
  type_values <- get_field("document_type"); types <- selection_types(type_values)
  abstract <- get_field("abstract"); language <- get_field("language"); country <- get_field("country")
  stage <- get_field("early_access")
  early <- grepl("early access|article in press|in press|anticipado", tolower(ascii_fold(paste(type_values, stage))))
  if (nzchar(p$fields$early_access %||% "")) {
    header <- tolower(ascii_fold(p$fields$early_access))
    if (header %in% c("ea", "early access date", "early access"))
      early <- early | (selection_present(stage) & !tolower(stage) %in% c("no", "false", "0"))
  }
  require_field(length(p$types) > 0, p$fields$document_type, "tipo documental")
  require_field(length(p$sources) > 0, mapping$source, "fuente")
  require_field(p$doi, mapping$doi, "DOI")
  require_field(p$abstract, p$fields$abstract, "resumen")
  require_field(length(p$languages) > 0, p$fields$language, "idioma")
  require_field(length(p$countries) > 0, p$fields$country, "pa\u00eds / columna expl\u00edcita")
  require_field(p$exclude_current_year, mapping$year, "a\u00f1o")
  require_field(p$text, mapping$text, "texto para analizar")
  if (p$early != "all" && !nzchar(p$fields$early_access) && !any(early))
    abort_user("No hay un campo de estado ni valores que indiquen acceso anticipado. No se puede inferir que los dem\u00e1s registros est\u00e9n publicados definitivamente.")
  has_any <- function(sets, values) vapply(sets, function(z) any(z %in% values), TRUE)
  rule <- function(label, active, mask) list(label = label, active = active, mask = if (active) mask else rep(TRUE, nrow(d)))
  list(options = p, types = types, language = selection_tokens(language), country = selection_tokens(country),
    abstract = selection_present(abstract), doi = selection_present(mapped(d, mapping, "doi")), early = early,
    rules = list(
      rule("Tipo documental", length(p$types) > 0, has_any(types, p$types)),
      rule("Revista / fuente", length(p$sources) > 0, mapped(d, mapping, "source") %in% p$sources),
      rule("DOI informado", p$doi, selection_present(mapped(d, mapping, "doi"))),
      rule("Resumen informado", p$abstract, selection_present(abstract)),
      rule("Idioma declarado", length(p$languages) > 0, has_any(selection_tokens(language), p$languages)),
      rule("Pa\u00eds / campo expl\u00edcito", length(p$countries) > 0, has_any(selection_tokens(country), p$countries)),
      rule("Acceso anticipado / estado", p$early != "all", if (p$early == "only") early else !early),
      rule(paste("Excluir a\u00f1o en curso /", reference_year), p$exclude_current_year,
        is.na(parse_numeric(mapped(d, mapping, "year"), "year", reference_year)) | parse_numeric(mapped(d, mapping, "year"), "year", reference_year) != reference_year),
      rule("Texto asignado no vac\u00edo", p$text, selection_present(mapped(d, mapping, "text")))))
}

selection_median <- function(x) if (any(is.finite(x))) stats::median(x[is.finite(x)]) else NA_real_

selection_tracker <- function(documents) {
  previous <- documents
  trace <- data.frame(paso = "Corpus inicial", quedan = nrow(documents), excluidos = 0L,
    ano_mediano_excluidos = NA_real_, citas_medianas_excluidos = NA_real_,
    excluidos_con_ano = 0L, excluidos_con_citas = 0L, activo = TRUE)
  excluded <- data.frame(fila_original = integer(), doc_id = character(), motivo = character())
  add <- function(label, docs, active = TRUE) {
    removed <- previous[!previous$source_row %in% docs$source_row, , drop = FALSE]
    trace <<- rbind(trace, data.frame(paso = label, quedan = nrow(docs), excluidos = nrow(removed),
      ano_mediano_excluidos = selection_median(removed$year), citas_medianas_excluidos = selection_median(removed$citations),
      excluidos_con_ano = sum(!is.na(removed$year)), excluidos_con_citas = sum(!is.na(removed$citations)), activo = active))
    if (nrow(removed)) excluded <<- rbind(excluded, data.frame(fila_original = removed$source_row, doc_id = removed$doc_id, motivo = label))
    previous <<- docs
  }
  list(add = add, result = function() list(steps = trace, excluded = excluded))
}

selection_result <- function(tracker, documents, initial, context) {
  out <- tracker$result()
  retained <- documents$source_row
  omitted <- initial[!initial$source_row %in% retained, , drop = FALSE]
  n <- nrow(documents)
  percent <- function(x) if (n) 100 * sum(x) / n else NA_real_
  out$summary <- list(initial = nrow(initial), retained = n, excluded = nrow(initial) - n,
    retained_pct = if (nrow(initial)) 100*n/nrow(initial) else NA_real_,
    doi_abstract_pct = if (nzchar(context$options$fields$abstract) && nzchar(context$doi_field)) percent(selection_present(documents$doi) & context$abstract[retained]) else NA_real_,
    year_min = if (any(!is.na(documents$year))) min(documents$year, na.rm = TRUE) else NA_real_,
    year_max = if (any(!is.na(documents$year))) max(documents$year, na.rm = TRUE) else NA_real_,
    median_year_kept = selection_median(documents$year), median_year_excluded = selection_median(omitted$year),
    median_citations_kept = selection_median(documents$citations), median_citations_excluded = selection_median(omitted$citations),
    kept_with_year = sum(!is.na(documents$year)), kept_with_citations = sum(!is.na(documents$citations)),
    excluded_with_year = sum(!is.na(omitted$year)), excluded_with_citations = sum(!is.na(omitted$citations)),
    kept_with_text = sum(selection_present(documents$text)),
    sources = length(unique(documents$source[selection_present(documents$source)])))
  years <- sort(unique(c(initial$year[!is.na(initial$year)], documents$year[!is.na(documents$year)])))
  out$annual <- data.frame(ano = rep(years, 2), estado = rep(c("Quedan", "Excluidos"), each = length(years)),
    registros = c(vapply(years, function(y) sum(documents$year == y, na.rm = TRUE), 0),
      vapply(years, function(y) sum(omitted$year == y, na.rm = TRUE), 0)))
  out$missing_year <- c(quedan = sum(is.na(documents$year)), excluidos = sum(is.na(omitted$year)))
  breakdown <- function(sets) {
    values <- unlist(lapply(sets[retained], unique), use.names = FALSE)
    if (!length(values)) return(data.frame(valor = character(), documentos = integer()))
    count <- sort(table(values), decreasing = TRUE)
    data.frame(valor = names(count), documentos = as.integer(count))
  }
  out$types <- breakdown(context$types); out$languages <- breakdown(context$language); out$countries <- breakdown(context$country)
  out$options <- context$options
  out
}

selection_preview <- function(d, mapping, config) {
  cfg <- config; cfg$selection_preview <- TRUE
  cfg$corpus_selection <- cfg$corpus_selection %||% selection_defaults()
  prepare_documents(d, mapping, cfg)
}

selection_export <- function(directory, prepared, raw = NULL) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  f <- prepared$selection
  if (is.null(f)) return(invisible(directory))
  tables <- list(pasos = f$steps, excluidos = f$excluded, por_ano = f$annual,
    tipos = f$types, idiomas = f$languages, paises = f$countries,
    retenidos = prepared$documents[c("source_row", "doc_id", "original_id", "title", "year", "source", "citations", "doi")],
    resumen = data.frame(indicador = names(f$summary), valor = as.numeric(unlist(f$summary))))
  for (key in names(tables)) safe_csv(tables[[key]], file.path(directory, paste0(key, ".csv")))
  jsonlite::write_json(list(version = BIBLIO_VERSION, mapping = prepared$mapping, configuracion = prepared$config,
    filtros_documentales = f$options, filas_retenidas = prepared$documents$source_row),
    file.path(directory, "decisiones.json"), pretty = TRUE, auto_unbox = TRUE, digits = NA, null = "null")
  if (!is.null(raw)) {
    saveRDS(raw, file.path(directory, "entrada_original.rds"))
    saveRDS(list(mapping = prepared$mapping, config = prepared$config, retained = prepared$documents$source_row), file.path(directory, "configuracion.rds"))
    writeLines(enc2utf8(c("# Ejecutar desde la carpeta descomprimida. Esta reproducci\u00f3n solo selecciona documentos.",
      script_preamble(), "datos <- readRDS('entrada_original.rds'); ajuste <- readRDS('configuracion.rds')",
      "seleccion <- prepare_documents(datos, ajuste$mapping, ajuste$config)",
      "stopifnot(identical(seleccion$documents$source_row, ajuste$retained))",
      "saveRDS(seleccion, 'seleccion_reproducida.rds')")), file.path(directory, "reproducir_seleccion.R"), useBytes = TRUE)
  }
  writeLines(enc2utf8(c("Selecci\u00f3n documental de Bibliolab. Rojo: retenidos; gris: excluidos.",
    "Cada registro excluido se atribuye al primer paso que lo elimina. El orden de filtros afecta a esa atribuci\u00f3n, no deben sumarse exclusiones calculadas por separado.",
    "Las medianas usan solo valores v\u00e1lidos; sus denominadores constan en pasos.csv y resumen.csv. Ausencia de citas no equivale a cero.",
    "Las citas de Scopus y WoS corresponden a la columna asignada y tienen coberturas distintas. No se fusionan ni homogeneizan autom\u00e1ticamente.",
    "Un documento puede tener varios tipos, idiomas o pa\u00edses; las tablas de desglose no son categor\u00edas necesariamente exclusivas.",
    "Acceso anticipado es un estado y puede coexistir con Art\u00edculo o Revisi\u00f3n. Que el registro no indique acceso anticipado no certifica que la publicaci\u00f3n sea definitiva.",
    "La presencia de DOI no valida su resoluci\u00f3n. Texto no vac\u00edo no garantiza vocabulario retenido tras preparar.",
    if (!is.null(raw)) "Este ZIP incluye el archivo original completo en RDS, tambi\u00e9n los registros excluidos. Puede contener textos y otros datos del usuario; rev\u00edsalo antes de compartirlo." else "Esta carpeta documenta la selecci\u00f3n aplicada. La entrada original y el guion general est\u00e1n en la entrega principal.")),
    file.path(directory, "LEEME.txt"), useBytes = TRUE)
  invisible(directory)
}
