# Regresiones de la auditoria del 22/10/2026 sobre la version 5.0.5 (fichas BL-01 a BL-05, BL-17 a BL-20,
# BL-23 y siguientes). Cada bloque reproduce el caso sintetico de la ficha con una entrada minima y
# comprueba el comportamiento corregido, no su implementacion.

crudo_506 <- function(...) {
  base <- data.frame(ID = c("A", "B"),
    Title = "Patterns of destination competitiveness across European coastal regions",
    Abstract = c("resumen del primer trabajo sobre competitividad", "resumen del segundo trabajo sobre otros destinos"),
    Year = 2020, Source = "J", Authors = c("Garcia Lopez, M.; Perez Ruiz, A.", "Brown, T.; Wilson, K."),
    `Cited by` = 1:2, `Author Keywords` = "k1; k2", DOI = "", Language = "en",
    check.names = FALSE, stringsAsFactors = FALSE)
  over <- list(...)
  for (nm in names(over)) base[[nm]] <- over[[nm]]
  base
}

# ---- BL-01: titulo largo igual con autores contradictorios --------------------------
test_that("BL-01: dos obras con igual titulo largo y anio pero autores distintos no se fusionan", {
  raw <- crudo_506()
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 2L)
  expect_equal(nrow(p$duplicates), 0L)
  expect_true("Autores distintos" %in% p$ambiguous$motivo)
  # El resultado no depende del orden de las filas.
  q <- prepare_documents(raw[2:1, ], guess_columns(raw))
  expect_setequal(q$documents$original_id, c("A", "B"))
})

test_that("BL-01: el mismo titulo con autores compatibles (otro formato de nombre) sigue siendo duplicado", {
  raw <- crudo_506(Authors = c("Garcia Lopez, M.; Perez Ruiz, A.", "M Garcia Lopez; A Perez Ruiz"))
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 1L)
  expect_equal(p$duplicates$criterio_duplicado, "Título normalizado")
  # Sin autores en alguno de los dos no hay contradiccion: se conserva el comportamiento previo.
  raw2 <- crudo_506(Authors = c("Garcia Lopez, M.", ""))
  expect_equal(nrow(prepare_documents(raw2, guess_columns(raw2))$documents), 1L)
})

test_that("BL-01: un DOI identico sigue siendo decisivo aunque los autores difieran", {
  raw <- crudo_506(DOI = "10.1/x")
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 1L)
  expect_equal(p$duplicates$criterio_duplicado, "DOI")
})

test_that("BL-01: las iniciales no cuentan como autor comun", {
  raw <- crudo_506(Authors = c("Garcia, M.; Perez, A.", "Brown, M.; Wilson, A."))
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 2L)
})

# ---- BL-02: duplicado con texto adicional -------------------------------------------
test_that("BL-02: la fila conservada recibe el resumen del duplicado y lo registra", {
  raw <- crudo_506(DOI = "10.1/x", Abstract = c("", "resumen disponible solo en la segunda fila"),
    Authors = "Garcia Lopez, M.")
  p <- prepare_documents(raw, guess_columns(raw))
  expect_equal(nrow(p$documents), 1L)
  expect_equal(p$documents$original_id, "A")
  expect_identical(p$documents$text, "resumen disponible solo en la segunda fila")
  expect_match(p$duplicates$campos_completados, "texto")
  expect_equal(p$duplicates$conservado_fila, 1L)
})

test_that("BL-02: no se sobrescribe un campo informado y las citas no se combinan", {
  raw <- crudo_506(DOI = "10.1/x", Authors = "Garcia Lopez, M.",
    Abstract = c("resumen de la primera fila", "resumen distinto de la segunda"),
    `Cited by` = c(NA, 40))
  p <- prepare_documents(raw, guess_columns(raw))
  expect_identical(p$documents$text, "resumen de la primera fila")
  expect_true(is.na(p$documents$citations))
  expect_false(grepl("texto", p$duplicates$campos_completados))
  # Con la deduplicacion desactivada no se completa nada.
  cfg <- utils::modifyList(default_config(), list(deduplicate = FALSE))
  raw$Abstract[1] <- ""
  q <- prepare_documents(raw, guess_columns(raw), cfg)
  expect_equal(q$documents$text, c("", "resumen distinto de la segunda"))
})

# ---- BL-03: denominadores de la prevalencia LDA -------------------------------------
test_that("BL-03: la tabla de calidad usa la prevalencia documental, igual que la tabla principal", {
  beta <- matrix(c(.4, .3, .2, .1, .1, .2, .3, .4), 2, byrow = TRUE, dimnames = list(NULL, letters[1:4]))
  # Documento 1 con una unidad (tema 1); documento 2 con tres unidades (tema 2): 50/50 por documento,
  # 25/75 por unidad.
  theta <- rbind(c(1, 0), c(0, 1), c(0, 1), c(0, 1))
  counts <- Matrix::Matrix(matrix(c(2, 1, 0, 0, 0, 0, 1, 2, 0, 1, 1, 0, 1, 0, 0, 1), 4, byrow = TRUE), sparse = TRUE)
  doc <- c(1, 0.5, 0.5, 0.5)
  por_unidad <- bibliolab:::lda_diagnostics(beta, theta, counts, top_n = 3L)
  expect_equal(por_unidad$topics$prevalencia_pct, c(25, 75))
  documental <- bibliolab:::lda_diagnostics(beta, theta, counts, top_n = 3L, prevalence = c(.5, .5))
  expect_equal(documental$topics$prevalencia_pct, c(50, 50))
  expect_equal(documental$overview$valor[5], 50)
  expect_error(bibliolab:::lda_diagnostics(beta, theta, counts, top_n = 3L, prevalence = 1))
})

test_that("BL-03: con frases, run_lda informa la misma prevalencia en ambas tablas", {
  skip_if_not_installed("topicmodels"); skip_if_not_installed("slam"); skip_on_cran()
  raw <- practica_raw(); mp <- guess_columns(raw)
  # Un tercio de los documentos conserva una sola frase: la media por unidad y la media por documento
  # dejan de coincidir.
  corto <- seq_len(nrow(raw)) %% 3L == 0L
  raw[[mp$text]][corto] <- sub("^([^.!?]+[.!?]).*$", "\\1", raw[[mp$text]][corto])
  cfg <- utils::modifyList(default_config(), list(split_sentences = TRUE))
  cp <- prepare_corpus(prepare_documents(raw, mp, cfg))
  frases <- table(cp$units$doc_id)
  expect_gt(length(unique(as.integer(frases))), 1L)
  f <- run_lda(cp, k = 3, seed = 1, iterations = 100, burnin = 20, thin = 5)
  expect_equal(f$diagnostics$topics$prevalencia_pct, 100 * f$prevalence$proporcion_media)
  por_unidad <- 100 * colMeans(f$gamma[grepl("^tema_", names(f$gamma))])
  expect_gt(max(abs(por_unidad - f$diagnostics$topics$prevalencia_pct)), 1e-8)
})

# ---- BL-05: referencias con el mismo DOI ---------------------------------------------
test_that("BL-05: dos formatos de una referencia con el mismo DOI forman una entidad", {
  prep <- list(config = list(metadata_sep = ";"), documents = data.frame(references = c(
    "Smith J, 2010, J Marketing, V74, P1, DOI 10.1509/jm.74.1.1; Lopez A, 2015, Tourism Manage, V50, P2",
    "Smith, J. (2010). Journal of Marketing, 74(1), 1-20. https://doi.org/10.1509/JM.74.1.1.; Otra obra, 2001",
    "Smith J, 2010, J Marketing, V74, P1, DOI 10.1509/jm.74.1.1"), stringsAsFactors = FALSE))
  s <- bibliolab:::reference_sets(prep)
  expect_equal(sum(grepl("smith", unlist(s))), 3L)           # una sola cadena por documento
  expect_equal(length(unique(grep("smith", unlist(s), value = TRUE))), 1L)
  # La etiqueta es la variante mas citada (2 de 3 documentos) y es una cadena real del corpus.
  expect_match(s[[1]][grepl("smith", s[[1]])], "^smith j, 2010")
  # Referencias sin DOI conservan la identidad por cadena exacta normalizada.
  expect_true("lopez a, 2015, tourism manage, v50, p2" %in% s[[1]])
  expect_true("otra obra, 2001" %in% s[[2]])
})

test_that("BL-05: referencias parecidas con DOI distintos permanecen separadas", {
  prep <- list(config = list(metadata_sep = ";"), documents = data.frame(references = c(
    "Smith J, 2010, DOI 10.1509/jm.74.1.1; Smith J, 2010b, DOI 10.1509/jm.74.1.2"), stringsAsFactors = FALSE))
  expect_length(bibliolab:::reference_sets(prep)[[1]], 2L)
  expect_identical(bibliolab:::reference_doi(c("x DOI 10.1000/ABC.", "sin doi", "https://doi.org/10.1016/j.tourman.2020.104)")),
    c("10.1000/abc", "", "10.1016/j.tourman.2020.104"))
})

# ---- BL-04: idioma de las palabras vacias ---------------------------------------------
ingles_506 <- function() data.frame(ID = 1:6,
  Title = paste("Study", 1:6, "of tourism"),
  Abstract = c(
    "The aim of this study is to examine the effect of price on the satisfaction of visitors and the loyalty of the tourists in the region",
    "We find that the perceived value of the destination is related to the intention to return and to the recommendation of the place to others",
    "This paper analyses how the image of a city can be built and what the residents think about the arrival of the visitors during the season",
    "The results show that there is a positive relationship between the quality of the service and the behaviour of the guests in the hotels",
    "In this article we propose a model that explains why the tourists are willing to pay for the experiences that they have at the destination",
    "Our findings suggest that the managers of the hotels should focus on the needs of the guests and on the reputation of the brand over time"),
  Year = 2015:2020, Source = "J", Authors = paste("Autor", LETTERS[1:6]), `Cited by` = 1:6,
  `Author Keywords` = "k1; k2", DOI = paste0("10.1/", 1:6), Language = "en", check.names = FALSE, stringsAsFactors = FALSE)

test_that("BL-04: un corpus ingles con la lista espanola inicial genera un aviso y no cambia la eleccion", {
  raw <- ingles_506(); mp <- guess_columns(raw)
  cfg <- utils::modifyList(default_config(), list(min_df = 1L))
  expect_identical(cfg$language, "es")
  cp <- prepare_corpus(prepare_documents(raw, mp, cfg))
  expect_true(cp$language_check$mismatch)
  expect_identical(cp$language_check$best, "en")
  expect_true(any(grepl("^AVISO DE IDIOMA", cp$issues)))
  # La eleccion del usuario se respeta: las palabras vacias inglesas siguen presentes en el vocabulario.
  expect_true("the" %in% cp$terms$termino[cp$terms$incluido])
})

test_that("BL-04: con la lista inglesa o 'ambas' no hay aviso, y un texto espanol con lista espanola tampoco", {
  raw <- ingles_506(); mp <- guess_columns(raw)
  for (lang in c("en", "both")) {
    cfg <- utils::modifyList(default_config(), list(min_df = 1L, language = lang))
    cp <- prepare_corpus(prepare_documents(raw, mp, cfg))
    expect_false(cp$language_check$mismatch)
    expect_false(any(grepl("AVISO DE IDIOMA", cp$issues)))
  }
  pr <- practica()
  expect_false(pr$corpus$language_check$mismatch)
  # Sin palabras vacias o por documento el control no se aplica; textos muy cortos tampoco se juzgan.
  expect_false(bibliolab:::stopword_language_check(character(), "es")$applicable)
  expect_false(bibliolab:::stopword_language_check("the of and", "es")$applicable)
  expect_false(bibliolab:::stopword_language_check(raw$Abstract, "by_document")$applicable)
})

# ---- BL-06: huella del codigo instalado ------------------------------------------------
test_that("BL-06: la entrega registra la huella del codigo y el guion la comprueba antes de calcular", {
  skip_on_cran()
  pr <- practica()
  dir <- file.path(withr::local_tempdir(), "codigo")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw)
  reg <- jsonlite::read_json(file.path(dir, "registro_reproducibilidad.json"))
  fp <- reg$software$codigo$huella_funciones
  expect_match(fp, "^[0-9a-f]{32}$")
  expect_gt(reg$software$codigo$funciones, 50)
  expect_identical(fp, bibliolab:::code_fingerprint()$huella)
  script <- readLines(file.path(dir, "reproducir_analisis.R"), encoding = "UTF-8", warn = FALSE)
  linea <- grep(fp, script, fixed = TRUE)
  expect_length(linea, 1L)
  expect_match(script[linea], "code_fingerprint()", fixed = TRUE)
  # Es un aviso (no un error) y precede a la primera comprobacion de la entrada.
  expect_match(script[linea], "warning(", fixed = TRUE)
  expect_lt(linea, grep("verify_reproduction(raw_fingerprint(datos)", script, fixed = TRUE))
})

test_that("BL-06: la huella es estable entre llamadas y cambia si cambia una funcion", {
  a <- bibliolab:::code_fingerprint()
  expect_identical(a$huella, bibliolab:::code_fingerprint()$huella)
  expect_null(bibliolab:::code_check_line(list(software = list(codigo = list(huella_funciones = NA_character_)))))
  expect_null(bibliolab:::code_check_line(list()))
  # La huella depende del contenido de las funciones.
  ns <- asNamespace("bibliolab")
  original <- get("author_tokens", envir = ns)
  on.exit({ unlockBinding("author_tokens", ns); assign("author_tokens", original, envir = ns); lockBinding("author_tokens", ns) }, add = TRUE)
  unlockBinding("author_tokens", ns)
  assign("author_tokens", function(x) character(), envir = ns)
  lockBinding("author_tokens", ns)
  # La huella se memoriza por sesion; se vacia para recalcularla sobre el codigo modificado.
  rm(list = ls(bibliolab:::.code_fingerprint_cache, all.names = TRUE), envir = bibliolab:::.code_fingerprint_cache)
  expect_false(identical(a$huella, bibliolab:::code_fingerprint()$huella))
  # Se restaura la huella original para no contaminar otros bloques.
  rm(list = ls(bibliolab:::.code_fingerprint_cache, all.names = TRUE), envir = bibliolab:::.code_fingerprint_cache)
})

# ---- BL-07: el guion de diagnosticos falla si la reproduccion difiere -----------------
test_that("BL-07: reproducir_diagnosticos.R termina con error ante una diferencia o sin comparaciones", {
  falso <- list(params = list(k_range = 2:3, seeds = 1L, iterations = 100L, alpha = "1/k", delta = 0.1, holdout_fraction = 0.1, top_n = 10L),
    table = data.frame(k = 2:3), reading = "x")
  guion <- bibliolab:::diagnostics_script(lda_selection = falso)
  expect_match(guion, "verificacion_diagnosticos.json", fixed = TRUE)
  expect_match(guion, "stop(sprintf('La reproduccion de los diagnosticos difiere", fixed = TRUE)
  expect_match(guion, "no hay nada que verificar", fixed = TRUE)
  expect_false(grepl("DIFIERE'\\)\\s*$", guion))
  expect_true(is.character(guion) && length(guion) == 1L)
  # Sin ningun insumo no hay comparaciones: el guion no puede declararse correcto.
  vacio <- bibliolab:::diagnostics_script()
  expect_match(vacio, "no hay nada que verificar", fixed = TRUE)
})

# ---- BL-08: el mapa tematico forma parte de la entrega ---------------------------------
test_that("BL-08: el mapa tematico vigente se entrega con sus parametros, su lectura y su cobertura", {
  skip_if_not_installed("igraph"); skip_on_cran()
  pr <- practica()
  tm <- run_thematic_map(pr$corpus, pr$prepared)
  dir <- file.path(withr::local_tempdir(), "tematico")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw, thematic = tm)
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_equal(par$mapa_tematico$subcarpeta, "mapa_tematico")
  expect_equal(par$mapa_tematico$parametros$field, tm$params$field)
  reg <- jsonlite::read_json(file.path(dir, "registro_reproducibilidad.json"))
  expect_equal(reg$semillas$mapa_tematico, tm$params$seed)
  expect_equal(reg$modelos$mapa_tematico$field, tm$params$field)
  expect_true(dir.exists(file.path(dir, "mapa_tematico")))
  expect_true(file.exists(file.path(dir, "mapa_tematico", "reproducir_mapa.R")))
  informe <- paste(readLines(file.path(dir, "informe.html"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(informe, "Mapa temático / método y lectura", fixed = TRUE)
  expect_match(informe, "Mapa temático / cobertura y selección", fixed = TRUE)
  metodologico <- paste(readLines(file.path(dir, "informe_metodologico.md"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(metodologico, "4.7 Mapa temático", fixed = TRUE)
  ev <- jsonlite::read_json(file.path(dir, "evidencia_ia.json"))
  expect_true(!is.null(ev$mapa_tematico$metodo))
  expect_true(!is.null(ev$mapa_tematico$cobertura))
  # El manifiesto incluye los archivos de la subcarpeta y verify_bundle los comprueba.
  v <- verify_bundle(dir)
  expect_true(all(v$estado == "correcto"))
  expect_true(any(grepl("^mapa_tematico/", v$archivo)))
})

test_that("BL-08: sin mapa tematico la entrega no lo declara y el resto no cambia", {
  skip_on_cran()
  pr <- practica()
  dir <- file.path(withr::local_tempdir(), "sin")
  export_bundle(dir, pr$prepared, pr$corpus, pr$bibliography, raw = pr$raw)
  par <- jsonlite::read_json(file.path(dir, "parametros.json"))
  expect_length(par$mapa_tematico, 0L)
  reg <- jsonlite::read_json(file.path(dir, "registro_reproducibilidad.json"))
  expect_null(reg$semillas$mapa_tematico)
  expect_false(dir.exists(file.path(dir, "mapa_tematico")))
  informe <- paste(readLines(file.path(dir, "informe.html"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_false(grepl("Mapa temático", informe, fixed = TRUE))
})

test_that("BL-08: si las figuras no pueden escribirse, las tablas se entregan y se deja constancia", {
  skip_if_not_installed("igraph"); skip_on_cran()
  pr <- practica()
  tm <- run_thematic_map(pr$corpus, pr$prepared)
  dir <- file.path(withr::local_tempdir(), "figuras")
  testthat::local_mocked_bindings(thematic_plot = function(...) stop("sin dispositivo grafico"), .package = "bibliolab")
  write_thematic_bundle(dir, tm)
  expect_true(file.exists(file.path(dir, "FIGURAS_NO_GENERADAS.txt")))
  expect_match(paste(readLines(file.path(dir, "FIGURAS_NO_GENERADAS.txt"), encoding = "UTF-8", warn = FALSE), collapse = " "), "sin dispositivo grafico")
  expect_true(file.exists(file.path(dir, "reproducir_mapa.R")))
  expect_false(file.exists(file.path(dir, "mapa_tematico.png")))
})

# ---- BL-17: grupos endogenos en la comparacion JSD --------------------------------------
test_that("BL-17: comparar temas LDA advierte que la separacion es en parte circular; los metadatos no", {
  skip_on_cran(); skip_if_not_installed("topicmodels")
  pr <- practica()
  lda <- run_lda(pr$corpus, k = 3, iterations = 100L)
  grupos <- data.frame(doc_id = lda$document_topics$doc_id,
    valor = paste("Tema", max.col(as.matrix(lda$document_topics[-1]), ties.method = "first")), stringsAsFactors = FALSE)
  cat_ab <- names(sort(table(grupos$valor), decreasing = TRUE))[1:2]
  comp <- run_comparison(pr$corpus, pr$prepared, list(mode = "lda", category_A = cat_ab[1], category_B = cat_ab[2], B = 50L), grouping = grupos)
  expect_true(any(grepl("Grupos endógenos: los temas LDA", comp$issues)))
  expect_true(any(grepl("tema dominante", comp$issues)))
  expect_true(any(grepl("no valida los grupos", comp$issues)))
  anio <- run_comparison(pr$corpus, pr$prepared, list(mode = "year", year_A_min = 2019, year_A_max = 2021, year_B_min = 2022, year_B_max = 2026, B = 50L))
  expect_false(any(grepl("Grupos endógenos", anio$issues)))
})

# ---- BL-20: palabras principales y vocabularios pequenos --------------------------------
test_that("BL-20: con un vocabulario de ocho terminos no se introducen NA y se advierte de la baja discriminacion", {
  skip_on_cran(); skip_if_not_installed("topicmodels"); skip_if_not_installed("slam")
  set.seed(7)
  m <- Matrix::Matrix(matrix(stats::rpois(40 * 8, 1.5) + 1L, 40, 8, dimnames = list(paste0("u", 1:40), paste0("t", 1:8))), sparse = TRUE)
  corpus <- list(counts = m, units = NULL)
  sel <- lda_select_k(corpus, k_range = 2:3, seeds = 1:2, iterations = 100L, holdout = 0, top_n = 10L)
  expect_equal(sel$params$top_n, 8L)
  expect_equal(sel$params$top_n_pedido, 10L)
  expect_false(anyNA(sel$table$estabilidad))
  expect_false(anyNA(sel$table$diversidad))
  expect_true(any(grepl("abarcan al menos la mitad del vocabulario", sel$recommendation$notes)))
  expect_true(any(grepl("Se pidieron 10 palabras principales", sel$recommendation$text)))
})

test_that("BL-20: la recomendacion lista las soluciones empatadas y avisa si la estabilidad no discrimina", {
  base <- data.frame(k = 2:4, perplejidad = NA_real_, perplejidad_de = NA_real_, coherencia_npmi = c(.10, .50, .50), coherencia_npmi_de = 0,
    coherencia_umass = -1, diversidad = c(.50, .90, .90), estabilidad = c(.50, .90, .89), tema_minimo_pct = 10)
  r <- bibliolab:::lda_k_recommendation(base)
  expect_setequal(r$near, c(3L, 4L))
  expect_true(any(grepl("no se distinguen", r$notes)))
  expect_match(r$text, "no se distinguen")
  expect_false(any(grepl("no discrimina", r$notes)))
  plana <- base; plana$estabilidad <- c(.800, .810, .805)
  expect_true(any(grepl("apenas var\u00eda", bibliolab:::lda_k_recommendation(plana)$notes)))
})

# ---- BL-25: celdas demasiado largas ----------------------------------------------------
test_that("BL-25: el mensaje de celdas largas nombra la columna y orienta si son referencias", {
  largo <- strrep("a", 50001L)
  d <- data.frame(Abstract = "x", `Cited References` = largo, Notes = largo, check.names = FALSE, stringsAsFactors = FALSE)
  msg <- bibliolab:::oversize_cells_message(d)
  expect_match(msg, "columnas: Cited References, Notes", fixed = TRUE)
  expect_match(msg, "cocitación")
  msg2 <- bibliolab:::oversize_cells_message(d[c("Abstract", "Notes")])
  expect_match(msg2, "columna: Notes", fixed = TRUE)
  expect_false(grepl("cocitaci", msg2))
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv2(d, tmp, row.names = FALSE, fileEncoding = "UTF-8")
  expect_error(read_biblio_csv(tmp, ";"), "columnas: Cited References, Notes")
})

# ---- BL-40: el boton promete lo que hace ----------------------------------------------
test_that("BL-40: el boton de fijar k no promete un recalculo que no ejecuta", {
  ruta <- system.file("app", "server", "validation.R", package = "bibliolab")
  skip_if(!nzchar(ruta))
  src <- paste(readLines(ruta, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_false(grepl("volver a calcular LDA", src, fixed = TRUE))
  expect_match(src, 'actionButton("use_k", "Usar este k en el modelo LDA"', fixed = TRUE)
  expect_match(src, "modelo final todav", fixed = TRUE)
})
