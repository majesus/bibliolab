# Dependencias opcionales, instalacion con consentimiento y modelos de idioma.

pendiente_falso <- function() {
  data.frame(paquete = "paqueteinexistentebibliolab", instalado = FALSE, habilita = "Una capacidad de prueba",
    funciones = "f()", instruccion = "install.packages('paqueteinexistentebibliolab')", stringsAsFactors = FALSE)
}

test_that("el catalogo de paquetes opcionales coincide con DESCRIPTION", {
  desc <- utils::packageDescription("bibliolab")
  declarado <- trimws(strsplit(gsub("\\s+", " ", desc[["Config/bibliolab/App-Suggests"]]), ",", fixed = TRUE)[[1]])
  expect_setequal(bibliolab:::dependency_catalog()$paquete, declarado)
  suggests <- trimws(sub("\\s*\\(.*$", "", strsplit(gsub("\\s+", " ", desc[["Suggests"]]), ",", fixed = TRUE)[[1]]))
  expect_true(all(declarado %in% suggests))
  expect_false("mclust" %in% suggests)
})

test_that("sin install = TRUE nunca se invoca el instalador", {
  testthat::local_mocked_bindings(biblio_check_dependencies = pendiente_falso, .package = "bibliolab")
  llamado <- FALSE
  expect_message(r <- bibliolab:::app_prepare_dependencies(installer = function(...) llamado <<- TRUE), "paqueteinexistentebibliolab")
  expect_false(llamado)
  expect_false(r)
})

test_that("la instalacion exige sesion interactiva o confirmacion explicita", {
  testthat::local_mocked_bindings(biblio_check_dependencies = pendiente_falso, .package = "bibliolab")
  llamado <- FALSE
  inst <- function(...) llamado <<- TRUE
  expect_error(bibliolab:::app_prepare_dependencies(install = TRUE, installer = inst), "interactiva")
  expect_false(llamado)
  expect_message(r <- bibliolab:::app_prepare_dependencies(install = TRUE, installer = inst, confirm = function(...) FALSE), "cancelada")
  expect_false(llamado); expect_false(r)
})

test_that("con confirmacion positiva se instala solo lo pendiente en la biblioteca de usuario", {
  testthat::local_mocked_bindings(biblio_check_dependencies = pendiente_falso, .package = "bibliolab")
  lib <- file.path(withr::local_tempdir(), "biblioteca")
  withr::local_envvar(R_LIBS_USER = lib)
  libs <- .libPaths(); withr::defer(.libPaths(libs))
  recibido <- NULL
  expect_message(r <- bibliolab:::app_prepare_dependencies(install = TRUE, confirm = function(...) TRUE,
    installer = function(pkgs, lib, ...) recibido <<- list(pkgs = pkgs, lib = lib)), "No se pudieron instalar")
  expect_equal(recibido$pkgs, "paqueteinexistentebibliolab")
  expect_equal(normalizePath(recibido$lib, winslash = "/"), normalizePath(lib, winslash = "/"))
  expect_false(r)
})

test_that("run_app valida max_upload_mb antes de comprobar o instalar dependencias", {
  testthat::local_mocked_bindings(app_prepare_dependencies = function(...) stop("no debe llegar aqui"), .package = "bibliolab")
  expect_error(run_app(max_upload_mb = 0), "entre 1 y 500")
  expect_error(run_app(max_upload_mb = NA_real_), "entre 1 y 500")
  expect_error(run_app(max_upload_mb = 501), "entre 1 y 500")
})

test_that("run_app solo propaga install_missing cuando es TRUE", {
  recibido <- "ninguno"
  testthat::local_mocked_bindings(
    app_prepare_dependencies = function(install = FALSE, ...) { recibido <<- install; stop("detenido tras comprobar") },
    .package = "bibliolab")
  expect_error(run_app(), "detenido tras comprobar")
  expect_false(recibido)
  expect_error(run_app(install_missing = TRUE), "detenido tras comprobar")
  expect_true(recibido)
})

modelo_falso <- function(dir, nombre = "spanish-gsd-ud-2.5-191206.udpipe", texto = "esto no es un modelo udpipe") {
  ruta <- file.path(dir, nombre); writeLines(texto, ruta); ruta
}

test_that("un modelo UDPipe danado no se considera utilizable", {
  skip_if_not_installed("udpipe")
  dir <- withr::local_tempdir()
  ruta <- modelo_falso(dir)
  expect_false(bibliolab:::model_usable(ruta))
  expect_false(bibliolab:::model_usable(file.path(dir, "no-existe.udpipe")))
  vacio <- file.path(dir, "vacio.udpipe"); file.create(vacio)
  expect_false(bibliolab:::model_usable(vacio))
})

test_that("una descarga fallida o danada no sustituye ni valida el modelo local", {
  skip_if_not_installed("udpipe")
  dir <- withr::local_tempdir()
  ruta <- modelo_falso(dir)
  original <- readLines(ruta)
  testthat::local_mocked_bindings(
    udpipe_download_model = function(...) data.frame(download_failed = TRUE, file_model = NA_character_, stringsAsFactors = FALSE),
    .package = "udpipe")
  expect_error(download_language_model("es", dir), "No se ha podido descargar")
  expect_equal(readLines(ruta), original)
  # Descarga "correcta" pero con un archivo que UDPipe no puede cargar.
  testthat::local_mocked_bindings(
    udpipe_download_model = function(language, model_dir, ...) {
      f <- file.path(model_dir, "spanish-gsd-ud-2.5-191206.udpipe"); writeLines("danado", f)
      data.frame(download_failed = FALSE, file_model = f, stringsAsFactors = FALSE)
    }, .package = "udpipe")
  expect_error(download_language_model("es", dir), "no se puede cargar")
  expect_equal(readLines(ruta), original)
  # Un archivo de otro idioma tampoco se instala.
  testthat::local_mocked_bindings(
    udpipe_download_model = function(language, model_dir, ...) {
      f <- file.path(model_dir, "english-ewt-ud-2.5-191206.udpipe"); writeLines("x", f)
      data.frame(download_failed = FALSE, file_model = f, stringsAsFactors = FALSE)
    }, .package = "udpipe")
  expect_error(download_language_model("es", dir), "no corresponde al idioma")
})

test_that("download_language_model valida el idioma y no reutiliza un modelo danado", {
  skip_if_not_installed("udpipe")
  expect_error(download_language_model("xx", withr::local_tempdir()), "seis idiomas")
  dir <- withr::local_tempdir()
  modelo_falso(dir)
  # El modelo danado no se devuelve como valido: se intenta una descarga (simulada como fallida).
  testthat::local_mocked_bindings(
    udpipe_download_model = function(...) stop("sin red"), .package = "udpipe")
  expect_error(download_language_model("es", dir), "No se ha podido descargar")
})

# Prueba con un modelo real: solo se ejecuta si BIBLIOLAB_TEST_MODEL apunta a un
# archivo .udpipe valido (no se descarga nada durante las pruebas).
test_that("un modelo real es utilizable y su version truncada no", {
  skip_if_not_installed("udpipe")
  real <- Sys.getenv("BIBLIOLAB_TEST_MODEL")
  skip_if(!nzchar(real) || !file.exists(real), "BIBLIOLAB_TEST_MODEL no definido")
  expect_true(bibliolab:::model_usable(real))
  truncado <- file.path(withr::local_tempdir(), basename(real))
  bytes <- readBin(real, "raw", n = file.size(real) %/% 2L)
  writeBin(bytes, truncado)
  expect_false(bibliolab:::model_usable(truncado))
  # Un modelo danado detiene la lematizacion con un mensaje claro en lugar de producir un corpus vacio.
  dir <- withr::local_tempdir()
  file.copy(truncado, file.path(dir, basename(real)))
  withr::local_options(bibliolab.model_dir = dir)
  raw <- practica_raw()
  cfg <- utils::modifyList(default_config(), list(lemmatize = TRUE))
  prep <- prepare_documents(raw, guess_columns(raw), cfg)
  expect_error(prepare_corpus(prep), "modelo|dañado|dañado|descarga", ignore.case = TRUE)
})
