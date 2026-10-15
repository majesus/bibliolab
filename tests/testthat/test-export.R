test_that("reproducibility_record guarda version, semillas y huella de los datos", {
  pr <- practica()
  rec <- reproducibility_record(pr$prepared, pr$corpus, input_md5 = "abc123")
  expect_equal(rec$software$bibliolab, as.character(utils::packageVersion("bibliolab")))
  expect_true(is.list(rec$entorno))
})

test_that("methods_report incluye las secciones y declara lo pendiente", {
  pr <- practica()
  rec <- reproducibility_record(pr$prepared, pr$corpus)
  md <- methods_report(pr$prepared, pr$corpus, pr$bibliography, record = rec)
  expect_type(md, "character")
  md <- paste(md, collapse = "\n")
  expect_match(md, "## 5\\. Validaci")
  expect_match(md, "Lectura de documentos y validaci")
  expect_match(md, "Pendiente")
  expect_match(md, "## 8\\. Informaci")
  expect_match(md, "\\[ \\] Base de datos")      # sin procedencia: casilla sin marcar
  html <- methods_report_html(md)
  expect_match(paste(html, collapse = ""), "<h2", fixed = TRUE)
})

test_that("safe_csv neutraliza formulas y escribe UTF-8 con separador punto y coma", {
  path <- withr::local_tempfile(fileext = ".csv")
  bibliolab:::safe_csv(data.frame(a = c("=1+1", "+cmd", "@x", "normal"), b = 1:4,
    stringsAsFactors = FALSE), path)
  lineas <- readLines(path, encoding = "UTF-8", warn = FALSE)
  expect_false(any(grepl("^\"?[=+@]", sub("^[^;]*;", "", lineas[-1]))))
  expect_false(any(grepl("(^|;)\"?=1\\+1", lineas)))
  expect_true(grepl(";", lineas[1], fixed = TRUE))
})

test_that("export_bundle crea la entrega minima y avisa de la privacidad", {
  skip_on_cran()
  pr <- practica()
  dir <- withr::local_tempdir()
  rec <- reproducibility_record(pr$prepared, pr$corpus)
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, record = rec)
  archivos <- list.files(dir)
  esperados <- c("parametros.json", "evidencia_ia.json", "informe.html", "registro_reproducibilidad.json",
    "reproducir_analisis.R", "reconstruir_graficos.R", "entrada_original.rds", "banco_prompts.md",
    "entorno_R.txt", "LEEME.txt", "documentos.csv", "terminos.csv", "indicadores.csv")
  expect_true(all(esperados %in% archivos), info = paste(setdiff(esperados, archivos), collapse = ", "))
  # Sin modelos vigentes no se crean sus tablas.
  expect_false(any(grepl("^(lda|ca|acp|jsd)_", archivos)))
  leeme <- paste(readLines(file.path(dir, "LEEME.txt"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(leeme, "privacidad")
  expect_match(leeme, "25 filas")
  # El JSON de parametros y el de evidencia son JSON valido.
  expect_silent(jsonlite::read_json(file.path(dir, "parametros.json")))
  ev <- jsonlite::read_json(file.path(dir, "evidencia_ia.json"))
  expect_true(isTRUE(ev$practica_sintetica) || is.null(ev$practica_sintetica) || is.logical(ev$practica_sintetica))
})
