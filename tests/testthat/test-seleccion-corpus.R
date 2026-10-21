selection_fixture <- function(wos = FALSE) {
  d <- data.frame(EID = paste0("eid", 1:8), Title = paste("Distinct publication title number", 1:8),
    Abstract = c("learning evaluation students evidence", "", rep("teachers learning research evidence", 4), "[No abstract available]", "research learning analysis evidence"),
    Year = c(2020:2026, NA), `Source title` = c("J1", "J1", "J2", "J2", "J1", "J2", "J1", ""),
    Authors = paste0("A", 1:8), `Cited by` = c(0, NA, 5, 10, 100, 2, NA, 3),
    DOI = c("10.1/1", "10.1/2", "", "10.1/4", "10.1/5", "10.1/6", "", "10.1/8"),
    `Author Keywords` = "learning; research", `Document Type` = c("Article", "Review", "Article", "Book Chapter", "Conference Paper", "Article", "Article", "Note"),
    `Language of Original Document` = c("English", "English", "Spanish", "English", "Spanish", "English", "English", ""),
    Country = c("Spain", "France", "Spain;France", "France", "Spain", "France", "Spain", ""),
    `Publication Stage` = c(rep("Final", 6), "Article in Press", ""), check.names = FALSE)
  if (wos) {
    names(d) <- c("UT", "TI", "AB", "PY", "SO", "AU", "TC", "DI", "DE", "DT", "LA", "Country", "EA")
    d$DT[7] <- "Article; Early Access"; d$EA <- c(rep("", 6), "OCT 2026", "")
    d$ID <- "Keywords Plus, not an identifier"
  }
  d
}

selection_config_fixture <- function(d) {
  cfg <- default_config()
  cfg$corpus_selection <- bibliolab:::selection_defaults()
  cfg$corpus_selection$fields <- bibliolab:::selection_columns(d)
  cfg$reference_year <- 2026L
  cfg
}

test_that("Scopus y WoS se filtran por campos equivalentes y conservan filas e identidades", {
  results <- lapply(c(FALSE, TRUE), function(wos) {
    d <- selection_fixture(wos); m <- guess_columns(d); cfg <- selection_config_fixture(d)
    expect_equal(m$id, if (wos) "UT" else "EID")
    expect_equal(m$language, if (wos) "LA" else "Language of Original Document")
    cfg$year_min <- 2020; cfg$year_max <- 2025
    cfg$corpus_selection$types <- c("Artículo", "Revisión")
    cfg$corpus_selection$sources <- "J2"; cfg$corpus_selection$doi <- TRUE; cfg$corpus_selection$abstract <- TRUE
    before <- serialize(d, NULL)
    actual <- prepare_documents(d, m, cfg); preview <- bibliolab:::selection_preview(d, m, cfg)
    expect_identical(actual$documents, preview$documents)
    expect_identical(actual$documents$source_row, 6L)
    expect_equal(actual$documents$doc_id, "D00006")
    expect_identical(serialize(d, NULL), before)
    expect_equal(sum(actual$selection$steps$excluidos), 7)
    expect_equal(nrow(actual$selection$excluded), 7)
    expect_equal(anyDuplicated(actual$selection$excluded$fila_original), 0L)
    expect_equal(actual$selection$summary$doi_abstract_pct, 100)
    expect_equal(sum(actual$selection$annual$registros), 7)
    actual$selection
  })
  expect_equal(results[[1]]$steps, results[[2]]$steps)
  expect_equal(results[[1]]$summary, results[[2]]$summary)
})

test_that("acceso anticipado es un estado compatible con Articulo, no una categoria excluyente", {
  for (wos in c(FALSE, TRUE)) {
    d <- selection_fixture(wos); m <- guess_columns(d); cfg <- selection_config_fixture(d)
    cfg$corpus_selection$types <- "Artículo"; cfg$corpus_selection$early <- "only"
    p <- prepare_documents(d, m, cfg)
    expect_equal(p$documents$source_row, 7)
    cfg$corpus_selection$early <- "exclude"
    expect_equal(prepare_documents(d, m, cfg)$documents$source_row, c(1, 3, 6))
  }
})

test_that("resumen exigido es independiente del texto elegido y no acepta marcadores de ausencia", {
  d <- selection_fixture(); m <- guess_columns(d); m$text <- "Title"
  cfg <- selection_config_fixture(d); cfg$corpus_selection$abstract <- TRUE
  p <- prepare_documents(d, m, cfg)
  expect_equal(p$documents$source_row, c(1, 3, 4, 5, 6, 8))
  expect_true(all(nzchar(p$documents$text)))
  cfg$corpus_selection$fields$abstract <- ""
  expect_error(prepare_documents(d, m, cfg), "Asigna el campo")
})

test_that("idioma y pais admiten varios valores sin inferir paises de afiliaciones", {
  d <- selection_fixture(); m <- guess_columns(d); cfg <- selection_config_fixture(d)
  cfg$corpus_selection$languages <- "Spanish"; cfg$corpus_selection$countries <- "France"
  expect_equal(prepare_documents(d, m, cfg)$documents$source_row, 3)
  names(d)[names(d) == "Country"] <- "Affiliations"
  expect_equal(bibliolab:::selection_columns(d)$country, "")
  cfg$corpus_selection$fields$country <- ""
  expect_error(prepare_documents(d, m, cfg), "Asigna el campo")
})

test_that("cero registros se previsualiza pero no se prepara para modelos", {
  d <- selection_fixture(); m <- guess_columns(d); cfg <- selection_config_fixture(d)
  cfg$corpus_selection$sources <- "Fuente inexistente"
  preview <- bibliolab:::selection_preview(d, m, cfg)
  expect_equal(nrow(preview$documents), 0)
  expect_equal(preview$selection$summary$excluded, nrow(d))
  expect_true(is.na(preview$selection$summary$doi_abstract_pct))
  expect_error(prepare_documents(d, m, cfg), "cero documentos")
  expect_s3_class(bibliolab:::selection_dashboard_ui(preview), "shiny.tag.list")
})

test_that("duplicados y muestra mantienen el resultado previo y el generador aleatorio", {
  pr <- practica(); cfg <- selection_config_fixture(pr$raw)
  old <- prepare_documents(pr$raw, pr$mapping)
  new <- prepare_documents(pr$raw, pr$mapping, cfg)
  expect_identical(new$documents, old$documents)
  expect_identical(new$duplicates, old$duplicates)
  cfg$sample_pct <- 50; set.seed(21); before <- .Random.seed
  sampled <- prepare_documents(pr$raw, pr$mapping, cfg)
  expect_identical(before, .Random.seed)
  expected <- prepare_documents(pr$raw, pr$mapping, utils::modifyList(default_config(), list(sample_pct = 50)))
  expect_identical(sampled$documents, expected$documents)
  expect_equal(sum(sampled$selection$steps$excluidos), nrow(pr$raw) - nrow(sampled$documents))
})

test_that("el resumen y las barras incorporan ano y DOI completados por duplicados seguros", {
  d <- selection_fixture()[c(1, 1), ]; rownames(d) <- NULL
  d$Year <- c(NA, 2020); d$DOI <- c("", "10.1/1")
  cfg <- selection_config_fixture(d)
  p <- prepare_documents(d, guess_columns(d), cfg)
  expect_equal(nrow(p$documents), 1)
  expect_equal(p$selection$summary$doi_abstract_pct, 100)
  expect_equal(p$selection$annual$registros, c(1, 1))
  expect_equal(unname(p$selection$missing_year), c(0, 0))
})

test_that("excluir el ano actual conserva el criterio congelado en la configuracion", {
  d <- selection_fixture(); cfg <- selection_config_fixture(d)
  cfg$corpus_selection$exclude_current_year <- TRUE
  p <- prepare_documents(d, guess_columns(d), cfg)
  expect_false(7 %in% p$documents$source_row)
  expect_true(8 %in% p$documents$source_row)
  expect_equal(p$config$reference_year, 2026)
  expect_equal(bibliolab:::selection_year(c(2021.5, 2020, NA)), c("2021,5", "2020", "—"))
})

test_that("descarga registra exclusiones y reproduce los mismos registros", {
  pr <- practica(); cfg <- selection_config_fixture(pr$raw); cfg$sample_pct <- 70
  p <- prepare_documents(pr$raw, pr$mapping, cfg)
  directory <- withr::local_tempdir()
  bibliolab:::selection_export(directory, p, pr$raw)
  saved <- readRDS(file.path(directory, "configuracion.rds"))
  restored <- prepare_documents(readRDS(file.path(directory, "entrada_original.rds")), saved$mapping, saved$config)
  expect_identical(restored$documents, p$documents)
  expect_identical(restored$selection$excluded, p$selection$excluded)
  expect_true(all(file.exists(file.path(directory, c("pasos.csv", "resumen.csv", "retenidos.csv", "excluidos.csv", "por_ano.csv", "reproducir_seleccion.R", "entrada_original.rds")))))
})

test_that("panel precede a Delimitar, los selectores siguen al grafico y los IDs no se duplican", {
  ui <- as.character(bibliolab:::build_ui())
  expect_lt(regexpr("selection_dashboard", ui, fixed = TRUE), regexpr("Delimitar y documentar", ui, fixed = TRUE))
  expect_lt(regexpr("selection_dashboard", ui, fixed = TRUE), regexpr('id="selection_types"', ui, fixed = TRUE))
  for (id in c("dedup", "year_filter", "year_min", "year_max", "value_filter", "filter_value", "sample_pct", "sample_seed"))
    expect_equal(lengths(regmatches(ui, gregexpr(paste0('id="', id, '"'), ui, fixed = TRUE))), 1L)
})

test_that("cambiar de Scopus a WoS no intenta leer encabezados anteriores en los visores", {
  mapping <- guess_columns(selection_fixture())
  expect_true(bibliolab:::selection_mapping_ready(selection_fixture(),mapping,c("authors","keywords")))
  expect_false(bibliolab:::selection_mapping_ready(selection_fixture(TRUE),mapping,c("authors","keywords")))
  expect_true(bibliolab:::selection_mapping_ready(selection_fixture(TRUE),guess_columns(selection_fixture(TRUE)),c("authors","keywords")))
  skip_on_cran()
  raw <- selection_fixture()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw,"Scopus",FALSE)
    session$setInputs(col_text="Abstract",col_authors="Authors",col_keywords="Author Keywords")
    set_data(selection_fixture(TRUE),"WoS",FALSE);session$flushReact()
    expect_no_error(reading <- output$metadata_separator_reading)
    expect_match(paste(unlist(reading),collapse=" "),"correspondencia")
    expect_no_error(output$metadata_separator_preview)
  })
})

test_that("servidor aplica lo previsualizado y marca pendientes los cambios posteriores", {
  skip_on_cran()
  raw <- selection_fixture(TRUE)
  mapping <- list(col_text = "AB", col_title = "TI", col_id = "UT", col_year = "PY", col_source = "SO", col_authors = "AU",
    col_citations = "TC", col_keywords = "DE", col_doi = "DI", col_language = "LA", language = "en", remove_stop = TRUE,
    min_chars = 3L, min_df = 1L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "WoS ficticio", FALSE); do.call(session$setInputs, mapping)
    session$setInputs(selection_types = "Artículo")
    predicted <- selection_data()$prepared$documents
    session$setInputs(prepare = 1)
    expect_null(rv$error)
    expect_identical(rv$prepared$documents, predicted)
    expect_identical(rv$prepared$documents$source_row, c(1L, 3L, 6L, 7L))
    session$setInputs(selection_doi = TRUE)
    expect_true(stale())
    expect_equal(selection_data()$prepared$documents$source_row, c(1, 6))
    session$setInputs(prepare = 2)
    expect_null(rv$error)
    expect_equal(rv$prepared$documents$source_row, c(1, 6))
    expect_false(stale())
  })
})

test_that("entrega general incluye las decisiones y su reproduccion verifica los documentos", {
  pr <- practica(); cfg <- selection_config_fixture(pr$raw)
  cfg$corpus_selection$sources <- pr$raw$Source[1]
  p <- prepare_documents(pr$raw, pr$mapping, cfg)
  cp <- prepare_corpus(p); b <- biblio_summary(p)
  directory <- withr::local_tempdir()
  export_bundle(directory, p, cp, b, raw = pr$raw)
  expect_true(file.exists(file.path(directory, "seleccion_documental", "pasos.csv")))
  withr::with_dir(directory, sys.source("reproducir_analisis.R", envir = new.env(parent = globalenv())))
  reproduced <- readRDS(file.path(directory, "resultados_reproducidos.rds"))
  expect_identical(reproduced$preparado$documents, p$documents)
  expect_identical(reproduced$preparado$selection$excluded, p$selection$excluded)
})
