# Diagnosticos metodologicos de V4: normalizacion, coherencia, estabilidad,
# incertidumbre y lineas base. Funciones puras; no dependen de Shiny.

# ---- Plegado ASCII y claves de etiqueta -------------------------------------
FOLD_FROM <- "\u00c0\u00c1\u00c2\u00c3\u00c4\u00c5\u00c7\u00c8\u00c9\u00ca\u00cb\u00cc\u00cd\u00ce\u00cf\u00d1\u00d2\u00d3\u00d4\u00d5\u00d6\u00d9\u00da\u00db\u00dc\u00dd\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e7\u00e8\u00e9\u00ea\u00eb\u00ec\u00ed\u00ee\u00ef\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f9\u00fa\u00fb\u00fc\u00fd\u00ff\u0100\u0101\u0102\u0103\u0104\u0105\u0106\u0107\u0108\u0109\u010a\u010b\u010c\u010d\u010e\u010f\u0112\u0113\u0114\u0115\u0116\u0117\u0118\u0119\u011a\u011b\u011c\u011d\u011e\u011f\u0120\u0121\u0122\u0123\u0124\u0125\u0128\u0129\u012a\u012b\u012c\u012d\u012e\u012f\u0130\u0134\u0135\u0136\u0137\u0139\u013a\u013b\u013c\u013d\u013e\u0143\u0144\u0145\u0146\u0147\u0148\u014c\u014d\u014e\u014f\u0150\u0151\u0154\u0155\u0156\u0157\u0158\u0159\u015a\u015b\u015c\u015d\u015e\u015f\u0160\u0161\u0162\u0163\u0164\u0165\u0168\u0169\u016a\u016b\u016c\u016d\u016e\u016f\u0170\u0171\u0172\u0173\u0174\u0175\u0176\u0177\u0178\u0179\u017a\u017b\u017c\u017d\u017e"
FOLD_TO <- "AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinooooouuuuyyAaAaAaCcCcCcCcDdEeEeEeEeEeGgGgGgGgHhIiIiIiIiIJjKkLlLlLlNnNnNnOoOoOoRrRrRrSsSsSsSsTtTtUuUuUuUuUuUuWwYyYZzZzZz"

# Pliega acentos y diacriticos a ASCII sin depender del iconv de la plataforma.
ascii_fold <- function(x) {
  x <- enc2utf8(as.character(x))
  ok <- !is.na(x)
  if (any(ok) && nchar(FOLD_FROM) == nchar(FOLD_TO)) x[ok] <- chartr(FOLD_FROM, FOLD_TO, x[ok])
  x
}

# Clave de comparacion de una etiqueta (minusculas, sin acentos latinos ni puntuacion).
# No hace stemming ni fusiona sinonimos: solo variantes de escritura. Las letras de
# otros alfabetos (griego, cirilico, CJK, etc.) y sus marcas combinantes se conservan,
# de modo que "alpha \u03b1" y "alpha \u03b2", o dos autores que solo comparten una inicial
# latina, no reciben la misma clave. Las marcas combinantes (NFD) que siguen a una
# letra latina se eliminan para que "e\u0301" y "\u00e9" coincidan.
label_key <- function(x, kind = c("keyword", "author", "source")) {
  kind <- match.arg(kind)
  raw <- tolower(clean_value(x))
  y <- ascii_fold(raw)
  y <- gsub("(?<=[a-z])\\p{M}+", "", y, perl = TRUE)
  if (kind == "author") y <- gsub(".", "", y, fixed = TRUE)
  y <- gsub("[^\\p{L}\\p{N}\\p{M},+# ]+", " ", y, perl = TRUE)
  if (kind != "author") y <- gsub(",", " ", y, fixed = TRUE)
  y <- trimws(gsub("[[:space:]]+", " ", y))
  # Etiquetas formadas solo por simbolos: conservar la original en minusculas.
  y[!nzchar(y)] <- trimws(gsub("[[:space:]]+", " ", raw[!nzchar(y)]))
  y
}

# Mapa variante -> etiqueta mostrada (la variante mas frecuente; empate: orden alfabetico).
variant_map <- function(values, kind = "keyword") {
  v <- clean_value(values); v <- v[nzchar(v)]
  empty <- list(map = character(), variants = data.frame(variante = character(), clave = character(), n = integer(), etiqueta = character(), stringsAsFactors = FALSE))
  if (!length(v)) return(empty)
  tab <- table(v)
  orig <- names(tab); n <- as.integer(tab)
  key <- label_key(orig, kind)
  d <- data.frame(variante = orig, clave = key, n = n, stringsAsFactors = FALSE)
  d <- d[order(d$clave, -d$n, d$variante), , drop = FALSE]
  first <- !duplicated(d$clave)
  label <- setNames(d$variante[first], d$clave[first])
  d$etiqueta <- unname(label[d$clave])
  map <- setNames(d$etiqueta, d$variante)
  list(map = map, variants = d)
}

# ---- Utilidades estadisticas -------------------------------------------------
# Indice de Rand ajustado (Hubert y Arabie, 1985). Las etiquetas iguales cuentan
# como una clase (el ruido de HDBSCAN es una clase mas).
adjusted_rand <- function(a, b) {
  stopifnot(length(a) == length(b))
  n <- length(a)
  if (n < 2L) return(NA_real_)
  tab <- table(a, b)
  comb2 <- function(v) sum(v * (v - 1) / 2)
  sa <- comb2(rowSums(tab)); sb <- comb2(colSums(tab)); sab <- comb2(as.numeric(tab))
  expected <- sa * sb / (n * (n - 1) / 2); maximum <- (sa + sb) / 2
  if (isTRUE(all.equal(maximum, expected))) return(1)
  (sab - expected) / (maximum - expected)
}

# Asignacion optima (maximiza la suma) entre filas y columnas: Kuhn-Munkres.
# Devuelve, para cada fila, la columna asignada.
assign_max <- function(S) {
  S <- as.matrix(S)
  transposed <- nrow(S) > ncol(S)
  if (transposed) S <- t(S)
  n <- nrow(S); m <- ncol(S)
  if (n == 0L) return(integer())
  cost <- max(S) - S
  u <- numeric(n + 1L); v <- numeric(m + 1L); p <- integer(m + 1L); way <- integer(m + 1L)
  for (i in seq_len(n)) {
    p[1L] <- i; j0 <- 0L
    minv <- rep(Inf, m + 1L); used <- rep(FALSE, m + 1L)
    repeat {
      used[j0 + 1L] <- TRUE
      i0 <- p[j0 + 1L]; delta <- Inf; j1 <- 0L
      for (j in seq_len(m)) if (!used[j + 1L]) {
        cur <- cost[i0, j] - u[i0 + 1L] - v[j + 1L]
        if (cur < minv[j + 1L]) { minv[j + 1L] <- cur; way[j + 1L] <- j0 }
        if (minv[j + 1L] < delta) { delta <- minv[j + 1L]; j1 <- j }
      }
      for (j in 0:m) {
        if (used[j + 1L]) { u[p[j + 1L] + 1L] <- u[p[j + 1L] + 1L] + delta; v[j + 1L] <- v[j + 1L] - delta }
        else minv[j + 1L] <- minv[j + 1L] - delta
      }
      j0 <- j1
      if (p[j0 + 1L] == 0L) break
    }
    repeat {
      j1 <- way[j0 + 1L]; p[j0 + 1L] <- p[j1 + 1L]; j0 <- j1
      if (j0 == 0L) break
    }
  }
  assignment <- integer(n)
  for (j in seq_len(m)) if (p[j + 1L] != 0L) assignment[p[j + 1L]] <- j
  if (!transposed) return(assignment)
  # Si se transpuso, devolver la asignacion de las filas originales (columnas de S).
  out <- rep(NA_integer_, m)
  for (i in seq_len(n)) out[assignment[i]] <- i
  out
}

jaccard <- function(a, b) {
  u <- length(union(a, b))
  if (u == 0L) return(NA_real_)
  length(intersect(a, b)) / u
}

# ---- Coherencia, diversidad y convergencia de LDA ----------------------------
# Coherencia por tema con co-ocurrencia documental interna (Mimno et al., 2011;
# NPMI segun Bouma 2009 / Roeder et al., 2015). Requiere conteos documento x termino.
topic_coherence <- function(beta, counts, top_n = 10L) {
  binary <- (counts > 0) * 1
  N <- nrow(binary)
  top_n <- min(as.integer(top_n), ncol(beta))
  res <- vapply(seq_len(nrow(beta)), function(t) {
    w <- order(beta[t, ], decreasing = TRUE)[seq_len(top_n)]
    co <- as.matrix(Matrix::crossprod(binary[, w, drop = FALSE]))
    d <- diag(co)
    um <- 0; np <- numeric()
    for (m in 2:top_n) for (l in seq_len(m - 1L)) {
      um <- um + log((co[m, l] + 1) / max(d[l], 1))
      p12 <- co[m, l] / N
      np <- c(np, if (p12 <= 0) -1 else if (p12 >= 1) 1 else log(p12 / ((d[m] / N) * (d[l] / N))) / (-log(p12)))
    }
    c(umass = um, npmi = mean(np))
  }, c(umass = 0, npmi = 0))
  list(umass = res["umass", ], npmi = res["npmi", ])
}

topic_diversity <- function(beta, top_n = 10L) {
  top_n <- min(as.integer(top_n), ncol(beta))
  words <- unlist(lapply(seq_len(nrow(beta)), function(t) colnames(beta)[order(beta[t, ], decreasing = TRUE)[seq_len(top_n)]]))
  length(unique(words)) / length(words)
}

# Ajusta un LDA por Gibbs y devuelve el estado de maxima verosimilitud entre los guardados
# (igual que best = TRUE de topicmodels) junto con la traza de log-verosimilitud.
fit_lda_gibbs <- function(dtm, k, seed, burnin = 100L, iter = 500L, thin = 10L, alpha = NULL, delta = 0.1) {
  tokens <- sum(dtm$v)
  # Cada estado guardado conserva la asignacion de cada token: se acota su numero para limitar memoria.
  max_states <- max(5L, min(100L, floor(2e7 / max(tokens, 1))))
  thin_eff <- max(as.integer(thin), as.integer(ceiling(iter / max_states)))
  ctrl <- list(seed = as.integer(seed), burnin = as.integer(burnin), iter = as.integer(iter), thin = thin_eff,
    alpha = if (is.null(alpha)) 1 / k else alpha, delta = delta, best = FALSE, verbose = 0L)
  g <- with_seed(seed, topicmodels::LDA(dtm, k = as.integer(k), method = "Gibbs", control = ctrl))
  states <- g@fitted
  ll <- vapply(states, function(s) as.numeric(s@loglikelihood), 0)
  list(fit = states[[which.max(ll)]], loglik = ll, thin = thin_eff, states = length(ll))
}

# Diagnostico heuristico de convergencia a partir de la traza de log-verosimilitud.
loglik_convergence <- function(loglik) {
  ll <- as.numeric(loglik); ll <- ll[is.finite(ll)]
  if (length(ll) < 6L) return(list(relative_change = NA_real_, converged = NA, n = length(ll)))
  h <- floor(length(ll) / 2)
  first <- mean(ll[seq_len(h)]); last <- mean(ll[(length(ll) - h + 1L):length(ll)])
  rel <- (last - first) / abs(first)
  list(relative_change = rel, converged = abs(rel) < 0.01, n = length(ll))
}

lda_diagnostics <- function(beta, theta, counts, loglik = NULL, top_n = 10L) {
  coh <- topic_coherence(beta, counts, top_n)
  prevalence <- colMeans(theta)
  top_terms <- vapply(seq_len(nrow(beta)), function(t) paste(colnames(beta)[order(beta[t, ], decreasing = TRUE)[seq_len(min(5L, ncol(beta)))]], collapse = ", "), "")
  conv <- loglik_convergence(loglik)
  topics <- data.frame(tema = seq_len(nrow(beta)), prevalencia_pct = 100 * prevalence, coherencia_umass = coh$umass,
    coherencia_npmi = coh$npmi, palabras = top_terms, stringsAsFactors = FALSE)
  overview <- data.frame(
    indicador = c("Coherencia NPMI media (co-ocurrencia documental interna)", "Coherencia UMass media", "Diversidad de palabras principales",
      "Proporcion media del tema dominante por unidad", "Tema menos prevalente (%)", "Cambio relativo de log-verosimilitud (2a mitad vs 1a)"),
    valor = c(mean(coh$npmi), mean(coh$umass), topic_diversity(beta, top_n), mean(apply(theta, 1, max)), 100 * min(prevalence), conv$relative_change),
    stringsAsFactors = FALSE)
  list(overview = overview, topics = topics, convergence = conv)
}

# ---- Seleccion asistida del numero de temas ---------------------------------
lda_quality_reading <- function(fit) {
  d<-fit$diagnostics;topics<-d$topics;v<-d$overview$valor
  best<-topics$tema[which.max(topics$coherencia_npmi)];weak<-topics$tema[which.min(topics$coherencia_npmi)]
  data.frame(Aspecto=c("Coherencia NPMI","Coherencia UMass","Diversidad","Mezcla tem\u00e1tica","Tema menos prevalente","Traza del ajuste"),
    Lectura=c(sprintf("La NPMI media es %.3f; tema %d tiene la mayor y tema %d la menor. Valores positivos describen coocurrencia superior a la independencia; no hay un corte universal de calidad.",v[1],best,weak),
      sprintf("UMass media = %.3f. Compara valores mayores (menos negativos) solo con el mismo corpus, vocabulario y n\u00famero de palabras principales.",v[2]),
      sprintf("Diversidad = %.1f %% de posiciones de palabras principales ocupadas por palabras distintas. El resto repite t\u00e9rminos entre temas; diversidad alta no garantiza temas interpretables.",100*v[3]),
      sprintf("El tema dominante acumula, en promedio, %.1f %% de la mezcla de cada unidad. %.1f %% ser\u00eda una mezcla uniforme con k = %d. El prior alpha y la longitud de los textos tambi\u00e9n condicionan la concentraci\u00f3n.",100*v[4],100/fit$params$k,fit$params$k),
      sprintf("El tema de menor prevalencia re\u00fane %.2f %% de la mezcla media. Un tema peque\u00f1o puede ser espec\u00edfico, redundante o poco definido; el porcentaje por s\u00ed solo no permite decidir.",v[5]),
      if(is.na(d$convergence$converged))"Hay menos de seis estados \u00fatiles; la traza no permite evaluar deriva." else sprintf("La media de log-verosimilitud cambia %.2f %% entre mitades. El criterio de deriva inferior al 1 %% es una comprobaci\u00f3n heur\u00edstica; una sola cadena no demuestra convergencia.",100*d$convergence$relative_change)),
    Siguiente_paso=c("Lee documentos representativos de los temas de mayor y menor coherencia; comprueba que las palabras sostienen una etiqueta defendible.",
      "Compara otros k y semillas conservando la preparaci\u00f3n; acompa\u00f1a UMass con NPMI y lectura humana.",
      "Revisa palabras compartidas y solapamiento de documentos; evita elegir k solo para aumentar diversidad.",
      "Consulta las mezclas y contrasta alpha antes de interpretar cada documento como perteneciente a un \u00fanico tema.",
      "Lee sus documentos y comprueba si reaparece con otras semillas y valores cercanos de k.",
      "Contrasta iteraciones y semillas; documenta estabilidad, deriva y la regla de elegir el estado de mayor verosimilitud."),stringsAsFactors=FALSE)
}

# Huella de contenido del corpus analitico: conteos, nombres de unidades y terminos, y la
# correspondencia unidad -> documento. Dos corpus con las mismas dimensiones pero distintos
# terminos, conteos o documentos tienen huellas distintas; se usa para decidir si un
# diagnostico guardado sigue describiendo el corpus vigente.
corpus_fingerprint <- function(corpus) {
  m <- corpus$counts
  if (is.null(m)) return("sin-matriz")
  trip <- methods::as(m, "TsparseMatrix")
  o <- order(trip@i, trip@j)
  doc <- corpus$units$doc_id[match(rownames(m), corpus$units$unit_id)]
  obj <- list(dim = dim(m), rows = rownames(m), cols = colnames(m), i = trip@i[o], j = trip@j[o], x = as.numeric(trip@x[o]), doc = doc)
  f <- tempfile(fileext = ".rds"); on.exit(unlink(f), add = TRUE)
  saveRDS(obj, f, version = 2, compress = FALSE)
  unname(tools::md5sum(f))
}

# Matriz documento x termino a partir de la matriz de unidades (frases o documentos).
# La coherencia se calcula sobre documentos completos: la co-ocurrencia declarada es documental.
document_term_counts <- function(counts, units) {
  if (is.null(units) || is.null(rownames(counts))) return(counts)
  doc <- units$doc_id[match(rownames(counts), units$unit_id)]
  if (anyNA(doc) || !anyDuplicated(doc)) return(counts)
  f <- factor(doc, levels = unique(doc))
  agg <- Matrix::sparseMatrix(i = as.integer(f), j = seq_along(f), x = 1, dims = c(nlevels(f), length(f)),
    dimnames = list(levels(f), NULL))
  out <- agg %*% counts
  out
}

dtm_from_counts <- function(counts, rows = NULL) {
  m <- if (is.null(rows)) counts else counts[rows, , drop = FALSE]
  sm <- methods::as(m, "TsparseMatrix")
  slam::simple_triplet_matrix(sm@i + 1L, sm@j + 1L, as.integer(sm@x), nrow = nrow(m), ncol = ncol(m), dimnames = dimnames(m))
}

#' Comparar soluciones LDA con distinto numero de temas
#'
#' Ajusta modelos LDA (Gibbs) para un rango de numeros de temas y varias semillas
#' y resume, para cada k, indicadores complementarios: coherencia tematica,
#' diversidad de palabras principales, estabilidad entre semillas y perplejidad
#' sobre documentos reservados. La coherencia se calcula con co-ocurrencia
#' documental. No existe un k universalmente optimo: la funcion
#' devuelve los criterios por separado, senala los conflictos entre ellos y un
#' valor de compromiso (maximin) solo como punto de partida.
#'
#' @param corpus Resultado de [prepare_corpus()].
#' @param k_range Enteros entre 2 y 12.
#' @param seeds Semillas de las repeticiones (al menos una; recomendadas tres).
#' @param iterations Iteraciones de Gibbs por ajuste (100-2000).
#' @param alpha Prior de mezcla por documento: `NULL` usa `1/k` en cada ajuste; un numero constante; o una funcion de `k`.
#' @param delta Prior de palabras por tema.
#' @param holdout Fraccion de documentos reservada para la perplejidad (0 la desactiva). Se reserva por documento: todas las frases de un documento reservado quedan fuera del entrenamiento. Solo se activa con 20 o mas documentos.
#' @param top_n Palabras principales por tema usadas en coherencia, diversidad y estabilidad.
#' @param progress Funcion opcional `function(i, total)` para informar del avance.
#'
#' @return Lista con `table` (resumen por k), `runs` (un ajuste por fila),
#'   `recommendation` (mejor k por criterio, compromiso y avisos) y `params`.
#' @references
#' Mimno, D. et al. (2011). Optimizing semantic coherence in topic models. EMNLP.
#' Greene, D., O'Callaghan, D., Cunningham, P. (2014). How many topics? Stability
#' analysis for topic models. ECML PKDD.
#' Chang, J. et al. (2009). Reading tea leaves: how humans interpret topic models. NIPS.
#' @examples
#' \donttest{
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' cp <- prepare_corpus(p)
#' if (requireNamespace("topicmodels", quietly = TRUE)) {
#'   sel <- lda_select_k(cp, k_range = 2:4, seeds = c(1, 2), iterations = 200)
#'   sel$recommendation$summary
#' }
#' }
#' @export
lda_select_k <- function(corpus, k_range = 2:8, seeds = c(2026L, 2027L, 2028L), iterations = 500L,
                         alpha = NULL, delta = 0.1, holdout = 0.1, top_n = 10L, progress = NULL) {
  if (!requireNamespace("topicmodels", quietly = TRUE) || !requireNamespace("slam", quietly = TRUE))
    abort_user("La seleccion de k necesita los paquetes topicmodels y slam. Instalalos con install.packages(c(\"topicmodels\", \"slam\")).")
  m <- corpus$counts
  if (is.null(m) || nrow(m) < 6 || ncol(m) < 6) abort_user("La seleccion de k necesita al menos seis unidades con palabras y seis terminos.")
  k_range <- sort(unique(as.integer(k_range)))
  if (!length(k_range) || any(is.na(k_range)) || any(k_range < 2L | k_range > 12L)) abort_user("El rango de temas debe estar entre 2 y 12.")
  if (max(k_range) >= min(dim(m))) abort_user("El numero maximo de temas debe ser menor que el numero de unidades y de terminos.")
  seeds <- unique(as.integer(seeds))
  if (!length(seeds) || any(is.na(seeds)) || any(seeds < 1L)) abort_user("Indica al menos una semilla entera positiva.")
  if (length(k_range) * length(seeds) > 60L) abort_user("Se piden demasiados ajustes (maximo 60). Reduce el rango de temas o las semillas.")
  check_number(iterations, "Las iteraciones", 100, 2000)
  check_number(holdout, "La fraccion reservada", 0, 0.5, FALSE)
  check_number(top_n, "Las palabras principales", 5, 20)
  model_resource_check(m, "LDA")
  n <- nrow(m)
  # La reserva se hace por documento: todas las unidades (frases) de un documento reservado
  # quedan fuera del entrenamiento, de modo que la perplejidad se mide en documentos nuevos.
  unit_doc <- if (is.null(corpus$units)) rownames(m) else corpus$units$doc_id[match(rownames(m), corpus$units$unit_id)]
  if (is.null(unit_doc) || anyNA(unit_doc)) unit_doc <- rownames(m)
  doc_ids <- unique(unit_doc)
  n_docs <- length(doc_ids)
  n_test_docs <- if (holdout > 0 && n_docs >= 20) max(2L, round(holdout * n_docs)) else 0L
  test_docs <- if (n_test_docs > 0) doc_ids[with_seed(min(seeds), sort(sample.int(n_docs, n_test_docs)))] else character()
  test <- which(unit_doc %in% test_docs)
  n_test <- length(test)
  train <- setdiff(seq_len(n), test)
  if (n_test > 0 && length(train) < 6L) abort_user("La reserva deja menos de seis unidades de entrenamiento. Reduce la fraccion reservada.")
  m_docs <- document_term_counts(m, corpus$units)
  dtm_train <- dtm_from_counts(m, train)
  dtm_test <- if (n_test > 0) dtm_from_counts(m, test) else NULL
  total <- length(k_range) * length(seeds); done <- 0L
  runs <- list(); tops <- list()
  for (k in k_range) for (s in seeds) {
    a <- if (is.null(alpha)) 1 / k else if (is.function(alpha)) alpha(k) else alpha
    t0 <- proc.time()[[3]]
    gf <- fit_lda_gibbs(dtm_train, k, s, burnin = 100L, iter = as.integer(iterations), thin = 10L, alpha = a, delta = delta)
    fit <- gf$fit
    post <- topicmodels::posterior(fit)
    beta <- post$terms
    coh <- topic_coherence(beta, m_docs, top_n)
    perp <- if (!is.null(dtm_test)) tryCatch(with_seed(s, as.numeric(topicmodels::perplexity(fit, newdata = dtm_test,
      control = list(seed = s, burnin = 100L, iter = as.integer(iterations), thin = 10L, alpha = a, delta = delta)))), error = function(e) NA_real_) else NA_real_
    conv <- loglik_convergence(gf$loglik)
    runs[[length(runs) + 1L]] <- data.frame(k = k, semilla = s, alpha = a, perplejidad = perp,
      coherencia_npmi = mean(coh$npmi), coherencia_umass = mean(coh$umass), diversidad = topic_diversity(beta, top_n),
      tema_minimo_pct = 100 * min(colMeans(post$topics)), cambio_loglik = conv$relative_change,
      segundos = proc.time()[[3]] - t0, stringsAsFactors = FALSE)
    tops[[paste(k, s)]] <- lapply(seq_len(k), function(t) colnames(beta)[order(beta[t, ], decreasing = TRUE)[seq_len(top_n)]])
    done <- done + 1L
    if (is.function(progress)) progress(done, total)
  }
  runs <- do.call(rbind, runs)
  # Estabilidad: emparejamiento optimo de temas entre semillas por Jaccard de palabras principales.
  stability <- vapply(k_range, function(k) {
    if (length(seeds) < 2L) return(NA_real_)
    pairs <- utils::combn(seeds, 2L, simplify = FALSE)
    mean(vapply(pairs, function(pr) {
      A <- tops[[paste(k, pr[1])]]; B <- tops[[paste(k, pr[2])]]
      S <- outer(seq_along(A), seq_along(B), Vectorize(function(i, j) jaccard(A[[i]], B[[j]])))
      asg <- assign_max(S)
      mean(S[cbind(seq_along(asg), asg)])
    }, 0))
  }, 0)
  summ <- do.call(rbind, lapply(seq_along(k_range), function(i) {
    r <- runs[runs$k == k_range[i], , drop = FALSE]
    sdv <- function(x) if (sum(is.finite(x)) > 1) stats::sd(x, na.rm = TRUE) else NA_real_
    data.frame(k = k_range[i], perplejidad = mean(r$perplejidad), perplejidad_de = sdv(r$perplejidad),
      coherencia_npmi = mean(r$coherencia_npmi), coherencia_npmi_de = sdv(r$coherencia_npmi),
      coherencia_umass = mean(r$coherencia_umass), diversidad = mean(r$diversidad),
      estabilidad = stability[i], tema_minimo_pct = mean(r$tema_minimo_pct), stringsAsFactors = FALSE)
  }))
  rownames(summ) <- NULL
  rec <- lda_k_recommendation(summ)
  list(table = summ, runs = runs, recommendation = rec,
    params = list(k_range = k_range, seeds = seeds, iterations = as.integer(iterations), alpha = if (is.null(alpha)) "1/k" else if (is.function(alpha)) paste(deparse(body(alpha)), collapse = " ") else alpha,
      delta = delta, holdout_units = n_test, holdout_documents = length(test_docs), holdout_doc_ids = test_docs,
      holdout_fraction = holdout, holdout_unit = "documento", coherence_unit = "documento",
      units = n, documents = n_docs, terms = ncol(m), top_n = as.integer(top_n)),
    ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}

# Resume por criterio, detecta conflictos y propone un compromiso maximin.
lda_k_recommendation <- function(summ) {
  best <- function(col, decreasing = TRUE) {
    x <- summ[[col]]
    if (!any(is.finite(x))) return(NA_integer_)
    summ$k[if (decreasing) which.max(x) else which.min(x)]
  }
  criteria <- data.frame(
    criterio = c("Coherencia NPMI", "Coherencia UMass", "Diversidad de palabras", "Estabilidad entre semillas", "Perplejidad reservada (menor es mejor)"),
    columna = c("coherencia_npmi", "coherencia_umass", "diversidad", "estabilidad", "perplejidad"),
    k_mejor = c(best("coherencia_npmi"), best("coherencia_umass"), best("diversidad"), best("estabilidad"), best("perplejidad", FALSE)),
    stringsAsFactors = FALSE)
  criteria$valor <- vapply(seq_len(nrow(criteria)), function(i) {
    if (is.na(criteria$k_mejor[i])) NA_real_ else summ[[criteria$columna[i]]][summ$k == criteria$k_mejor[i]]
  }, 0)
  scale01 <- function(x) {
    if (!any(is.finite(x))) return(rep(NA_real_, length(x)))
    r <- range(x, na.rm = TRUE)
    if (r[2] - r[1] < 1e-12) rep(1, length(x)) else (x - r[1]) / (r[2] - r[1])
  }
  comp <- cbind(scale01(summ$coherencia_npmi), scale01(summ$estabilidad), scale01(summ$diversidad))
  comp <- comp[, colSums(is.finite(comp)) > 0, drop = FALSE]
  score <- if (ncol(comp)) apply(comp, 1, function(r) min(r, na.rm = TRUE)) else rep(NA_real_, nrow(summ))
  summ_score <- data.frame(k = summ$k, puntuacion_compromiso = score)
  compromise <- if (any(is.finite(score))) summ$k[which.max(score)] else NA_integer_
  used <- criteria$k_mejor[criteria$columna %in% c("coherencia_npmi", "estabilidad", "diversidad")]
  spread <- if (any(!is.na(used))) diff(range(used, na.rm = TRUE)) else NA
  conflict <- isTRUE(spread >= 2)
  text <- paste0(
    if (!is.na(compromise)) paste0("Valor de compromiso (maximin sobre coherencia NPMI, estabilidad y diversidad): k = ", compromise, ". ") else "",
    if (conflict) "Los criterios apuntan a valores de k distintos: no hay un k dominante; decide leyendo los temas de las soluciones candidatas. " else "Los criterios principales coinciden de forma aproximada, pero confirma el resultado leyendo los temas. ",
    "La perplejidad se muestra a titulo informativo: suele mejorar al aumentar k y no equivale a interpretabilidad (Chang et al., 2009).")
  summary <- criteria[c("criterio", "k_mejor", "valor")]
  list(summary = summary, scores = summ_score, compromise = compromise, conflict = conflict, text = text)
}

# ---- Estabilidad y sensibilidad de UMAP + HDBSCAN ---------------------------
#' Evaluar la estabilidad de UMAP + HDBSCAN
#'
#' Repite el flujo con otras semillas (estabilidad) y con vecinos y `minPts`
#' alrededor de los valores elegidos (sensibilidad), y compara cada agrupacion
#' con la de referencia mediante el indice de Rand ajustado (ARI). Tambien
#' resume, por grupo de referencia, su persistencia (Jaccard maximo) en las
#' repeticiones. Un solo mapa no demuestra que los grupos sean reproducibles.
#'
#' @param corpus,prepared Resultados de [prepare_corpus()] y [prepare_documents()].
#' @param params Parametros de [run_density()] (ver `density_defaults()` interno).
#' @param seeds Semillas adicionales; por defecto `semilla + 1:4`.
#' @param neighbors,min_pts Valores alternativos; por defecto la mitad, el valor y el doble.
#' @param vectors,embedding_model Vectores importados, si la representacion es `"vectors"`.
#' @param progress Funcion opcional `function(i, total)`.
#'
#' @return Lista con `reference`, `runs`, `summary`, `cluster_stability` y `params`.
#' @references
#' Hubert, L., Arabie, P. (1985). Comparing partitions. Journal of Classification.
#' Hennig, C. (2007). Cluster-wise assessment of cluster stability. CSDA.
#' @examples
#' \donttest{
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' cp <- prepare_corpus(p)
#' if (all(vapply(c("uwot", "dbscan", "irlba"), requireNamespace, logical(1), quietly = TRUE))) {
#'   s <- density_sensitivity(cp, p, list(neighbors = 5L, min_pts = 3L), seeds = 1:2,
#'                            neighbors = 5L, min_pts = 3L)
#'   s$summary
#' }
#' }
#' @export
density_sensitivity <- function(corpus, prepared, params = list(), seeds = NULL, neighbors = NULL, min_pts = NULL,
                                vectors = NULL, embedding_model = "", progress = NULL) {
  p <- utils::modifyList(density_defaults(), params)
  if (is.null(seeds)) seeds <- derive_seed(p$seed, 1:4)
  seeds <- unique(as.integer(seeds)); seeds <- seeds[seeds != as.integer(p$seed)]
  base_nb <- as.integer(p$neighbors); base_mp <- as.integer(p$min_pts)
  if (is.null(neighbors)) neighbors <- unique(pmax(2L, c(round(base_nb / 2), base_nb, base_nb * 2L)))
  if (is.null(min_pts)) min_pts <- unique(pmax(2L, c(round(base_mp / 2), base_mp, base_mp * 2L)))
  neighbors <- sort(unique(as.integer(neighbors))); min_pts <- sort(unique(as.integer(min_pts)))
  total <- 1L + length(seeds) + length(neighbors) * length(min_pts) - 1L
  done <- 0L
  tick <- function() { done <<- done + 1L; if (is.function(progress)) progress(done, total) }
  ref <- run_density(corpus, prepared, p, vectors, embedding_model, display = FALSE); tick()
  ref_label <- ref$assignments$grupo
  one <- function(tipo, s, nb, mp) {
    q <- p; q$seed <- s; q$neighbors <- nb; q$min_pts <- mp
    cause <- NULL
    out <- tryCatch(run_density(corpus, prepared, q, vectors, embedding_model, display = FALSE), error = function(e) { cause <<- conditionMessage(e); NULL })
    tick()
    if (is.null(out) || !identical(out$assignments$doc_id, ref$assignments$doc_id))
      return(list(row = data.frame(tipo = tipo, semilla = s, vecinos = nb, min_pts = mp, grupos = NA_integer_, sin_asignar_pct = NA_real_,
        ari = NA_real_, ari_asignados = NA_real_, estado = "fallida",
        causa = cause %||% "Los documentos de la repetici\u00f3n no coinciden con los de la referencia.", stringsAsFactors = FALSE), labels = NULL))
    lab <- out$assignments$grupo
    both <- lab > 0 & ref_label > 0
    list(row = data.frame(tipo = tipo, semilla = s, vecinos = nb, min_pts = mp, grupos = sum(unique(lab) > 0),
      sin_asignar_pct = 100 * mean(lab == 0), ari = adjusted_rand(ref_label, lab),
      ari_asignados = if (sum(both) > 1L) adjusted_rand(ref_label[both], lab[both]) else NA_real_, estado = "ejecutada", causa = "", stringsAsFactors = FALSE), labels = lab)
  }
  rows <- list(data.frame(tipo = "Referencia", semilla = as.integer(p$seed), vecinos = base_nb, min_pts = base_mp,
    grupos = sum(unique(ref_label) > 0), sin_asignar_pct = 100 * mean(ref_label == 0), ari = 1, ari_asignados = 1, estado = "ejecutada", causa = "", stringsAsFactors = FALSE))
  seed_labels <- list()
  for (s in seeds) { r <- one("Semilla", s, base_nb, base_mp); rows[[length(rows) + 1L]] <- r$row; if (!is.null(r$labels)) seed_labels[[length(seed_labels) + 1L]] <- r$labels }
  for (nb in neighbors) for (mp in min_pts) {
    if (nb == base_nb && mp == base_mp) next
    r <- one("Parametros", as.integer(p$seed), nb, mp); rows[[length(rows) + 1L]] <- r$row
  }
  runs <- do.call(rbind, rows); rownames(runs) <- NULL
  # Persistencia por grupo de referencia (Jaccard maximo con cualquier grupo de otra semilla).
  groups <- sort(unique(ref_label[ref_label > 0]))
  cluster_stability <- if (length(groups) && length(seed_labels)) do.call(rbind, lapply(groups, function(g) {
    members <- which(ref_label == g)
    j <- vapply(seed_labels, function(lab) {
      cand <- unique(lab[members]); cand <- cand[cand > 0]
      if (!length(cand)) return(0)
      max(vapply(cand, function(c2) jaccard(members, which(lab == c2)), 0))
    }, 0)
    data.frame(grupo = g, documentos = length(members), jaccard_medio = mean(j), jaccard_minimo = min(j), stringsAsFactors = FALSE)
  })) else data.frame(grupo = integer(), documentos = integer(), jaccard_medio = numeric(), jaccard_minimo = numeric())
  sd_runs <- runs[runs$tipo == "Semilla", , drop = FALSE]; pm_runs <- runs[runs$tipo == "Parametros", , drop = FALSE]
  med <- function(x) if (any(is.finite(x))) stats::median(x, na.rm = TRUE) else NA_real_
  mn <- function(x) if (any(is.finite(x))) min(x, na.rm = TRUE) else NA_real_
  band <- function(x) {
    if (!is.finite(x)) return("sin datos")
    if (x >= 0.90) "excelente (>= 0,90)" else if (x >= 0.80) "buena (>= 0,80)" else if (x >= 0.65) "moderada (>= 0,65)" else "baja (< 0,65)"
  }
  summary <- data.frame(
    indicador = c("Repeticiones con otra semilla", "ARI mediano entre semillas", "ARI minimo entre semillas",
      "Repeticiones con otros vecinos / minPts", "ARI mediano al variar parametros", "ARI minimo al variar parametros",
      "Grupos en la referencia", "Documentos sin asignar en la referencia (%)", "Rango de grupos entre repeticiones",
      "Grupos con Jaccard medio >= 0,6", "Repeticiones fallidas"),
    valor = c(nrow(sd_runs), med(sd_runs$ari), mn(sd_runs$ari), nrow(pm_runs), med(pm_runs$ari), mn(pm_runs$ari),
      sum(unique(ref_label) > 0), 100 * mean(ref_label == 0),
      if (any(is.finite(runs$grupos))) diff(range(runs$grupos, na.rm = TRUE)) else NA_real_,
      if (nrow(cluster_stability)) sum(cluster_stability$jaccard_medio >= 0.6) else NA_real_,
      sum(runs$estado == "fallida")),
    stringsAsFactors = FALSE)
  reading <- paste0("Estabilidad entre semillas: ", band(med(sd_runs$ari)), ". Sensibilidad a parametros: ", band(med(pm_runs$ari)),
    ". Las bandas son una convencion orientativa (Steinley, 2004) y no un contraste. ",
    "Si la estabilidad es baja, trata los grupos como una exploracion y apoyate solo en los que persisten (tabla de persistencia).",
    if (any(runs$estado == "fallida")) sprintf(" Atencion: %d de %d repeticiones fallaron y no entran en los resumenes; consulta la causa en la tabla de repeticiones.", sum(runs$estado == "fallida"), nrow(runs)) else "")
  list(reference = ref, runs = runs, summary = summary, cluster_stability = cluster_stability, reading = reading,
    params = list(base = p, seeds = seeds, neighbors = neighbors, min_pts = min_pts),
    ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}

# ---- Incertidumbre de la divergencia de Jensen-Shannon ----------------------
# JSD en bits entre las filas de dos matrices de frecuencias. No oculta entradas improcedentes:
# valores no finitos, negativos o dimensiones distintas son un error. Una fila sin masa en P o en Q
# no define una distribucion y devuelve NA (nunca 0, que significaria igualdad exacta).
jsd_rows <- function(P, Q) {
  P <- as.matrix(P); Q <- as.matrix(Q)
  if (!is.numeric(P) || !is.numeric(Q) || !identical(dim(P), dim(Q)) || anyNA(P) || anyNA(Q) ||
      any(!is.finite(P)) || any(!is.finite(Q)) || any(P < 0) || any(Q < 0))
    abort_user("La JSD necesita matrices num\u00e9ricas finitas, no negativas y de igual dimensi\u00f3n.")
  sp <- rowSums(P); sq <- rowSums(Q)
  valid <- sp > 0 & sq > 0
  P <- P / ifelse(valid, sp, 1); Q <- Q / ifelse(valid, sq, 1)
  M <- (P + Q) / 2
  part <- function(X) { r <- matrix(0, nrow(X), ncol(X)); ix <- which(X > 0); r[ix] <- X[ix] * log2(X[ix] / M[ix]); r }
  out <- 0.5 * rowSums(part(P)) + 0.5 * rowSums(part(Q))
  out[!valid] <- NA_real_
  pmin(1, pmax(0, out))
}

# Convierte una seleccion de documentos (logica o de indices) en indices validos y unicos.
jsd_index <- function(x, n, label) {
  if (is.logical(x)) {
    if (length(x) != n || anyNA(x)) abort_user(sprintf("La selecci\u00f3n del grupo %s debe ser un vector l\u00f3gico sin ausentes y con un valor por documento (%d).", label, n))
    return(which(x))
  }
  if (!is.numeric(x) || anyNA(x) || any(!is.finite(x)) || any(x != floor(x))) abort_user(sprintf("El grupo %s debe indicarse con \u00edndices enteros de documento o un vector l\u00f3gico.", label))
  x <- as.integer(x)
  if (any(x < 1L | x > n)) abort_user(sprintf("El grupo %s contiene \u00edndices fuera del rango de documentos (1 a %d).", label, n))
  if (anyDuplicated(x)) abort_user(sprintf("El grupo %s repite documentos: cada documento debe aparecer una sola vez.", label))
  x
}

#' Incertidumbre de la JSD entre dos grupos de documentos
#'
#' La JSD calculada con conteos finitos es un estimador sesgado al alza: dos
#' muestras del mismo corpus ya presentan una JSD positiva que crece cuando hay
#' pocos documentos o tokens. Esta funcion compara la JSD observada con una
#' distribucion nula por permutacion de las etiquetas de grupo entre documentos,
#' y estima un intervalo por remuestreo de documentos (bootstrap percentil).
#'
#' @param weighted Matriz documento x termino (conteos o pesos por documento).
#' @param in_a,in_b Indices logicos o enteros de los documentos de A y de B.
#' @param B Numero de permutaciones y remuestreos.
#' @param seed Semilla.
#' @param conf Nivel del intervalo (0.5-0.99).
#'
#' @details Los pesos deben ser finitos y no negativos; los indices de cada grupo
#'   (o los vectores logicos, con un valor por documento) deben ser unicos y estar
#'   dentro del rango. Si un grupo no reune masa lexica, la JSD no esta definida y
#'   se produce un error. Las replicas sin masa en algun grupo se excluyen y se
#'   informan en `valid_null` y `valid_boot`.
#' @return Lista con `observed`, `null_mean`, `null_p95`, `excess` (observada menos
#'   media nula), `p_value` (permutacion, con correccion +1), `ci` (bootstrap),
#'   `valid_null`, `valid_boot` y tamanos.
#' @references
#' Lin, J. (1991). Divergence measures based on the Shannon entropy. IEEE Trans. Inf. Theory.
#' Gallagher, R. et al. (2021). Generalized word shift graphs. EPJ Data Science.
#' @examples
#' set.seed(1)
#' W <- matrix(rpois(60 * 8, 2), 60, 8, dimnames = list(NULL, letters[1:8]))
#' jsd_uncertainty(W, 1:30, 31:60, B = 100, seed = 1)$p_value
#' @export
jsd_uncertainty <- function(weighted, in_a, in_b, B = 500L, seed = 2026L, conf = 0.95) {
  check_number(B, "Las permutaciones", 50, 5000)
  check_number(conf, "El nivel de confianza", 0.5, 0.99, FALSE)
  W <- weighted
  if (!(is.matrix(W) || inherits(W, "Matrix")) || !(is.numeric(W) || inherits(W, "dMatrix") || inherits(W, "iMatrix")) || !nrow(W) || !ncol(W))
    abort_user("La incertidumbre JSD necesita una matriz num\u00e9rica documento x t\u00e9rmino no vac\u00eda.")
  values <- if (inherits(W, "sparseMatrix")) as.numeric(methods::as(methods::as(W, "generalMatrix"), "CsparseMatrix")@x) else as.numeric(as.matrix(W))
  if (anyNA(values) || any(!is.finite(values)) || any(values < 0)) abort_user("La matriz de pesos debe contener valores finitos y no negativos.")
  ia <- jsd_index(in_a, nrow(W), "A"); ib <- jsd_index(in_b, nrow(W), "B")
  if (length(ia) < 2L || length(ib) < 2L) abort_user("Cada grupo necesita al menos dos documentos para estimar la incertidumbre.")
  if (length(intersect(ia, ib))) abort_user("Los grupos A y B deben ser disjuntos.")
  rowsum <- function(idx, w) as.numeric(Matrix::colSums(Matrix::Diagonal(x = w) %*% W[idx, , drop = FALSE]))
  obs_a <- as.numeric(Matrix::colSums(W[ia, , drop = FALSE])); obs_b <- as.numeric(Matrix::colSums(W[ib, , drop = FALSE]))
  if (sum(obs_a) <= 0 || sum(obs_b) <= 0) abort_user("Un grupo no tiene masa l\u00e9xica (ning\u00fan t\u00e9rmino retenido en sus documentos): la JSD no est\u00e1 definida.")
  observed <- jsd_rows(rbind(obs_a), rbind(obs_b))[[1]]
  pool <- c(ia, ib); na <- length(ia); n <- length(pool)
  Wp <- W[pool, , drop = FALSE]
  total <- as.numeric(Matrix::colSums(Wp))
  res <- with_seed(seed, {
    # Permutacion: asignar al azar na documentos del conjunto A U B al grupo A.
    S <- matrix(0, B, n)
    for (b in seq_len(B)) S[b, sample.int(n, na)] <- 1
    Aperm <- as.matrix(Matrix::Matrix(S, sparse = TRUE) %*% Wp)
    Bperm <- matrix(total, B, ncol(Wp), byrow = TRUE) - Aperm
    null <- jsd_rows(Aperm, pmax(Bperm, 0))
    # Bootstrap de documentos dentro de cada grupo.
    boot_counts <- function(idx) {
      M <- matrix(0, B, length(idx))
      for (b in seq_len(B)) M[b, ] <- tabulate(sample.int(length(idx), length(idx), replace = TRUE), length(idx))
      as.matrix(Matrix::Matrix(M, sparse = TRUE) %*% W[idx, , drop = FALSE])
    }
    boot <- jsd_rows(boot_counts(ia), boot_counts(ib))
    list(null = null, boot = boot)
  })
  alpha <- (1 - conf) / 2
  # Las replicas cuyo grupo no reune masa l\u00e9xica no definen una JSD y se excluyen (se informan).
  null <- res$null[is.finite(res$null)]; boot <- res$boot[is.finite(res$boot)]
  if (length(null) < B / 2 || length(boot) < B / 2) abort_user("La mayor\u00eda de las r\u00e9plicas dejan un grupo sin vocabulario retenido: la incertidumbre no es estimable con estos documentos.")
  list(observed = observed, null_mean = mean(null), null_p95 = as.numeric(stats::quantile(null, 0.95)),
    excess = observed - mean(null),
    p_value = (1 + sum(null >= observed - 1e-12)) / (length(null) + 1),
    ci = as.numeric(stats::quantile(boot, c(alpha, 1 - alpha))), conf = conf,
    B = as.integer(B), valid_null = length(null), valid_boot = length(boot), n_a = length(ia), n_b = length(ib), seed = seed,
    note = paste("Permutacion de documentos entre A y B (intercambiabilidad) y remuestreo de documentos.",
      "El intervalo bootstrap hereda el sesgo al alza del estimador; usa el exceso sobre la nula como referencia.",
      "Documentos de una misma revista o autor pueden no ser intercambiables: interpreta como descripcion, no como prueba causal."))
}

# ---- Linea base de ejes (permutacion) para ACP y correspondencias -----------
perm_pca_pct <- function(x, B, scale) {
  n <- nrow(x); p <- ncol(x); k <- min(n - 1L, p)
  out <- matrix(NA_real_, B, k)
  for (b in seq_len(B)) {
    xp <- x
    for (j in seq_len(p)) xp[, j] <- x[sample.int(n), j]
    xp <- scale(xp, center = TRUE, scale = scale)
    xp[!is.finite(xp)] <- 0
    d <- svd(xp, nu = 0, nv = 0)$d^2
    out[b, ] <- 100 * d[seq_len(k)] / sum(d)
  }
  out
}
perm_ca_pct <- function(m, B) {
  n <- nrow(m); p <- ncol(m)
  out <- matrix(NA_real_, B, min(n, p) - 1L)
  for (b in seq_len(B)) {
    mp <- m
    for (j in seq_len(p)) mp[, j] <- m[sample.int(n), j]
    mp <- mp[rowSums(mp) > 0, , drop = FALSE]
    P <- mp / sum(mp); r <- rowSums(P); cc <- colSums(P)
    S <- (P - outer(r, cc)) / sqrt(outer(r, cc))
    d <- svd(S, nu = 0, nv = 0)$d^2
    k <- min(ncol(out), length(d))
    out[b, seq_len(k)] <- 100 * d[seq_len(k)] / sum(d)
  }
  out
}
baseline_table <- function(dimensions, null_pct, probs = 0.95, max_dim = 10L) {
  q <- apply(null_pct, 2, stats::quantile, probs = probs, na.rm = TRUE)
  k <- min(max_dim, nrow(dimensions), length(q))
  dimensions$umbral_azar_pct <- NA_real_; dimensions$supera_azar <- NA
  dimensions$umbral_azar_pct[seq_len(k)] <- q[seq_len(k)]
  dimensions$supera_azar[seq_len(k)] <- dimensions$porcentaje[seq_len(k)] > q[seq_len(k)]
  dimensions
}

# ---- Diagnostico de vocabulario ---------------------------------------------
GENERIC_ACADEMIC_TERMS <- c("study", "studies", "paper", "article", "results", "result", "research", "findings", "analysis",
  "based", "using", "use", "used", "approach", "purpose", "methodology", "method", "methods", "data", "effect", "effects",
  "implications", "literature", "review", "originality", "value", "design", "findings", "limitations",
  "estudio", "estudios", "articulo", "resultados", "investigacion", "analisis", "mediante", "metodo", "metodologia", "objetivo", "datos")

#' Diagnostico del vocabulario retenido
#'
#' Ayuda a decidir umbrales y palabras vacias propias del corpus: muestra como
#' cambia el vocabulario al variar la presencia minima, que terminos aparecen en
#' una gran parte de los documentos (candidatos a palabras vacias propias del
#' corpus, que decide el investigador) y que documentos quedan con muy pocas
#' palabras. No modifica el corpus.
#'
#' @param corpus Resultado de [prepare_corpus()].
#' @param prepared Resultado de [prepare_documents()].
#' @param generic_pct Porcentaje de documentos desde el cual un termino se
#'   marca como candidato generico.
#' @param min_terms Documentos con menos de este numero de terminos retenidos se cuentan como pobres.
#'
#' @details Cada fila de `sensitivity` repite la seleccion efectiva del corpus
#'   con otra presencia minima y los mismos criterios restantes (frecuencia,
#'   TF-IDF, entropia, presencia maxima, orden y maximo de terminos), por lo que
#'   la fila `actual` coincide con el vocabulario retenido. `terminos_solo_presencia`
#'   cuenta los terminos que cumplen unicamente la presencia minima.
#' @return Lista con `sensitivity`, `generic`, `coverage`, `suggestion` y `boilerplate`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' vocabulary_diagnostics(prepare_corpus(p), p)$sensitivity
#' @export
vocabulary_diagnostics <- function(corpus, prepared, generic_pct = 25, min_terms = 5L) {
  terms <- corpus$terms
  if (is.null(terms) || !nrow(terms)) abort_user("No hay vocabulario evaluado. Revisa la limpieza del texto.")
  n_docs <- nrow(prepared$documents)
  total_tokens <- sum(terms$frecuencia)
  grid <- sort(unique(c(1L, 2L, 3L, 5L, 10L, 20L, prepared$config$min_df)))
  grid <- grid[grid <= max(terms$documentos)]
  cfg <- prepared$config
  sens <- do.call(rbind, lapply(grid, function(md) {
    # Cada fila repite la seleccion real del corpus con otra presencia minima y los mismos
    # criterios restantes (frecuencia, TF-IDF, entropia, presencia maxima, orden y maximo de terminos).
    alt <- cfg; alt$min_df <- md
    kept <- terms$termino %in% vocabulary_selection(terms, alt, n_docs)$vocabulary
    only_presence <- terms$documentos >= md
    data.frame(presencia_minima = md, terminos = sum(kept), terminos_pct = 100 * mean(kept),
      tokens_conservados_pct = 100 * sum(terms$frecuencia[kept]) / total_tokens,
      terminos_solo_presencia = sum(only_presence), actual = md == cfg$min_df, stringsAsFactors = FALSE)
  }))
  hapax_pct <- 100 * mean(terms$documentos == 1)
  gen <- terms[terms$porcentaje_documentos >= generic_pct, c("termino", "documentos", "porcentaje_documentos", "frecuencia", "tfidf_medio", "incluido"), drop = FALSE]
  gen <- gen[order(-gen$porcentaje_documentos, gen$termino), , drop = FALSE]
  gen$tipo_academico_generico <- gen$termino %in% GENERIC_ACADEMIC_TERMS
  m <- corpus$counts
  per_doc <- if (!is.null(m) && nrow(m)) as.numeric(Matrix::rowSums(m > 0)) else numeric()
  coverage <- data.frame(
    indicador = c("Documentos preparados", "Unidades con vocabulario retenido", paste0("Unidades con menos de ", min_terms, " terminos retenidos"),
      "Terminos en un solo documento (% del vocabulario evaluado)", "Mediana de terminos distintos por unidad"),
    valor = c(n_docs, length(per_doc), sum(per_doc < min_terms), hapax_pct, if (length(per_doc)) stats::median(per_doc) else NA_real_),
    stringsAsFactors = FALSE)
  suggestion <- gen$termino[gen$tipo_academico_generico & gen$incluido]
  texts <- prepared$documents$text
  boiler <- sum(grepl("all rights reserved|todos los derechos reservados|copyright|\u00a9|\\(c\\) *(19|20)[0-9]{2}", texts, ignore.case = TRUE, perl = TRUE))
  list(sensitivity = sens, generic = gen, coverage = coverage, suggestion = suggestion,
    boilerplate = data.frame(indicador = "Documentos con aviso de derechos o copyright en el texto", valor = boiler, stringsAsFactors = FALSE),
    params = list(generic_pct = generic_pct, min_terms = min_terms))
}

# Elimina avisos finales de derechos de autor del texto que se tokeniza (el original se conserva).
strip_boilerplate <- function(x) {
  x <- as.character(x)
  # Aviso de copyright y editorial al final del resumen: "(c) 2023 Editorial Ltd. All rights reserved."
  pattern <- "(\\s|^)(\\(c\\)|\u00a9|copyright)\\s*(19|20)[0-9]{2}[^\\n]{0,160}$"
  x <- sub(pattern, "", x, ignore.case = TRUE, perl = TRUE)
  x <- gsub("\\s*all rights reserved[.]?\\s*$", "", x, ignore.case = TRUE, perl = TRUE)
  x <- gsub("\\s*todos los derechos reservados[.]?\\s*$", "", x, ignore.case = TRUE, perl = TRUE)
  x
}

# ---- Estabilidad de comunidades --------------------------------------------
community_stability <- function(graph, weights, method = "louvain", resolution = 1, B = 20L, seed = 2026L) {
  none <- function(status, reason) list(status = status, reason = reason, ari = NA_real_, modularity_range = c(NA_real_, NA_real_), B = 0L, seeds = integer())
  if (igraph::ecount(graph) == 0L) return(none("no_aplicable", "La red no tiene conexiones: no hay comunidades que repetir."))
  if (method != "louvain") return(none("no_aplicable", sprintf("La estabilidad entre semillas solo se eval\u00faa con Louvain; el m\u00e9todo %s no se repite.", method)))
  if (B < 2L) return(none("no_aplicable", "Se necesitan al menos dos repeticiones."))
  seeds <- derive_seed(seed, seq_len(B))
  out <- tryCatch({
    runs <- lapply(seeds, function(s) with_seed(s, igraph::cluster_louvain(graph, weights = weights, resolution = resolution)))
    mem <- lapply(runs, igraph::membership)
    mod <- vapply(runs, igraph::modularity, 0)
    pairs <- utils::combn(B, 2L)
    ari <- mean(vapply(seq_len(ncol(pairs)), function(i) adjusted_rand(mem[[pairs[1, i]]], mem[[pairs[2, i]]]), 0))
    list(status = "ejecutada", reason = "", ari = ari, modularity_range = range(mod), B = as.integer(B), seeds = seeds)
  }, error = function(e) none("fallida", conditionMessage(e)))
  out
}
