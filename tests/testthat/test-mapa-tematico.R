test_that("Callon cuenta cada pareja interna una vez y cada externa en ambos temas", {
  nodes <- data.frame(termino = letters[1:5], tema = c(1, 1, 2, 2, 3))
  edges <- data.frame(from = c("a", "c", "b", "d"), to = c("b", "d", "c", "e"), peso = c(.8, .4, .1, .2))
  d <- bibliolab:::thematic_callon(nodes, edges)
  expect_equal(d$centralidad, c(1, 3, 2))
  expect_equal(d$densidad, c(40, 20, 0))
  expect_equal(d$terminos, c(2, 2, 1))
  reversed <- edges; reversed$from <- edges$to; reversed$to <- edges$from
  expect_identical(bibliolab:::thematic_callon(nodes, reversed), d)
})

test_that("cuadrantes usan medianas y no fuerzan empates ni un tema unico", {
  d <- data.frame(centralidad = c(1, 1, 3, 3, 2), densidad = c(1, 3, 1, 3, 2))
  out <- bibliolab:::thematic_quadrants(d)
  expect_equal(unname(out$cuts), c(2, 2))
  expect_equal(out$themes$cuadrante, c("Emergente o en declive", "Especializado / nicho", "Básico / transversal", "Motor", "En el límite"))
  expect_equal(bibliolab:::thematic_quadrants(d[1, ])$themes$cuadrante, "Sin contraste entre temas")
})

test_that("equivalencia usa copresencias binarias y registra aislados y filtros", {
  skip_if_not_installed("igraph")
  b <- Matrix::Matrix(matrix(c(1,1,0,0, 1,1,1,0, 0,0,0,1), 4,
    dimnames = list(paste0("d", 1:4), c("a", "b", "aislado"))), sparse = TRUE)
  f <- bibliolab:::thematic_from_incidence(b, list(min_presence = 1))
  expect_equal(f$edges$coincidencias, 2)
  expect_equal(f$edges$peso, 4/6)
  expect_equal(f$themes$centralidad, 0)
  expect_equal(f$themes$densidad, 100*(4/6)/2)
  expect_equal(f$themes$documentos, 3)
  expect_equal(f$selection$estado[f$selection$termino == "aislado"], "Aislado tras filtrar conexiones")
  expect_equal(f$coverage$cantidad[f$coverage$etapa == "Aislados excluidos"], 1)
  f2 <- bibliolab:::thematic_from_incidence(b*7, list(min_presence = 1))
  expect_identical(f$themes, f2$themes)
  expect_identical(f$edges, f2$edges)
  expect_error(bibliolab:::thematic_from_incidence(b, list(min_shared = 3)), "No hay copresencias")
  expect_error(bibliolab:::thematic_from_incidence(b, list(min_presence = 3)), "Menos de dos")
  expect_error(bibliolab:::thematic_from_incidence(b, list(max_terms = 151)), "Máximo")
  bad <- b; bad[1, 1] <- Inf
  expect_error(bibliolab:::thematic_from_incidence(bad), "no es válida")
})

test_that("ambos origenes conservan el corpus, las frases se agregan por documento y RNG no cambia", {
  skip_if_not_installed("igraph")
  pr <- practica()
  before <- serialize(pr, NULL)
  set.seed(123); random_before <- .Random.seed
  for (field in c("keywords", "text")) {
    f <- run_thematic_map(pr$corpus, pr$prepared, list(field = field))
    expect_true(nrow(f$themes) > 0)
    expect_true(all(f$edges$peso > 0 & f$edges$peso <= 1))
    expect_true(all(f$themes$documentos <= nrow(pr$prepared$documents)))
    expect_identical(.Random.seed, random_before)
    expect_identical(serialize(pr, NULL), before)
    expect_identical(f$themes, run_thematic_map(pr$corpus, pr$prepared, list(field = field))$themes)
  }
  prepared <- pr$prepared
  prepared$config$split_sentences <- TRUE
  cp <- prepare_corpus(prepared)
  expected <- bibliolab:::thematic_incidence(pr$corpus, pr$prepared, "text")
  actual <- bibliolab:::thematic_incidence(cp, prepared, "text")
  expect_equal(as.matrix(actual[, colnames(expected)]), as.matrix(expected))
  # An empty keyword field cannot silently switch to text.
  prepared$documents$keywords <- ""
  expect_error(run_thematic_map(cp, prepared), "No hay palabras clave")
})

test_that("seleccion limita terminos y deja auditable su exclusion", {
  skip_if_not_installed("igraph")
  b <- Matrix::Matrix(matrix(1, 4, 4, dimnames = list(NULL, c("d", "c", "b", "a"))), sparse = TRUE)
  f <- bibliolab:::thematic_from_incidence(b, list(max_terms = 2))
  expect_equal(f$terms$termino, c("a", "b"))
  expect_equal(f$selection$estado[f$selection$termino %in% c("c", "d")], rep("Fuera del máximo de términos", 2))
})

test_that("exportacion reproduce el analisis sin instalar bibliolab", {
  skip_if_not_installed("igraph")
  pr <- practica(); f <- run_thematic_map(pr$corpus, pr$prepared)
  directory <- withr::local_tempdir()
  bibliolab:::write_thematic_bundle(directory, f, figures = FALSE)
  expect_true(all(file.exists(file.path(directory, c("themes.csv", "terms.csv", "coverage.csv", "selection.csv", "edges.csv", "metodo.json", "entrada_mapa.rds", "reproducir_mapa.R", "LEEME.txt")))))
  withr::with_dir(directory, sys.source("reproducir_mapa.R", envir = new.env(parent = baseenv())))
  reproduced <- readRDS(file.path(directory, "mapa_reproducido.rds"))
  expect_equal(reproduced$themes, f$themes)
  expect_equal(reproduced$edges, f$edges)
  expect_equal(reproduced$cuts, f$cuts)
  graph <- bibliolab:::thematic_plot(f)
  expect_s3_class(graph, "ggplot")
  expect_silent(ggplot2::ggplot_build(graph))
})

test_that("nuevo mapa comparte ficha, numeracion y ayuda con los modelos existentes", {
  ui <- as.character(bibliolab:::build_ui())
  expect_match(ui, 'id="model_intro_thematic"', fixed = TRUE)
  expect_match(ui, 'id="run_thematic"', fixed = TRUE)
  expect_match(ui, 'id="download_thematic"', fixed = TRUE)
  expect_match(bibliolab:::help_document("thematic")$meta$titulo, "Comprender el análisis", fixed = TRUE)
  expect_true("run_thematic_map" %in% getNamespaceExports("bibliolab"))
})

test_that("mapa de sesion invalida cambios y no modifica otros resultados", {
  skip_on_cran(); skip_if_not_installed("igraph")
  raw <- practica_raw()
  mapping <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
    col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
    language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE); do.call(session$setInputs, mapping)
    session$setInputs(prepare = 1)
    rv$network <- list(test_marker = TRUE); rv$pca <- list(test_marker = TRUE)
    before <- serialize(list(rv$prepared, rv$corpus, rv$bib, rv$network, rv$pca), NULL)
    session$setInputs(run_thematic = 1)
    expect_null(rv$error)
    expect_true(nrow(thematic_current()$themes) > 0)
    expect_identical(serialize(list(rv$prepared, rv$corpus, rv$bib, rv$network, rv$pca), NULL), before)
    session$setInputs(thematic_presence = 3)
    expect_null(thematic_current())
    session$setInputs(run_thematic = 2)
    expect_null(rv$error); expect_false(is.null(thematic_current()))
    session$setInputs(prepare = 2)
    expect_null(thematic_fit()); expect_null(thematic_current())
  })
})
