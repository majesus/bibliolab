test_that("el banco tiene 21 tareas ordenadas y con requisito valido", {
  cat <- prompt_catalog()
  expect_length(cat, 21L)
  numeros <- as.integer(sub("^([0-9]+).*", "\\1", vapply(cat, `[[`, "", "title")))
  expect_equal(numeros, 1:21)
  validos <- c("prepared", "text", "lda", "ca", "density", "network", "comparison", "pca")
  expect_true(all(vapply(cat, `[[`, "", "requires") %in% validos))
  expect_true(all(vapply(cat, function(x) nzchar(x$task) && nzchar(x$format), TRUE)))
})

test_that("el prompt incluye las reglas, la pregunta y la evidencia, sin datos adicionales", {
  pr <- practica()
  prepared <- pr$prepared
  prepared$is_demo <- TRUE          # la aplicacion marca asi los datos de practica
  ev <- bibliolab:::evidence_bundle(prepared, pr$corpus, pr$bibliography)
  expect_true(ev$practica_sintetica)
  txt <- bibliolab:::build_prompt("calidad", "¿Qué calidad tienen los datos?", ev)
  expect_match(txt, "# INSTRUCCIONES", fixed = TRUE)
  expect_match(txt, "# PREGUNTA DE INVESTIGACI", fixed = FALSE)
  expect_match(txt, "[PENDIENTE]", fixed = TRUE)
  expect_match(txt, "ficticios")
  expect_false(grepl("\"anos\"", txt, fixed = TRUE))     # 'calidad' solo usa el contexto comun
})

test_that("los rankings de la evidencia se limitan a 25 filas", {
  pr <- practica()
  ev <- bibliolab:::evidence_bundle(pr$prepared, pr$corpus, pr$bibliography)
  expect_lte(nrow(ev$terminos$datos), 25L)
  expect_gte(ev$terminos$filas_totales, ev$terminos$filas_incluidas)
})
