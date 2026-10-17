# Importacion real de libros Excel (se omite si faltan readxl o writexl).

libro_prueba <- function() {
  skip_if_not_installed("readxl"); skip_if_not_installed("writexl")
  practica <- utils::read.csv2(practica_path(), stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8")
  practica$ID <- sprintf("%03d", seq_len(nrow(practica)))
  repetida <- practica; names(repetida)[names(repetida) == "Abstract"] <- "Title"
  ruta <- withr::local_tempfile(fileext = ".xlsx", .local_envir = parent.frame())
  writexl::write_xlsx(list(Datos = practica, Duplicados = repetida), ruta)
  list(path = ruta, data = practica)
}

test_that("un libro XLSX se importa como texto conservando los ceros iniciales", {
  x <- libro_prueba()
  d <- read_biblio_file(x$path, "libro.xlsx")
  expect_equal(nrow(d), nrow(x$data))
  expect_equal(d$ID, x$data$ID)
  expect_equal(d$ID[1], "001")
  expect_identical(attr(d, "source_md5"), unname(tools::md5sum(x$path)))
  info <- attr(d, "import_info")
  expect_equal(info$format, "xlsx")
  expect_equal(info$sheet, "Datos")
  expect_setequal(info$sheets, c("Datos", "Duplicados"))
  expect_true(all(is.character(unlist(d[1, ]))))
})

test_that("los encabezados repetidos se corrigen y se registran", {
  x <- libro_prueba()
  d <- read_biblio_file(x$path, "libro.xlsx", sheet = "Duplicados")
  expect_equal(sum(startsWith(names(d), "Title")), 2L)
  expect_false(anyDuplicated(names(d)) > 0L)
  h <- attr(d, "import_info")$headers
  expect_true(any(h$corregido))
})

test_that("una hoja inexistente o un libro danado producen errores claros", {
  x <- libro_prueba()
  expect_error(read_biblio_file(x$path, "libro.xlsx", sheet = "NoExiste"), "ya no existe")
  malo <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("esto no es un libro de Excel", malo)
  expect_error(read_biblio_file(malo, "malo.xlsx"))
})

test_that("un libro Excel recorre la preparacion igual que el CSV equivalente", {
  x <- libro_prueba()
  d <- read_biblio_file(x$path, "libro.xlsx")
  m <- guess_columns(d)
  p <- prepare_documents(d, m)
  csv <- practica()
  expect_equal(nrow(p$documents), nrow(csv$prepared$documents))
  expect_equal(p$documents$title, csv$prepared$documents$title)
  expect_equal(sum(is.na(p$documents$citations)), 3L)
})
