test_that("el CSV de practica se importa con las columnas esperadas", {
  d <- practica_raw()
  expect_s3_class(d, "data.frame")
  expect_equal(nrow(d), 25L)
  expect_true(all(c("Title", "Abstract", "Year", "DOI") %in% names(d)))
  expect_true(is.character(attr(d, "source_md5")))
})

test_that("las columnas ausentes se leen como NA y no como cero", {
  d <- practica_raw()
  expect_equal(sum(is.na(d[["Cited by"]])), 3L)
})

test_that("read_biblio_csv rechaza archivos vacios, separadores y codificaciones no admitidos", {
  vacio <- withr::local_tempfile(fileext = ".csv")
  file.create(vacio)
  expect_error(read_biblio_csv(vacio), "vac")
  expect_error(read_biblio_csv(practica_path(), sep = "|"), "Separador")
  expect_error(read_biblio_csv(practica_path(), ";", encoding = "ASCII"), "Codificaci")
})

test_that("read_biblio_csv rechaza encabezados repetidos y filas inconsistentes", {
  repetidos <- write_csv_text(c("a;a;b", "1;2;3"))
  expect_error(read_biblio_csv(repetidos, ";"), "nicos")
  inconsistente <- write_csv_text(c("a;b;c", "1;2;3", "4;5"))
  expect_error(read_biblio_csv(inconsistente, ";"))
})

test_that("read_biblio_csv no admite bytes nulos", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(charToRaw("a;b\n1;2\n"), as.raw(0)), path)
  expect_error(read_biblio_csv(path, ";"), "nulos")
})

test_that("read_biblio_csv conserva acentos y respeta la codificacion Latin-1", {
  path <- withr::local_tempfile(fileext = ".csv")
  texto <- "título;año\nEducación;2020\n"
  writeBin(iconv(texto, from = "UTF-8", to = "latin1", toRaw = TRUE)[[1]], path)
  d <- read_biblio_csv(path, ";", encoding = "Latin-1")
  expect_equal(names(d), c("título", "año"))
  expect_equal(d[[1]], "Educación")
})

test_that("guess_columns reconoce encabezados de Web of Science etiquetados", {
  wos <- data.frame(AB = "texto", TI = "titulo", PY = "2020", SO = "Revista", AU = "A", ID = "kp",
    DE = "k", CR = "r", TC = "3", UT = "WOS:1", stringsAsFactors = FALSE)
  g <- guess_columns(wos)
  expect_equal(g$text, "AB")
  expect_equal(g$year, "PY")
  expect_equal(g$id, "UT")      # ID es Keywords Plus en WoS, no el identificador
  expect_equal(g$citations, "TC")
})

test_that("guess_columns reconoce encabezados en espanol y en el CSV de practica", {
  g <- guess_columns(practica_raw())
  expect_equal(g$text, "Abstract")
  expect_equal(g$title, "Title")
  expect_equal(g$year, "Year")
  expect_equal(g$doi, "DOI")
  expect_equal(g$language, "Language")
  g2 <- guess_columns(data.frame(resumen = "x", titulo = "y", ano = "2020", autores = "A"))
  expect_equal(g2$text, "resumen")
  expect_equal(g2$year, "ano")
})
