# Datos ficticios del paquete (inst/extdata/practica.csv): 25 registros, uno de
# ellos duplicado por DOI, tres con cita ausente.
practica_path <- function() {
  path <- system.file("extdata", "practica.csv", package = "bibliolab")
  if (!nzchar(path)) testthat::skip("No se encuentra inst/extdata/practica.csv")
  path
}

practica_raw <- function() read_biblio_csv(practica_path(), ";")

# Se calcula una vez por sesion de tests (el corpus es determinista).
.practica_cache <- new.env(parent = emptyenv())
practica <- function() {
  if (is.null(.practica_cache$value)) {
    raw <- practica_raw()
    mapping <- guess_columns(raw)
    prepared <- prepare_documents(raw, mapping)
    corpus <- prepare_corpus(prepared)
    .practica_cache$value <- list(raw = raw, mapping = mapping, prepared = prepared,
      corpus = corpus, bibliography = biblio_summary(prepared))
  }
  .practica_cache$value
}

write_csv_text <- function(text, ...) {
  path <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  writeLines(text, path, useBytes = TRUE, ...)
  path
}

# Ejecuta un guion con Rscript en un proceso limpio. Las variables de entorno se pasan con
# withr::with_envvar(): el argumento `env` de system2() antepone texto al comando en Windows y
# hace fallar la invocacion. Se omite (no se da por buena) si bibliolab no esta instalado en las
# bibliotecas visibles, por ejemplo al ejecutar con pkgload::load_all().
ejecutar_rscript <- function(script, dir) {
  ruta <- find.package("bibliolab", lib.loc = .libPaths(), quiet = TRUE)
  instalado <- length(ruta) == 1L && nzchar(ruta) && file.exists(file.path(ruta, "Meta", "package.rds"))
  if (!instalado) testthat::skip("bibliolab no esta instalado: el proceso independiente no puede cargarlo")
  rscript <- file.path(R.home("bin"), "Rscript")
  withr::with_envvar(c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep), LANG = "C.UTF-8"),
    withr::with_dir(dir, suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))))
}
