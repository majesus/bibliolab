# Vectores importados: lectura estricta, conservacion para reproducir y entrega parcial.

vectores_prueba <- function(pr, dims = 6L) {
  set.seed(3)
  ids <- pr$prepared$documents$doc_id
  v <- data.frame(doc_id = ids, matrix(stats::rnorm(length(ids) * dims), ncol = dims))
  f <- tempfile(fileext = ".csv"); utils::write.csv(v, f, row.names = FALSE)
  f
}

test_that("read_document_vectors valida alineacion, identificadores y valores", {
  pr <- practica()
  f <- vectores_prueba(pr)
  withr::defer(unlink(f))
  v <- read_document_vectors(f, pr$prepared)
  expect_equal(rownames(v$matrix), pr$prepared$documents$doc_id)
  expect_equal(v$dimensions, 6L)
  expect_equal(v$md5, unname(tools::md5sum(f)))
  # Falta un documento.
  d <- utils::read.csv(f, stringsAsFactors = FALSE)[-3, ]
  g <- tempfile(fileext = ".csv"); utils::write.csv(d, g, row.names = FALSE); withr::defer(unlink(g))
  expect_error(read_document_vectors(g, pr$prepared), "Faltan vectores")
  # Valor no numerico.
  d <- utils::read.csv(f, stringsAsFactors = FALSE); d$X1 <- as.character(d$X1); d$X1[2] <- "abc"
  h <- tempfile(fileext = ".csv"); utils::write.csv(d, h, row.names = FALSE); withr::defer(unlink(h))
  expect_error(read_document_vectors(h, pr$prepared), "no num")
  expect_error(read_document_vectors(tempfile(), pr$prepared), "no existe")
})

test_that("run_density conserva los vectores de entrada para reproducir la ejecucion", {
  skip_on_cran()
  skip_if_not_installed("uwot"); skip_if_not_installed("dbscan"); skip_if_not_installed("irlba")
  pr <- practica()
  f <- vectores_prueba(pr); withr::defer(unlink(f))
  vec <- read_document_vectors(f, pr$prepared)
  fit <- run_density(pr$corpus, pr$prepared, list(representation = "vectors", neighbors = 5L, min_pts = 3L),
    vectors = vec, embedding_model = "modelo-de-prueba", display = FALSE)
  expect_identical(fit$input_vectors, vec)
  lexical <- run_density(pr$corpus, pr$prepared, list(neighbors = 5L, min_pts = 3L), display = FALSE)
  expect_null(lexical$input_vectors)

  # La entrega incluye los vectores y el script de reproduccion los carga.
  dir <- file.path(withr::local_tempdir(), "vectores")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, density = fit)
  expect_true(file.exists(file.path(dir, "vectores_entrada.rds")))
  expect_identical(readRDS(file.path(dir, "vectores_entrada.rds")), vec)
  script <- paste(readLines(file.path(dir, "reproducir_analisis.R"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(script, "vectores_entrada.rds", fixed = TRUE)

  # Sin los vectores, la entrega se declara parcial y no ofrece un script que no pueda ejecutarse.
  incompleto <- fit; incompleto$input_vectors <- NULL
  dir2 <- file.path(withr::local_tempdir(), "sin-vectores")
  expect_warning(export_bundle(dir2, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, density = incompleto), "Entrega parcial")
  expect_false(file.exists(file.path(dir2, "reproducir_analisis.R")))
  expect_match(paste(readLines(file.path(dir2, "LEEME.txt"), encoding = "UTF-8", warn = FALSE), collapse = "\n"), "vectores_entrada")
})
