test_that("biblio_check_dependencies describe los paquetes opcionales", {
  d <- biblio_check_dependencies()
  expect_named(d, c("paquete", "instalado", "habilita", "instruccion"))
  expect_true(all(c("topicmodels", "uwot", "udpipe") %in% d$paquete))
  expect_type(d$instalado, "logical")
  expect_true(all(nzchar(d$instruccion[!d$instalado])))
})

test_that("model_directory respeta la opcion bibliolab.model_dir", {
  withr::local_options(bibliolab.model_dir = "/ruta/de/prueba")
  expect_equal(model_directory(), "/ruta/de/prueba")
})

test_that("los modulos de sesion se analizan sin errores de sintaxis", {
  carpeta <- system.file("app", "server", package = "bibliolab")
  skip_if(!nzchar(carpeta))
  archivos <- list.files(carpeta, pattern = "[.]R$", full.names = TRUE)
  expect_gte(length(archivos), 10L)
  for (f in archivos) expect_no_error(parse(f, encoding = "UTF-8"))
})

test_that("la interfaz se construye y la version coincide con DESCRIPTION", {
  expect_s3_class(bibliolab:::build_ui(), "shiny.tag.list")
  expect_equal(bibliolab:::BIBLIO_VERSION, as.character(utils::packageVersion("bibliolab")))
})

test_that("run_app valida max_upload_mb antes de abrir la aplicacion", {
  skip_on_cran()
  skip_if_not(all(vapply(c("DT", "plotly", "visNetwork"), requireNamespace, TRUE, quietly = TRUE)))
  expect_error(run_app(max_upload_mb = 0), "entre 1 y 500")
})

test_that("check_number valida rangos y enteros", {
  expect_error(bibliolab:::check_number(0, "El valor", 1, 10), "El valor")
  expect_error(bibliolab:::check_number(1.5, "El valor", 1, 10), "El valor")
  expect_silent(bibliolab:::check_number(5, "El valor", 1, 10))
})
