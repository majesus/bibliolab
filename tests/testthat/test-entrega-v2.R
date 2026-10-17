# Regresiones de la entrega: publicacion transaccional, entrega parcial,
# manifiesto verificable y ciclo completo de reproduccion.

entrega_basica <- function(dir, ...) {
  pr <- practica()
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, ...)
}

test_that("una carpeta de destino con archivos se rechaza sin modificarla", {
  dir <- withr::local_tempdir()
  writeLines("previo", file.path(dir, "anterior.txt"))
  expect_error(entrega_basica(dir), "ya contiene archivos")
  expect_equal(list.files(dir, all.files = TRUE, no.. = TRUE), "anterior.txt")
  expect_equal(readLines(file.path(dir, "anterior.txt")), "previo")
})

test_that("un fallo durante la exportacion no deja destino ni restos de preparacion", {
  padre <- withr::local_tempdir()
  destino <- file.path(padre, "entrega")
  testthat::local_mocked_bindings(report_html = function(...) stop("fallo simulado"), .package = "bibliolab")
  expect_error(entrega_basica(destino), "fallo simulado")
  expect_false(dir.exists(destino))
  expect_length(list.files(padre, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("la entrega completa se publica de una vez y su manifiesto es verificable", {
  skip_on_cran()
  padre <- withr::local_tempdir()
  destino <- file.path(padre, "entrega")
  entrega_basica(destino)
  expect_true(dir.exists(destino))
  expect_length(list.files(padre, all.files = TRUE, no.. = TRUE), 1L)
  v <- verify_bundle(destino)
  expect_true(all(v$estado == "correcto"))
  expect_true("parametros.json" %in% v$archivo)
  expect_false("manifiesto_archivos.csv" %in% v$archivo)
  man <- utils::read.csv(file.path(destino, "manifiesto_archivos.csv"), stringsAsFactors = FALSE, colClasses = "character")
  esperado <- unname(tools::md5sum(file.path(destino, man$archivo)))
  expect_identical(man$md5, esperado)
  # Alteraciones: modificado, ausente y no registrado.
  writeLines("alterado", file.path(destino, "LEEME.txt"))
  file.remove(file.path(destino, "indicadores.csv"))
  writeLines("nuevo", file.path(destino, "extra.txt"))
  v2 <- verify_bundle(destino)
  estado <- stats::setNames(v2$estado, v2$archivo)
  expect_equal(estado[["LEEME.txt"]], "modificado")
  expect_equal(estado[["indicadores.csv"]], "ausente")
  expect_equal(estado[["extra.txt"]], "no registrado")
  expect_error(verify_bundle(withr::local_tempdir()), "manifiesto")
})

test_that("sin entrada original la entrega se declara parcial y no incluye scripts engañosos", {
  skip_on_cran()
  dir <- file.path(withr::local_tempdir(), "parcial")
  pr <- practica()
  expect_warning(export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography), "Entrega parcial")
  archivos <- list.files(dir)
  expect_false("reproducir_analisis.R" %in% archivos)
  expect_false("entrada_original.rds" %in% archivos)
  leeme <- paste(readLines(file.path(dir, "LEEME.txt"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(leeme, "ENTREGA PARCIAL")
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_false(par$entrega$reproducible)
  expect_match(unlist(par$entrega$insumos_faltantes), "entrada_original")
})

test_that("una entrega solo con la seleccion de k conserva la evidencia de la decision", {
  skip_on_cran()
  skip_if_not_installed("topicmodels")
  pr <- practica()
  sel <- lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L)
  dir <- file.path(withr::local_tempdir(), "seleccion")
  entrega_basica(dir, lda_selection = sel)
  archivos <- list.files(dir)
  expect_true(all(c("lda_seleccion_k.csv", "lda_seleccion_k_ejecuciones.csv", "lda_seleccion_k_documentos_reservados.csv",
    "diagnosticos_decision.rds", "reproducir_diagnosticos.R") %in% archivos))
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_equal(unlist(par$seleccion_k$k_range), 2:3)
  ev <- jsonlite::read_json(file.path(dir, "evidencia_ia.json"))
  expect_false(is.null(ev$seleccion_k))
  guardado <- readRDS(file.path(dir, "diagnosticos_decision.rds"))
  expect_equal(guardado$lda_selection$table$perplejidad, sel$table$perplejidad)
  expect_no_error(parse(file.path(dir, "reproducir_diagnosticos.R")))
})

test_that("el script de reproduccion regenera el analisis en un proceso independiente", {
  skip_on_cran()
  skip_if_not_installed("topicmodels")
  pr <- practica()
  lda <- run_lda(pr$corpus, k = 3, iterations = 100L)
  dir <- file.path(withr::local_tempdir(), "ciclo")
  entrega_basica(dir, lda = lda)
  script <- readLines(file.path(dir, "reproducir_analisis.R"), encoding = "UTF-8", warn = FALSE)
  expect_true(any(grepl("stopifnot(nrow(preparado$documents)", script, fixed = TRUE)))
  expect_true(any(grepl("dim(corpus$counts)", script, fixed = TRUE)))
  expect_true(any(grepl(attr(pr$raw, "source_md5"), script, fixed = TRUE)))
  rscript <- file.path(R.home("bin"), "Rscript")
  salida <- withr::with_dir(dir, suppressWarnings(system2(rscript, "reproducir_analisis.R", stdout = TRUE, stderr = TRUE,
    env = paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep), " LANG=C.UTF-8"))))
  expect_null(attr(salida, "status"), info = paste(utils::tail(salida, 5), collapse = "\n"))
  reproducido <- readRDS(file.path(dir, "resultados_reproducidos.rds"))
  expect_equal(reproducido$lda$top, lda$top)
  expect_equal(reproducido$corpus$counts, pr$corpus$counts)
})
