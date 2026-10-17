# Regresiones de los diagnosticos metodologicos (holdout, huella, estados, JSD).

corpus_oraciones <- function() {
  raw <- practica_raw()
  cfg <- utils::modifyList(default_config(), list(split_sentences = TRUE))
  prep <- prepare_documents(raw, guess_columns(raw), cfg)
  list(prepared = prep, corpus = prepare_corpus(prep))
}

test_that("el holdout de lda_select_k reserva documentos completos", {
  skip_if_not_installed("topicmodels")
  x <- corpus_oraciones()
  sel <- lda_select_k(x$corpus, k_range = 2:3, seeds = c(1L, 2L), iterations = 100L)
  par <- sel$params
  ids <- par$holdout_doc_ids
  expect_true(all(ids %in% x$corpus$units$doc_id))
  # Oraculo: las unidades reservadas son exactamente las de los documentos reservados.
  expect_equal(par$holdout_units, sum(x$corpus$units$doc_id %in% ids))
  expect_equal(par$holdout_documents, length(ids))
  expect_equal(par$holdout_unit, "documento")
  expect_equal(par$coherence_unit, "documento")
  expect_equal(par$units, nrow(x$corpus$counts))
  expect_equal(par$documents, length(unique(x$corpus$units$doc_id)))
  expect_true(all(is.finite(sel$table$coherencia_npmi)))
})

test_that("lda_select_k es reproducible y no altera el generador global", {
  skip_if_not_installed("topicmodels")
  pr <- practica()
  set.seed(11); antes <- get(".Random.seed", globalenv())
  a <- lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L)
  expect_identical(get(".Random.seed", globalenv()), antes)
  b <- lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L)
  expect_equal(a$table$perplejidad, b$table$perplejidad)
  expect_equal(a$params$holdout_doc_ids, b$params$holdout_doc_ids)
})

test_that("corpus_fingerprint distingue corpus con las mismas dimensiones", {
  pr <- practica()
  f1 <- bibliolab:::corpus_fingerprint(pr$corpus)
  expect_identical(f1, bibliolab:::corpus_fingerprint(pr$corpus))
  alterado <- pr$corpus
  alterado$counts@x[1] <- alterado$counts@x[1] + 1
  expect_equal(dim(alterado$counts), dim(pr$corpus$counts))
  expect_false(identical(f1, bibliolab:::corpus_fingerprint(alterado)))
  # Misma matriz con otras etiquetas de termino: tambien cambia.
  renombrado <- pr$corpus
  colnames(renombrado$counts)[1] <- "zzz_otro"
  expect_false(identical(f1, bibliolab:::corpus_fingerprint(renombrado)))
})

test_that("la sensibilidad del vocabulario refleja el vocabulario realmente retenido", {
  raw <- practica_raw()
  cfg <- utils::modifyList(default_config(), list(max_terms = 20L))
  prep <- prepare_documents(raw, guess_columns(raw), cfg)
  corp <- prepare_corpus(prep)
  expect_lte(ncol(corp$counts), 20L)
  s <- vocabulary_diagnostics(corp, prep)$sensitivity
  actual <- s[s$actual, ]
  expect_equal(nrow(actual), 1L)
  expect_equal(actual$terminos, ncol(corp$counts))
  expect_true(all(c("presencia_minima", "terminos", "terminos_pct", "tokens_conservados_pct", "terminos_solo_presencia", "actual") %in% names(s)))
})

test_that("jsd_rows no confunde una fila sin masa con igualdad exacta", {
  P <- rbind(c(1, 0), c(0, 0), c(1, 1)); Q <- rbind(c(0, 1), c(0, 0), c(1, 1))
  j <- bibliolab:::jsd_rows(P, Q)
  expect_equal(j[1], 1)
  expect_true(is.na(j[2]))
  expect_equal(j[3], 0)
  expect_error(bibliolab:::jsd_rows(rbind(c(1, -1)), rbind(c(1, 1))))
  expect_error(bibliolab:::jsd_rows(rbind(c(1, NA)), rbind(c(1, 1))))
  expect_error(bibliolab:::jsd_rows(rbind(c(1, 1)), rbind(c(1, 1, 1))))
})

test_that("jsd_uncertainty rechaza entradas improcedentes", {
  W <- matrix(1, 6, 4)
  expect_error(jsd_uncertainty(W, 1:3, 4:9, B = 10, seed = 1))
  expect_error(jsd_uncertainty(W, 1:3, c(4, 4.5), B = 10, seed = 1))
  W2 <- W; W2[1, 1] <- NA
  expect_error(jsd_uncertainty(W2, 1:3, 4:6, B = 10, seed = 1))
  W3 <- W; W3[1:3, ] <- 0
  expect_error(jsd_uncertainty(W3, 1:3, 4:6, B = 10, seed = 1))
  ok <- jsd_uncertainty(matrix(stats::rpois(60 * 6, 3), 60, 6), 1:30, 31:60, B = 50, seed = 1)
  expect_true(all(c("observed", "null_mean", "p_value", "valid_null", "valid_boot") %in% names(ok)))
  expect_lte(ok$valid_null, 50)
})

test_that("community_stability distingue ejecutada, no aplicable y fallida", {
  skip_if_not_installed("igraph")
  g <- igraph::make_graph(~ A - B - C - A, D - E - F - D, C - D)
  w <- rep(1, igraph::ecount(g))
  ok <- bibliolab:::community_stability(g, w, "louvain", B = 5L, seed = 1L)
  expect_equal(ok$status, "ejecutada")
  expect_equal(ok$B, 5L)
  expect_true(ok$ari >= 0 && ok$ari <= 1)
  expect_equal(bibliolab:::community_stability(g, w, "walktrap", B = 5L)$status, "no_aplicable")
  expect_equal(bibliolab:::community_stability(g, w, "louvain", B = 1L)$status, "no_aplicable")
  vacio <- igraph::make_empty_graph(3)
  expect_equal(bibliolab:::community_stability(vacio, numeric(), "louvain", B = 5L)$status, "no_aplicable")
  # Fallo interno: se registra con su causa y no se propaga.
  testthat::local_mocked_bindings(cluster_louvain = function(...) stop("fallo simulado"), .package = "igraph")
  fallo <- bibliolab:::community_stability(g, w, "louvain", B = 3L)
  expect_equal(fallo$status, "fallida")
  expect_match(fallo$reason, "fallo simulado")
})

test_that("la semilla maxima entera no desborda en la estabilidad de comunidades", {
  skip_if_not_installed("igraph")
  g <- igraph::make_graph(~ A - B - C - A, D - E - F - D, C - D)
  r <- bibliolab:::community_stability(g, rep(1, igraph::ecount(g)), "louvain", B = 4L, seed = .Machine$integer.max)
  expect_equal(r$status, "ejecutada")
  expect_false(anyNA(r$seeds))
})

test_that("density_sensitivity registra las repeticiones fallidas con su causa", {
  skip_if_not_installed("uwot"); skip_if_not_installed("dbscan"); skip_if_not_installed("irlba")
  skip_on_cran()
  pr <- practica()
  llamadas <- 0L
  real <- bibliolab:::run_density
  testthat::local_mocked_bindings(run_density = function(...) {
    llamadas <<- llamadas + 1L
    if (llamadas > 1L) stop("fallo simulado de densidad")
    real(...)
  }, .package = "bibliolab")
  s <- density_sensitivity(pr$corpus, pr$prepared, params = list(), seeds = c(1L, 2L), neighbors = 5L, min_pts = 3L)
  expect_true(all(c("estado", "causa") %in% names(s$runs)))
  expect_equal(s$runs$estado[1], "ejecutada")
  expect_true(all(s$runs$estado[-1] == "fallida"))
  expect_match(s$runs$causa[2], "fallo simulado")
  expect_true(all(is.na(s$runs$ari[-1])))
  expect_match(s$reading, "fallaron")
  expect_equal(s$summary$valor[s$summary$indicador == "Repeticiones fallidas"], nrow(s$runs) - 1L)
})

test_that("jsd_uncertainty exige indices unicos, enteros y de longitud correcta", {
  W <- matrix(stats::rpois(60, 3), 10, 6)
  expect_error(jsd_uncertainty(W, c(1, 1, 2), 6:10, B = 50, seed = 1), "repite")
  expect_error(jsd_uncertainty(W, 1:5, c(5, 6:10), B = 50, seed = 1), "")
  expect_error(jsd_uncertainty(W, c(TRUE, FALSE), 6:10, B = 50, seed = 1), "lógico")
  expect_error(jsd_uncertainty(W, rep(c(TRUE, FALSE), 5), c(NA, rep(TRUE, 9)), B = 50, seed = 1))
  ok <- jsd_uncertainty(W, rep(c(TRUE, FALSE), 5), !rep(c(TRUE, FALSE), 5), B = 50, seed = 1)
  expect_true(ok$ci[1] >= 0 && ok$ci[2] <= 1)
  # Un peso negativo ya no produce un intervalo fuera de [0, 1].
  Wn <- W; Wn[1, 1] <- -2
  expect_error(jsd_uncertainty(Wn, 1:5, 6:10, B = 50, seed = 1))
})
