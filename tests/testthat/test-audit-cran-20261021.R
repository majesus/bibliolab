test_that("el CSV rechaza encabezados vacios antes de que fread los invente", {
  for (txt in c(";b\n1;2", "a;\n1;2", "a;;c\n1;2;3", "a;   ;c\n1;2;3", "NA;NA\n1;2")) {
    p <- withr::local_tempfile(fileext = ".csv")
    writeBin(charToRaw(txt), p)
    expect_error(read_biblio_csv(p, ";"), "encabezados", ignore.case = TRUE)
    expect_error(read_biblio_csv(p, "auto"), "encabezados", ignore.case = TRUE)
  }
  p <- withr::local_tempfile(fileext = ".csv")
  writeBin(charToRaw("V1;NA\n001;value"), p)
  expect_identical(names(read_biblio_csv(p, ";")), c("V1", "NA"))
  expect_identical(read_biblio_csv(p, ";")$V1, "001")
})

test_that("la seleccion LDA no trunca parametros fraccionarios", {
  skip_if_not_installed("topicmodels")
  skip_if_not_installed("slam")
  pr <- practica()
  for (value in list(2.9, NA_real_, Inf, "2", numeric()))
    expect_error(lda_select_k(pr$corpus, k_range = value, iterations = 100), "entero")
  for (value in list(1.9, NA_real_, Inf, "1", 2^31, numeric()))
    expect_error(lda_select_k(pr$corpus, k_range = 2L, seeds = value, iterations = 100), "entera")
})
