# Estados de validacion en comparaciones y redes, y palabras vacias por documento.

periodos <- function(pr) {
  yrs <- range(pr$prepared$documents$year, na.rm = TRUE); mid <- floor(mean(yrs))
  list(year_A_min = yrs[1], year_A_max = mid, year_B_min = mid + 1, year_B_max = yrs[2], B = 50L)
}

test_that("run_comparison registra la incertidumbre como ejecutada", {
  pr <- practica()
  f <- run_comparison(pr$corpus, pr$prepared, periodos(pr))
  expect_equal(f$uncertainty_status, "ejecutada")
  expect_equal(f$uncertainty_cause, "")
  expect_false(is.null(f$uncertainty))
  g <- run_comparison(pr$corpus, pr$prepared, c(periodos(pr), list(uncertainty = FALSE)))
  expect_equal(g$uncertainty_status, "no_solicitada")
  expect_null(g$uncertainty)
})

test_that("un fallo en la incertidumbre se registra con su causa y no se oculta", {
  pr <- practica()
  testthat::local_mocked_bindings(jsd_uncertainty = function(...) stop("fallo simulado de JSD"), .package = "bibliolab")
  f <- run_comparison(pr$corpus, pr$prepared, periodos(pr))
  expect_equal(f$uncertainty_status, "fallida")
  expect_match(f$uncertainty_cause, "fallo simulado de JSD")
  expect_null(f$uncertainty)
  expect_true(any(grepl("fallo simulado de JSD", f$issues)))
  expect_true(is.finite(f$jsd))
})

test_that("el informe metodologico distingue ejecutada, fallida y no aplicable", {
  pr <- practica()
  rec <- reproducibility_record(pr$prepared, pr$corpus)
  ok <- run_comparison(pr$corpus, pr$prepared, periodos(pr))
  informe <- function(cmp) paste(methods_report(pr$prepared, pr$corpus, pr$bibliography, comparison = cmp, record = rec), collapse = "\n")
  expect_match(informe(ok), "Ejecutada")
  testthat::local_mocked_bindings(jsd_uncertainty = function(...) stop("fallo simulado"), .package = "bibliolab")
  malo <- run_comparison(pr$corpus, pr$prepared, periodos(pr))
  expect_match(informe(malo), "Fallida")
})

test_that("run_network registra la estabilidad de comunidades con un estado explicito", {
  skip_if_not_installed("igraph")
  pr <- practica()
  r <- run_network(pr$corpus, pr$prepared, list(type = "words", max_nodes = 20L, seed = .Machine$integer.max))
  expect_true(is.list(r$stability))
  expect_true(r$stability$status %in% c("ejecutada", "no_aplicable", "fallida"))
  expect_false(identical(r$stability$status, "fallida"))
  expect_true(all(c("status", "reason", "ari", "B", "seeds") %in% names(r$stability)))
})

test_that("las palabras vacias por documento respetan el idioma de cada registro", {
  raw <- data.frame(ID = 1:4, Title = paste("t", 1:4),
    Abstract = c("The model and the data show the results for the study of learning",
      "Los estudiantes y los profesores para el aprendizaje de los datos y la evaluacion",
      "The learning data and the methods for the analysis of results",
      "Las plataformas para los alumnos y los resultados de la evaluacion continua"),
    Year = 2020:2023, Source = "J", Authors = "A", `Cited by` = 1:4, `Author Keywords` = "k",
    DOI = c("a", "b", "c", "d"), Language = c("en", "es", "en", "es"), check.names = FALSE, stringsAsFactors = FALSE)
  cfg <- utils::modifyList(default_config(), list(language = "by_document", min_df = 1L))
  terminos <- colnames(prepare_corpus(prepare_documents(raw, guess_columns(raw), cfg))$counts)
  expect_false(any(c("the", "and", "for", "los", "las", "para", "y") %in% terminos))
  expect_true(all(c("data", "learning", "aprendizaje", "alumnos") %in% terminos))
  # Un documento sin idioma reconocido aborta en lugar de aplicar una lista arbitraria.
  raw$Language[2] <- "xx"
  expect_error(prepare_corpus(prepare_documents(raw, guess_columns(raw), cfg)), "idioma reconocido")
})

test_that("las funciones publicas de valores por defecto y vectores estan exportadas", {
  exportadas <- getNamespaceExports("bibliolab")
  expect_true(all(c("density_defaults", "read_document_vectors", "network_defaults", "comparison_defaults") %in% exportadas))
})
