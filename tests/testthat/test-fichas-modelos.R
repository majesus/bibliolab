sheet_tags <- function(node, predicate) {
  if (inherits(node, "shiny.tag")) {
    if (predicate(node)) return(list(node))
    return(unlist(lapply(node$children, sheet_tags, predicate = predicate), recursive = FALSE))
  }
  if (is.list(node)) return(unlist(lapply(node, sheet_tags, predicate = predicate), recursive = FALSE))
  list()
}

test_that("cada modelo comienza por la misma ficha antes de sus parametros", {
  ui <- bibliolab:::build_ui_content()
  methods <- c(density = "UMAP + HDBSCAN", lda = "LDA", pca = "ACP", ca = "Correspondencias")
  headings <- c("Finalidad y datos de partida", "Salidas y cómo interpretarlas",
    "Parámetros y primer ajuste", "Primer recorrido y límites")
  for (key in names(methods)) {
    tab <- sheet_tags(ui, function(node) bibliolab:::ui_has_class(node, "tab-pane") &&
      identical(node$attribs[["data-value"]], methods[[key]]))[[1]]
    panels <- sheet_tags(tab, function(node) bibliolab:::ui_has_class(node, "panel-card"))
    card <- panels[[1]]
    expect_identical(card$attribs$id, paste0("model_intro_", key))
    expect_identical(card$children[[1]]$children[[1]], "Comprender el análisis")
    subheads <- sheet_tags(card, function(node) node$name == "h3")
    expect_identical(vapply(subheads, function(node) node$children[[1]], ""), headings)
    expect_true(bibliolab:::ui_has_id(card, paste0("help_", key)))
    # Cada ayuda existente aparece una sola vez, aunque ahora esté al principio.
    expect_length(sheet_tags(ui, function(node) identical(node$attribs$id, paste0("help_", key))), 1L)
    expect_match(bibliolab:::help_document(key)$meta$titulo, " / Comprender el análisis", fixed = TRUE)
  }
})

test_that("LDA explica que compara numeros de temas y conserva la comparacion especifica", {
  ui <- as.character(bibliolab:::build_ui())
  expect_match(ui, "Aquí comparas soluciones de LDA con distinto número de temas", fixed = TRUE)
  expect_match(ui, "No se comparan técnicas diferentes", fixed = TRUE)
  expect_false(grepl("Comprender la comparación", ui, fixed = TRUE))
  for (id in c("run_kselect", "kselect_min", "kselect_max", "kselect_seeds", "run_lda", "k"))
    expect_match(ui, paste0("id=\"", id, "\""), fixed = TRUE)
})
