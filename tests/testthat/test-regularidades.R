test_that("Lotka conserva autores y clases vacías con referencia finita normalizada", {
  a <- data.frame(elemento = letters[1:4], documentos = c(1L, 1L, 2L, 4L))
  d <- bibliolab:::lotka_regularity(a)
  expect_equal(d$autores, c(2L, 1L, 0L, 1L))
  expect_equal(sum(d$autores_referencia), 4)
  expect_equal(d$autores_referencia[2] / d$autores_referencia[1], 1/4)
  expect_equal(d$autores_referencia[4] / d$autores_referencia[1], 1/16)
  expect_equal(sum(d$porcentaje_autores), 100)
})

test_that("las escalas corresponden a los rótulos de cada regularidad", {
  p <- practica()
  fit <- bibliolab:::biblio_regularities(p$prepared, p$corpus, p$bibliography)
  for (kind in c("lotka", "bradford", "zipf")) {
    graph <- bibliolab:::regularity_plot(fit, kind)
    built <- ggplot2::ggplot_build(graph)
    expect_equal(built$layout$panel_scales_x[[1]]$transform(c(1, 10, 100)), c(0, 1, 2))
    expect_match(graph$labels$x, "logarítmica", fixed = TRUE)
    if (kind == "bradford") {
      expect_equal(built$layout$panel_scales_y[[1]]$transform(c(1, 10, 100)), c(1, 10, 100))
    } else {
      expect_equal(built$layout$panel_scales_y[[1]]$transform(c(1, 10, 100)), c(0, 1, 2))
      expect_match(graph$labels$y, "logarítmica", fixed = TRUE)
    }
  }
})

test_that("las lecturas distinguen recuentos reales y referencias sin denominadores inexistentes", {
  fit <- list(lotka = bibliolab:::lotka_regularity(data.frame(documentos = c(1, 1, 2, 3))),
    bradford = bibliolab:::bradford_regularity(data.frame(elemento = LETTERS[1:7], documentos = c(12, 6, 6, 3, 3, 3, 3))),
    zipf = bibliolab:::zipf_regularity(data.frame(termino = c("alfa", "beta", "gamma"), frecuencia = c(100, 50, 25))))
  expect_match(bibliolab:::regularity_reading(fit, "lotka"), "4 autores: 2 con un documento, 1 con dos y 1 con tres", fixed = TRUE)
  expect_match(bibliolab:::regularity_reading(fit, "lotka"), "50,0 con dos y 50,0 con tres", fixed = TRUE)
  expect_match(bibliolab:::regularity_reading(fit, "bradford"), "1 / 2 / 4 fuentes", fixed = TRUE)
  expect_match(bibliolab:::regularity_reading(fit, "bradford"), "2,00 y 2,00", fixed = TRUE)
  expect_match(bibliolab:::regularity_reading(fit, "zipf"), "3 términos y 175 apariciones", fixed = TRUE)
  expect_match(bibliolab:::regularity_reading(fit, "zipf"), "50,0 %", fixed = TRUE)
  fit$lotka <- bibliolab:::lotka_regularity(data.frame(documentos = c(2, 3)))
  expect_match(bibliolab:::regularity_reading(fit, "lotka"), "No hay autores con un solo documento", fixed = TRUE)
  fit$zipf <- bibliolab:::zipf_regularity(data.frame(termino = "alfa", frecuencia = 10))
  expect_match(bibliolab:::regularity_reading(fit, "zipf"), "menos de tres términos", fixed = TRUE)
})

test_that("la numeración de Lotka no altera los puntos y las etiquetas de Zipf priorizan el ranking", {
  values <- data.frame(x = 1:100, observado = rep(10, 100), referencia = 100 / (1:100)^2)
  before <- values
  selected <- bibliolab:::regularity_numbered_points(values, compact = TRUE, canvas_width = 308)
  expect_gt(nrow(selected), 0)
  expect_lt(nrow(selected), nrow(values))
  expect_identical(values, before)
  expect_true(all(selected$x %in% values$x))
  p <- practica()
  fit <- bibliolab:::biblio_regularities(p$prepared, p$corpus, p$bibliography)
  graph <- bibliolab:::regularity_plot(fit, "zipf")
  layers <- Filter(function(layer) "etiqueta" %in% names(layer$data), graph$layers)
  expect_length(layers, 1L)
  labels <- layers[[1]]$data
  expect_equal(labels$rango[nzchar(labels$etiqueta)], 1:8)
  expect_identical(gsub("\n", "", labels$etiqueta[1:8], fixed = TRUE), fit$zipf$termino[1:8])
})

test_that("Bradford conserva fuentes completas y recupera una progresión conocida", {
  s <- data.frame(elemento = LETTERS[1:7], documentos = c(12L, 6L, 6L, 3L, 3L, 3L, 3L))
  fit <- bibliolab:::bradford_regularity(s)
  expect_equal(fit$zonas$fuentes, c(1L, 2L, 4L))
  expect_equal(fit$zonas$documentos, rep(12, 3))
  expect_equal(fit$zonas$multiplicador_anterior[-1], c(2, 2))
  expect_identical(bibliolab:::bradford_regularity(s[7:1, ]), fit)
  expect_equal(sum(fit$fuentes$documentos), sum(s$documentos))
  expect_false(anyDuplicated(fit$fuentes$fuente) > 0)
})

test_that("Bradford declara zonas vacías y empates sin inventar razones", {
  fit <- bibliolab:::bradford_regularity(data.frame(elemento = c("A", "B"), documentos = c(9L, 1L)))
  expect_equal(fit$zonas$fuentes, c(1L, 0L, 1L))
  expect_equal(fit$zonas$documentos, c(9, 0, 1))
  expect_true(all(is.na(fit$zonas$multiplicador_anterior)))
  ties <- bibliolab:::bradford_regularity(data.frame(elemento = LETTERS[1:4], documentos = rep(3L, 4)))
  expect_true(ties$empates)
})

test_that("Zipf cuenta apariciones de todo el vocabulario, incluidos términos excluidos", {
  terms <- data.frame(termino = c("beta", "alfa", "gamma"), frecuencia = c(3, 3, 1),
    incluido = c(TRUE, FALSE, FALSE), documentos = c(1L, 3L, 1L))
  d <- bibliolab:::zipf_regularity(terms)
  expect_identical(d$termino, c("alfa", "beta", "gamma"))
  expect_equal(d$frecuencia, c(3, 3, 1))
  expect_equal(sum(d$frecuencia_referencia), 7)
  expect_equal(d$frecuencia_referencia / d$frecuencia_referencia[1], 1 / (1:3))
})

test_that("las regularidades no alteran el corpus y admiten campos ausentes", {
  p <- practica()
  before <- serialize(p, NULL)
  f <- bibliolab:::biblio_regularities(p$prepared, p$corpus, p$bibliography)
  expect_equal(sum(f$lotka$autores), nrow(p$bibliography$authors))
  expect_equal(sum(f$bradford$fuentes$documentos), sum(p$bibliography$sources$documentos))
  expect_equal(sum(f$zipf$frecuencia), p$corpus$total_tokens)
  expect_identical(serialize(p, NULL), before)
  for (kind in c("lotka", "bradford", "zipf"))
    expect_no_error(ggplot2::ggplot_build(bibliolab:::regularity_plot(f, kind)))
  expect_no_error(ggplot2::ggplot_build(bibliolab:::regularity_plot(f, "zipf", compact = TRUE)))
  p$prepared$documents$authors <- ""
  p$prepared$documents$source <- NA_character_
  p$corpus$terms <- data.frame()
  p$corpus$units$cleaned <- ""
  f <- bibliolab:::biblio_regularities(p$prepared, p$corpus)
  expect_equal(nrow(f$lotka), 0)
  expect_equal(nrow(f$bradford$fuentes), 0)
  expect_true(all(f$bradford$zonas$fuentes == 0))
  expect_equal(nrow(f$zipf), 0)
  expect_equal(f$cobertura$documentos_con_datos, c(0, 0, 0))
})

test_that("las tablas nuevas están en informe y entrega reproducible", {
  p <- practica()
  html <- bibliolab:::report_html(p$prepared, p$corpus, p$bibliography)
  for (label in c("Lotka /", "Bradford /", "Zipf /")) expect_match(html, label, fixed = TRUE)
  directory <- withr::local_tempdir()
  export_bundle(directory, p$prepared, p$corpus, p$bibliography, raw = p$raw)
  files <- c("regularidades_cobertura.csv", "lotka_productividad.csv", "bradford_zonas.csv", "bradford_fuentes.csv", "zipf_rango_frecuencia.csv")
  expect_true(all(file.exists(file.path(directory, files))))
  expect_match(bibliolab:::reproduction_script(p$prepared), "regularidades <- biblio_regularities", fixed = TRUE)
})

test_that("los subbloques mantienen los controles y condiciones de Shiny", {
  original <- bibliolab:::build_ui_content()
  organized <- bibliolab:::ui_compartments(original)
  collect <- function(node, predicate) {
    if (inherits(node, "shiny.tag")) {
      if (predicate(node)) return(list(node))
      return(unlist(lapply(node$children, collect, predicate = predicate), recursive = FALSE))
    }
    if (is.list(node)) return(unlist(lapply(node, collect, predicate = predicate), recursive = FALSE))
    list()
  }
  control <- function(node) node$name %in% c("input", "select", "textarea", "button")
  snapshots <- function(ui) vapply(collect(ui, control), as.character, "")
  expect_identical(snapshots(organized), snapshots(original))
  conditional <- function(node) !is.null(node$attribs[["data-display-if"]])
  conditions <- function(ui) vapply(collect(ui, conditional), function(node) node$attribs[["data-display-if"]], "")
  expect_identical(conditions(organized), conditions(original))
  blocks <- collect(organized, function(node) !is.null(node$attribs[["data-block-number"]]))
  numbers <- vapply(blocks, function(node) node$attribs[["data-block-number"]], "")
  expect_false(anyDuplicated(numbers) > 0)
  expect_true(all(paste0(sprintf("%02d", 1:5), ".01") %in% numbers))
})

test_that("las regularidades de la sesión se invalidan al cambiar la preparación", {
  skip_on_cran()
  raw <- practica_raw()
  mapping <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
    col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
    language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapping)
    session$setInputs(prepare = 1)
    before <- serialize(list(rv$prepared, rv$corpus, rv$bib), NULL)
    fit <- regularities_current()
    expect_true(nrow(fit$lotka) > 0)
    expect_identical(serialize(list(rv$prepared, rv$corpus, rv$bib), NULL), before)
    session$setInputs(min_chars = 4L)
    expect_error(regularities_current(), class = "shiny.silent.error")
    session$setInputs(prepare = 2)
    expect_null(rv$error)
    expect_true(nrow(regularities_current()$zipf) > 0)
  })
})
