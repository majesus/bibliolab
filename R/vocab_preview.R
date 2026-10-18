# Vista previa del vocabulario: aplica a la tabla de terminos de la ultima preparacion los umbrales que el usuario
# ha escrito, sin recalcular la limpieza ni sustituir el corpus vigente. Longitud minima/maxima, palabras vacias,
# lemas y categorias actuan durante la limpieza y solo se aplican al pulsar "Preparar corpus".
vocabulary_preview_fields <- c("min_df", "max_df_pct", "min_tf", "max_terms", "min_tfidf", "max_entropy", "term_order")

#' Vista previa del efecto de los umbrales de vocabulario
#'
#' @param corpus Resultado de `prepare_corpus()`.
#' @param prepared Resultado de `prepare_documents()` con el que se preparo `corpus`.
#' @param changes Lista con los umbrales a probar (`min_df`, `max_df_pct`, `min_tf`, `max_terms`, `min_tfidf`,
#'   `max_entropy`, `term_order`). Los valores ausentes, `NA` o no numericos conservan el valor vigente.
#' @return Lista con `estado` (`"sin_cambios"`, `"cambia"` o `"no_disponible"`), recuentos del vocabulario vigente
#'   y del propuesto, palabras que entrarian y saldrian, porcentaje de apariciones conservadas y unidades sin
#'   vocabulario.
#' @noRd
vocabulary_preview <- function(corpus, prepared, changes = list()) {
  terms <- corpus$terms
  if (is.null(terms) || !nrow(terms)) return(list(estado = "no_disponible", motivo = "No hay vocabulario evaluado."))
  cfg <- prepared$config; n_docs <- nrow(prepared$documents)
  numeric_fields <- setdiff(vocabulary_preview_fields, "term_order")
  for (nm in numeric_fields) {
    v <- suppressWarnings(as.numeric(changes[[nm]]))
    if (length(v) == 1L && is.finite(v)) cfg[[nm]] <- v
  }
  order_new <- changes$term_order
  if (is.character(order_new) && length(order_new) == 1L && order_new %in% c("frequency", "tfidf", "bm25")) cfg$term_order <- order_new
  stat_changed <- !identical(changes$tfidf_stat %||% cfg$tfidf_stat %||% "mean", prepared$config$tfidf_stat %||% "mean") ||
    !identical(changes$tfidf_scope %||% cfg$tfidf_scope %||% "all", prepared$config$tfidf_scope %||% "all") ||
    !isTRUE(all.equal(as.numeric(changes$tfidf_percentile %||% cfg$tfidf_percentile %||% 75), as.numeric(prepared$config$tfidf_percentile %||% 75)))
  if (identical(cfg$term_order, "tfidf") && stat_changed) {
    return(list(estado = "no_disponible", motivo = "El resumen TF-IDF elegido para ordenar cambia cómo se calcula cada peso; pulsa Preparar corpus para ver su efecto."))
  }
  current <- corpus$vocabulary
  proposed <- vocabulary_selection(terms, cfg, n_docs)
  vocab <- proposed$vocabulary
  enter <- setdiff(vocab, current); leave <- setdiff(current, vocab)
  by_freq <- function(x) x[order(-terms$frecuencia[match(x, terms$termino)], x)]
  units_with <- function(v) {
    if (is.null(corpus$units) || !nrow(corpus$units)) return(NA_integer_)
    tokens <- strsplit(corpus$units$cleaned, " ", fixed = TRUE)
    sum(vapply(tokens, function(z) any(z %in% v), TRUE))
  }
  total <- sum(terms$frecuencia)
  list(estado = if (!length(enter) && !length(leave)) "sin_cambios" else "cambia",
    terminos_vigentes = length(current), terminos_propuestos = length(vocab), elegibles_propuestos = length(proposed$eligible),
    entran = by_freq(enter), salen = by_freq(leave),
    apariciones_vigentes_pct = 100 * sum(terms$frecuencia[terms$termino %in% current]) / total,
    apariciones_propuestas_pct = 100 * sum(terms$frecuencia[terms$termino %in% vocab]) / total,
    unidades_con_vocabulario_vigentes = units_with(current), unidades_con_vocabulario_propuestas = units_with(vocab),
    unidades_activas = corpus$n_active %||% NA_integer_,
    recorta = length(proposed$eligible) > cfg$max_terms)
}

vocabulary_preview_ui <- function(p, shown = 8L) {
  if (is.null(p)) return(NULL)
  tag <- htmltools::tags
  lead <- "Vista previa sobre la última preparación. No sustituye al corpus vigente hasta que pulses Preparar corpus; la longitud de las palabras, las palabras vacías, los lemas y las categorías solo se aplican al preparar."
  if (identical(p$estado, "no_disponible")) return(tag$div(class = "empty-help", tag$p(lead), tag$p(p$motivo)))
  names_of <- function(x) if (length(x) > shown) paste0(paste(x[seq_len(shown)], collapse = ", "), " y ", length(x) - shown, " más") else paste(x, collapse = ", ")
  fmt <- function(x) format(round(x, 1), nsmall = 1, decimal.mark = ",")
  if (identical(p$estado, "sin_cambios")) {
    return(tag$div(class = "empty-help", tag$p(lead), tag$p(sprintf("Con estos valores el vocabulario de los modelos no cambia: siguen entrando %d palabras.", p$terminos_vigentes))))
  }
  empty_now <- if (is.na(p$unidades_con_vocabulario_propuestas)) NULL else {
    lost <- p$unidades_con_vocabulario_vigentes - p$unidades_con_vocabulario_propuestas
    tag$p(sprintf("Unidades con alguna palabra del vocabulario: %d ahora y %d con estos valores%s.", p$unidades_con_vocabulario_vigentes, p$unidades_con_vocabulario_propuestas,
      if (lost > 0L) sprintf(" (%d quedarían sin vocabulario y no entrarían en los modelos)", lost) else ""))
  }
  tag$div(class = "empty-help vocab-preview", tag$p(lead),
    tag$p(tag$strong(sprintf("Entrarían %d palabras (ahora %d). ", p$terminos_propuestos, p$terminos_vigentes)),
      sprintf("Conservarían el %s %% de las apariciones (ahora %s %%).", fmt(p$apariciones_propuestas_pct), fmt(p$apariciones_vigentes_pct))),
    if (length(p$salen)) tag$p(tag$strong("Saldrían: "), names_of(p$salen), "."),
    if (length(p$entran)) tag$p(tag$strong("Entrarían ahora: "), names_of(p$entran), "."),
    empty_now,
    if (!p$recorta) tag$p("El máximo de términos no recorta con estos valores: el criterio de orden no cambia cuáles entran."))
}
