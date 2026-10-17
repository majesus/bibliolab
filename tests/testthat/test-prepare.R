test_that("prepare_documents audita cada etapa y detecta duplicados por DOI", {
  p <- practica()$prepared
  expect_equal(p$audit$documentos, c(25L, 25L, 25L, 24L, 24L))
  expect_equal(nrow(p$documents), 24L)
  expect_equal(nrow(p$duplicates), 1L)
  expect_equal(p$duplicates$criterio_duplicado, "DOI")
})

test_that("las citas ausentes se conservan como NA", {
  x <- practica()
  docs <- x$prepared$documents
  expect_equal(sum(is.na(docs$citations)), 3L)
  # Oraculo independiente: el valor original de "Cited by" convertido a numero.
  # Las celdas vacias son NA; los ceros declarados se conservan como cero.
  original <- suppressWarnings(as.numeric(x$raw[["Cited by"]]))
  esperado <- original[match(docs$source_row, seq_along(original))]
  expect_identical(is.na(docs$citations), is.na(esperado))
  expect_equal(docs$citations[!is.na(esperado)], esperado[!is.na(esperado)])
  expect_equal(sum(docs$citations == 0, na.rm = TRUE), sum(esperado == 0, na.rm = TRUE))
})

test_that("se puede conservar los duplicados si se desactiva la deduplicacion", {
  cfg <- utils::modifyList(default_config(), list(deduplicate = FALSE))
  p <- prepare_documents(practica()$raw, practica()$mapping, cfg)
  expect_equal(nrow(p$documents), 25L)
})

test_that("el filtro temporal descarta los documentos fuera del periodo", {
  p <- prepare_documents(practica()$raw, practica()$mapping,
    list(year_min = 2021L, year_max = 2022L))
  expect_true(all(p$documents$year %in% 2021:2022))
  expect_lt(nrow(p$documents), 24L)
})

test_that("un filtro que deja cero documentos produce un error claro", {
  expect_error(prepare_documents(practica()$raw, practica()$mapping,
    list(year_min = 1900L, year_max = 1901L)), "cero documentos")
})

test_that("la muestra aleatoria es reproducible con la misma semilla", {
  cfg <- list(sample_pct = 50, seed = 7L)
  a <- prepare_documents(practica()$raw, practica()$mapping, cfg)
  b <- prepare_documents(practica()$raw, practica()$mapping, cfg)
  expect_identical(a$documents$doc_id, b$documents$doc_id)
  expect_equal(nrow(a$documents), 12L)
})

test_that("prepare_documents valida la configuracion", {
  m <- practica()$mapping
  raw <- practica()$raw
  expect_error(prepare_documents(raw, list(text = "")), "columna de texto")
  expect_error(prepare_documents(raw, m, list(sample_pct = 0)))
  expect_error(prepare_documents(raw, m, list(metadata_sep = ",")), "punto y coma")
  expect_error(prepare_documents(raw, m, list(filter_col = "no_existe", filter_value = "x")), "no existe")
})

test_that("parse_numeric distingue ausentes de cero", {
  x <- bibliolab:::parse_numeric(c("0", "12", "", NA, "abc"))
  expect_equal(x[1:2], c(0, 12))
  expect_true(all(is.na(x[3:5])))
})

test_that("prepare_corpus devuelve una matriz de conteos con terminos retenidos", {
  co <- practica()$corpus
  expect_true(all(c("counts", "terms") %in% names(co)))
  expect_s4_class(co$counts, "Matrix")
  expect_gt(ncol(co$counts), 10L)
  expect_true(all(co$counts@x >= 1))
  expect_true(all(c("educación", "aprendizaje") %in% colnames(co$counts)) ||
    all(c("educacion", "aprendizaje") %in% colnames(co$counts)))
})
