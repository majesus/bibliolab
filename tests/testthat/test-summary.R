test_that("biblio_summary cuenta documentos y citas validas", {
  ov <- practica()$bibliography$overview
  expect_s3_class(ov, "data.frame")
  valor <- stats::setNames(ov[[2]], ov[[1]])
  expect_equal(unname(valor["Documentos analizados"]), 24)
  expect_equal(unname(valor["Documentos con citas válidas"]), 21)
})

test_that("el indice h se calcula con las citas validas del corpus", {
  d <- data.frame(Title = paste("Documento", 1:6), Abstract = paste("texto sobre educacion", 1:6),
    Year = as.character(2018:2023), `Cited by` = c("10", "8", "5", "4", "3", "0"),
    DOI = paste0("10.1/", 1:6), check.names = FALSE, stringsAsFactors = FALSE)
  p <- prepare_documents(d, guess_columns(d))
  ov <- biblio_summary(p)$overview
  h <- ov[[2]][grepl("ndice h", ov[[1]])]
  expect_equal(h, 4)   # cuatro publicaciones con al menos 4 citas
})

test_that("la produccion anual cubre los anos del corpus", {
  anual <- practica()$bibliography$annual
  expect_s3_class(anual, "data.frame")
  expect_equal(sum(anual[[2]]), 24)
})
