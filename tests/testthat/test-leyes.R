# Leyes de Lotka, Bradford y Zipf (R/leyes.R) y rotulado de nodos en Redes.

test_that("Lotka recupera el exponente de una poblacion simulada y no depende del metodo clasico", {
  set.seed(1)
  x <- sample(1:60, 400, TRUE, prob = (1:60)^-2)
  f <- lotka_fit(x)
  expect_identical(f$estado, "ok")
  expect_lt(abs(f$exponente - 2), 0.25)
  # El ajuste por minimos cuadrados subestima el exponente con colas poco pobladas: no debe ser el principal.
  expect_lt(f$exponente_ls, f$exponente)
  expect_true(f$compatible)
  expect_match(f$lectura, "no lo demuestra", fixed = TRUE)
  expect_false(grepl("confirma", f$lectura, fixed = TRUE))
})

test_that("Lotka detecta una distribucion que no sigue una ley de potencia", {
  x <- c(rep(1, 150), rep(2, 20), rep(3, 20), rep(25, 60), rep(26, 50))
  f <- lotka_fit(x)
  expect_identical(f$estado, "ok")
  expect_false(f$compatible)
  expect_match(f$lectura, "se aparta", fixed = TRUE)
})

test_that("las tres leyes se niegan a ajustar con datos insuficientes y lo explican", {
  expect_identical(lotka_fit(c(1, 1, 2, 3))$estado, "insuficiente")
  expect_identical(lotka_fit(rep(c(1, 2), 50))$estado, "insuficiente") # solo dos niveles
  expect_identical(bradford_fit(data.frame(elemento = c("a", "b", "c"), documentos = c(8, 8, 8)))$estado, "insuficiente")
  expect_identical(zipf_fit(paste0("w", 1:10), 10:1)$estado, "insuficiente")
  f <- lotka_fit(c(1, 1, 2))
  expect_match(f$lectura, "No hay datos suficientes", fixed = TRUE)
  expect_s3_class(lotka_graph(f), "ggplot")
})

test_that("Bradford forma tres zonas con un tercio de los articulos y compara multiplicadores", {
  docs <- c(rep(16, 5), rep(4, 20), rep(1, 80))
  f <- bradford_fit(data.frame(elemento = paste0("R", seq_along(docs)), documentos = docs))
  expect_identical(f$estado, "ok")
  expect_equal(f$zonas$fuentes, c(5L, 20L, 80L))
  expect_equal(f$zonas$porcentaje_documentos, rep(100 / 3, 3), tolerance = 1e-8)
  expect_equal(f$multiplicadores, c(4, 4))
  expect_true(f$compatible)
  docs2 <- c(rep(40, 2), rep(10, 8), rep(1, 80))
  g <- bradford_fit(data.frame(elemento = paste0("R", seq_along(docs2)), documentos = docs2))
  expect_false(g$compatible)
  expect_match(g$lectura, "No prueba la ley|no se parece", perl = TRUE)
})

test_that("Zipf ajusta una recta log-log y declara su criterio", {
  fr <- round(1000 / (1:300)^1.05)
  f <- zipf_fit(paste0("w", 1:300), fr)
  expect_identical(f$estado, "ok")
  expect_lt(abs(f$exponente - 1.05), 0.05)
  expect_true(f$compatible)
  expect_match(f$criterio, "Descriptivo, no confirma la ley", fixed = TRUE)
  expect_s3_class(zipf_graph(f), "ggplot"); expect_s3_class(bradford_graph(bradford_fit(data.frame(elemento = "a", documentos = 1))), "ggplot")
})

test_that("con el corpus de practica solo Zipf es calculable y las tablas se exportan", {
  p <- practica()
  L <- bibliometric_laws(p$bibliography, p$corpus)
  expect_identical(L$lotka$estado, "insuficiente"); expect_identical(L$bradford$estado, "insuficiente"); expect_identical(L$zipf$estado, "ok")
  tabs <- laws_tables(L)
  expect_true(all(c("ley_lotka_resumen", "ley_bradford_resumen", "ley_zipf_resumen", "ley_zipf_tabla") %in% names(tabs)))
  d <- withr::local_tempdir(); out <- file.path(d, "entrega")
  export_bundle(out, p$prepared, p$corpus, p$bibliography, raw = p$raw)
  expect_true(file.exists(file.path(out, "ley_zipf_tabla.csv")))
  expect_true(any(grepl("Ley de Zipf", readLines(file.path(out, "informe.html"), warn = FALSE, encoding = "UTF-8"))))
  md <- readLines(file.path(out, "informe_metodologico.md"), warn = FALSE, encoding = "UTF-8")
  expect_true(any(grepl("Leyes de Lotka, Bradford y Zipf", md, fixed = TRUE)))
})

test_that("la interfaz ofrece la pestana de leyes con una salida por ley", {
  html <- as.character(build_ui())
  expect_match(html, "Leyes biblio", fixed = TRUE)
  for (id in c("law_lotka_plot", "law_bradford_plot", "law_zipf_plot", "help_lotka", "help_zipf")) expect_match(html, id, fixed = TRUE)
})

mapeo_leyes <- list(col_text = "Abstract", col_title = "Title", col_id = "ID", col_year = "Year", col_source = "Source",
  col_authors = "Authors", col_citations = "Cited by", col_keywords = "Author Keywords", col_doi = "DOI", col_language = "Language",
  language = "es", remove_stop = TRUE, min_chars = 3L, min_df = 2L, max_terms = 1000L, sample_pct = 100, sample_seed = 2026L, dedup = TRUE)

test_that("Redes rotula todos los nodos con halo blanco y permite rotular solo los destacados", {
  skip_on_cran(); skip_if_not(requireNamespace("visNetwork", quietly = TRUE))
  raw <- practica_raw()
  shiny::testServer(bibliolab:::app_server, {
    set_data(raw, "practica", TRUE)
    do.call(session$setInputs, mapeo_leyes)
    session$setInputs(prepare = 1)
    session$setInputs(network_type = "words", network_nodes = 30, network_presence = 2, network_shared = 1, network_edges = 120)
    session$setInputs(run_network = 1)
    fit <- network_current(); skip_if(is.null(fit))
    w <- make_network_widget(fit)
    n <- w$x$nodes
    expect_true(all(nzchar(n$label)))
    expect_true(all(n$font.size >= 13))
    expect_true(all(n$font.strokeWidth == 4)); expect_true(all(n$font.strokeColor == "#ffffff"))
    session$setInputs(network_label_all = FALSE)
    n2 <- make_network_widget(fit)$x$nodes
    if (nrow(n2) > 15) expect_true(any(!nzchar(n2$label)))
  })
})

test_that("Narrativa didactica: cada concepto declara pregunta, calculo, analogia con limite y errores", {
  n <- narrative_catalog()
  expect_true(all(c("lotka", "bradford", "zipf", "jsd", "lda", "density", "networks", "tokens", "pca", "ca", "bm25", "coverage") %in% names(n)))
  for (k in names(n)) {
    x <- n[[k]]
    expect_true(all(c("natural", "calcula", "analogia", "limite", "errores") %in% names(x)), info = k)
    expect_true(all(nzchar(c(x$natural, x$calcula, x$analogia, x$limite))), info = k)
    expect_true(endsWith(trimws(x$natural), "?"), info = k)
    expect_gte(length(x$errores), 2L)
    expect_true(grepl("\\*\\*[^*]+\\*\\*", x$calcula) || k %in% c("coverage"), info = k)
  }
  html <- as.character(narrative_ui("lotka"))
  expect_match(html, "Lo que quieres saber", fixed = TRUE)
  expect_match(html, "Dónde deja de servir", fixed = TRUE)
  expect_match(html, "<strong>exponente</strong>", fixed = TRUE)
  expect_identical(as.character(rich_p("<b>x</b> **y**")), "<p>&lt;b&gt;x&lt;/b&gt; <strong>y</strong></p>")
})

test_that("Cada ley ofrece una frase de informe con las cifras del corpus y sin afirmar la ley", {
  d <- read_biblio_csv(app_extdata("practica.csv"), ";")
  p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
  L <- bibliometric_laws(biblio_summary(p), cp)
  for (k in names(L)) {
    f <- L[[k]]
    if (identical(f$estado, "ok")) {
      expect_true(nzchar(f$informe), info = k)
      expect_false(grepl("confirma la ley|demuestra la ley|se cumple la ley", f$informe), info = k)
      expect_match(f$informe, "descripción|descripción del|descripción de", info = k)
    } else expect_identical(f$informe, "", info = k)
  }
  z <- zipf_fit(paste0("w", 1:60), round(1000 / (1:60)))
  expect_match(z$informe, "60 términos evaluados", fixed = TRUE)
  expect_match(z$informe, fmt_es(z$exponente), fixed = TRUE)
  expect_identical(lotka_fit(c(1, 1, 2))$informe, "")
})
