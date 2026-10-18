# Correspondencia entre explicacion y calculo (auditoria de ayudas, hallazgos P0). Cada prueba falla con el texto previo.

mapeo_510 <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
  col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
  language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)

test_that("H06/H07/H17: la explicacion del cuaderno describe top-k y TF-IDF segun el calculo", {
  txt <- paste(as.character(wiki_method_explainer()), collapse = " ")
  expect_false(grepl("solo mejora la lectura", txt, fixed = TRUE))
  expect_false(grepl("red fragmentada", txt, fixed = TRUE))
  expect_match(txt, "cambia la red que se analiza", fixed = TRUE)
  expect_match(txt, "m\u00e1s de k l\u00edneas", fixed = TRUE)
  expect_match(txt, "no cambiar\u00eda el orden", fixed = TRUE)
})

test_that("H08: la leyenda del grafo depende del filtro vigente", {
  sin_filtro <- wiki_graph_texts(list(params = list(alpha = NA_real_, top_k = NA_integer_, criterion = "df"), nodes = data.frame(a = 1:10)))
  expect_false(grepl("significativa", sin_filtro$legend, fixed = TRUE))
  expect_match(sin_filtro$legend, "sin prueba de significaci\u00f3n", fixed = TRUE)
  con_filtro <- wiki_graph_texts(list(params = list(alpha = .05, top_k = 3L, criterion = "df"), nodes = data.frame(a = 1:10)))
  expect_match(con_filtro$legend, "esperable por azar", fixed = TRUE)
  expect_match(con_filtro$guide, "5 %", fixed = TRUE)
  expect_match(con_filtro$guide, "antes de calcular comunidades", fixed = TRUE)
})

test_that("H09: la fuerza de asociacion no se presenta como prueba frente al azar", {
  ui <- as.character(build_ui())
  expect_false(grepl("Fuerza de asociaci\u00f3n \u00b7 frente al azar", ui, fixed = TRUE))
  expect_match(ui, "normalizada por presencia", fixed = TRUE)
})

test_that("H13: el boton de k describe lo que hace", {
  f <- system.file("app", "server", "validation.R", package = "bibliolab")
  skip_if(!nzchar(f))
  txt <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  expect_false(grepl("volver a calcular LDA", txt, fixed = TRUE))
  expect_match(txt, "Usar este n\u00famero de temas", fixed = TRUE)
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
    expect_match(html, "Aparecen en m\u00e1s documentos", fixed = TRUE)
    expect_false(grepl("mayores TF-IDF medios", html, fixed = TRUE)); expect_match(html, "lenguaje gen\u00e9rico", fixed = TRUE)
    session$setInputs(token_rank_metric = "tfidf_median")
    expect_match(output$guide_tokens$html, "TF-IDF / mediana global", fixed = TRUE)
    expect_match(output$vocab_order_note$html, "no modifica el vocabulario incluido", fixed = TRUE)
    session$setInputs(max_terms = 20L, prepare = 2)
    expect_match(output$vocab_order_note$html, "dej\u00f3 fuera", fixed = TRUE)
  })
})

test_that("T03/T05/T07: selector reducido, entrada por proposito y retirada de redundancias", {
  ch <- term_metric_choices_grouped()
  expect_identical(unname(ch[[1]]), c("documentos", "frecuencia", "tfidf_medio"))
  expect_gt(length(ch[[2]]), 3L)
  expect_setequal(unname(unlist(ch)), unname(term_metric_choices()))
  ui <- as.character(build_ui())
  expect_match(ui, "\u00bfQu\u00e9 quieres hacer?", fixed = TRUE)
  for (id in c("purpose_lda", "purpose_density", "purpose_pca", "purpose_ca", "purpose_jsd", "purpose_wiki", "purpose_network", "to_export_direct")) expect_match(ui, id, fixed = TRUE)
  expect_false(grepl("lda_time_spline", ui, fixed = TRUE))
  expect_false(grepl("Temas por densidad", ui, fixed = TRUE))
  expect_match(ui, "Grupos de documentos parecidos", fixed = TRUE)
  expect_match(ui, "Elegir otro an\u00e1lisis, si lo necesitas", fixed = TRUE)
})

test_that("H15: la tabla de terminos a la vista muestra una sola columna de TF-IDF medio", {
  skip_on_cran(); skip_if_not(all(vapply(c("DT", "plotly", "visNetwork"), requireNamespace, TRUE, quietly = TRUE)))
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_510)
    session$setInputs(prepare = 1)
    rv$table_key <- "tokens"; session$setInputs(result_detail = "tokens", term_status = "all", term_reason = "all")
    expect_false("tfidf_mean" %in% names(result_data()))
    expect_true("tfidf_medio" %in% names(result_data()))
    expect_true("tfidf_mean" %in% names(rv$corpus$terms)) # el alias se conserva para scripts y entregas anteriores
  })
})

test_that("T02: cada ficha de decision cumple el contrato y aparece junto a su control", {
  h <- decision_help_catalog()
  expect_gte(length(h), 12L)
  words <- function(x) length(strsplit(trimws(x), "\\s+")[[1]])
  for (id in names(h)) {
    f <- h[[id]]
    expect_true(all(decision_help_fields %in% names(f)), info = id)
    expect_true(all(nzchar(unlist(f[decision_help_fields]))), info = id)
    expect_gte(words(f$empezar), 15L); expect_lte(words(f$empezar), 35L)
    expect_true(endsWith(trimws(f$pregunta), "?"), info = id)
    expect_false(grepl("\\bV[0-9]\\b", paste(unlist(f), collapse = " ")), info = id)
  }
  ui <- as.character(build_ui())
  expect_match(ui, "En cu\u00e1ntos documentos debe aparecer una palabra", fixed = TRUE)
  expect_match(ui, "Ejemplo ilustrativo", fixed = TRUE)
  for (id in c("lda_k", "jsd_weight", "hdb_min_pts", "network_weight", "token_rank_metric", "split_sentences", "wiki_concept_k")) expect_match(ui, h[[id]]$pregunta, fixed = TRUE)
})
