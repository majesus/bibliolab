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
