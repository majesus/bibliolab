# Comparaciones de distribuciones: Shannon, base 2, mezcla simetrica 1/2.
# Formulacion independiente en R; referencia: Gallagher et al. (2021), Shifterator.
#' Divergencia de Jensen-Shannon y aportacion de cada termino
#'
#' Calcula la JSD en bits (base 2, mezcla 50/50, rango 0-1) entre dos
#' distribuciones de frecuencias con vocabulario comun, y la descompone en la
#' aportacion no negativa de cada termino (Lin, 1991; Gallagher et al., 2021).
#' Es un estimador sin correccion: con pocos documentos o tokens es sesgado al
#' alza; usa [jsd_uncertainty()] o `run_comparison()` para una referencia nula.
#'
#' @param a,b Vectores numericos no negativos con nombres unicos.
#' @return Lista con `jsd`, `distancia` (raiz de la JSD) y `terms`.
#' @examples
#' jsd_shift(c(a = 5, b = 3, c = 2), c(a = 1, b = 3, c = 6))$jsd
#' @export
jsd_shift <- function(a, b) {
  valid <- function(x) is.numeric(x) && length(x) && !is.null(names(x)) &&
    !anyNA(names(x)) && !anyDuplicated(names(x)) && all(nzchar(names(x))) && all(is.finite(x) & x >= 0) && is.finite(sum(x)) && sum(x) > 0
  if (!valid(a) || !valid(b)) abort_user("JSD necesita dos distribuciones no vac\u00edas, con etiquetas \u00fanicas y valores finitos no negativos.")
  keys <- sort(union(names(a), names(b)))
  align <- function(x) { out <- setNames(rep(0, length(keys)), keys); out[names(x)] <- x; out }
  aa <- align(a); bb <- align(b); use <- aa + bb > 0
  aa <- aa[use]; bb <- bb[use]; keys <- keys[use]
  p <- aa / sum(aa); q <- bb / sum(bb); m <- (p + q) / 2
  part <- function(x) { v <- rep(0, length(x)); ix <- x > 0; v[ix] <- .5 * x[ix] * log2(x[ix] / m[ix]); v }
  contribution <- part(p) + part(q)
  # La convexidad garantiza no negatividad; corregir unicamente ruido numerico.
  if (any(contribution < -1e-12)) abort_user("La descomposici\u00f3n JSD produjo valores inconsistentes.")
  contribution <- pmax(0, contribution); total <- sum(contribution)
  if (total > 1 + 1e-12) abort_user("JSD fuera del intervalo esperado en base 2.")
  total <- min(1, total)
  direction <- ifelse(q > p, "Mayor en B", ifelse(p > q, "Mayor en A", "Igual"))
  pct <- if (total > 0) 100 * contribution / total else rep(0, length(p))
  d <- data.frame(termino = keys, valor_A = as.numeric(aa), valor_B = as.numeric(bb),
    proporcion_A = as.numeric(p), proporcion_B = as.numeric(q), cambio_pp = 100 * as.numeric(q-p),
    aporte_bits = as.numeric(contribution), aporte_pct = as.numeric(pct), direccion = direction,
    shift_pct = as.numeric(pct) * ifelse(direction == "Mayor en A", -1, ifelse(direction == "Mayor en B", 1, 0)))
  d <- d[order(-d$aporte_bits, d$termino), ]; rownames(d) <- NULL
  d$posicion <- seq_len(nrow(d)); d$aporte_acumulado_pct <- cumsum(d$aporte_pct)
  list(jsd = total, distancia = sqrt(total), terms = d)
}

#' Parametros por defecto de las comparaciones
#'
#' Valores iniciales de [run_comparison()]; se modifican con una lista parcial.
#'
#' @return Lista con `mode` (`"year"`, `"metadata"`, `"density"` o `"lda"`),
#'   `weighting` (`"tokens"` o `"documents"`), las etiquetas `label_A` y `label_B`,
#'   los periodos `year_A_min`, `year_A_max`, `year_B_min`, `year_B_max`, las
#'   categorias `category_A`, `category_B` y `category_column`, `max_groups` (2 a
#'   30 grupos en la matriz), `uncertainty` (si se estima la referencia nula y el
#'   intervalo), `B` (50 a 5000 permutaciones y remuestreos) y `seed`.
#' @examples
#' comparison_defaults()$B
#' @export
comparison_defaults <- function() list(mode = "year", weighting = "tokens", label_A = "A", label_B = "B",
  year_A_min = 2019, year_A_max = 2022, year_B_min = 2023, year_B_max = 2026,
  category_A = "", category_B = "", category_column = "", max_groups = 25L,
  uncertainty = TRUE, B = 500L, seed = 2026L)

#' Compara dos grupos de documentos por su vocabulario
#'
#' Compara periodos, categorias de metadatos, grupos de [run_density()] o temas
#' dominantes de [run_lda()] mediante JSD, con matriz entre categorias,
#' trayectoria por anios y, por defecto, referencia nula por permutacion e
#' intervalo bootstrap (ver [jsd_uncertainty()]).
#'
#' @param corpus,prepared Resultados de [prepare_corpus()] y [prepare_documents()].
#' @param params Lista parcial: `mode` (`"year"`, `"metadata"`, `"density"`,
#'   `"lda"`), `weighting` (`"tokens"` o `"documents"`), periodos o categorias,
#'   `uncertainty`, `B` y `seed`.
#' @param grouping `data.frame` con `doc_id` y `valor` para modos distintos de `"year"`.
#' @return Lista con `jsd`, `distancia`, `uncertainty`, `terms`, `matrix`,
#'   `coverage`, `temporal`, `audit`, `issues` y `params`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
#' yrs <- range(p$documents$year, na.rm = TRUE)
#' mid <- floor(mean(yrs))
#' fit <- run_comparison(cp, p, list(year_A_min = yrs[1], year_A_max = mid,
#'   year_B_min = mid + 1, year_B_max = yrs[2], B = 100))
#' fit$jsd
#' @export
run_comparison <- function(corpus, prepared, params = list(), grouping = NULL) {
  p <- utils::modifyList(comparison_defaults(), params)
  if (!p$mode %in% c("year", "metadata", "density", "lda") || !p$weighting %in% c("tokens", "documents")) abort_user("Tipo de comparaci\u00f3n o ponderaci\u00f3n no v\u00e1lido.")
  check_number(p$max_groups, "M\u00e1ximo de grupos para la matriz JSD", 2, 30)
  check_number(p$B, "Las permutaciones de JSD", 50, 5000); check_number(p$seed, "La semilla de JSD", 1, .Machine$integer.max)
  m <- document_counts(corpus, prepared); doc <- prepared$documents[match(rownames(m), prepared$documents$doc_id), ]
  if (p$mode == "year") {
    for (key in c("year_A_min", "year_A_max", "year_B_min", "year_B_max")) check_number(p[[key]], "A\u00f1os de comparaci\u00f3n", 1500, 2200)
    if (p$year_A_min > p$year_A_max || p$year_B_min > p$year_B_max) abort_user("El a\u00f1o inicial no puede superar el final de un per\u00edodo.")
    if (max(p$year_A_min, p$year_B_min) <= min(p$year_A_max, p$year_B_max)) abort_user("Los per\u00edodos A y B deben ser disjuntos. Ajusta sus a\u00f1os para evitar comparar documentos consigo mismos.")
    ia <- !is.na(doc$year) & doc$year >= p$year_A_min & doc$year <= p$year_A_max
    ib <- !is.na(doc$year) & doc$year >= p$year_B_min & doc$year <= p$year_B_max
    p$label_A <- paste("A /", p$year_A_min, "a", p$year_A_max); p$label_B <- paste("B /", p$year_B_min, "a", p$year_B_max)
    values <- ifelse(is.na(doc$year), "", as.character(doc$year))
  } else {
    if (is.null(grouping) || !all(c("doc_id", "valor") %in% names(grouping)) || anyDuplicated(grouping$doc_id)) abort_user("Faltan asignaciones \u00fanicas de documentos a grupos para comparar.")
    values <- clean_value(grouping$valor[match(doc$doc_id, grouping$doc_id)])
    if (!nzchar(p$category_A) || !nzchar(p$category_B) || p$category_A == p$category_B) abort_user("Elige dos categor\u00edas diferentes, A y B.")
    ia <- values == p$category_A; ib <- values == p$category_B
    p$label_A <- paste("A /", p$category_A); p$label_B <- paste("B /", p$category_B)
  }
  if (!any(ia) || !any(ib)) abort_user("Uno de los grupos no contiene documentos con vocabulario retenido. Elige otras categor\u00edas/per\u00edodos o revisa los filtros.")
  # Vocabulario comun global: los ceros se conservan y no se anade pseudoconteo.
  totals <- Matrix::rowSums(m)
  weighted <- if (p$weighting == "documents") Matrix::Diagonal(x = 1/totals) %*% m else m
  colnames(weighted) <- colnames(m); rownames(weighted) <- rownames(m)
  aggregate_dist <- function(ix) setNames(as.numeric(Matrix::colSums(weighted[ix, , drop = FALSE])), colnames(m))
  fit <- jsd_shift(aggregate_dist(ia), aggregate_dist(ib))
  uncertainty <- NULL; uncertainty_status <- if (isTRUE(p$uncertainty)) "no_aplicable" else "no_solicitada"; uncertainty_cause <- ""
  if (isTRUE(p$uncertainty) && (sum(ia) < 2L || sum(ib) < 2L)) uncertainty_cause <- "Cada grupo necesita al menos dos documentos."
  if (isTRUE(p$uncertainty) && sum(ia) >= 2L && sum(ib) >= 2L) {
    uncertainty <- tryCatch(jsd_uncertainty(weighted, ia, ib, B = p$B, seed = p$seed), error = function(e) { uncertainty_cause <<- conditionMessage(e); NULL })
    uncertainty_status <- if (is.null(uncertainty)) "fallida" else "ejecutada"
  }
  sizes <- table(values[nzchar(values)])
  eligible <- if (p$mode == "year") names(sort(sizes)) else names(sizes)[order(-as.numeric(sizes), names(sizes))]
  if (p$mode == "year") eligible <- names(sizes)[order(as.numeric(names(sizes)))]
  selected <- head(eligible, p$max_groups)
  profiles <- lapply(selected, function(v) aggregate_dist(values == v)); names(profiles) <- selected
  mat <- matrix(0, length(selected), length(selected), dimnames = list(selected, selected))
  for (i in seq_along(selected)) if (i > 1L) for (j in seq_len(i-1L)) mat[i,j] <- mat[j,i] <- jsd_shift(profiles[[i]], profiles[[j]])$jsd
  pairs <- expand.grid(grupo_A = selected, grupo_B = selected, stringsAsFactors = FALSE); pairs$jsd_bits <- as.vector(mat); pairs$distancia <- sqrt(pairs$jsd_bits)
  coverage <- data.frame(codigo = sprintf("%02d",seq_along(selected)), grupo = selected, documentos = as.integer(sizes[selected]), tokens = vapply(selected, function(v) sum(totals[values == v]), 0))
  # Trayectoria entre anos observados: conservar saltos explicitos, sin inventar anos.
  time <- data.frame()
  if (p$mode == "year" && length(eligible) >= 2) {
    yearly <- lapply(eligible, function(v) aggregate_dist(values == v))
    time <- do.call(rbind, lapply(seq_len(length(eligible)-1L), function(i) {
      s <- jsd_shift(yearly[[i]], yearly[[i+1L]]); a <- as.numeric(eligible[i]); b <- as.numeric(eligible[i+1L])
      ya <- values == eligible[i]; yb <- values == eligible[i+1L]
      null_mean <- NA_real_; null_p <- NA_real_
      state <- if (!isTRUE(p$uncertainty)) "no solicitada" else "no aplicable: menos de dos documentos en un a\u00f1o"
      if (isTRUE(p$uncertainty) && sum(ya) >= 2L && sum(yb) >= 2L) {
        cause <- ""
        u <- tryCatch(jsd_uncertainty(weighted, ya, yb, B = min(p$B, 200L), seed = derive_seed(p$seed, i)), error = function(e) { cause <<- conditionMessage(e); NULL })
        if (!is.null(u)) { null_mean <- u$null_mean; null_p <- u$p_value; state <- "ejecutada" } else state <- paste0("fallida: ", cause)
      }
      data.frame(ano_A = a, ano_B = b, consecutivo = b-a == 1, documentos_A = as.integer(sizes[i]), documentos_B = as.integer(sizes[i+1L]), jsd_bits = s$jsd, distancia = s$distancia,
        jsd_nula_media = null_mean, exceso_sobre_nula = s$jsd - null_mean, p_permutacion = null_p, incertidumbre = state)
    }))
  }
  audit <- data.frame(indicador = c("Documentos preparados", "Con vocabulario retenido", "Documentos de A", "Documentos de B", "Tokens retenidos en A", "Tokens retenidos en B", "Documentos fuera de A y B", "Categor\u00edas observadas", "Categor\u00edas en matriz", "Sin categor\u00eda o a\u00f1o v\u00e1lido"),
    valor = c(nrow(prepared$documents), nrow(m), sum(ia), sum(ib), sum(totals[ia]), sum(totals[ib]), nrow(m)-sum(ia)-sum(ib), length(eligible), length(selected), sum(!nzchar(values))))
  issues <- c("JSD descriptiva: no implica causalidad, significaci\u00f3n estad\u00edstica ni equivalencia sem\u00e1ntica entre idiomas.",
    "Se usa vocabulario retenido com\u00fan y Shannon base 2, con mezcla 50/50; JSD en bits y distancia sqrt(JSD) son magnitudes distintas.",
    if (p$weighting == "tokens") "Tokens agrupados: documentos largos aportan m\u00e1s apariciones." else "Cada documento aporta una distribuci\u00f3n normalizada; todos los documentos con vocabulario tienen el mismo peso dentro de su grupo.",
    "La matriz compara categor\u00edas del corpus completo vigente; la comparaci\u00f3n principal usa solamente A y B.")
  if (sum(ia) < 5 || sum(ib) < 5) issues <- c(issues, "Hay menos de cinco documentos en al menos un grupo: interpreta con especial cautela la cobertura; no es un umbral de validez inferencial.")
  if (length(eligible) > length(selected)) issues <- c(issues, paste("Matriz limitada a", length(selected), "categor\u00edas. La trayectoria anual conserva todos los a\u00f1os observados; consulta cobertura."))
  if (fit$jsd < 1e-12) issues <- c(issues, "Las distribuciones son iguales o num\u00e9ricamente indistinguibles; no hay un cambio l\u00e9xico que atribuir a t\u00e9rminos.")
  if (!is.null(uncertainty)) {
    issues <- c(issues, sprintf("Referencia nula (permutaci\u00f3n de documentos entre A y B, B = %d): JSD esperada %.4f bits; exceso observado %.4f; p = %.3f. El intervalo bootstrap al %d%% es [%.4f, %.4f].",
      uncertainty$B, uncertainty$null_mean, uncertainty$excess, uncertainty$p_value, round(100 * uncertainty$conf), uncertainty$ci[1], uncertainty$ci[2]))
    if (uncertainty$p_value > 0.05) issues <- c(issues, "La JSD observada no supera claramente lo esperable al reasignar documentos entre A y B: la diferencia l\u00e9xica puede ser ruido de muestreo.")
  } else if (isTRUE(p$uncertainty)) issues <- c(issues, paste0("No se pudo estimar la incertidumbre (", uncertainty_status, "): ", uncertainty_cause))
  list(jsd = fit$jsd, distancia = fit$distancia, uncertainty = uncertainty, uncertainty_status = uncertainty_status, uncertainty_cause = uncertainty_cause, terms = fit$terms, matrix = pairs, coverage = coverage, temporal = time,
    audit = audit, issues = issues, params = p, grouping = grouping,
    documents = data.frame(doc_id = doc$doc_id, grupo = ifelse(ia, "A", ifelse(ib, "B", "Fuera de A/B"))),
    ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}

#' Analisis de componentes principales sobre perfiles TF-IDF
#'
#' @param corpus,prepared Resultados de [prepare_corpus()] y [prepare_documents()].
#' @param max_terms Terminos mas frecuentes incluidos (3-300).
#' @param standardize Si se estandarizan los terminos a varianza 1.
#' @param baseline,B,seed Linea base por permutacion de la varianza por
#'   componente (percentil 95), numero de permutaciones y semilla.
#' @return Lista con `documents`, `terms`, `dimensions`, `params` y `excluded`.
#' @references Jolliffe, I. T. (2002). Principal Component Analysis (2nd ed.). Springer.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
#' run_pca(cp, p, 30, B = 20)$dimensions[1:3, ]
#' @export
run_pca <- function(corpus, prepared, max_terms = 100L, standardize = FALSE, baseline = TRUE, B = 50L, seed = 2026L) {
  check_number(max_terms, "T\u00e9rminos m\u00e1ximos en ACP", 3, 300)
  if (!is.logical(standardize) || length(standardize) != 1 || is.na(standardize)) abort_user("La estandarizaci\u00f3n ACP debe ser S\u00ed o No.")
  m <- document_counts(corpus, prepared)
  if (nrow(m) < 3 || ncol(m) < 3) abort_user("ACP necesita al menos tres documentos con vocabulario y tres t\u00e9rminos retenidos.")
  cols <- head(order(-Matrix::colSums(m), colnames(m)), max_terms)
  model_resource_check(m[,cols,drop=FALSE], "ACP")
  # TF sobre todo el vocabulario retenido, IDF suavizado por documentos activos.
  x <- as.matrix(m[, cols, drop = FALSE]) / as.numeric(Matrix::rowSums(m))
  idf <- log((1+nrow(m))/(1+Matrix::colSums(m[, cols, drop = FALSE] > 0))) + 1
  x <- sweep(x, 2, idf, "*"); sd0 <- apply(x, 2, stats::sd); kept <- is.finite(sd0) & sd0 > 1e-12
  removed <- colnames(x)[!kept]; x <- x[, kept, drop = FALSE]
  if (ncol(x) < 3) abort_user("Menos de tres t\u00e9rminos tienen variaci\u00f3n \u00fatil para ACP. Ampl\u00eda el vocabulario o revisa el corpus.")
  fit <- stats::prcomp(x, center = TRUE, scale. = standardize)
  eigen <- fit$sdev^2
  if (length(eigen) < 2 || eigen[2] < 1e-12 * max(eigen)) abort_user("Los perfiles l\u00e9xicos solo permiten una componente interpretable; un plano ACP ser\u00eda enga\u00f1oso.")
  for (j in seq_len(ncol(fit$rotation))) if (fit$rotation[which.max(abs(fit$rotation[,j])),j] < 0) {
    fit$rotation[,j] <- -fit$rotation[,j]; fit$x[,j] <- -fit$x[,j]
  }
  z <- scale(x, center = fit$center, scale = if (standardize) fit$scale else FALSE)
  distance2 <- rowSums(z^2)
  contrib <- sweep(fit$x^2, 2, pmax((nrow(x)-1)*eigen,.Machine$double.eps), "/") * 100
  docs <- prepared$documents[match(rownames(m), prepared$documents$doc_id), ]
  scores <- data.frame(doc_id = docs$doc_id, title = docs$title, source = docs$source, year = docs$year,
    eje_1 = fit$x[,1], eje_2 = fit$x[,2], cos2_plano = pmin(1, rowSums(fit$x[,1:2,drop=FALSE]^2) / pmax(distance2, .Machine$double.eps)),
    contribucion_eje_1 = contrib[,1], contribucion_eje_2 = contrib[,2])
  correlation <- stats::cor(x, fit$x)
  variables <- data.frame(termino = colnames(x), eje_1 = correlation[,1], eje_2 = correlation[,2],
    carga_1 = fit$rotation[,1], carga_2 = fit$rotation[,2],
    contribucion_eje_1 = 100*fit$rotation[,1]^2, contribucion_eje_2 = 100*fit$rotation[,2]^2,
    cos2_plano = pmin(1, rowSums(correlation[,1:2,drop=FALSE]^2)))
  dimensions <- data.frame(eje = seq_along(eigen), varianza = eigen, porcentaje = 100*eigen/sum(eigen))
  base_info <- list(computed = FALSE)
  if (isTRUE(baseline)) {
    check_number(B, "Las permutaciones de la l\u00ednea base", 10, 1000)
    null_pct <- with_seed(seed, perm_pca_pct(x, as.integer(B), standardize))
    dimensions <- baseline_table(dimensions, null_pct)
    base_info <- list(computed = TRUE, B = as.integer(B), seed = seed, quantile = 0.95,
      description = "Permutaci\u00f3n independiente de cada t\u00e9rmino entre documentos; percentil 95 del porcentaje de varianza por componente.")
  }
  list(documents = scores, terms = variables, dimensions = dimensions,
    coordinates=list(documents=fit$x,terms=correlation,document_contributions=contrib,term_contributions=100*fit$rotation^2,loadings=fit$rotation,document_distance2=distance2),
    params = list(max_terms = max_terms, standardize = standardize, center = TRUE, baseline = base_info, representation = "TF-IDF: TF sobre vocabulario retenido; IDF log((1+N)/(1+df))+1"),
    excluded = data.frame(termino = removed, motivo = rep("Varianza nula o inferior a tolerancia 1e-12", length(removed))),
    center = fit$center, scale = if (standardize) fit$scale else NULL,
    ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}

# Lectura breve de las cifras de incertidumbre de la JSD (observada, esperada por permutacion, exceso, p e intervalo).
# Se genera siempre a partir de los valores calculados, para que la interpretacion no dependa de una frase fija.
jsd_uncertainty_reading <- function(jsd, u) {
  f <- function(x) format(round(x, 4), decimal.mark = ",", nsmall = 4, scientific = FALSE)
  p <- if (is.finite(u$p_value) && u$p_value < .001) "menor que 0,001" else format(round(u$p_value, 3), decimal.mark = ",", nsmall = 3)
  excess <- if (u$excess > 0) paste0("La JSD observada (", f(jsd), " bits) supera en ", f(u$excess), " la que producir\u00edan asignaciones al azar de los documentos entre A y B (", f(u$null_mean), "), de modo que la diferencia es mayor que la referencia de permutaci\u00f3n.")
    else paste0("La JSD observada (", f(jsd), " bits) no supera la que producir\u00edan asignaciones al azar de los documentos entre A y B (", f(u$null_mean), "): el exceso (", f(u$excess), ") es la resta entre ambas, no una JSD negativa, y no se observa una diferencia mayor que la referencia de permutaci\u00f3n. Eso no prueba que A y B sean conceptualmente equivalentes.")
  ci <- u$ci
  boot <- paste0("El intervalo bootstrap [", f(ci[1]), "; ", f(ci[2]), "] remuestrea documentos dentro de cada grupo y hereda el sesgo al alza de la JSD con pocos datos")
  boot <- paste0(boot, if (jsd < ci[1]) ": aqu\u00ed la JSD observada queda por debajo del intervalo, algo esperable con un estimador sesgado que no indica un error de c\u00e1lculo, y no debe leerse como intervalo de la diferencia verdadera. " else if (jsd > ci[2]) ": aqu\u00ed la JSD observada queda por encima del intervalo, lo que tampoco indica un error de c\u00e1lculo. " else ". ")
  paste0(excess, " El valor p (", p, ") es la proporci\u00f3n de permutaciones con una JSD al menos igual a la observada, ajustada como (1 + n\u00famero de nulas \u2265 observada) / (B + 1). ", boot,
    "Estas cifras no son cinco pruebas independientes de cambio tem\u00e1tico: la referencia, el exceso y el valor p proceden de las mismas permutaciones, y el intervalo, de otro remuestreo.")
}
