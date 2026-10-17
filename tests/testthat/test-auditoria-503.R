# Regresiones de la auditoria de la version 5.0.2 (R02-R13 y R18). Cada bloque reproduce el
# defecto con una entrada minima y comprueba el comportamiento corregido, no su implementacion.

# ---- Utilidades de integridad -------------------------------------------------
test_that("normalize_unicode unifica NFC/NFD, conserva NA y nombres e ignora UTF-8 invalido", {
  # Cadenas UTF-8 marcadas de forma explicita: en un locale no UTF-8 el literal "\u0301" no queda marcado.
  utf8 <- function(bytes) { x <- rawToChar(as.raw(bytes)); Encoding(x) <- "UTF-8"; x }
  nfd <- utf8(c(0x63, 0x61, 0x66, 0x65, 0xcc, 0x81)); nfc <- utf8(c(0x63, 0x61, 0x66, 0xc3, 0xa9))
  expect_false(identical(charToRaw(nfd), charToRaw(nfc)))
  expect_identical(charToRaw(normalize_unicode(nfd)), charToRaw(nfc))
  x <- c(a = "plain", b = NA, c = nfd)
  y <- normalize_unicode(x)
  expect_identical(names(y), names(x))
  expect_true(is.na(y[["b"]]))
  expect_identical(charToRaw(y[["c"]]), charToRaw(nfc))
  invalido <- rawToChar(as.raw(c(0x61, 0xff, 0x62))); Encoding(invalido) <- "UTF-8"
  expect_identical(charToRaw(normalize_unicode(invalido)), charToRaw(invalido))
  expect_identical(normalize_unicode(character()), character())
})

test_that("num_literal devuelve la representacion mas corta que recupera el doble exacto", {
  v <- c(1 / 3, 0.1, 50 / 7, 1e-5, 12345.6789, .Machine$integer.max, 2 / 3 * 1e10)
  lit <- num_literal(v)
  expect_identical(vapply(lit, function(s) eval(parse(text = s)), 0, USE.NAMES = FALSE), v)
  expect_identical(num_literal(0.1), "0.1")
  expect_identical(num_literal(NA_real_), "NA_real_")
})

test_that("content_digest distingue NA, cadena vacia y 'NA' y no depende de la marca de codificacion", {
  d <- function(x) bibliolab:::content_digest(list(x = x))
  expect_false(identical(d(NA_character_), d("")))
  expect_false(identical(d(NA_character_), d("NA")))
  latin <- iconv("caf\u00e9", "UTF-8", "latin1")
  expect_identical(d(latin), d("caf\u00e9"))
  expect_false(identical(d(c("ab", "c")), d(c("a", "bc"))))
  expect_identical(d(c(1, 2)), d(c(1, 2)))
  expect_false(identical(d(c(1, 2)), d(c(2, 1))))
})

# ---- R03: deduplicacion independiente del orden --------------------------------
crudo_triple <- function(orden = 1:3) {
  base <- data.frame(ID = c("A", "B", "C"),
    Title = "A comprehensive study of collaboration networks in science",
    Abstract = "networks science collaboration analysis",
    Year = c(NA, 2019, 2021), Source = "J", Authors = "Autor Uno; Autor Dos", `Cited by` = 1:3,
    `Author Keywords` = "k1; k2", DOI = c("", "10.1/b", "10.1/c"), Language = "en",
    check.names = FALSE, stringsAsFactors = FALSE)
  out <- base[orden, ]; rownames(out) <- NULL; out
}

test_that("permutar el orden no cambia el conjunto de obras ante una coincidencia ambigua", {
  claves <- function(orden) {
    raw <- crudo_triple(orden)
    p <- prepare_documents(raw, guess_columns(raw))
    sort(paste(p$documents$original_id, p$documents$doi, p$documents$year))
  }
  permutaciones <- list(1:3, c(1, 3, 2), c(2, 1, 3), c(2, 3, 1), c(3, 1, 2), c(3, 2, 1))
  res <- lapply(permutaciones, claves)
  expect_true(all(vapply(res, length, 1L) == 3L))
  expect_true(all(vapply(res, identical, TRUE, res[[1]])))
  raw <- crudo_triple()
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 3L)
  expect_equal(nrow(p$duplicates), 0L)
  expect_true(any(grepl("Varias coincidencias", p$ambiguous$motivo)))
})

test_that("un duplicado inequivoco completa el anio y el DOI del registro conservado y lo registra", {
  raw <- crudo_triple()[1:2, ]
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 1L)
  expect_equal(p$documents$year, 2019)
  expect_equal(p$documents$doi, "10.1/b")
  expect_match(p$duplicates$campos_completados, "a\u00f1o")
  expect_match(p$duplicates$campos_completados, "doi")
  # Con deduplicacion desactivada no se toca ningun campo.
  cfg <- utils::modifyList(default_config(), list(deduplicate = FALSE))
  q <- prepare_documents(raw, guess_columns(raw), cfg)
  expect_equal(nrow(q$documents), 2L)
  expect_true(is.na(q$documents$year[q$documents$original_id == "A"]))
})

test_that("tres copias compatibles se reducen a una sola obra", {
  raw <- crudo_triple(); raw$Year <- 2020; raw$DOI <- ""
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 1L)
  expect_equal(nrow(p$duplicates), 2L)
})

# ---- R04: equivalencias Unicode -------------------------------------------------
test_that("las formas NFC y NFD de una palabra forman un unico termino", {
  raw <- data.frame(ID = 1:3, Title = c("Primero uno", "Segundo dos", "Tercero tres"),
    Abstract = c("el caf\u00e9 caliente sabe bien", "el cafe\u0301 frio sabe mal", "otro texto distinto cualquiera"),
    Year = 2020:2022, Source = "J", Authors = "A", `Cited by` = 1L, `Author Keywords` = "k", DOI = c("a", "b", "c"),
    Language = "es", check.names = FALSE, stringsAsFactors = FALSE)
  p <- prepare_documents(raw, guess_columns(raw))
  cp <- prepare_corpus(p)
  terminos <- cp$terms$termino
  expect_equal(sum(grepl("^caf", terminos)), 1L)
  fila <- cp$terms[cp$terms$termino == "caf\u00e9", ]
  expect_equal(fila$frecuencia, 2)
  expect_equal(fila$documentos, 2)
  # Una marca combinante sin forma precompuesta forma parte de la palabra y no la parte.
  cfg <- default_config(); cfg$min_chars <- 1L
  q <- bibliolab:::tokenize_one("x\u0301y z cafe\u0301", cfg, character())[[1]]
  expect_length(q, 3L)
  expect_identical(charToRaw(q[3]), charToRaw("caf\u00e9"))
  expect_identical(charToRaw(q[1]), charToRaw("x\u0301y"))
})

# ---- R05: coherencia entre insumos y huellas ----------------------------------
test_that("una entrada original con otro contenido se rechaza antes de crear la entrega", {
  pr <- practica()
  raw <- pr$raw
  col <- pr$mapping$text
  idx <- which(nzchar(raw[[col]]))[1:2]
  raw[[col]][idx] <- rev(raw[[col]][idx])
  attr(raw, "source_md5") <- attr(pr$raw, "source_md5")
  destino <- file.path(withr::local_tempdir(), "entrega")
  expect_error(export_bundle(destino, pr$prepared, pr$corpus, pr$bibliography, raw = raw), "no reproduce los documentos")
  expect_false(dir.exists(destino))
})

test_that("el script de reproduccion se detiene si entrada_original.rds es otro contenido", {
  skip_on_cran()
  pr <- practica()
  dir <- file.path(withr::local_tempdir(), "huella")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw)
  script <- readLines(file.path(dir, "reproducir_analisis.R"), encoding = "UTF-8", warn = FALSE)
  expect_true(any(grepl("verify_reproduction(raw_fingerprint(datos)", script, fixed = TRUE)))
  expect_true(any(grepl("verify_reproduction(documents_fingerprint(preparado$documents)", script, fixed = TRUE)))
  expect_true(any(grepl("verify_reproduction(corpus_fingerprint(corpus)", script, fixed = TRUE)))
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_true(all(c("entrada", "documentos", "matriz") %in% names(par$entrega$huellas)))
  alterado <- readRDS(file.path(dir, "entrada_original.rds"))
  col <- pr$mapping$text
  alterado[[col]][1] <- paste(alterado[[col]][1], "palabra adicional")
  saveRDS(alterado, file.path(dir, "entrada_original.rds"))
  salida <- ejecutar_rscript("reproducir_analisis.R", dir)
  expect_false(is.null(attr(salida, "status")))
  expect_match(paste(salida, collapse = "\n"), "no coincide con la entrega")
})

test_that("corpus_fingerprint es canonico y detecta cambios de terminos con las mismas dimensiones", {
  cp <- practica()$corpus
  huella <- corpus_fingerprint(cp)
  perm <- cp
  perm$counts <- cp$counts[rev(seq_len(nrow(cp$counts))), rev(seq_len(ncol(cp$counts)))]
  expect_identical(corpus_fingerprint(perm), huella)
  renombrado <- cp
  colnames(renombrado$counts)[1] <- "otro_termino"
  expect_false(identical(corpus_fingerprint(renombrado), huella))
  cambiado <- cp
  cambiado$counts@x[1] <- cambiado$counts@x[1] + 1
  expect_false(identical(corpus_fingerprint(cambiado), huella))
})

# ---- R06: requisitos por resultado ----------------------------------------------
test_that("la sensibilidad guardada se reproduce sin el modelo final de densidad", {
  skip_on_cran()
  skip_if_not(all(vapply(c("uwot", "dbscan", "irlba"), requireNamespace, TRUE, quietly = TRUE)))
  pr <- practica()
  sens <- density_sensitivity(pr$corpus, pr$prepared, list(neighbors = 5L, min_pts = 3L), seeds = 1L, neighbors = 5L, min_pts = 3L)
  dir <- file.path(withr::local_tempdir(), "sens")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, density_sens = sens)
  script <- paste(readLines(file.path(dir, "reproducir_diagnosticos.R"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_false(grepl("r$densidad", script, fixed = TRUE))
  expect_null(attr(ejecutar_rscript("reproducir_analisis.R", dir), "status"))
  salida <- ejecutar_rscript("reproducir_diagnosticos.R", dir)
  expect_null(attr(salida, "status"), info = paste(utils::tail(salida, 5), collapse = "\n"))
  expect_match(paste(salida, collapse = "\n"), "Sensibilidad de UMAP \\+ HDBSCAN: coincide con la entrega")
})

test_that("una comparacion por temas LDA se entrega sin lda y se declara la comprobacion omitida", {
  skip_on_cran()
  skip_if_not_installed("topicmodels")
  pr <- practica()
  lda <- run_lda(pr$corpus, k = 3, iterations = 100L)
  grupos <- data.frame(doc_id = lda$document_topics$doc_id,
    valor = paste("Tema", max.col(as.matrix(lda$document_topics[-1]), ties.method = "first")), stringsAsFactors = FALSE)
  cat_ab <- names(sort(table(grupos$valor), decreasing = TRUE))[1:2]
  comp <- run_comparison(pr$corpus, pr$prepared, list(mode = "lda", category_A = cat_ab[1], category_B = cat_ab[2], B = 50L), grouping = grupos)
  dir <- file.path(withr::local_tempdir(), "comp")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, comparison = comp)
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_match(unlist(par$entrega$comprobaciones_omitidas), "origen LDA")
  script <- paste(readLines(file.path(dir, "reproducir_analisis.R"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_false(grepl("stopifnot(!is.null(lda))", script, fixed = TRUE))
  expect_no_error(parse(file.path(dir, "reproducir_analisis.R")))
  salida <- ejecutar_rscript("reproducir_analisis.R", dir)
  expect_null(attr(salida, "status"), info = paste(utils::tail(salida, 5), collapse = "\n"))
  reproducido <- readRDS(file.path(dir, "resultados_reproducidos.rds"))
  expect_equal(reproducido$comparacion$jsd, comp$jsd)
})

test_that("una sensibilidad con vectores sin sus vectores se declara insumo faltante", {
  skip_on_cran()
  pr <- practica()
  falso <- list(params = list(base = list(representation = "vectors")), reference = list(input_vectors = NULL),
    runs = data.frame(tipo = "Referencia", estado = "ejecutada"), summary = data.frame(indicador = "x", valor = 1), reading = "x")
  dir <- file.path(withr::local_tempdir(), "vec")
  expect_warning(export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, density_sens = falso), "parcial")
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_false(par$entrega$reproducible)
  expect_match(paste(unlist(par$entrega$insumos_faltantes), collapse = " "), "vectores de la sensibilidad")
})

# ---- R07: alpha como funcion con entorno ----------------------------------------
test_that("la regla de alpha se registra como valores efectivos y se reproduce sin el entorno original", {
  skip_if_not_installed("topicmodels")
  pr <- practica()
  coeficiente <- 4
  regla <- function(k) coeficiente / k
  sel <- lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L, alpha = regla)
  expect_equal(sel$params$alpha_regla, "funcion")
  expect_equal(sel$params$alpha_por_k$alpha, c(2, 4 / 3))
  codigo <- bibliolab:::alpha_literal(sel$params)
  rm(coeficiente)
  evaluada <- eval(parse(text = codigo))
  expect_true(is.function(evaluada))
  expect_equal(evaluada(2L), 2)
  expect_equal(evaluada(3L), 4 / 3)
  sel1 <- lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L)
  expect_identical(bibliolab:::alpha_literal(sel1$params), "NULL")
  expect_equal(sel1$params$alpha_regla, "1/k")
  const <- lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L, alpha = 0.3)
  expect_equal(eval(parse(text = bibliolab:::alpha_literal(const$params))), 0.3)
  expect_error(lda_select_k(pr$corpus, k_range = 2:3, seeds = 1L, iterations = 100L, alpha = function(k) -1), "alpha")
})

# ---- R08: semillas derivadas sin desbordamiento ---------------------------------
test_that("derive_seed permanece en el rango entero con la semilla maxima", {
  s <- derive_seed(.Machine$integer.max, 0:3)
  expect_false(anyNA(s))
  expect_true(all(s >= 1L & s <= .Machine$integer.max))
  expect_equal(length(unique(s)), 4L)
})

mapeo_503 <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
  col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
  language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)

test_that("la seleccion de k de la interfaz usa semillas derivadas validas con la semilla maxima", {
  skip_on_cran()
  skip_if_not(all(vapply(c("DT", "plotly", "visNetwork"), requireNamespace, TRUE, quietly = TRUE)))
  skip_if_not_installed("topicmodels")
  capturadas <- NULL
  testthat::local_mocked_bindings(
    lda_select_k = function(corpus, k_range, seeds, ...) { capturadas <<- seeds; stop("detenido tras capturar las semillas") },
    .package = "bibliolab")
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_503)
    session$setInputs(prepare = 1)
    session$setInputs(lda_seed = .Machine$integer.max, kselect_seeds = 2L, kselect_min = 2L, kselect_max = 3L, iterations = 100L)
    try(session$setInputs(run_kselect = 1), silent = TRUE)
  })
  expect_false(is.null(capturadas))
  expect_false(anyNA(capturadas))
  expect_true(all(capturadas >= 1L))
})

# ---- R09: espaciado frente a iteraciones --------------------------------------
test_that("run_lda rechaza un espaciado mayor que las iteraciones antes de llamar al motor", {
  skip_if_not_installed("topicmodels")
  pr <- practica()
  expect_error(run_lda(pr$corpus, k = 3, iterations = 100L, thin = 1000L), "espaciado")
  expect_no_error(run_lda(pr$corpus, k = 2, iterations = 100L, thin = 100L))
})

# ---- R10: NPMI sin variacion ----------------------------------------------------
test_that("la NPMI no premia pares de terminos presentes en todos los documentos", {
  beta <- matrix(c(.5, .3, .2, 0, .1, .1, .1, .7), nrow = 2, byrow = TRUE, dimnames = list(NULL, c("a", "b", "c", "d")))
  universal <- Matrix::Matrix(matrix(1, 4, 4, dimnames = list(paste0("u", 1:4), c("a", "b", "c", "d"))), sparse = TRUE)
  r <- bibliolab:::topic_coherence(beta, universal, top_n = 3L)
  expect_true(all(is.na(r$npmi)))
  expect_equal(unname(r$pairs), c(0, 0))
  variado <- Matrix::Matrix(matrix(c(1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1), 4, 4, byrow = TRUE,
    dimnames = list(paste0("u", 1:4), c("a", "b", "c", "d"))), sparse = TRUE)
  v <- bibliolab:::topic_coherence(beta, variado, top_n = 3L)
  expect_true(all(is.finite(v$npmi)))
  expect_true(all(v$npmi <= 1) && all(v$pairs > 0))
  expect_true(is.na(bibliolab:::mean_finite(c(NA, NaN))))
  expect_equal(bibliolab:::mean_finite(c(NA, 1, 3)), 2)
})

test_that("un corpus sin variacion lo declara en la lectura y no recomienda un k por NPMI", {
  skip_if_not_installed("topicmodels")
  pr <- practica()
  universal <- pr$corpus
  universal$counts <- universal$counts[, seq_len(6L)]
  universal$counts[] <- 1
  fit <- run_lda(universal, k = 2, iterations = 100L)
  expect_true(all(is.na(fit$diagnostics$topics$coherencia_npmi)))
  expect_true("pares_npmi" %in% names(fit$diagnostics$topics))
  lectura <- paste(bibliolab:::lda_quality_reading(fit)$Lectura, collapse = " ")
  expect_match(lectura, "NPMI no es informativa")
})

# ---- R11: sensibilidad sin grupos -----------------------------------------------
test_that("sin grupos en la referencia la lectura no habla de estabilidad excelente", {
  skip_on_cran()
  skip_if_not(all(vapply(c("uwot", "dbscan", "irlba"), requireNamespace, TRUE, quietly = TRUE)))
  pr <- practica()
  s <- density_sensitivity(pr$corpus, pr$prepared, list(neighbors = 5L, min_pts = 23L), seeds = 1:2, neighbors = 5L, min_pts = 23L)
  expect_equal(s$runs$grupos[s$runs$tipo == "Referencia"], 0L)
  expect_true(is.na(s$runs$ari_asignados[s$runs$tipo == "Referencia"]))
  expect_equal(s$runs$ari[s$runs$tipo == "Referencia"], 1)
  expect_false(grepl("excelente", s$reading))
  expect_match(s$reading, "misma ausencia de grupos")
  # Con grupos, la lectura conserva la banda de estabilidad.
  c3 <- density_sensitivity(pr$corpus, pr$prepared, list(neighbors = 5L, min_pts = 3L), seeds = 1L, neighbors = 5L, min_pts = 3L)
  expect_match(c3$reading, "Estabilidad entre semillas")
  expect_equal(c3$runs$ari_asignados[c3$runs$tipo == "Referencia"], 1)
})

# ---- R12: denominadores de los indicadores de preparacion -----------------------
test_that("el corpus distingue tokens tras la limpieza, tokens en el modelo y unidades efectivas", {
  pr <- practica()
  cfg <- utils::modifyList(pr$prepared$config, list(min_df = 7L))
  p7 <- prepare_documents(pr$raw, pr$mapping, cfg)
  c7 <- prepare_corpus(p7)
  expect_equal(c7$tokens_in_model, sum(c7$counts))
  expect_lt(c7$tokens_in_model, c7$total_tokens)
  expect_equal(c7$units_in_model, nrow(c7$counts))
  expect_true(any(grepl("dentro del vocabulario de los modelos", c7$issues, fixed = TRUE)))
  expect_true(any(grepl(as.character(c7$tokens_in_model), c7$issues, fixed = TRUE)))
  vacio <- prepare_corpus(prepare_documents(pr$raw, pr$mapping, utils::modifyList(pr$prepared$config, list(min_df = 10000L))))
  expect_equal(vacio$tokens_in_model, 0)
  expect_equal(vacio$units_in_model, 0L)
})

# ---- R13: fila actual en el diagnostico de vocabulario ---------------------------
test_that("el diagnostico de vocabulario conserva la fila actual aunque el vocabulario quede vacio", {
  pr <- practica()
  cfg <- utils::modifyList(pr$prepared$config, list(min_df = 10000L))
  p <- prepare_documents(pr$raw, pr$mapping, cfg)
  cp <- prepare_corpus(p)
  d <- vocabulary_diagnostics(cp, p)
  fila <- d$sensitivity[d$sensitivity$actual, , drop = FALSE]
  expect_equal(nrow(fila), 1L)
  expect_equal(fila$presencia_minima, 10000L)
  expect_equal(fila$terminos, 0)
  base <- vocabulary_diagnostics(pr$corpus, pr$prepared)
  expect_equal(sum(base$sensitivity$actual), 1L)
})

# ---- R18: verificacion estricta del manifiesto -------------------------------------
test_that("verify_bundle rechaza manifiestos ilegibles, vacios o con rutas improcedentes", {
  dir <- withr::local_tempdir()
  writeLines("contenido", file.path(dir, "a.txt"))
  manifiesto <- file.path(dir, "manifiesto_archivos.csv")
  escribir <- function(df) utils::write.csv(df, manifiesto, row.names = FALSE)
  md5 <- unname(tools::md5sum(file.path(dir, "a.txt")))
  bueno <- data.frame(archivo = "a.txt", bytes = file.size(file.path(dir, "a.txt")), md5 = md5, stringsAsFactors = FALSE)
  escribir(bueno)
  expect_true(all(verify_bundle(dir)$estado == "correcto"))
  escribir(bueno[0, ]); expect_error(verify_bundle(dir), "manifiesto")
  escribir(data.frame(archivo = "a.txt")); expect_error(verify_bundle(dir), "manifiesto")
  for (ruta in c("../a.txt", "/etc/passwd", "", "manifiesto_archivos.csv")) {
    malo <- bueno; malo$archivo <- ruta; escribir(malo)
    expect_error(verify_bundle(dir), "manifiesto|ruta", info = paste("ruta:", ruta))
  }
  duplicado <- rbind(bueno, bueno); escribir(duplicado); expect_error(verify_bundle(dir), "manifiesto|duplicad")
  malo <- bueno; malo$md5 <- "no-es-md5"; escribir(malo); expect_error(verify_bundle(dir), "manifiesto|MD5")
  malo <- bueno; malo$bytes <- bueno$bytes + 1; escribir(malo)
  expect_equal(verify_bundle(dir)$estado, "modificado")
  writeBin(as.raw(c(0xff, 0xfe, 0x00)), manifiesto)
  expect_error(verify_bundle(dir), "manifiesto")
})

# ---- Publicacion alternativa de la entrega ----------------------------------------
test_that("si no se puede renombrar la carpeta, la entrega se publica por copia y se verifica", {
  skip_on_cran()
  pr <- practica()
  padre <- withr::local_tempdir()
  destino <- file.path(padre, "entrega")
  testthat::local_mocked_bindings(publish_directory = function(from, to) FALSE, .package = "bibliolab")
  export_bundle(destino, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw)
  expect_true(all(verify_bundle(destino)$estado == "correcto"))
  expect_equal(list.files(padre), "entrega")
})

# ---- R02: ggrepel opcional -----------------------------------------------------------
test_that("las figuras con etiquetas se dibujan sin ggrepel", {
  pr <- practica()
  ca <- run_ca(pr$corpus)
  testthat::local_mocked_bindings(pkg_available = function(pkg) if (identical(pkg, "ggrepel")) FALSE else requireNamespace(pkg, quietly = TRUE), .package = "bibliolab")
  capa <- bibliolab:::label_layer(data.frame(x = 1, y = 1, l = "a"), ggplot2::aes(x, y, label = l))
  expect_s3_class(capa$geom, "GeomText")
  g <- ordination_figure(ca$terms, ca$dimensions, "CA sin ggrepel")
  archivo <- withr::local_tempfile(fileext = ".png")
  ggplot2::ggsave(archivo, g, width = 6, height = 5, dpi = 60)
  expect_gt(file.size(archivo), 1000)
  expect_false(any(vapply(g$layers, function(l) inherits(l$geom, "GeomTextRepel"), TRUE)))
})

test_that("con ggrepel instalado la capa de etiquetas usa el reposicionamiento", {
  skip_if_not_installed("ggrepel")
  capa <- bibliolab:::label_layer(data.frame(x = 1, y = 1, l = "a"), ggplot2::aes(x, y, label = l))
  expect_s3_class(capa$geom, "GeomTextRepel")
})

# ---- R16: licencia y procedencia de los modelos UDPipe --------------------------------
test_that("la descarga de un modelo avisa de su licencia antes de intentar descargarlo", {
  skip_if_not_installed("udpipe")
  src <- bibliolab:::udpipe_model_source()
  expect_identical(src$licencia, "CC BY-NC-SA 4.0")
  expect_match(src$url, "udpipe.models.ud.2.5", fixed = TRUE)
  aviso <- bibliolab:::model_license_notice()
  expect_match(aviso, "CC BY-NC-SA 4.0", fixed = TRUE)
  expect_match(aviso, "MIT", fixed = TRUE)
  testthat::local_mocked_bindings(udpipe_download_model = function(...) data.frame(download_failed = TRUE, file_model = NA_character_), .package = "udpipe")
  directorio <- withr::local_tempdir()
  expect_message(
    expect_error(download_language_model("es", directory = directorio), "No se ha podido descargar"),
    "CC BY-NC-SA 4.0", fixed = TRUE)
  expect_length(list.files(directorio), 0L)
})

# ---- R17: metricas de autor en una pasada y JSD por lotes -----------------------------
test_that("las citas por autor coinciden con un calculo manual independiente", {
  raw <- data.frame(ID = 1:4, Title = paste("Titulo distinto numero", 1:4, "para la prueba"),
    Abstract = paste("texto", c("uno", "dos", "tres", "cuatro"), "alfa beta"), Year = 2020:2023, Source = "J",
    Authors = c("Ana A; Beto B", "Ana A", "Beto B; Carla C", "Ana A; Ana A"), `Cited by` = c(10, 3, NA, 1),
    `Author Keywords` = "k", DOI = paste0("10/", 1:4), Language = "es", check.names = FALSE, stringsAsFactors = FALSE)
  p <- prepare_documents(raw, guess_columns(raw))
  m <- bibliolab:::author_citation_metrics(p, biblio_summary(p)$authors)
  fila <- function(nombre) m[grepl(nombre, m$elemento, ignore.case = TRUE), , drop = FALSE]
  a <- fila("Ana"); b <- fila("Beto"); c <- fila("Carla")
  expect_equal(c(a$citas_validas, a$citas_ausentes, a$citas_suma, a$h_corpus), c(3, 0, 14, 2))
  expect_equal(c(b$citas_validas, b$citas_ausentes, b$citas_suma, b$h_corpus), c(1, 1, 10, 1))
  expect_equal(c(c$citas_validas, c$citas_ausentes), c(0, 1))
  expect_true(is.na(c$citas_suma) && is.na(c$h_corpus))
})

test_that("jsd_uncertainty por lotes reproduce el algoritmo de referencia con la misma semilla", {
  referencia <- function(W, ia, ib, B, seed) {
    pool <- c(ia, ib); na <- length(ia); n <- length(pool); Wp <- W[pool, , drop = FALSE]; total <- colSums(Wp)
    bibliolab:::with_seed(seed, {
      S <- matrix(0, B, n); for (b in seq_len(B)) S[b, sample.int(n, na)] <- 1
      Ap <- S %*% Wp; null <- bibliolab:::jsd_rows(Ap, pmax(matrix(total, B, ncol(Wp), byrow = TRUE) - Ap, 0))
      boot <- function(idx) { M <- matrix(0, B, length(idx)); for (b in seq_len(B)) M[b, ] <- tabulate(sample.int(length(idx), length(idx), replace = TRUE), length(idx)); M %*% W[idx, , drop = FALSE] }
      list(null = null, boot = bibliolab:::jsd_rows(boot(ia), boot(ib)))
    })
  }
  set.seed(2)
  W <- matrix(rpois(60 * 25, .6), 60, 25)
  ref <- referencia(W, 1:25, 26:60, 80L, 9L)
  got <- jsd_uncertainty(W, 1:25, 26:60, B = 80L, seed = 9L)
  expect_equal(got$null_mean, mean(ref$null[is.finite(ref$null)]))
  expect_equal(got$ci, as.numeric(stats::quantile(ref$boot[is.finite(ref$boot)], c(.025, .975))))
  expect_equal(got$p_value, (1 + sum(ref$null[is.finite(ref$null)] >= got$observed - 1e-12)) / (sum(is.finite(ref$null)) + 1))
})

# ---- Validacion de la configuracion -------------------------------------------------------
test_that("prepare_documents rechaza claves desconocidas y opciones logicas invalidas", {
  pr <- practica()
  prep <- function(cfg) prepare_documents(pr$raw, pr$mapping, cfg)
  expect_error(prep(list(deduplicar = TRUE)), "desconocidas.*deduplicar")
  expect_error(prep(list(deduplicat = TRUE)), "deduplicate")
  for (opcion in c("deduplicate", "remove_stop", "remove_numbers", "split_sentences", "normalize_labels", "lemmatize")) {
    cfg <- list(); cfg[[opcion]] <- NA
    expect_error(prep(cfg), opcion, fixed = TRUE, info = paste("NA en", opcion))
  }
  expect_error(prep(list(remove_stop = 1)), "remove_stop", fixed = TRUE)
  expect_error(prep(list(remove_stop = c(TRUE, FALSE))), "remove_stop", fixed = TRUE)
  expect_no_error(prep(list(min_df = 3L, normalize_labels = FALSE)))
})

# ---- R02: descarga del ZIP con graficos que fallan o sin ggrepel -----------------------------------
zip_de_la_aplicacion <- function() {
  raw <- practica_raw()
  out <- NULL
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_503)
    session$setInputs(prepare = 1)
    out <<- output$download_zip
    carpeta <- withr::local_tempdir(.local_envir = parent.frame())
    utils::unzip(out, exdir = carpeta)
    out <<- carpeta
  })
  out
}

test_that("un grafico que falla no aborta el ZIP: se omite y se registra", {
  skip_on_cran()
  skip_if_not(all(vapply(c("DT", "plotly", "visNetwork", "zip"), requireNamespace, TRUE, quietly = TRUE)))
  testthat::local_mocked_bindings(swiss_theme = function(...) stop("fallo simulado de figura"), .package = "bibliolab")
  carpeta <- zip_de_la_aplicacion()
  archivos <- list.files(carpeta)
  expect_true(all(c("graficos_omitidos.csv", "LEEME.txt", "manifiesto_archivos.csv", "parametros.json") %in% archivos))
  omitidos <- utils::read.csv(file.path(carpeta, "graficos_omitidos.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
  expect_gt(nrow(omitidos), 0L)
  expect_true(all(grepl("fallo simulado", omitidos$motivo)))
  expect_false(any(file.exists(file.path(carpeta, paste0(omitidos$grafico, ".png")))))
  leeme <- paste(readLines(file.path(carpeta, "LEEME.txt"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(leeme, "OMITIDOS")
  # El manifiesto se regenera despues de anadir el registro de omisiones.
  expect_true(all(verify_bundle(carpeta)$estado == "correcto"))
})

test_that("el ZIP incluye los graficos con etiquetas aunque ggrepel no este instalado", {
  skip_on_cran()
  skip_if_not(all(vapply(c("DT", "plotly", "visNetwork", "zip"), requireNamespace, TRUE, quietly = TRUE)))
  testthat::local_mocked_bindings(pkg_available = function(pkg) if (identical(pkg, "ggrepel")) FALSE else requireNamespace(pkg, quietly = TRUE), .package = "bibliolab")
  carpeta <- zip_de_la_aplicacion()
  archivos <- list.files(carpeta)
  expect_false("graficos_omitidos.csv" %in% archivos)
  expect_true(all(c("seleccion_vocabulario.png", "palabras.png") %in% archivos))
  expect_true(all(verify_bundle(carpeta)$estado == "correcto"))
})

# ---- Cuaderno de lectura: figura del grafo sin ggrepel ---------------------------------------------
test_that("el grafo del cuaderno se dibuja sin ggrepel", {
  skip_if_not_installed("igraph")
  pr <- practica()
  idx <- build_wiki_index(pr$prepared, pr$corpus)
  g <- wiki_local_graph(idx, idx$concepts$key[1])
  testthat::local_mocked_bindings(pkg_available = function(pkg) if (identical(pkg, "ggrepel")) FALSE else requireNamespace(pkg, quietly = TRUE), .package = "bibliolab")
  f <- wiki_graph_figure(g)
  archivo <- withr::local_tempfile(fileext = ".png")
  ggplot2::ggsave(archivo, f, width = 6, height = 5, dpi = 60)
  expect_gt(file.size(archivo), 1000)
  expect_false(any(vapply(f$layers, function(l) inherits(l$geom, "GeomTextRepel"), TRUE)))
})
