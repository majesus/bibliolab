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

test_that("H11: la pregunta, la procedencia y la ejecucion no invalidan el corpus; un ajuste analitico si", {
  skip_on_cran(); skip_if_not(all(vapply(c("DT", "plotly", "visNetwork"), requireNamespace, TRUE, quietly = TRUE)))
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_510)
    session$setInputs(prepare = 1)
    expect_false(stale())
    prepared_at <- rv$prepared$prepared_at
    session$setInputs(question = "¿Qué temas dominan?", source_db = "Scopus", search_query = "TITLE-ABS-KEY(x)", extraction_date = "2026-10-01", inclusion = "artículos")
    expect_false(stale())
    expect_identical(rv$prepared$question, "¿Qué temas dominan?")
    expect_identical(rv$prepared$provenance$base_de_datos, "Scopus")
    expect_identical(rv$prepared$provenance$fecha_extraccion, "2026-10-01")
    expect_identical(rv$prepared$prepared_at, prepared_at)
    session$setInputs(parallel_enabled = FALSE)
    expect_false(stale())
    expect_false(isTRUE(rv$prepared$config$execution$enabled))
    # Una fecha incompleta no sustituye a la ultima fecha valida ni invalida resultados.
    session$setInputs(extraction_date = "2026-10-")
    expect_false(stale())
    expect_identical(rv$prepared$provenance$fecha_extraccion, "2026-10-01")
    # Un ajuste que si cambia el vocabulario marca el corpus como pendiente.
    session$setInputs(max_terms = 7L)
    expect_true(stale())
  })
})

test_that("H10/H16: los controles especializados de Redes y de UMAP + HDBSCAN van en secciones plegadas", {
  skip_if_not_installed("xml2")
  ui <- as.character(build_ui())
  expect_match(ui, "Ajustes finos de la red", fixed = TRUE)
  expect_match(ui, "Movimiento y posición de los nodos", fixed = TRUE)
  expect_match(ui, "Ajustes especializados", fixed = TRUE)
  doc <- xml2::read_html(ui)
  folded <- function(id) length(xml2::xml_find_all(doc, sprintf("//details[.//*[@id='%s']]", id))) > 0L
  for (id in c("network_seed", "network_edges", "network_community", "network_keyplayers", "network_motion", "network_pin_drag", "density_rep", "umap_min_dist", "umap_epochs")) expect_true(folded(id), info = id)
  for (id in c("network_type", "network_presence", "network_nodes", "network_label_all", "umap_neighbors", "hdb_min_pts")) expect_false(folded(id), info = id)
})

test_that("D04: la vista previa del vocabulario coincide con la preparacion real y no la sustituye", {
  d <- read_biblio_csv(app_extdata("practica.csv"), ";")
  p <- prepare_documents(d, guess_columns(d))
  cp <- prepare_corpus(p)
  # Sin cambios, la vista previa reproduce el corpus vigente.
  same <- vocabulary_preview(cp, p, list(min_df = p$config$min_df, max_terms = p$config$max_terms))
  expect_identical(same$estado, "sin_cambios")
  expect_identical(same$unidades_con_vocabulario_vigentes, as.integer(cp$units_in_model))
  # Con un umbral distinto, coincide con preparar de verdad con ese umbral.
  prev <- vocabulary_preview(cp, p, list(min_df = 5))
  expect_identical(prev$estado, "cambia")
  p2 <- prepare_documents(d, guess_columns(d), modifyList(p$config, list(min_df = 5)))
  cp2 <- prepare_corpus(p2)
  expect_setequal(setdiff(cp$vocabulary, prev$salen), cp2$vocabulary)
  expect_identical(prev$terminos_propuestos, length(cp2$vocabulary))
  expect_identical(prev$unidades_con_vocabulario_propuestas, as.integer(cp2$units_in_model))
  # El resumen TF-IDF distinto exige recalcular: no se inventa una vista previa.
  expect_identical(vocabulary_preview(cp, p, list(term_order = "tfidf", tfidf_stat = "median"))$estado, "no_disponible")
  html <- paste(as.character(vocabulary_preview_ui(prev)), collapse = " ")
  expect_match(html, "No sustituye al corpus vigente", fixed = TRUE)
  expect_match(html, "Saldrían", fixed = TRUE)
})

test_that("D01-D10: cada ficha del catalogo aparece junto a su control", {
  h <- decision_help_catalog()
  ui <- as.character(build_ui())
  server_side <- "col_text" # se genera con el selector de columnas, que depende del archivo cargado
  for (id in setdiff(names(h), server_side)) expect_match(ui, htmltools::htmlEscape(h[[id]]$pregunta), fixed = TRUE, info = id)
  expect_gte(length(h), 27L)
})

test_that("Las fichas con analogia declaran su limite y lo que no significan", {
  ex <- decision_help_extras(); cat_ids <- names(decision_help_catalog())
  expect_true(all(names(ex) %in% cat_ids))
  expect_gte(length(ex), 10L)
  for (id in names(ex)) expect_true(all(nzchar(unlist(ex[[id]])) & c("analogia", "limite", "no_significa") %in% names(ex[[id]])), info = id)
  html <- as.character(decision_card("network_weight"))
  expect_match(html, "Una analogía", fixed = TRUE); expect_match(html, "Dónde deja de servir", fixed = TRUE); expect_match(html, "Lo que no significa", fixed = TRUE)
  expect_false(grepl("Una analogía", as.character(decision_card("min_tfidf")), fixed = TRUE))
})

test_that("La comparacion JSD ofrece una frase de informe con cifras, ponderacion y cautelas", {
  skip_on_cran()
  d <- read_biblio_csv(app_extdata("practica.csv"), ";")
  p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
  yrs <- sort(unique(stats::na.omit(p$documents$year)))
  skip_if(length(yrs) < 2L)
  fit <- run_comparison(cp, p, list(mode = "year", year_A_min = yrs[1], year_A_max = yrs[1], year_B_min = yrs[length(yrs)], year_B_max = yrs[length(yrs)], weighting = "documents", uncertainty = FALSE))
  s <- jsd_report_sentence(fit)
  expect_match(s, "divergencia de Jensen-Shannon", fixed = TRUE)
  expect_match(s, "documentos equilibrados", fixed = TRUE)
  expect_match(s, "no establece su causa", fixed = TRUE)
  expect_match(s, fmt_es(fit$jsd, 4), fixed = TRUE)
  expect_identical(jsd_report_sentence(NULL), "")
})

test_that("La red ofrece una frase de informe que define la conexion y declara filtros y limites", {
  skip_on_cran(); skip_if_not(requireNamespace("igraph", quietly = TRUE))
  d <- read_biblio_csv(app_extdata("practica.csv"), ";")
  p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
  f <- run_network(cp, p, utils::modifyList(network_defaults(), list(type = "words", min_presence = 2, max_nodes = 30)))
  s <- network_report_sentence(f)
  expect_match(s, "coinciden en al menos un documento", fixed = TRUE)
  expect_match(s, "presencia mínima 2", fixed = TRUE)
  expect_match(s, paste0(f$summary$valor[1], " nodos"), fixed = TRUE)
  expect_match(s, "sin implicar influencia ni causalidad", fixed = TRUE)
  expect_identical(network_report_sentence(NULL), "")
})

test_that("D05, D09 y D12: las ayudas operativas figuran en el codigo de la interfaz", {
  rd <- function(f) paste(readLines(system.file(f, package = "bibliolab"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  ext <- rd("app/server/extensions.R"); cmp <- rd("app/server/comparisons.R")
  expect_match(ext, "Excluido no significa que la palabra sea incorrecta", fixed = TRUE)
  expect_match(cmp, "Estar bien representado, contribuir mucho y ser importante para tu pregunta son cosas distintas", fixed = TRUE)
  ui <- as.character(rank_controls("authors", author = TRUE))
  expect_match(ui, "no los documentos ni los cálculos", fixed = TRUE)
  expect_match(ui, "Ninguna de las tres medidas es una evaluación integral", fixed = TRUE)
  expect_match(as.character(build_ui()), "Est\u00e1 desactivado por defecto; usa", fixed = TRUE)
})

test_that("ACP, Correspondencias, LDA y densidad ofrecen frases de informe con cifras reales y limites", {
  skip_on_cran()
  for (pk in c("uwot", "dbscan", "irlba")) skip_if_not_installed(pk)
  d <- read_biblio_csv(app_extdata("practica.csv"), ";")
  p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
  pca <- run_pca(cp, p, max_terms = 50, B = 20)
  s <- ordination_report_sentence(pca, "ACP", c(1L, 2L))
  pct <- format(round(sum(pca$dimensions$porcentaje[1:2]), 1), decimal.mark = ",", trim = TRUE)
  expect_match(s, paste0("recoge el ", pct, " % de la varianza"), fixed = TRUE)
  expect_match(s, "no son temas ni valoraciones", fixed = TRUE)
  expect_match(ordination_report_sentence(run_ca(cp, max_terms = 30, B = 20), "Correspondencias"), "de la inercia total", fixed = TRUE)
  expect_identical(ordination_report_sentence(NULL), "")
  expect_identical(ordination_report_sentence(pca, "ACP", c(1L, 99L)), "")
  den <- run_density(cp, p, density_defaults())
  sd <- density_report_sentence(den)
  expect_match(sd, paste0("detectó ", sum(den$summary$grupo > 0), " grupos entre ", nrow(den$assignments), " documentos"), fixed = TRUE)
  expect_match(sd, "no temas validados", fixed = TRUE)
  fake <- list(params = list(k = 2L), prevalence = data.frame(tema = 1:2, proporcion_media = c(.3, .7)),
    top = data.frame(tema = c(1, 1, 2, 2), termino = c("a", "b", "c", "d")))
  sl <- lda_report_sentence(fake)
  expect_match(sl, "El tema 2 (c, d)", fixed = TRUE); expect_match(sl, "70", fixed = TRUE)
  expect_match(sl, "no descubierto por el modelo", fixed = TRUE)
  expect_identical(lda_report_sentence(NULL), "")
  expect_null(report_sentence_ui(""))
})
