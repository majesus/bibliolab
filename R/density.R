# Pipeline de temas por densidad, integramente en R.
# Representacion lexical LSA o vectores externos; no se ejecuta BERT en esta app.
#' Parametros por defecto de UMAP + HDBSCAN
#'
#' Valores iniciales de [run_density()] y [density_sensitivity()]. Se modifican con
#' una lista parcial en el argumento `params`.
#'
#' @return Lista con:
#' * `representation`: `"lexical"` (TF-IDF o BM25 + LSA) o `"vectors"` (vectores importados).
#' * `weighting`: `"tfidf"` o `"bm25"`, solo con representacion lexical; `bm25_k1` y `bm25_b` son sus constantes.
#' * `lsa_dims`: dimensiones LSA (2 a 100).
#' * `neighbors`: vecinos de UMAP (2 a 100; menos que los documentos retenidos).
#' * `cluster_dims`: dimensiones del UMAP donde se agrupa (2 a 10).
#' * `min_dist`: distancia minima de UMAP (0 a 0,99).
#' * `min_pts`: `minPts` de HDBSCAN (2 a 500; menos que los documentos retenidos).
#' * `epochs`: epocas de UMAP (100 a 1000).
#' * `seed`: semilla de UMAP (1 a `.Machine$integer.max`).
#' @examples
#' str(density_defaults())
#' @export
density_defaults <- function() list(representation = "lexical", lsa_dims = 30L, neighbors = 10L,
  cluster_dims = 5L, min_dist = 0, min_pts = 5L, seed = 2026L, epochs = 300L, weighting = "tfidf", bm25_k1 = 1.2, bm25_b = .75)
density_display <- function(fit, max_groups = 20L) {
  d <- fit$assignments; d$grupo_label <- ifelse(d$grupo == 0, "Sin asignar", paste("Grupo", d$grupo))
  sizes <- sort(table(d$grupo[d$grupo > 0]), decreasing = TRUE)
  shown <- as.integer(head(names(sizes), max_groups))
  d$plot_label <- ifelse(d$grupo == 0, "Sin asignar", ifelse(d$grupo %in% shown, d$grupo_label, "Otros grupos"))
  d
}
density_palette <- function(labels) {
  categories <- sort(unique(labels))
  colours <- setNames(rep(c("#c7281e", "#245579", "#2d7164", "#9c6d13", "#66518a", "#aa4e65", "#333333", "#4b7c95", "#687944", "#b56835", "#817487", "#7b4637"), length.out = length(categories)), categories)
  if ("Sin asignar" %in% categories) colours["Sin asignar"] <- "#b8b8b8"
  if ("Otros grupos" %in% categories) colours["Otros grupos"] <- "#888888"
  colours
}
document_counts <- function(corpus, prepared) {
  m <- corpus$counts
  if (is.null(m) || !nrow(m) || !ncol(m)) abort_user("No hay vocabulario retenido. Revisa los filtros de tokens antes de calcular UMAP.")
  ids <- corpus$units$doc_id[match(rownames(m), corpus$units$unit_id)]
  if (anyNA(ids)) abort_user("La matriz contiene unidades sin documento. Vuelve a preparar el corpus.")
  all_ids <- prepared$documents$doc_id
  a <- Matrix::sparseMatrix(i = match(ids, all_ids), j = seq_along(ids), x = 1, dims = c(length(all_ids), length(ids)))
  out <- a %*% m; rownames(out) <- all_ids
  out <- out[Matrix::rowSums(out) > 0, , drop = FALSE]
  out <- out[, Matrix::colSums(out) > 0, drop = FALSE]
  out
}
#' Lee vectores de documentos desde un CSV
#'
#' Importa representaciones calculadas fuera de R (por ejemplo, embeddings) para
#' usarlas con `run_density(..., params = list(representation = "vectors"))`. El
#' CSV debe tener una columna de identificador (`doc_id` u `original_id`) y al
#' menos dos columnas numericas, cubrir todos los documentos preparados, no tener
#' filas nulas y no superar 20 MB, 10.000 filas ni 1.024 dimensiones. Cualquier
#' inconsistencia es un error: no se completan ni descartan filas.
#'
#' @param path Ruta del CSV (UTF-8, punto decimal, sin separador de miles).
#' @param prepared Resultado de [prepare_documents()], con el que se alinean los vectores.
#' @param id_column `"doc_id"` (por defecto) o `"original_id"`.
#' @return Lista con `matrix` (documentos por dimensiones, filas con `doc_id`),
#'   `md5` y `file` (huella y nombre del archivo), y `dimensions`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' set.seed(1)
#' v <- data.frame(doc_id = p$documents$doc_id, matrix(stats::rnorm(nrow(p$documents) * 4), ncol = 4))
#' f <- tempfile(fileext = ".csv")
#' utils::write.csv(v, f, row.names = FALSE)
#' vec <- read_document_vectors(f, p)
#' dim(vec$matrix)
#' @export
read_document_vectors <- function(path, prepared, id_column = "doc_id") {
  if (!file.exists(path) || is.na(file.info(path)$size) || file.info(path)$size > 20 * 1024^2)
    abort_user("El CSV de vectores no existe o supera 20 MB.")
  w <- character()
  d <- tryCatch(withCallingHandlers(data.table::fread(file = path, colClasses = "character", encoding = "UTF-8",
    fill = FALSE, nrows = 10001, check.names = FALSE, showProgress = FALSE),
    warning = function(e) { w <<- c(w, conditionMessage(e)); invokeRestart("muffleWarning") }),
    error = function(e) abort_user("CSV de vectores no v\u00e1lido. Revisa encabezados, separador y comillas."))
  if (length(w) || nrow(d) > 10000 || ncol(d) > 1025 || anyDuplicated(names(d))) abort_user("El CSV de vectores tiene formato inconsistente o supera 10.000 filas / 1.024 dimensiones.")
  if (!id_column %in% names(d) || ncol(d) < 3) abort_user("Los vectores deben tener una columna doc_id (o original_id) y al menos dos dimensiones num\u00e9ricas.")
  ids <- clean_value(d[[id_column]])
  if (any(!nzchar(ids)) || anyDuplicated(ids)) abort_user("Los ID de los vectores deben ser \u00fanicos y no estar vac\u00edos.")
  target <- if (id_column == "original_id") prepared$documents$original_id else prepared$documents$doc_id
  if (any(!nzchar(target)) || anyDuplicated(target)) abort_user("Los ID originales del corpus no son \u00fanicos. Usa doc_id interno para alinear vectores.")
  idx <- match(target, ids)
  if (anyNA(idx)) abort_user("Faltan vectores para uno o m\u00e1s documentos del corpus. El archivo debe cubrir todos los ID preparados.")
  values <- as.matrix(as.data.frame(d[, setdiff(names(d), id_column), with = FALSE]))
  x <- suppressWarnings(matrix(as.numeric(values), nrow = nrow(values), ncol = ncol(values), dimnames = dimnames(values)))
  if (any(!is.finite(x))) abort_user("Hay dimensiones no num\u00e9ricas o ausentes. Usa punto decimal sin separadores de miles.")
  x <- x[idx, , drop = FALSE]; rownames(x) <- prepared$documents$doc_id
  if (any(rowSums(x^2) < 1e-12)) abort_user("Los vectores contienen filas nulas. Regenera esas representaciones.")
  list(matrix = x, md5 = unname(tools::md5sum(path)), file = basename(path), dimensions = ncol(x))
}
lsa_vectors <- function(counts, dims, seed, weighting = "tfidf", k1 = 1.2, b = .75) {
  n <- nrow(counts); df <- as.numeric(Matrix::colSums(counts > 0))
  idf <- log((n + 1) / (df + 1)) + 1
  tf <- Matrix::Diagonal(x = 1 / as.numeric(Matrix::rowSums(counts))) %*% counts
  weighted <- if (weighting == "bm25") bm25_weights(counts, k1, b) else tf %*% Matrix::Diagonal(x = idf)
  weighted <- Matrix::Diagonal(x = 1 / sqrt(as.numeric(Matrix::rowSums(weighted^2)))) %*% weighted
  k <- min(as.integer(dims), min(dim(weighted)) - 1L)
  if (k < 2) abort_user("LSA necesita al menos tres documentos y t\u00e9rminos. Ampl\u00eda el corpus o reduce los filtros.")
  decomp <- with_seed(seed, if (min(dim(weighted)) <= 60L) svd(as.matrix(weighted), nu = k, nv = 0)
    else irlba::irlba(weighted, nv = k, nu = k, maxit = 1000))
  active <- which(decomp$d[seq_len(k)] > max(decomp$d) * 1e-8)
  if (length(active) < 2) abort_user("La representaci\u00f3n lexical tiene menos de dos dimensiones \u00fatiles. Usa textos m\u00e1s variados.")
  x <- sweep(decomp$u[, active, drop = FALSE], 2, decomp$d[active], "*")
  rownames(x) <- rownames(counts)
  list(matrix = x, dimensions = ncol(x), idf = if(weighting=="bm25") "log(1+(N-df+0.5)/(df+0.5))" else "log((N+1)/(df+1))+1", l2 = TRUE)
}
class_tfidf <- function(counts, clusters, top_n = 10L) {
  groups <- sort(unique(clusters[clusters > 0]))
  empty <- data.frame(grupo = integer(), termino = character(), c_tfidf = numeric(), frecuencia = numeric(), posicion = integer())
  if (!length(groups)) return(empty)
  cluster_map <- Matrix::sparseMatrix(i = match(clusters[clusters > 0], groups),
    j = which(clusters > 0), x = 1, dims = c(length(groups), nrow(counts)))
  combined <- cluster_map %*% counts
  total <- as.numeric(Matrix::rowSums(combined)); word_total <- as.numeric(Matrix::colSums(combined))
  avg_words <- mean(total)
  scores <- Matrix::Diagonal(x = 1 / pmax(total, 1)) %*% combined %*%
    Matrix::Diagonal(x = log(1 + avg_words / pmax(word_total, 1)))
  # Formula estandar class-based: A = promedio de palabras por clase,
  # f_t = apariciones del termino en todas las clases (no df documental).
  do.call(rbind, lapply(seq_along(groups), function(i) {
    s <- as.numeric(scores[i, ]); ix <- head(order(-s, colnames(counts))[s[order(-s, colnames(counts))] > 0], top_n)
    if (!length(ix)) return(empty)
    data.frame(grupo = groups[i], termino = colnames(counts)[ix], c_tfidf = s[ix],
      frecuencia = as.numeric(combined[i, ix]), posicion = seq_along(ix))
  }))
}
#' UMAP + HDBSCAN + c-TF-IDF
#'
#' Representa los documentos (TF-IDF o BM25 + LSA, o vectores importados),
#' reduce con UMAP, agrupa por densidad con HDBSCAN y describe los grupos con
#' c-TF-IDF. Un solo resultado depende de la semilla y de los parametros:
#' evalua su estabilidad con [density_sensitivity()].
#'
#' @param corpus,prepared Resultados de [prepare_corpus()] y [prepare_documents()].
#' @param params Lista parcial de parametros (`neighbors`, `cluster_dims`,
#'   `min_dist`, `min_pts`, `seed`, `epochs`, `lsa_dims`, `weighting`, ...).
#' @param vectors Vectores importados (ver `read_document_vectors`), opcional.
#' @param embedding_model Nombre/version del modelo que genero los vectores.
#' @param display Si se calcula tambien el UMAP 2D de lectura.
#' @return Lista con `assignments`, `summary`, `terms`, `examples`, `quality`,
#'   `similarity`, `temporal`, `params`, `representation`, `issues` e
#'   `input_vectors` (los vectores importados si `representation = "vectors"`,
#'   necesarios para reproducir la ejecucion; `NULL` en caso contrario).
#' @references
#' McInnes, L., Healy, J., Melville, J. (2018). UMAP. arXiv:1802.03426.
#' Campello, R., Moulavi, D., Sander, J. (2013). Density-based clustering based on hierarchical density estimates. PAKDD.
#' @examples
#' \donttest{
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
#' if (all(vapply(c("uwot", "dbscan", "irlba"), requireNamespace, logical(1), quietly = TRUE))) {
#'   fit <- run_density(cp, p, list(neighbors = 5L, min_pts = 3L))
#'   table(fit$assignments$grupo)
#' }
#' }
#' @export
run_density <- function(corpus, prepared, params = density_defaults(), vectors = NULL, embedding_model = "", display = TRUE) {
  p <- utils::modifyList(density_defaults(), params)
  p$vocabulary_terms<-length(corpus$vocabulary)
  deps <- c("uwot", "dbscan", "irlba")
  if (!all(vapply(deps, requireNamespace, logical(1), quietly = TRUE))) abort_user("Faltan los paquetes uwot, dbscan o irlba. Inst\u00e1lalos con install.packages(c(\"uwot\", \"dbscan\", \"irlba\")) para habilitar UMAP y HDBSCAN.")
  check_number(p$neighbors, "Vecinos UMAP", 2, 100); check_number(p$cluster_dims, "Dimensiones UMAP para agrupar", 2, 10)
  check_number(p$min_dist, "Distancia m\u00ednima UMAP", 0, 0.99, FALSE); check_number(p$min_pts, "minPts HDBSCAN", 2, 500)
  check_number(p$lsa_dims, "Dimensiones LSA", 2, 100); check_number(p$epochs, "\u00c9pocas UMAP", 100, 1000)
  check_number(p$seed, "Semilla UMAP", 1, .Machine$integer.max)
  if (!p$representation %in% c("lexical", "vectors")) abort_user("Representaci\u00f3n no admitida.")
  counts <- document_counts(corpus, prepared)
  if (nrow(counts) < 10L) abort_user("UMAP y HDBSCAN requieren al menos diez documentos con vocabulario. A\u00f1ade documentos o reduce filtros.")
  if (nrow(counts) > 3000L) abort_user("El an\u00e1lisis por densidad est\u00e1 limitado a 3.000 documentos. Usa una muestra con semilla.")
  if (p$neighbors >= nrow(counts)) abort_user("Los vecinos UMAP deben ser menos que los documentos retenidos.")
  if (p$min_pts >= nrow(counts)) abort_user("minPts debe ser menor que el n\u00famero de documentos retenidos.")
  if (p$representation == "vectors") {
    if (is.null(vectors) || !nzchar(trimws(embedding_model))) abort_user("Carga los vectores y registra el nombre/versi\u00f3n del modelo que los gener\u00f3.")
    x <- vectors$matrix[match(rownames(counts), rownames(vectors$matrix)), , drop = FALSE]
    if (anyNA(x)) abort_user("Los vectores no est\u00e1n alineados con los documentos del corpus.")
    provenance <- list(type = "Vectores importados", model = embedding_model, file = vectors$file, md5 = vectors$md5, dimensions = ncol(x))
  } else {
    if(!p$weighting %in% c("tfidf","bm25")) abort_user("Ponderacion lexical no admitida.")
    lsa <- lsa_vectors(counts, p$lsa_dims, p$seed, p$weighting, p$bm25_k1, p$bm25_b); x <- lsa$matrix
    provenance <- list(type = paste(if(p$weighting=="bm25") "BM25" else "TF-IDF", "+ LSA lexical"), dimensions = lsa$dimensions, idf = lsa$idf,
      note = "No hay embeddings BERT ni equivalencia sem\u00e1ntica multiling\u00fce.")
  }
  norms <- sqrt(rowSums(x^2))
  if (p$cluster_dims > ncol(x)) abort_user(paste("Las dimensiones UMAP para agrupar no pueden superar las", ncol(x), "dimensiones \u00fatiles de la representaci\u00f3n. Reduce este par\u00e1metro."))
  if (any(!is.finite(norms) | norms < 1e-12)) abort_user("Hay representaciones nulas o no v\u00e1lidas. Revisa el vocabulario o los vectores.")
  x <- x / norms
  if (nrow(unique(as.data.frame(round(x, 10)))) < 3) abort_user("Hay menos de tres perfiles distintos. Usa un corpus m\u00e1s variado.")
  reduced <- with_seed(p$seed, uwot::umap(x, n_neighbors = p$neighbors, n_components = p$cluster_dims,
    metric = "cosine", min_dist = p$min_dist, n_epochs = p$epochs, init = "random",
    n_threads = 1, n_sgd_threads = 1, fast_sgd = FALSE, verbose = FALSE))
  fit <- dbscan::hdbscan(reduced, minPts = p$min_pts)
  # La vista 2D no es el espacio donde se hace clustering: se calcula por separado.
  display_xy <- if (isTRUE(display)) with_seed(p$seed, uwot::umap(x, n_neighbors = p$neighbors, n_components = 2,
    metric = "cosine", min_dist = 0.15, n_epochs = p$epochs, init = "random",
    n_threads = 1, n_sgd_threads = 1, fast_sgd = FALSE, verbose = FALSE)) else matrix(NA_real_, nrow(reduced), 2)
  terms <- class_tfidf(counts, fit$cluster)
  docs <- prepared$documents[match(rownames(counts), prepared$documents$doc_id), ]
  assignments <- data.frame(doc_id = docs$doc_id, original_id = docs$original_id, title = docs$title,
    grupo = as.integer(fit$cluster), membresia = as.numeric(fit$membership_prob),
    atipicidad = as.numeric(fit$outlier_scores), umap_1 = display_xy[, 1], umap_2 = display_xy[, 2], year = docs$year)
  groups <- sort(unique(assignments$grupo))
  summary <- do.call(rbind, lapply(groups, function(g) {
    ix <- assignments$grupo == g
    data.frame(grupo = g, etiqueta = if (g == 0) "Sin asignar" else paste("Grupo", g), documentos = sum(ix),
      porcentaje = 100 * sum(ix) / nrow(assignments), membresia_media = mean(assignments$membresia[ix]),
      palabras = paste(head(terms$termino[terms$grupo == g], 5), collapse = ", "))
  }))
  examples <- do.call(rbind, lapply(groups[groups > 0], function(g) {
    a <- assignments[assignments$grupo == g, ]; head(a[order(-a$membresia, a$doc_id), ], 3)
  }))
  if (is.null(examples)) examples <- assignments[0, ]
  grouped <- groups[groups > 0]; similarity <- data.frame()
  if (length(grouped) >= 2) {
    topic_counts <- do.call(rbind, lapply(grouped, function(g) as.numeric(Matrix::colSums(counts[fit$cluster == g, , drop = FALSE]))))
    tf <- topic_counts / pmax(rowSums(topic_counts), 1)
    idf <- log(1 + mean(rowSums(topic_counts)) / pmax(colSums(topic_counts), 1))
    weighted <- sweep(tf, 2, idf, "*"); weighted <- weighted / sqrt(rowSums(weighted^2))
    sim <- tcrossprod(weighted)
    similarity <- expand.grid(grupo_a = grouped, grupo_b = grouped)
    similarity$similitud_coseno <- as.vector(sim)
  }
  temporal <- if (any(!is.na(assignments$year))) stats::aggregate(rep(1L, sum(!is.na(assignments$year))),
    list(grupo = assignments$grupo[!is.na(assignments$year)], ano = assignments$year[!is.na(assignments$year)]), sum)
    else data.frame(grupo = integer(), ano = numeric(), documentos = integer())
  names(temporal)[3] <- "documentos"
  issues <- c("UMAP 2D es una visualizaci\u00f3n independiente. HDBSCAN usa la reducci\u00f3n de mayor dimensi\u00f3n; no interpreta distancias globales del mapa como distancias sem\u00e1nticas exactas.",
    "minPts en dbscan controla tama\u00f1o y suavizado de densidad; no reproduce dos par\u00e1metros separados min_cluster_size/min_samples de otras implementaciones.",
    "El grado de pertenencia al grupo es estabilidad de asignaci\u00f3n, no probabilidad calibrada de pertenencia a un tema cient\u00edfico.",
    sprintf("%d de %d documentos sin asignar; %d documentos del corpus sin vocabulario quedan fuera de este an\u00e1lisis.", sum(fit$cluster == 0), nrow(counts), nrow(prepared$documents) - nrow(counts)))
  if (!any(fit$cluster > 0)) issues <- c(issues, "No se han detectado grupos. Es un resultado v\u00e1lido: revisa minPts, representaci\u00f3n y corpus sin forzar temas.")
  quality <- data.frame(
    indicador = c("Grupos detectados", "Documentos sin asignar (%)", "Grado medio de pertenencia de los asignados", "Documentos en el an\u00e1lisis"),
    valor = c(length(grouped), 100 * mean(fit$cluster == 0), if (any(fit$cluster > 0)) mean(assignments$membresia[fit$cluster > 0]) else NA_real_, nrow(assignments)),
    stringsAsFactors = FALSE)
  list(assignments = assignments, summary = summary, terms = terms, examples = examples, quality = quality,
    similarity = similarity, temporal = temporal, reduced = reduced, hierarchy = fit$hc,
    params = p, representation = provenance, issues = issues,
    input_vectors = if (p$representation == "vectors") vectors else NULL,
    ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}
