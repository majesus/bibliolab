# Comportamiento del servidor de la aplicacion con shiny::testServer: invalidacion de
# los diagnosticos al cambiar el corpus y propagacion de la huella de entrada.

mapeo_practica <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
  col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
  language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)

skip_si_falta_interfaz <- function() {
  skip_on_cran()
  skip_if_not(all(vapply(c("DT", "plotly", "visNetwork"), requireNamespace, TRUE, quietly = TRUE)))
}

test_that("preparar propaga la huella de entrada y reinicia los diagnosticos guardados", {
  skip_si_falta_interfaz()
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_practica)
    session$setInputs(prepare = 1)
    expect_null(rv$error)
    expect_false(is.null(rv$prepared))
    expect_identical(rv$prepared$input_md5, attr(raw, "source_md5"))
    rv$kselect <- list(marca = 1); rv$kselect_signature <- kselect_settings()
    rv$dsens <- list(marca = 1); rv$dsens_signature <- "firma"
    session$setInputs(prepare = 2)
    expect_null(rv$kselect); expect_null(rv$kselect_signature)
    expect_null(rv$dsens); expect_null(rv$dsens_signature)
  })
})

test_that("la seleccion de k deja de ser vigente si cambia el corpus con las mismas dimensiones", {
  skip_si_falta_interfaz()
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_practica)
    session$setInputs(prepare = 1)
    expect_false(is.null(rv$corpus))
    rv$kselect <- list(marca = 1); rv$kselect_signature <- kselect_settings()
    expect_false(is.null(kselect_current()))
    alterado <- rv$corpus
    alterado$counts@x[1] <- alterado$counts@x[1] + 1
    expect_identical(dim(alterado$counts), dim(rv$corpus$counts))
    rv$corpus <- alterado
    expect_null(kselect_current())
  })
})
