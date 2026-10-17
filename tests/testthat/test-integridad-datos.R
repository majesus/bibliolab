# Pruebas de regresion con oraculos independientes de la implementacion.

crudo_duplicados <- function() {
  data.frame(ID = 1:6,
    Title = c("Editorial", "Editorial", "A study of networks in science", "A Study of Networks in Science!", "Same title", "Same title"),
    Abstract = c("x one", "x two", "Abstract about networks and science collaboration",
      "Abstract about networks and science collaboration", "aa bb cc dd ee", "aa bb cc dd ee"),
    Year = c(2020, 2025, 2019, 2019, 2018, 2018), Source = "J", Authors = "A; B", `Cited by` = 1:6,
    `Author Keywords` = "k1; k2", DOI = c("", "", "", "10.1/abc", "10.1/x", "10.1/y"), Language = "en",
    check.names = FALSE, stringsAsFactors = FALSE)
}

test_that("la deduplicacion exige evidencia compatible y registra el criterio", {
  raw <- crudo_duplicados()
  p <- prepare_documents(raw, guess_columns(raw))
  # Titulos genericos con anios distintos no son duplicados; DOI distintos tampoco.
  expect_setequal(p$documents$original_id, c("1", "2", "3", "5", "6"))
  expect_equal(p$duplicates$original_id, "4")
  expect_equal(p$duplicates$criterio_duplicado, "Título normalizado")
  expect_equal(p$duplicates$conservado_doc_id, p$documents$doc_id[p$documents$original_id == "3"])
  expect_equal(p$duplicates$conservado_fila, 3L)
  amb <- p$ambiguous
  expect_equal(nrow(amb), 2L)
  expect_setequal(amb$motivo, c("Año distinto", "DOI distinto"))
  expect_equal(p$input_md5, attr(raw, "source_md5"))
})

test_that("un DOI idéntico es decisivo aunque el título difiera", {
  raw <- crudo_duplicados()[c(5, 5), ]
  raw$ID <- 1:2; raw$Title <- c("First wording of the title", "Completely other wording here"); raw$DOI <- "10.1/same"
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 1L)
  expect_equal(p$duplicates$criterio_duplicado, "DOI")
})

test_that("label_key conserva escrituras no latinas y unifica diacriticos", {
  k <- bibliolab:::label_key
  expect_false(identical(k("李 a", "author"), k("王 a", "author")))
  expect_false(identical(k("alpha α", "keyword"), k("alpha β", "keyword")))
  expect_identical(k("José", "author"), k("José", "author"))
  expect_identical(k("José", "author"), "jose")
  expect_true(nzchar(k("—", "keyword")))
})

test_that("las semillas derivadas se mantienen en el rango entero y son distintas", {
  m <- .Machine$integer.max
  s <- bibliolab:::derive_seed(m, 0:5)
  expect_type(s, "integer")
  expect_false(anyNA(s))
  expect_true(all(s >= 1L & s <= m))
  expect_equal(length(unique(s)), 6L)
  expect_equal(bibliolab:::derive_seed(2026L, 0L), 2026L)
})

test_that("with_seed restaura el estado del generador, con o sin semilla previa y tras error", {
  rm_seed <- function() if (exists(".Random.seed", globalenv())) rm(".Random.seed", envir = globalenv())
  set.seed(7); antes <- get(".Random.seed", globalenv())
  bibliolab:::with_seed(99L, stats::runif(3))
  expect_identical(get(".Random.seed", globalenv()), antes)
  try(bibliolab:::with_seed(99L, stop("fallo")), silent = TRUE)
  expect_identical(get(".Random.seed", globalenv()), antes)
  rm_seed()
  bibliolab:::with_seed(99L, stats::runif(3))
  expect_false(exists(".Random.seed", globalenv()))
  # Reproducible: misma semilla, mismo resultado.
  expect_identical(bibliolab:::with_seed(5L, stats::runif(2)), bibliolab:::with_seed(5L, stats::runif(2)))
})

test_that("la FDR de la red documental se calcula sobre toda la familia de pares", {
  skip_if_not_installed("igraph")
  skip_if_not_installed("Matrix")
  n <- 6L; trials <- 8L
  M <- matrix(0, n, trials)
  M[1, c(1, 2, 3)] <- 1; M[2, c(1, 2, 4)] <- 1     # d1-d2 comparten 2 conceptos
  M[3, c(5, 6)] <- 1; M[4, c(5, 7)] <- 1           # d3-d4 comparten 1 concepto
  M[5, 8] <- 1; M[6, c(3, 4)] <- 1
  claves <- paste0("k", seq_len(n))
  indice <- list(
    documents = data.frame(key = claves, doc_id = sprintf("D%02d", seq_len(n)), title = paste("Titulo", seq_len(n)),
      doi = "", stringsAsFactors = FALSE),
    counts = Matrix::Matrix(M, sparse = TRUE),
    concepts = data.frame(label = paste0("c", seq_len(trials)), stringsAsFactors = FALSE))
  # Oraculo independiente: se recorre cada par de la familia completa (15 pares).
  grado <- rowSums(M > 0)
  p_par <- c(); id_par <- c()
  for (i in 1:(n - 1)) for (j in (i + 1):n) {
    sh <- sum(M[i, ] > 0 & M[j, ] > 0)
    p_par <- c(p_par, if (sh == 0) 1 else stats::phyper(sh - 1, grado[i], trials - grado[i], grado[j], lower.tail = FALSE))
    id_par <- c(id_par, paste(i, j))
  }
  ajustado <- stats::setNames(stats::p.adjust(p_par, "BH"), id_par)
  for (m in c(1L, 2L)) {
    red <- bibliolab:::wiki_document_network(indice, min_shared = m, min_similarity = 0)
    if (m == 1L) {
      esperado <- ajustado[c("1 2", "3 4")]
      obtenido <- red$edges$p_adj[match(c("k1 k2", "k3 k4"), paste(red$edges$from, red$edges$to))]
      expect_equal(unname(obtenido), unname(esperado))
    }
    # La p ajustada de d1-d2 no depende del umbral descriptivo de coaparicion.
    fila <- which(red$edges$from == "k1" & red$edges$to == "k2")
    expect_equal(red$edges$p_adj[fila], unname(ajustado["1 2"]))
  }
  # Con alpha, la familia sigue siendo la completa.
  con_alpha <- bibliolab:::wiki_document_network(indice, min_shared = 1L, min_similarity = 0, alpha = 0.5)
  expect_true(all(con_alpha$edges$p_adj <= 0.5))
})

test_that("BM25 valida valores almacenados sin densificar la matriz", {
  skip_if_not_installed("Matrix")
  grande <- Matrix::sparseMatrix(i = c(1L, 20000L), j = c(1L, 100000L), x = c(2, 3), dims = c(20000L, 100000L))
  w <- bibliolab:::bm25_weights(grande)
  expect_s4_class(w, "sparseMatrix")
  expect_equal(dim(w), c(20000L, 100000L))
  expect_equal(length(w@x), 2L)
  invalido <- grande; invalido@x[1] <- -1
  expect_error(bibliolab:::bm25_weights(invalido), "BM25")
  invalido@x[1] <- NA_real_
  expect_error(bibliolab:::bm25_weights(invalido), "BM25")
})
