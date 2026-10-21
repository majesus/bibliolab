# Independent co-word analysis; existing model and network engines are unchanged.
thematic_defaults <- function() list(field = "keywords", min_presence = 2L,
  max_terms = 100L, min_shared = 1L, resolution = 1, seed = 2026L)

thematic_incidence <- function(corpus, prepared, field) {
  ids <- prepared$documents$doc_id
  if (identical(field, "text")) {
    if (is.null(corpus$counts) || !ncol(corpus$counts))
      abort_user("No hay vocabulario retenido. Revisa la preparaci\u00f3n en 02.")
    counts <- document_counts(corpus, prepared)
    pos <- match(rownames(counts), ids)
    out <- Matrix::sparseMatrix(i = pos, j = seq_along(pos), x = 1,
      dims = c(length(ids), length(pos))) %*% (counts > 0)
    dimnames(out) <- list(ids, colnames(counts))
    return(out)
  }
  sets <- lapply(metadata_split(prepared$documents$keywords,
    metadata_separator(prepared, "keywords")), function(z) unique(clean_value(z[nzchar(trimws(z))])))
  if (isTRUE(prepared$config$normalize_labels)) {
    variants <- variant_map(unlist(sets, use.names = FALSE), "keyword")
    sets <- lapply(sets, function(z) unique(unname(variants$map[z])))
  }
  terms <- sort(unique(unlist(sets, use.names = FALSE)), method = "radix")
  if (!length(terms)) abort_user("No hay palabras clave declaradas. Revisa su columna y separador en 02 o elige vocabulario preparado.")
  Matrix::sparseMatrix(i = rep(seq_along(ids), lengths(sets)),
    j = match(unlist(sets, use.names = FALSE), terms), x = 1,
    dims = c(length(ids), length(terms)), dimnames = list(ids, terms))
}

# Internal links counted once (unordered pairs); each external link contributes
# once to EACH incident theme. Callon indices are not percentages.
thematic_callon <- function(nodes, edges) {
  groups <- sort(unique(nodes$tema))
  a <- nodes$tema[match(edges$from, nodes$termino)]
  b <- nodes$tema[match(edges$to, nodes$termino)]
  do.call(rbind, lapply(groups, function(k) data.frame(tema = k,
    terminos = sum(nodes$tema == k),
    centralidad = 10 * sum(edges$peso[(a == k) != (b == k)]),
    densidad = 100 * sum(edges$peso[a == k & b == k]) / sum(nodes$tema == k))))
}

thematic_quadrants <- function(d) {
  cuts <- c(centralidad = stats::median(d$centralidad), densidad = stats::median(d$densidad))
  dx <- d$centralidad - cuts[1]; dy <- d$densidad - cuts[2]
  tol <- 1e-10 * max(1, abs(unlist(d[c("centralidad", "densidad")])))
  d$cuadrante <- ifelse(abs(dx) <= tol | abs(dy) <= tol, "En el l\u00edmite",
    ifelse(dx > 0 & dy > 0, "Motor", ifelse(dx < 0 & dy > 0, "Especializado / nicho",
      ifelse(dx > 0 & dy < 0, "B\u00e1sico / transversal", "Emergente o en declive"))))
  if (nrow(d) == 1L) d$cuadrante <- "Sin contraste entre temas"
  list(themes = d, cuts = cuts)
}

thematic_from_incidence <- function(incidence, params = list()) {
  if (!requireNamespace("igraph", quietly = TRUE)) abort_user("Falta el paquete igraph para calcular el mapa tem\u00e1tico.")
  p <- utils::modifyList(thematic_defaults(), params)
  if (length(p$field) != 1L || !p$field %in% c("keywords", "text")) abort_user("Origen de t\u00e9rminos no admitido.")
  check_number(p$min_presence, "Presencia m\u00ednima", 1, 10000)
  check_number(p$max_terms, "M\u00e1ximo de t\u00e9rminos", 2, 150)
  check_number(p$min_shared, "Coincidencias m\u00ednimas", 1, 10000)
  check_number(p$resolution, "Resoluci\u00f3n Louvain", .1, 3, FALSE)
  check_number(p$seed, "Semilla", 1, .Machine$integer.max)
  if (is.null(dim(incidence)) || !nrow(incidence) || !ncol(incidence) ||
      is.null(colnames(incidence)) || anyNA(colnames(incidence)) ||
      anyDuplicated(colnames(incidence)) || any(!nzchar(colnames(incidence))) ||
      anyNA(incidence) || any(!is.finite(incidence)) || any(incidence < 0)) abort_user("La tabla documento-t\u00e9rmino no es v\u00e1lida.")
  b <- (incidence > 0) * 1
  presence <- Matrix::colSums(b)
  eligible <- which(presence >= p$min_presence)
  chosen <- utils::head(eligible[order(-presence[eligible], enc2utf8(colnames(b)[eligible]), method = "radix")], p$max_terms)
  if (length(chosen) < 2L) abort_user("Menos de dos t\u00e9rminos superan los filtros. Reduce la presencia m\u00ednima o revisa el origen de t\u00e9rminos.")
  selected <- b[, chosen, drop = FALSE]
  raw <- as.matrix(Matrix::crossprod(selected))
  pairs <- which(upper.tri(raw) & raw >= p$min_shared, arr.ind = TRUE)
  if (!nrow(pairs)) abort_user("No hay copresencias entre t\u00e9rminos que superen el umbral. Reduce coincidencias m\u00ednimas o revisa los datos.")
  weights <- raw^2 / outer(presence[chosen], presence[chosen])
  edges <- data.frame(from = colnames(selected)[pairs[, 1]], to = colnames(selected)[pairs[, 2]],
    coincidencias = as.numeric(raw[pairs]), peso = as.numeric(weights[pairs]), stringsAsFactors = FALSE)
  connected <- colnames(selected) %in% unique(c(edges$from, edges$to))
  kept <- colnames(selected)[connected]
  graph <- igraph::graph_from_data_frame(edges, directed = FALSE, vertices = kept)
  communities <- with_seed(p$seed, igraph::cluster_louvain(graph, weights = edges$peso, resolution = p$resolution))
  membership <- as.integer(igraph::membership(communities))
  # Stable theme identifiers: highest total document-presences, then term name.
  strength <- vapply(unique(membership), function(k) sum(presence[kept[membership == k]]), 0)
  first <- vapply(unique(membership), function(k) sort(kept[membership == k], method = "radix")[1], "")
  group_order <- unique(membership)[order(-strength, enc2utf8(first), method = "radix")]
  nodes <- data.frame(termino = kept, documentos = as.numeric(presence[kept]),
    tema = match(membership, group_order), stringsAsFactors = FALSE)
  d <- thematic_callon(nodes, edges)
  d$etiqueta <- vapply(d$tema, function(k) {
    z <- nodes[nodes$tema == k, ]; paste(utils::head(z$termino[order(-z$documentos, enc2utf8(z$termino), method = "radix")], 3), collapse = "; ")
  }, "")
  d$documentos <- vapply(d$tema, function(k) sum(Matrix::rowSums(b[, nodes$termino[nodes$tema == k], drop = FALSE]) > 0), 0)
  classified <- thematic_quadrants(d)
  selection <- data.frame(termino = colnames(b), documentos = as.numeric(presence),
    estado = ifelse(colnames(b) %in% kept, "Incluido", ifelse(presence < p$min_presence,
      "No supera presencia m\u00ednima", ifelse(!seq_along(presence) %in% chosen, "Fuera del m\u00e1ximo de t\u00e9rminos", "Aislado tras filtrar conexiones"))), stringsAsFactors = FALSE)
  selection <- selection[order(-selection$documentos, enc2utf8(selection$termino), method = "radix"), ]
  coverage <- data.frame(etapa = c("Documentos preparados", "Documentos con t\u00e9rminos de este origen", "T\u00e9rminos observados",
    "T\u00e9rminos que superan presencia m\u00ednima", "T\u00e9rminos seleccionados", "Aislados excluidos", "T\u00e9rminos en el mapa", "Conexiones", "Temas", "Documentos con t\u00e9rminos del mapa"),
    cantidad = c(nrow(b), sum(Matrix::rowSums(b) > 0), ncol(b), length(eligible), length(chosen), sum(!connected), nrow(nodes), nrow(edges), nrow(d), sum(Matrix::rowSums(b[, kept, drop = FALSE]) > 0)))
  list(themes = classified$themes, terms = nodes, edges = edges, selection = selection,
    coverage = coverage, cuts = classified$cuts, params = p, incidence = b,
    modularity = igraph::modularity(communities),
    method = "Copresencia documental binaria; equivalencia e_ij = c_ij^2 / (c_i c_j); Louvain ponderado. C = 10 suma de pesos externos; D = 100 suma de pesos internos / n\u00famero de t\u00e9rminos. Cada pareja interna se cuenta una vez. Cortes: medianas entre temas; igualdades sobre el l\u00edmite. Tama\u00f1o: documentos distintos con alg\u00fan t\u00e9rmino del tema, no exclusivos.")
}

#' Mapa tematico de centralidad y densidad de Callon
#'
#' Detecta comunidades de terminos mediante Louvain sobre copresencias por
#' documento normalizadas con el indice de equivalencia. No modifica el corpus.
#' @param corpus,prepared Resultados de [prepare_corpus()] y [prepare_documents()].
#' @param params Lista parcial: `field` (`"keywords"` o `"text"`),
#'   `min_presence` (2), `max_terms` (100, maximo 150), `min_shared` (1),
#'   `resolution` (1) y `seed` (2026).
#' @return Lista con `themes`, `terms`, `edges`, `selection`, `coverage`,
#'   `cuts`, `params`, `incidence`, `modularity` y `method`. Los cortes son
#'   las medianas de centralidad y densidad. Los documentos por tema no son
#'   exclusivos. Un mapa sin comparacion temporal no distingue emergencia de declive.
#' @references Cobo et al. (2012). SciMAT: A new science mapping analysis
#'   software tool. JASIST, 63(8), 1609-1630. doi:10.1002/asi.22688.
#' @export
run_thematic_map <- function(corpus, prepared, params = list()) {
  p <- utils::modifyList(thematic_defaults(), params)
  if (length(p$field) != 1L || !p$field %in% c("keywords", "text")) abort_user("Origen de t\u00e9rminos no admitido.")
  thematic_from_incidence(thematic_incidence(corpus, prepared, p$field), p)
}

thematic_reading <- function(fit) {
  d <- fit$themes
  paste(nrow(d), "temas a partir de", nrow(fit$terms), "t\u00e9rminos y", nrow(fit$edges), "conexiones.",
    if (nrow(d) == 1) "Solo hay un tema: no existe contraste externo ni una clasificaci\u00f3n por cuadrantes interpretable." else
      paste(sum(d$cuadrante == "En el l\u00edmite"), "temas sobre alg\u00fan corte: no se les fuerza a un cuadrante."),
    if (nrow(d) > 1L && diff(range(d$centralidad)) < 1e-10) "Todos los temas tienen la misma centralidad: el eje horizontal no permite distinguir posiciones relativas." else "",
    "Las etiquetas re\u00fanen los tres t\u00e9rminos m\u00e1s presentes de cada tema; rev\u00edsalas antes de asignar un nombre sustantivo.",
    "Emergente o en declive es una posici\u00f3n estructural: este mapa no determina la direcci\u00f3n temporal.")
}

thematic_plot <- function(fit, compact = FALSE) {
  d <- fit$themes
  d$texto <- if (compact) paste0("T", d$tema) else paste0("T", d$tema, " \u00b7 ",
    vapply(d$etiqueta, function(z) paste(strwrap(z, width = 30), collapse = "\n"), ""))
  cx <- fit$cuts[[1]]; cy <- fit$cuts[[2]]
  rx <- max(c(abs(d$centralidad - cx), abs(cx) * .1, .1)) * 1.5
  ry <- max(c(abs(d$densidad - cy), abs(cy) * .1, .1)) * 1.5
  colours <- c("Motor" = "#245579", "Especializado / nicho" = "#66518a", "B\u00e1sico / transversal" = "#2d7164",
    "Emergente o en declive" = "#9c6d13", "En el l\u00edmite" = "#666666", "Sin contraste entre temas" = "#666666")
  graph <- ggplot2::ggplot(d, ggplot2::aes(x = centralidad, y = densidad)) +
    ggplot2::annotate("rect", xmin = cx-rx, xmax = cx, ymin = cy, ymax = cy+ry, fill = "#66518a", alpha = .055) +
    ggplot2::annotate("rect", xmin = cx, xmax = cx+rx, ymin = cy, ymax = cy+ry, fill = "#245579", alpha = .055) +
    ggplot2::annotate("rect", xmin = cx-rx, xmax = cx, ymin = cy-ry, ymax = cy, fill = "#9c6d13", alpha = .055) +
    ggplot2::annotate("rect", xmin = cx, xmax = cx+rx, ymin = cy-ry, ymax = cy, fill = "#2d7164", alpha = .055) +
    ggplot2::geom_vline(xintercept = cx, linetype = "dashed", colour = "#777777", linewidth = .4) +
    ggplot2::geom_hline(yintercept = cy, linetype = "dashed", colour = "#777777", linewidth = .4) +
    ggplot2::geom_point(ggplot2::aes(size = documentos, fill = cuadrante), shape = 21, colour = "white", stroke = .8, alpha = .85) +
    ggplot2::scale_size_area(max_size = if (compact) 18 else 25, name = "Documentos por tema") +
    ggplot2::scale_fill_manual(values = colours, guide = "none") +
    ggplot2::scale_x_continuous(breaks = function(limits) { z <- pretty(limits); z[z >= 0] }) +
    ggplot2::scale_y_continuous(breaks = function(limits) { z <- pretty(limits); z[z >= 0] }) +
    ggplot2::coord_cartesian(xlim = c(cx-rx, cx+rx), ylim = c(cy-ry, cy+ry), expand = FALSE) +
    swiss_theme(if (compact) 10 else 12) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 0), legend.position = "bottom",
      plot.title = ggplot2::element_text(size = if (compact) 14 else 17)) +
    ggplot2::labs(title = if (compact) "Mapa tem\u00e1tico\nCentralidad y densidad" else "Mapa tem\u00e1tico / centralidad y densidad", subtitle = if (compact) "Cortes: medianas entre temas" else "Copresencias documentales \u00b7 \u00edndice de equivalencia \u00b7 cortes: medianas",
      x = if (compact) "Centralidad de Callon\nConexi\u00f3n externa" else "Centralidad de Callon / conexi\u00f3n externa",
      y = if (compact) "Densidad de Callon\nCohesi\u00f3n interna" else "Densidad de Callon / cohesi\u00f3n interna")
  if (compact) graph <- graph + ggplot2::theme(plot.margin = ggplot2::margin(8, 6, 8, 2),
    axis.title = ggplot2::element_text(size = 10), axis.text = ggplot2::element_text(size = 8),
    axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 5)),
    legend.title = ggplot2::element_text(size = 9), legend.text = ggplot2::element_text(size = 8),
    legend.box.margin = ggplot2::margin(t = 3))
  quadrants <- data.frame(x = c(cx-rx*.94, cx+rx*.94, cx-rx*.94, cx+rx*.94),
    y = c(cy+ry*.94, cy+ry*.94, cy-ry*.94, cy-ry*.94),
    label = c("Especializados /\nnicho", "Motores", "Emergentes o\nen declive", "B\u00e1sicos /\ntransversales"),
    hjust = c(0, 1, 0, 1), vjust = c(1, 1, 0, 0))
  if (nrow(d) > 1L) graph <- graph + ggplot2::geom_text(data = quadrants,
    ggplot2::aes(x = x, y = y, label = label, hjust = hjust, vjust = vjust), inherit.aes = FALSE,
    colour = "#666666", size = if (compact) 2.6 else 3.3)
  graph + label_layer(d, ggplot2::aes(label = texto), size = if (compact) 2.7 else 3.5,
    seed = fit$params$seed, repel = list(max.overlaps = Inf, box.padding = .6,
      point.padding = 1.1, point.size = if (compact) 18 else 25,
      min.segment.length = 0, max.time = 3))
}

write_thematic_bundle <- function(directory, fit, figures = TRUE) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  for (key in c("themes", "terms", "edges", "selection", "coverage"))
    safe_csv(fit[[key]], file.path(directory, paste0(key, ".csv")))
  saveRDS(list(incidence = fit$incidence, params = fit$params), file.path(directory, "entrada_mapa.rds"))
  jsonlite::write_json(list(parametros = fit$params, cortes = fit$cuts, metodo = fit$method,
    R = as.character(getRversion()), igraph = as.character(utils::packageVersion("igraph"))),
    file.path(directory, "metodo.json"), pretty = TRUE, auto_unbox = TRUE, digits = NA)
  definitions <- c("%||%", "abort_user", "check_number", "rng_state", "rng_restore", "with_seed",
    "thematic_defaults", "thematic_callon", "thematic_quadrants", "thematic_from_incidence")
  script <- c("# Ejecutar desde esta carpeta. Requiere Matrix, igraph y shiny.",
    "# entrada_mapa.rds contiene presencias por documento y etiquetas; no textos.",
    unlist(lapply(definitions, function(key) c(paste0("`", key, "` <- ", paste(deparse(get(key, mode = "function")), collapse = "\n")), ""))),
    "entrada <- readRDS('entrada_mapa.rds')", "resultado <- thematic_from_incidence(entrada$incidence, entrada$params)",
    "saveRDS(resultado, 'mapa_reproducido.rds')", "print(resultado$themes)")
  writeLines(enc2utf8(script), file.path(directory, "reproducir_mapa.R"), useBytes = TRUE)
  writeLines(enc2utf8(c(fit$method, thematic_reading(fit),
    "Los documentos pueden aparecer en varios temas: los tama\u00f1os no deben sumarse como categor\u00edas exclusivas.",
    "Los valores son \u00edndices, no porcentajes. Valores negativos del margen gr\u00e1fico son espacio de lectura; las medidas son no negativas.",
    "Las medianas son referencias relativas al mapa. Un tema sobre un corte queda En el l\u00edmite; con un \u00fanico tema no se interpretan cuadrantes.",
    "Los t\u00e9rminos aislados se excluyen de comunidades y constan en selection.csv. Los filtros cambian las medidas y los temas.",
    "La reproducci\u00f3n conserva la matriz de entrada completa, con identificadores de documentos y t\u00e9rminos. No incluye res\u00famenes ni t\u00edtulos.",
    "Cobo et al. (2012). SciMAT. DOI: 10.1002/asi.22688. La normalizaci\u00f3n y Louvain se documentan expl\u00edcitamente; no se presupone igualdad con otras aplicaciones.")),
    file.path(directory, "LEEME.txt"), useBytes = TRUE)
  if (figures) {
    graph <- thematic_plot(fit)
    ggplot2::ggsave(file.path(directory, "mapa_tematico.png"), graph, width = 12, height = 9, dpi = 150)
    ggplot2::ggsave(file.path(directory, "mapa_tematico.pdf"), graph, width = 12, height = 9, device = grDevices::cairo_pdf)
  }
  invisible(directory)
}
