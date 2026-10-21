# Ayudas como documentos (inst/app/help/*.md): el analizador, la estructura de cada archivo y,
# sobre todo, que las cifras y las afirmaciones de los ejemplos coinciden con el calculo real.

test_that("el analizador convierte el subconjunto de Markdown de las ayudas", {
  doc <- bibliolab:::help_parse_document(paste(c(
    "---", "titulo: Prueba", "objetivo: Objetivo.", "fuentes:", "  - Etiqueta uno | https://ejemplo.org/a", "---",
    "## 1. Primera", "Texto con **negrita**, *cursiva* y `a * b`.", "Segunda linea del mismo parrafo.",
    "- uno", "  - uno-a", "- dos", "1. primero", "2. segundo",
    "> **Analogia:**", ">", "> La sal aparece en todas.",
    "| A | B |", "| --- | --- |", "| 1 | 2 |",
    "$$ IDF = ln(N / df) $$",
    "+++ Nota tecnica", "Dentro del plegado.", "+++",
    "## 2. Segunda", "### Sub", "Hola."), collapse = "\n"))
  expect_equal(doc$meta$titulo, "Prueba")
  expect_equal(doc$meta$objetivo, "Objetivo.")
  expect_equal(unname(doc$meta$fuentes), "https://ejemplo.org/a")
  expect_equal(names(doc$meta$fuentes), "Etiqueta uno")
  html <- doc$html
  # Solo la primera seccion se muestra abierta.
  expect_equal(lengths(regmatches(html, gregexpr("<details class=\"help-section\"", html, fixed = TRUE))), 2L)
  expect_equal(lengths(regmatches(html, gregexpr("<details class=\"help-section\" open>", html, fixed = TRUE))), 1L)
  expect_match(html, "<strong>negrita</strong>", fixed = TRUE)
  expect_match(html, "<em>cursiva</em>", fixed = TRUE)
  expect_match(html, "<code>a * b</code>", fixed = TRUE)
  expect_match(html, "<ul><li>uno<ul><li>uno-a</li></ul></li><li>dos</li></ul>", fixed = TRUE)
  expect_match(html, "<ol><li>primero</li><li>segundo</li></ol>", fixed = TRUE)
  expect_match(html, "<blockquote><p><strong>Analogia:</strong></p><p>La sal aparece en todas.</p></blockquote>", fixed = TRUE)
  expect_match(html, "<table class=\"help-table\"><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>", fixed = TRUE)
  expect_match(html, "<p class=\"help-formula\">IDF = ln(N / df)</p>", fixed = TRUE)
  expect_match(html, "<details class=\"help-fold\"><summary>Nota tecnica</summary><p>Dentro del plegado.</p></details>", fixed = TRUE)
  expect_match(html, "<h4>Sub</h4>", fixed = TRUE)
})

test_that("el analizador escapa el HTML y conserva la numeracion y las formulas dentro de listas", {
  html <- bibliolab:::help_parse_document(paste(c("## S", "Texto <script>alert(1)</script> & mas.",
    "1. uno", "$$ a < b $$", "2. dos", "", "Parrafo intermedio.", "", "3. tres"), collapse = "\n"))$html
  expect_false(grepl("<script>", html, fixed = TRUE))
  expect_match(html, "&lt;script&gt;", fixed = TRUE)
  expect_match(html, "<li>uno<p class=\"help-formula\">a &lt; b</p></li><li>dos</li>", fixed = TRUE)
  expect_match(html, "<ol start=\"3\"><li>tres</li></ol>", fixed = TRUE)
})

test_that("cada documento de ayuda tiene cabecera completa y se convierte sin restos de marcado", {
  claves <- bibliolab:::help_document_keys()
  expect_gt(length(claves), 0L)
  for (clave in claves) {
    doc <- bibliolab:::help_document(clave)
    expect_true(nzchar(doc$meta$titulo), info = clave)
    expect_true(nzchar(doc$meta$objetivo), info = clave)
    expect_match(doc$html, "<details class=\"help-section\" open>", fixed = TRUE, info = clave)
    visible <- gsub("<[^>]+>", "", doc$html)
    expect_false(grepl("\\*\\*|\\$\\$|\\[GAP-DATO\\]", visible), info = clave)
    expect_false(grepl("^\\s*\\|", strsplit(visible, "\n", fixed = TRUE)[[1]]), info = clave)
    expect_false(is.null(bibliolab:::help_modal_body(clave)), info = clave)
  }
})

test_that("las cifras del ejemplo de BM25 coinciden con bm25_weights()", {
  factor_de <- function(counts, k1 = 1.2, b = .75) {
    counts <- Matrix::Matrix(counts, sparse = TRUE)
    w <- as.matrix(bibliolab:::bm25_weights(counts, k1, b))
    df <- colSums(as.matrix(counts) > 0)
    idf <- log(1 + (nrow(counts) - df + .5) / (df + .5))
    sweep(w, 2, idf, "/")
  }
  # Caso A: textos de longitud igual a la media, k1 = 1,2.
  a <- factor_de(cbind(a = c(1, 2, 5), z = c(9, 8, 5)))
  expect_equal(round(a[, "a"], 2), c(1.00, 1.38, 1.77))
  # El factor de frecuencia nunca supera k1 + 1.
  grande <- factor_de(cbind(a = c(1000, 1000), z = c(1, 1)))
  expect_lt(max(grande[, "a"]), 2.2)
  # Caso B: tres menciones en un texto de 80 palabras y en otro de 400; longitud media 240.
  largo <- cbind(a = c(3, 3), z = c(77, 397))
  expect_equal(mean(rowSums(largo)), 240)
  b0 <- factor_de(largo, b = 0)
  b75 <- factor_de(largo, b = .75)
  expect_equal(round(unname(b0[, "a"]), 2), c(1.57, 1.57))
  expect_equal(round(unname(b75[, "a"]), 2), c(1.83, 1.38))
})

test_that("el ejemplo de TF-IDF de la ayuda coincide con la tabla de terminos", {
  repetir <- function(x) paste(rep(names(x), x), collapse = " ")
  raw <- data.frame(ID = 1:3, Title = c("Uno", "Dos", "Tres"),
    Abstract = c(repetir(c(estudio = 5, hospital = 3, relleno = 92)), repetir(c(estudio = 5, relleno = 95)),
      repetir(c(estudio = 5, relleno = 95))),
    Year = 2020, Source = "J", Authors = "A; B", `Cited by` = 1:3, `Author Keywords` = "k1; k2",
    DOI = c("10.1/a", "10.1/b", "10.1/c"), Language = "es", check.names = FALSE, stringsAsFactors = FALSE)
  cfg <- utils::modifyList(bibliolab:::default_config(), list(deduplicate = FALSE, remove_stop = FALSE, min_df = 1L))
  terms <- bibliolab:::prepare_corpus(bibliolab:::prepare_documents(raw, bibliolab:::guess_columns(raw), cfg))$terms
  hospital <- terms[terms$termino == "hospital", ]
  estudio <- terms[terms$termino == "estudio", ]
  expect_equal(c(hospital$frecuencia, hospital$documentos), c(3, 1))
  expect_equal(c(estudio$frecuencia, estudio$documentos), c(15, 3))
  # TF = 3/100, IDF = ln(3/1): peso 0,033 en el Resumen A y media 0,011 sobre las tres unidades.
  expect_equal(hospital$tfidf_medio * 3, 0.03 * log(3))
  expect_equal(round(hospital$tfidf_medio, 3), 0.011)
  expect_equal(estudio$tfidf_medio, 0)
})

test_that("los valores iniciales y las estadisticas que citan las ayudas son los del codigo", {
  cfg <- bibliolab:::default_config()
  expect_equal(c(cfg$min_chars, cfg$max_chars, cfg$min_tf, cfg$min_df, cfg$max_terms), c(3, 40, 1, 2, 1000))
  expect_equal(c(cfg$max_df_pct, cfg$min_tfidf, cfg$max_entropy), c(100, 0, 1))
  expect_true(cfg$remove_numbers && cfg$remove_links && !cfg$remove_codes && !cfg$split_sentences && cfg$deduplicate)
  # El ACP centra siempre y solo estandariza si se pide.
  expect_false(formals(bibliolab:::run_pca)$standardize)
  # MAD sin el factor 1,4826.
  x <- Matrix::Matrix(matrix(c(0, 0.1, 0.3, 0.2, 0, 0.4), ncol = 1), sparse = TRUE)
  resumen <- bibliolab:::sparse_weight_summary(x)
  positivos <- c(0.1, 0.3, 0.2, 0.4)
  expect_equal(resumen$present_mad, stats::mad(positivos, constant = 1))
  expect_equal(resumen$present_mean, mean(positivos))
})

# ---- Cobertura de claves y ejemplos de las guias de redes, n-gramas, bibliografia, k, estabilidad, paralelo y lectura enlazada ----

test_that("cada boton de ayuda y cada modal propio tiene su documento", {
  ext <- file.path(dirname(bibliolab:::help_document_dir()), "server", "extensions.R")
  skip_if_not(file.exists(ext))
  txt <- paste(readLines(ext, warn = FALSE), collapse = "\n")
  pairs <- regmatches(txt, gregexpr("help_[a-z_0-9]+ ?= ?\"[a-z_0-9]+\"", txt))[[1]]
  keys <- unique(gsub("^.*= ?\"|\"$", "", pairs))
  expect_gt(length(keys), 20L)
  own_modals <- c("kselect", "stability", "wiki", "jsd_weight", "networks")
  for (k in union(keys, own_modals)) expect_false(is.null(bibliolab:::help_document(k)), info = k)
  expect_true("tokens_explore" %in% keys)
})

test_that("el ejemplo de coautoria de las guias de redes coincide con run_network() y extract_subgraph()", {
  skip_if_not_installed("igraph"); skip_if_not_installed("data.table")
  au <- c("Ana; Luis; Eva", "Ana; Luis", "Ana; Eva", "Marta; Pablo", "Eva; Marta")
  raw <- data.frame(ID = 1:5, Title = paste("Titulo", 1:5), Abstract = rep("hospital salud paciente estudio", 5), Year = 2020,
    Source = "J", Authors = au, `Cited by` = 1:5, `Author Keywords` = "k1; k2", DOI = paste0("10.1/", letters[1:5]),
    Language = "es", check.names = FALSE, stringsAsFactors = FALSE)
  cfg <- utils::modifyList(default_config(), list(deduplicate = FALSE, remove_stop = FALSE, min_df = 1L))
  p <- prepare_documents(raw, guess_columns(raw), cfg); co <- prepare_corpus(p)
  r <- run_network(co, p, list(type = "authors", weighting = "full", min_presence = 1, min_shared = 1))
  n <- r$nodes[match(c("Ana", "Eva", "Luis", "Marta", "Pablo"), r$nodes$name), ]
  expect_equal(n$grado, c(2, 3, 2, 2, 1)); expect_equal(n$fuerza, c(4, 4, 3, 2, 1))
  expect_equal(round(n$intermediacion, 2), c(0, .67, 0, .5, 0)); expect_equal(n$articulacion, c(FALSE, TRUE, FALSE, TRUE, FALSE))
  expect_equal(round(n$participacion, 2), c(0, .44, 0, .5, 0))
  expect_equal(round(r$summary$valor[r$summary$indicador == "Densidad"], 2), .5)
  expect_equal(round(r$summary$valor[r$summary$indicador == "Modularidad"], 2), .19)
  expect_equal(r$keyplayers$nodo, c("Eva", "Marta", "Ana")); expect_equal(r$keyplayers$porcentaje_cubierto, c(80, 100, 100))
  fr <- run_network(co, p, list(type = "authors", weighting = "fractional", min_presence = 1, min_shared = 1))
  w <- setNames(round(fr$edges$weight, 3), paste(fr$edges$from, fr$edges$to))
  expect_equal(unname(w[c("Ana Eva", "Ana Luis", "Eva Luis")]), c(1.333, 1.333, .333))
  s <- extract_subgraph(r, "ego", focus = "Eva", order = 1)
  expect_equal(nrow(s$edges), 4L); expect_equal(round(s$summary$valor[s$summary$indicador == "Densidad"], 2), .67)
  expect_equal(s$nodes$grado[s$nodes$name == "Marta"], 1); expect_equal(s$nodes$grado_origen[s$nodes$name == "Marta"], 2)
  m <- extract_subgraph(r, "manual", selection = c("Ana", "Pablo"))
  expect_equal(nrow(m$edges), 0L); expect_equal(m$summary$valor[m$summary$indicador == "Componentes"], 2)
})

test_that("el ejemplo de n-gramas de la guia: misma frecuencia, presencia y concentracion distintas", {
  skip_if_not_installed("data.table")
  seqs <- lapply(1:10, function(i) list(c("estudio", "ciclo", "vital", "datos")))
  seqs[[1]] <- list(c("estudio", "ciclo", "vital", rep(c("atencion", "primaria"), 10), "datos"))
  d <- ngram_summary(seqs, 1:10, 10, orders = 2)
  a <- d[d$expresion == "atencion primaria", ]; b <- d[d$expresion == "ciclo vital", ]
  expect_equal(c(a$frecuencia, b$frecuencia), c(10, 10)); expect_equal(c(a$documentos, b$documentos), c(1, 10))
  expect_equal(c(1 - a$entropia, 1 - b$entropia), c(1, 0)); expect_equal(round(a$tfidf_medio, 3), .100); expect_equal(b$tfidf_medio, 0)
  # Los segmentos (separados por puntuacion) no se cruzan.
  s <- ngram_summary(list(list(c("a", "b"), c("c", "d"))), 1, 1, orders = 2)
  expect_setequal(s$expresion, c("a b", "c d"))
})

test_that("el ejemplo de cobertura, referencias, fuentes y citas relativas de las guias", {
  n <- 10
  raw <- data.frame(ID = 1:n, Title = paste("Titulo", 1:n), Abstract = rep("hospital salud paciente estudio", n),
    Year = c(2020, 2020, 2020, 2020, 2020, 2021, 2021, 2021, NA, NA),
    Source = c("Rev A", "Rev A", "Rev A", "Rev B", "Rev B", "Rev C", "Rev D", "Rev E", "", ""), Authors = paste("Autor", 1:n),
    `Cited by` = c(10, 2, 0, 4, 4, 1, NA, NA, NA, NA),
    `Cited References` = c("Smith 2010; Lee 2015", "Smith 2010; Lee 2015", "Smith 2010; Gomez 2018", "Smith J. 2010; Lee 2015", "", "", "", "", "", ""),
    DOI = paste0("10.1/", 1:n), Language = "es", check.names = FALSE, stringsAsFactors = FALSE)
  cfg <- utils::modifyList(default_config(), list(deduplicate = FALSE, remove_stop = FALSE, min_df = 1L))
  b <- bibliography_extensions(prepare_documents(raw, guess_columns(raw), cfg))
  expect_equal(b$cobertura$documentos_validos, c(4, 8, 10, 8, 6))
  r <- setNames(b$referencias$documentos, b$referencias$elemento)
  expect_equal(unname(r[c("smith 2010", "lee 2015", "gomez 2018", "smith j. 2010")]), c(3, 3, 1, 1))
  expect_equal(b$concentracion_fuentes$porcentaje_acumulado, c(37.5, 62.5, 75, 87.5, 100))
  expect_equal(b$citas_cohorte$citas_relativas_cohorte[1:5], c(2.5, .5, 0, 1, 1)); expect_true(is.na(b$citas_cohorte$citas_relativas_cohorte[6]))
})

test_that("los escenarios de la guia de seleccion de k y las cifras de ARI de la guia de estabilidad son las del codigo", {
  summ <- data.frame(k = 3:6, perplejidad = c(310, 280, 262, 250), coherencia_npmi = c(.10, .18, .15, .08), coherencia_umass = -c(60, 55, 58, 70),
    diversidad = c(1, .95, .90, .80), estabilidad = c(.80, .70, .55, .50), tema_minimo_pct = 5)
  r <- bibliolab:::lda_k_recommendation(summ)
  expect_equal(r$compromise, 4L); expect_false(r$conflict); expect_equal(round(r$scores$puntuacion_compromiso, 2), c(.20, .67, .17, 0))
  s2 <- summ; s2$coherencia_npmi <- c(.05, .10, .12, .20); s2$estabilidad <- c(.85, .80, .60, .40); s2$diversidad <- c(1, .98, .95, .9)
  r2 <- bibliolab:::lda_k_recommendation(s2)
  expect_equal(r2$compromise, 5L); expect_true(r2$conflict); expect_equal(round(max(r2$scores$puntuacion_compromiso), 2), .44)
  ar <- bibliolab:::adjusted_rand; ref <- c(1, 1, 1, 1, 2, 2, 2, 2, 0, 0)
  runs <- list(A = c(1, 1, 1, 1, 2, 2, 2, 2, 0, 0), B = c(1, 1, 1, 2, 2, 2, 2, 2, 0, 0), C = c(1, 1, 1, 1, 1, 1, 1, 1, 0, 0),
    D = c(1, 1, 0, 0, 2, 2, 0, 0, 0, 0), E = c(1, 2, 1, 2, 1, 2, 1, 2, 1, 2))
  expect_equal(round(vapply(runs, function(l) ar(ref, l), 0), 2), c(A = 1, B = .63, C = .37, D = .01, E = -.17))
  asig <- function(l) { both <- l > 0 & ref > 0; ar(ref[both], l[both]) }
  expect_equal(round(vapply(runs, asig, 0), 2), c(A = 1, B = .49, C = 0, D = 1, E = -.17))
  expect_equal(c(bibliolab:::jaccard(which(ref == 1), which(runs$B == 1)), bibliolab:::jaccard(which(ref == 2), which(runs$B == 2))), c(.75, .8))
  expect_equal(ar(rep(0, 10), rep(0, 10)), 1)
})

test_that("las reglas de paralelismo que cita la guia son las de processing_plan()", {
  testthat::local_mocked_bindings(processing_worker_limit = function() 4L, .package = "bibliolab")
  ex <- list(enabled = TRUE, workers = 2L)
  for (job in c("language", "lexical", "annotate", "normalize")) {
    expect_false(bibliolab:::processing_plan(job, 36L, 36 * 1500, ex)$parallel, info = job)
    expect_true(bibliolab:::processing_plan(job, 5000L, 5000 * 1500, ex)$parallel, info = job)
  }
  expect_true(bibliolab:::processing_plan("language", 1000L, 0, ex)$parallel); expect_false(bibliolab:::processing_plan("language", 999L, 4e5, ex)$parallel)
  expect_true(bibliolab:::processing_plan("lexical", 3000L, 0, ex)$parallel); expect_false(bibliolab:::processing_plan("lexical", 2999L, 9e5, ex)$parallel)
  expect_true(bibliolab:::processing_plan("annotate", 2L, 1e5, ex)$parallel); expect_false(bibliolab:::processing_plan("annotate", 1L, 1e7, ex)$parallel)
  expect_true(bibliolab:::processing_plan("normalize", 4L, 1e6, ex)$parallel); expect_false(bibliolab:::processing_plan("normalize", 3L, 1e7, ex)$parallel)
})

test_that("el ejemplo de la lectura enlazada: el filtro FDR descarta la palabra presente en todas las fichas", {
  skip_if_not_installed("igraph")
  N <- 20; terms <- c("salud", "hospital", "paciente", "energia", "edificio", "eficiencia", "datos")
  m <- matrix(0, N, length(terms), dimnames = list(sprintf("D%02d", 1:N), terms))
  m[1:8, c("salud", "hospital", "paciente")] <- 1; m[c(3, 6), "paciente"] <- 0
  m[9:16, c("energia", "edificio", "eficiencia")] <- 1; m[c(10, 14), "edificio"] <- 0
  m[, "datos"] <- 1; m[17, c("salud", "energia")] <- 1; m[18, c("hospital", "edificio")] <- 1; m[1, "salud"] <- 3; m[2, "hospital"] <- 2
  idx <- list(documents = data.frame(key = rownames(m), doc_id = rownames(m), title = rownames(m), doi = "", stringsAsFactors = FALSE),
    concepts = data.frame(key = terms, label = terms, documents = colSums(m > 0), occurrences = colSums(m), stringsAsFactors = FALSE),
    counts = methods::as(Matrix::Matrix(m, sparse = TRUE), "dgCMatrix"))
  f0 <- bibliolab:::wiki_concept_network(idx, alpha = NULL, top_k = NULL)
  f1 <- bibliolab:::wiki_concept_network(idx, alpha = 0.05, top_k = NULL)
  expect_equal(nrow(f0$edges), 14L); expect_equal(nrow(f1$edges), 6L)
  e <- f1$edges; key <- paste(e$from, e$to)
  expect_equal(round(e$weight[key == "salud hospital"], 2), .8); expect_equal(round(e$p_adj[key == "salud hospital"], 3), .006)
  expect_false(any(grepl("datos", key))); expect_equal(f1$nodes$community[f1$nodes$label == "datos"], 0L)
  expect_equal(round(f1$modularity, 2), .5); expect_true(all(f1$roles$role[f1$roles$label != "datos"] == "Apoyo exclusivo de su comunidad"))
  expect_equal(nrow(bibliolab:::wiki_concept_network(idx, alpha = 0.05, top_k = 1)$edges), 4L)
  # TF-IDF en suma y en media ordenan igual cuando los pesos y las fichas son los mismos.
  w <- methods::as(idx$counts, "CsparseMatrix"); w@x <- log1p(w@x)
  s <- as.numeric(Matrix::colSums(w)) * log(N / idx$concepts$documents)
  expect_identical(order(-s), order(-s / N)); expect_equal(s[terms == "datos"], 0)
})

test_that("M02: la lectura de la red sin filtro no atribuye significación y con filtro cita la prueba hipergeométrica", {
  skip_if_not_installed("igraph")
  N <- 12; terms <- c("a", "b", "c", "d")
  m <- matrix(0, N, 4, dimnames = list(sprintf("D%02d", 1:N), terms))
  m[1:5, c("a", "b")] <- 1; m[6:10, c("c", "d")] <- 1; m[, "a"] <- m[, "a"]; m[11, c("a", "c")] <- 1
  idx <- list(documents = data.frame(key = rownames(m), doc_id = rownames(m), title = rownames(m), doi = "", stringsAsFactors = FALSE),
    concepts = data.frame(key = terms, label = terms, documents = colSums(m > 0), occurrences = colSums(m), stringsAsFactors = FALSE),
    counts = methods::as(Matrix::Matrix(m, sparse = TRUE), "dgCMatrix"))
  r0 <- paste(bibliolab:::wiki_network_reading(bibliolab:::wiki_concept_network(idx, alpha = NULL, top_k = NULL)), collapse = " ")
  r1 <- paste(bibliolab:::wiki_network_reading(bibliolab:::wiki_concept_network(idx, alpha = 0.05, top_k = NULL)), collapse = " ")
  expect_match(r0, "coaparición observada")
  expect_false(grepl("hipergeom", r0)); expect_false(grepl("más de lo esperable por azar", r0))
  expect_match(r1, "hipergeométrica")
})

test_that("M09: la mediana del ARI no oculta las repeticiones sin grupos", {
  runs <- data.frame(tipo = c("Referencia", "Semilla", "Semilla", "Semilla", "Parametros", "Parametros"),
    estado = "ejecutada", grupos = c(3L, 3L, 0L, 3L, 3L, 0L), ari = c(1, .9, 0, .95, .8, 0), stringsAsFactors = FALSE)
  note <- bibliolab:::density_zero_group_note(runs)
  expect_match(note, "2 de 5 repeticiones ejecutadas no detectan ningún grupo")
  expect_match(note, "1 de 3 con otra semilla"); expect_match(note, "1 de 2 al variar vecinos o minPts")
  expect_identical(bibliolab:::density_zero_group_note(transform(runs, grupos = 3L)), "")
})

test_that("M10: la lectura de incertidumbre de la JSD explica un exceso nulo y un valor fuera del intervalo", {
  u <- list(p_value = .4, excess = -.002, null_mean = .05, ci = c(.06, .09))
  txt <- bibliolab:::jsd_uncertainty_reading(.048, u)
  expect_match(txt, "no una JSD negativa"); expect_match(txt, "queda por debajo del intervalo"); expect_match(txt, "no prueba que A y B sean")
  txt2 <- bibliolab:::jsd_uncertainty_reading(.2, list(p_value = 1 / 501, excess = .15, null_mean = .05, ci = c(.15, .25)))
  expect_match(txt2, "menor que 0,001|0,002"); expect_match(txt2, "mayor que la referencia de permutación")
})

test_that("M12: el campo de texto inexistente no rompe la lectura de cobertura", {
  src <- paste(readLines(system.file("app/server/wiki.R", package = "bibliolab"), warn = FALSE), collapse = "\n")
  skip_if(!nzchar(src))
  expect_match(src, "length\\(field\\)!=1L\\|\\|is\\.na\\(field\\)\\|\\|!nzchar\\(field\\)")
  expect_match(src, "i<-match\\(field,d\\$field\\);if\\(length\\(i\\)!=1L\\|\\|is\\.na\\(i\\)\\)return\\(NULL\\)")
})

test_that("M14 y M15: tablas desplazables con teclado y modales con semántica de diálogo y foco", {
  html <- paste(as.character(bibliolab:::help_modal_body("stability")), collapse = "")
  expect_match(html, "class=\"help-scroll\" role=\"region\" tabindex=\"0\" aria-label=", fixed = FALSE)
  www <- function(f) paste(readLines(system.file(file.path("app/www", f), package = "bibliolab"), warn = FALSE), collapse = "\n")
  css <- www("style.css"); js <- www("app.js")
  expect_match(css, "\\.help-table\\{min-width:520px\\}"); expect_match(css, "\\.help-scroll\\{overflow-x:auto")
  for (needle in c("show.bs.modal", "shown.bs.modal", "hidden.bs.modal", "'role', 'dialog'", "'aria-modal', 'true'", "aria-labelledby"))
    expect_true(grepl(needle, js, fixed = TRUE), info = needle)
})

test_that("M19: el preámbulo de reproducción se detiene con un mensaje preciso ante una instalación incompatible", {
  p <- bibliolab:::script_preamble()
  expect_silent(parse(text = p))
  txt <- paste(p, collapse = "\n")
  expect_match(txt, "requiere bibliolab %s o posterior", fixed = TRUE)
  expect_match(txt, "verify_reproduction", fixed = TRUE); expect_match(txt, "pkgload::load_all", fixed = TRUE)
  expect_match(txt, "find.package('bibliolab')", fixed = TRUE)
})

test_that("M11: el diagnóstico de vocabulario cuenta los empates en cero sin juzgar el cálculo", {
  tt <- data.frame(termino = letters[1:10], tfidf_median = c(rep(0, 7), .1, .2, .3), tfidf_q75 = c(rep(0, 4), rep(.1, 6)),
    motivo_exclusion = c(rep("Retenido", 6), rep("Límite de vocabulario", 2), rep("Presencia mínima", 2)), stringsAsFactors = FALSE)
  tx <- bibliolab:::tfidf_zero_diagnosis(tt)
  expect_match(tx, "7 de 10 términos tienen mediana global 0 y 4 de 10 tienen P75 0")
  expect_match(tx, "no es un error de cálculo ni exige eliminar los ceros")
  expect_match(tx, "deja fuera 2 de 8 términos elegibles")
  tt$motivo_exclusion[7:8] <- "Retenido"
  expect_match(bibliolab:::tfidf_zero_diagnosis(tt), "no hay límite de vocabulario")
  expect_null(bibliolab:::tfidf_zero_diagnosis(NULL)); expect_null(bibliolab:::tfidf_zero_diagnosis(data.frame()))
})

test_that("M13: el nivel de FDR admitido por la interfaz coincide con el del motor y el estado sin filtro es explícito", {
  skip_if_not_installed("igraph")
  expect_null(bibliolab:::wiki_fdr_level(FALSE, 0.75)); expect_null(bibliolab:::wiki_fdr_level(FALSE, NA_real_))
  expect_identical(bibliolab:::wiki_fdr_level(TRUE, 0.05), 0.05); expect_identical(bibliolab:::wiki_fdr_level(TRUE, 0.5), 0.5)
  for (v in list(0.75, 1, 0, 0.0001, NA_real_, c(.1, .2))) expect_error(bibliolab:::wiki_fdr_level(TRUE, v), "entre 0,001 y 0,5")
  ui <- paste(as.character(bibliolab:::wiki_ui()), collapse = "")
  expect_match(ui, "wiki_concept_fdr_on"); expect_match(ui, "id=\"wiki_concept_alpha\"[^>]*max=\"0.5\"")
  expect_false(grepl("1 = sin filtro", ui, fixed = TRUE))
  # Todo valor que la interfaz acepta (0,001 a 0,5) lo acepta también el motor.
  m <- matrix(c(1,1,0,0, 1,1,0,0, 0,0,1,1, 0,0,1,1, 1,0,1,0, 0,1,0,1), 6, 4, byrow = TRUE, dimnames = list(sprintf("D%d", 1:6), c("a","b","c","d")))
  idx <- list(documents = data.frame(key = rownames(m), doc_id = rownames(m), title = rownames(m), doi = "", stringsAsFactors = FALSE),
    concepts = data.frame(key = colnames(m), label = colnames(m), documents = colSums(m > 0), occurrences = colSums(m), stringsAsFactors = FALSE),
    counts = methods::as(Matrix::Matrix(m, sparse = TRUE), "dgCMatrix"))
  for (a in c(0.001, 0.05, 0.5)) expect_no_error(bibliolab:::wiki_concept_network(idx, alpha = bibliolab:::wiki_fdr_level(TRUE, a)))
})

test_that("M03: cambiar solo las relaciones por palabra se declara como cambio del grafo analizado", {
  skip_if_not_installed("igraph")
  N <- 20; terms <- c("salud", "hospital", "paciente", "energia", "edificio", "eficiencia", "datos")
  m <- matrix(0, N, length(terms), dimnames = list(sprintf("D%02d", 1:N), terms))
  m[1:8, c("salud", "hospital", "paciente")] <- 1; m[c(3, 6), "paciente"] <- 0
  m[9:16, c("energia", "edificio", "eficiencia")] <- 1; m[c(10, 14), "edificio"] <- 0
  m[, "datos"] <- 1; m[17, c("salud", "energia")] <- 1; m[18, c("hospital", "edificio")] <- 1
  idx <- list(documents = data.frame(key = rownames(m), doc_id = rownames(m), title = rownames(m), doi = "", stringsAsFactors = FALSE),
    concepts = data.frame(key = terms, label = terms, documents = colSums(m > 0), occurrences = colSums(m), stringsAsFactors = FALSE),
    counts = methods::as(Matrix::Matrix(m, sparse = TRUE), "dgCMatrix"))
  fa <- bibliolab:::wiki_concept_network(idx, alpha = 0.05, top_k = NULL); fb <- bibliolab:::wiki_concept_network(idx, alpha = 0.05, top_k = 1)
  sa <- list(index = "x", alpha = 0.05, top_k = NA_integer_, resolution = 1); sb <- modifyList(sa, list(top_k = 1L))
  note <- bibliolab:::wiki_k_sensitivity_note(sa, fa, sb, fb)
  expect_match(note, "de todas a 1"); expect_match(note, "filtro del análisis"); expect_match(note, "enlaces pasan de 6 a 4")
  expect_match(note, "no indica por sí sola una solución mejor")
  # No se compara si cambia otro ajuste, si no cambia k o si falta el cálculo anterior.
  expect_null(bibliolab:::wiki_k_sensitivity_note(modifyList(sa, list(resolution = 2)), fa, sb, fb))
  expect_null(bibliolab:::wiki_k_sensitivity_note(sa, fa, sa, fa)); expect_null(bibliolab:::wiki_k_sensitivity_note(NULL, NULL, sb, fb))
})

test_that("M05: Modelos se abre con cinco preguntas y cada ruta declara devolución, decisión y límite", {
  rutas <- bibliolab:::model_routes()
  expect_identical(names(rutas), c("patrones", "mezclas", "grupos", "tematico", "describir"))
  for (r in rutas) for (campo in c("question", "technique", "returns", "decision", "limit", "labels")) expect_true(nzchar(r[[campo]][1]), info = campo)
  ui <- paste(as.character(bibliolab:::build_ui()), collapse = "")
  for (r in rutas) expect_true(grepl(htmltools::htmlEscape(r$question), ui, fixed = TRUE), info = r$question)
  # Cada ruta abre una pestaña que existe con ese título exacto.
  for (tab in unlist(lapply(rutas, `[[`, "tabs"))) expect_true(grepl(paste0("data-value=\"", tab, "\""), ui, fixed = TRUE), info = tab)
  expect_null(rutas$describir$tabs); expect_match(rutas$describir$limit, "no permite inferir temas, grupos")
  # La pregunta precede a los parámetros: el selector de ruta aparece antes que el primer panel de técnica.
  expect_lt(regexpr("model_route", ui, fixed = TRUE), regexpr("data-value=\"UMAP + HDBSCAN\"", ui, fixed = TRUE))
})

test_that("M17: la descripción puede cerrarse sin modelos y cada descarga se explica por su uso", {
  ui <- paste(as.character(bibliolab:::build_ui()), collapse = "")
  expect_match(ui, "Finalizar descripción y descargar")
  f <- system.file("R/app_server.R", package = "bibliolab")
  skip_if(!nzchar(f), "el paquete instalado no incluye las fuentes R")
  src <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_match(src, "finish_description = \"export\""); expect_match(src, "finish_models = \"export\"")
  for (id in c("download_zip", "download_report", "download_code", "download_methods", "download_methods_md", "download_bank"))
    expect_equal(lengths(regmatches(ui, gregexpr(paste0("id=\"", id, "\""), ui, fixed = TRUE))), 1L, info = id)
  for (objetivo in c("Revisar los resultados", "Informar los métodos", "Reproducir el cálculo", "Conservar toda la ejecución")) expect_match(ui, objetivo, fixed = TRUE)
  # Las skills (y su aviso completo) aparecen después de la tabla de descargas, y el aviso sigue accesible.
  expect_lt(regexpr("Qué descargar según tu objetivo", ui, fixed = TRUE), regexpr("Redacción asistida / skills", ui, fixed = TRUE))
  expect_match(ui, "La IA no es autora ni responsable del paper", fixed = TRUE)
})

test_that("M08: las decisiones especializadas quedan en opciones avanzadas con valores iniciales restablecibles", {
  ui <- paste(as.character(bibliolab:::build_ui()), collapse = "")
  pos <- function(x) regexpr(x, ui, fixed = TRUE)[1]
  inicio <- pos("Opciones avanzadas de LSA y UMAP"); fin <- pos("id=\"density_seed\"")
  expect_true(inicio > 0 && fin > inicio)
  # Dentro del bloque avanzado: dimensiones LSA, dimensiones para agrupar, compactación, épocas y restablecer.
  for (id in c("lsa_dims", "umap_dims", "umap_min_dist", "umap_epochs", "reset_density_advanced")) {
    p <- pos(paste0("id=\"", id, "\"")); expect_true(p > inicio && p < fin, info = id)
  }
  # Siguen visibles las decisiones metodológicas: vecinos y minPts, antes del bloque avanzado.
  for (id in c("umap_neighbors", "hdb_min_pts")) { p <- pos(paste0("id=\"", id, "\"")); expect_true(p > 0 && p < inicio, info = id) }
  # Los trabajadores y el paralelismo están en un bloque avanzado de la preparación.
  a <- pos("Opciones avanzadas / rendimiento y procesamiento paralelo"); expect_true(a > 0)
  expect_true(pos("id=\"processing_controls\"") > a); expect_true(pos("id=\"reset_processing\"") > a)
  # Los valores que restablece el servidor son los iniciales de la interfaz.
  expect_match(ui, "id=\"lsa_dims\"[^>]*value=\"30\""); expect_match(ui, "id=\"umap_dims\"[^>]*value=\"5\"")
  expect_match(ui, "id=\"umap_min_dist\"[^>]*value=\"0\"")
  f <- system.file("app/server/pedagogy.R", package = "bibliolab"); skip_if(!nzchar(f))
  src <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_match(src, "\"lsa_dims\",value=30", fixed = TRUE); expect_match(src, "\"umap_dims\",value=5", fixed = TRUE)
  expect_match(src, "\"umap_min_dist\",value=0", fixed = TRUE); expect_match(src, "\"umap_epochs\",selected=\"300\"", fixed = TRUE)
})
