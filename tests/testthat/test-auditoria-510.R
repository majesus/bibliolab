# Correspondencia entre explicacion y calculo (auditoria de ayudas, hallazgos P0). Cada prueba falla con el texto previo.

mapeo_510 <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
  col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
  language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)

test_that("H06/H07/H17: la explicacion del cuaderno describe top-k y TF-IDF segun el calculo", {
  txt <- paste(as.character(wiki_method_explainer()), collapse = " ")
  expect_false(grepl("solo mejora la lectura", txt, fixed = TRUE))
  expect_false(grepl("red fragmentada", txt, fixed = TRUE))
  expect_match(txt, "cambia la red que se analiza", fixed = TRUE)
  expect_match(txt, "más de k líneas", fixed = TRUE)
  expect_match(txt, "no cambiaría el orden", fixed = TRUE)
})

test_that("H08: la leyenda del grafo depende del filtro vigente", {
  sin_filtro <- wiki_graph_texts(list(params = list(alpha = NA_real_, top_k = NA_integer_, criterion = "df"), nodes = data.frame(a = 1:10)))
  expect_false(grepl("significativa", sin_filtro$legend, fixed = TRUE))
  expect_match(sin_filtro$legend, "sin prueba de significación", fixed = TRUE)
  con_filtro <- wiki_graph_texts(list(params = list(alpha = .05, top_k = 3L, criterion = "df"), nodes = data.frame(a = 1:10)))
  expect_match(con_filtro$legend, "esperable por azar", fixed = TRUE)
  expect_match(con_filtro$guide, "5 %", fixed = TRUE)
  expect_match(con_filtro$guide, "antes de calcular comunidades", fixed = TRUE)
})

test_that("H09: la fuerza de asociacion no se presenta como prueba frente al azar", {
  ui <- as.character(build_ui())
  expect_false(grepl("Fuerza de asociación · frente al azar", ui, fixed = TRUE))
  expect_match(ui, "normalizada por presencia", fixed = TRUE)
})

test_that("H13: el boton de k describe lo que hace", {
  f <- system.file("app", "server", "validation.R", package = "bibliolab")
  skip_if(!nzchar(f))
  txt <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  expect_false(grepl("volver a calcular LDA", txt, fixed = TRUE))
  expect_match(txt, "Usar este número de temas", fixed = TRUE)
  expect_match(txt, "Ahora pulsa Calcular LDA", fixed = TRUE)
})

test_that("H02: la ayuda declara que las variantes de TF-IDF no coinciden entre pantallas", {
  expect_match(paste(as.character(vocabulary_decision_text()), collapse = " "), "no coinciden entre pantallas", fixed = TRUE)
})

test_that("H03/H04/H12: el texto interpretativo sigue el indicador activo y el orden informa si importa", {
  skip_on_cran(); skip_if_not(all(vapply(c("DT", "plotly", "visNetwork"), requireNamespace, TRUE, quietly = TRUE)))
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_510)
    session$setInputs(prepare = 1)
    expect_null(rv$error)
    session$setInputs(token_rank_metric = "documentos", token_rank_status = "all")
    html <- output$guide_tokens$html
    expect_match(html, "Más presentes en documentos", fixed = TRUE)
    expect_false(grepl("mayores TF-IDF medios", html, fixed = TRUE))
    session$setInputs(token_rank_metric = "tfidf_median")
    expect_match(output$guide_tokens$html, "TF-IDF / mediana global", fixed = TRUE)
    expect_match(output$vocab_order_note$html, "no modifica el vocabulario incluido", fixed = TRUE)
    session$setInputs(max_terms = 20L, prepare = 2)
    expect_match(output$vocab_order_note$html, "dejó fuera", fixed = TRUE)
  })
})
