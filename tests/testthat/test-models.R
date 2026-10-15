test_that("run_ca es reproducible y compara los ejes con el azar", {
  co <- practica()$corpus
  a <- run_ca(co, max_terms = 20, B = 10, seed = 1)
  b <- run_ca(co, max_terms = 20, B = 10, seed = 1)
  expect_equal(a$dimensions, b$dimensions)
  expect_true(all(c("eje", "inercia", "porcentaje", "umbral_azar_pct", "supera_azar") %in% names(a$dimensions)))
  expect_equal(sum(a$dimensions$porcentaje), 100, tolerance = 1e-6)
})

test_that("run_ca valida los parametros", {
  co <- practica()$corpus
  expect_error(run_ca(co, max_terms = 1))
  expect_error(run_ca(list(counts = NULL)), "al menos")
})

test_that("run_pca devuelve componentes con varianza explicada", {
  pr <- practica()
  r <- run_pca(pr$corpus, pr$prepared, max_terms = 30, B = 10, seed = 1)
  expect_true(is.data.frame(r$dimensions))
  expect_gt(nrow(r$dimensions), 1L)
  expect_lte(sum(r$dimensions$porcentaje), 100 + 1e-6)
})

test_that("run_lda genera mezclas de temas que suman uno y es reproducible", {
  skip_if_not_installed("topicmodels")
  skip_if_not_installed("slam")
  skip_on_cran()
  co <- practica()$corpus
  f1 <- run_lda(co, k = 3, seed = 1, iterations = 100, burnin = 20, thin = 5)
  f2 <- run_lda(co, k = 3, seed = 1, iterations = 100, burnin = 20, thin = 5)
  expect_equal(f1$params$k, 3)
  temas <- as.matrix(f1$gamma[grepl("^tema_", names(f1$gamma))])
  expect_equal(ncol(temas), 3L)
  expect_equal(unname(rowSums(temas)), rep(1, nrow(temas)), tolerance = 1e-6)
  expect_equal(f1$gamma, f2$gamma)
  # Los tres temas ficticios del corpus de practica se recuperan con claridad.
  expect_gt(mean(apply(temas, 1, max)), 0.6)
  expect_identical(f1$params$alpha, 1 / 3)     # prior por defecto: 1/k
})

test_that("lda_select_k resume criterios y una recomendacion", {
  skip_if_not_installed("topicmodels")
  skip_if_not_installed("slam")
  skip_on_cran()
  sel <- lda_select_k(practica()$corpus, k_range = 2:3, seeds = c(1, 2), iterations = 100)
  expect_true(all(c("k", "coherencia_npmi", "diversidad", "estabilidad") %in% names(sel$table)))
  expect_equal(sort(unique(sel$table$k)), 2:3)
  expect_true(is.character(sel$recommendation$text))
})

test_that("run_density agrupa documentos y deja los no asignados en el grupo 0", {
  skip_if_not_installed("uwot")
  skip_if_not_installed("dbscan")
  skip_if_not_installed("irlba")
  skip_on_cran()
  pr <- practica()
  p <- utils::modifyList(density_defaults(), list(lsa_dims = 5L, neighbors = 5L, min_pts = 3L, seed = 1L))
  r <- run_density(pr$corpus, pr$prepared, p, display = FALSE)
  expect_true(is.data.frame(r$assignments))
  expect_equal(nrow(r$assignments), nrow(pr$corpus$counts))
  expect_equal(r$params$min_pts, 3L)
})

test_that("vocabulary_diagnostics resume la sensibilidad a la presencia minima", {
  pr <- practica()
  v <- vocabulary_diagnostics(pr$corpus, pr$prepared)
  expect_true(is.data.frame(v$sensitivity))
  expect_gt(nrow(v$sensitivity), 0L)
})

test_that("with_seed restaura el generador aleatorio", {
  set.seed(10); antes <- runif(1); set.seed(10)
  bibliolab:::with_seed(99, runif(3))
  expect_equal(runif(1), antes)
})
