# Registro de reproducibilidad e informe metodologico (V4).

#' Registro de reproducibilidad de una ejecucion
#'
#' Reune versiones de R y paquetes, plataforma, semillas, parametros y huella de
#' los datos de entrada: lo necesario para repetir un analisis y para declararlo
#' en la seccion de metodos.
#'
#' @param prepared Resultado de [prepare_documents()].
#' @param corpus Resultado de [prepare_corpus()] (opcional).
#' @param lda,ca,pca,density,network,comparison Resultados de los modelos, si existen.
#' @param input_md5 Huella MD5 del archivo importado, si se conoce.
#'
#' @return Lista serializable a JSON con `software`, `entorno`, `semillas`,
#'   `datos` y `modelos`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' rec <- reproducibility_record(p)
#' rec$software$bibliolab
#' @export
reproducibility_record <- function(prepared, corpus = NULL, lda = NULL, ca = NULL, density = NULL, network = NULL,
                                   comparison = NULL, pca = NULL, input_md5 = NULL) {
  pk <- c("shiny", "Matrix", "data.table", "igraph", "topicmodels", "slam", "udpipe", "cld2", "uwot", "dbscan", "irlba",
          "mgcv", "ggplot2", "readxl", "stopwords", "jsonlite", "DT", "plotly", "visNetwork", "zip")
  ver <- function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  versions <- vapply(pk, ver, "")
  info <- Sys.info()
  cfg <- prepared$config
  seeds <- list(muestra = if (isTRUE(cfg$sample_pct < 100)) cfg$seed else NULL,
    lda = lda$params$seed, correspondencias_linea_base = ca$params$baseline$seed, acp_linea_base = pca$params$baseline$seed,
    umap_hdbscan = density$params$seed, red = network$params$seed, jsd = comparison$params$seed)
  models <- Filter(Negate(is.null), list(
    lda = if (!is.null(lda)) lda$params, correspondencias = if (!is.null(ca)) ca$params, acp = if (!is.null(pca)) pca$params,
    umap_hdbscan = if (!is.null(density)) density$params, red = if (!is.null(network)) network$params,
    jsd = if (!is.null(comparison)) comparison$params))
  list(
    software = list(bibliolab = BIBLIO_VERSION, R = R.version.string, paquetes = as.list(versions[!is.na(versions)])),
    entorno = list(plataforma = R.version$platform, sistema = unname(info[["sysname"]]), version_sistema = unname(info[["release"]]),
      locale = Sys.getlocale("LC_CTYPE"), zona_horaria = Sys.timezone(), blas = unname(extSoftVersion()[["BLAS"]])),
    semillas = Filter(Negate(is.null), seeds),
    datos = list(fuente = prepared$source_name, md5_archivo = input_md5 %||% prepared$input_md5 %||% NA_character_,
      documentos_importados = if (!is.null(prepared$audit)) prepared$audit$documentos[1] else NA,
      documentos_analizados = nrow(prepared$documents), practica_sintetica = isTRUE(prepared$is_demo),
      preparado_en = prepared$prepared_at %||% NA_character_),
    parametros_preparacion = cfg,
    modelos_idioma = if (!is.null(corpus)) corpus$models else list(),
    modelos = models,
    generado_en = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}

fmt_value <- function(x, digits = 4) {
  if (is.numeric(x)) ifelse(is.na(x), "NA", ifelse(x == round(x) & abs(x) < 1e9, format(x, scientific = FALSE, trim = TRUE), formatC(x, digits = digits, format = "g")))
  else if (is.logical(x)) ifelse(is.na(x), "NA", ifelse(x, "S\u00ed", "No")) else ifelse(is.na(x), "NA", as.character(x))
}
md_escape_cell <- function(x) gsub("|", "/", gsub("\n", " ", x, fixed = TRUE), fixed = TRUE)
md_table <- function(d, max_rows = 40L) {
  if (is.null(d) || !nrow(d)) return("_Sin datos._")
  shown <- utils::head(d, max_rows)
  cells <- lapply(shown, function(col) md_escape_cell(fmt_value(col)))
  rows <- do.call(paste, c(lapply(cells, function(v) paste0("| ", v)), list(sep = " ")))
  out <- c(paste0("| ", paste(names(shown), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(shown)), collapse = "|"), "|"), paste0(rows, " |"))
  if (nrow(d) > max_rows) out <- c(out, "", paste0("_Se muestran ", max_rows, " de ", nrow(d), " filas; el resto est\u00e1 en los CSV._"))
  out
}
kv_table <- function(keys, values) md_table(data.frame(campo = keys, valor = vapply(values, function(v) if (is.null(v) || !length(v)) "No indicado" else paste(fmt_value(v), collapse = ", "), ""), stringsAsFactors = FALSE))

#' Informe metodologico en Markdown
#'
#' Genera un texto en espanol con los procedimientos aplicados, parametros,
#' diagnosticos de validez ejecutados (y los que no se han ejecutado), limitaciones
#' y registro de reproducibilidad. Es un borrador para la seccion de metodos: no
#' sustituye el juicio del investigador ni valida interpretaciones sustantivas.
#'
#' @param prepared,corpus,bibliography Resultados de [prepare_documents()],
#'   [prepare_corpus()] y [biblio_summary()].
#' @param lda,ca,pca,density,network,comparison Resultados de los modelos, si existen.
#' @param record Salida de [reproducibility_record()]; se calcula si es `NULL`.
#' @param lda_selection Salida de [lda_select_k()] (opcional).
#' @param density_sensitivity Salida de [density_sensitivity()] (opcional).
#'
#' @return Cadena de texto en Markdown.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' cp <- prepare_corpus(p)
#' cat(substr(methods_report(p, cp, biblio_summary(p)), 1, 400))
#' @export
methods_report <- function(prepared, corpus, bibliography, lda = NULL, ca = NULL, pca = NULL, density = NULL,
                           network = NULL, comparison = NULL, record = NULL, lda_selection = NULL, density_sensitivity = NULL) {
  if (is.null(record)) record <- reproducibility_record(prepared, corpus, lda = lda, ca = ca, density = density, network = network, comparison = comparison, pca = pca)
  cfg <- prepared$config; prov <- prepared$provenance %||% list()
  L <- character()
  add <- function(...) L <<- c(L, ...)
  add(paste0("# Informe metodol\u00f3gico \u00b7 bibliolab ", BIBLIO_VERSION), "",
    paste0("Generado: ", record$generado_en, ". ", if (isTRUE(prepared$is_demo)) "**DATOS DE PR\u00c1CTICA FICTICIOS: no usar como evidencia de investigaci\u00f3n.**" else ""), "",
    "## 0. C\u00f3mo leer este informe", "",
    "- **Nivel de evidencia:** todo lo que sigue es *descriptivo* o *exploratorio*. Ninguna salida de esta herramienta es una prueba confirmatoria ni permite inferencias causales.",
    "- Los modelos (temas, grupos, ejes, comunidades) son **herramientas de lectura**: su validez sustantiva depende de leer documentos y justificar etiquetas.",
    "- Este texto es un borrador de la secci\u00f3n de m\u00e9todos; debe completarse con la informaci\u00f3n que la herramienta no conoce (ver secci\u00f3n 8).", "")
  # 1. Datos
  add("## 1. Datos y procedencia", "",
    kv_table(c("Fuente local", "Base de datos", "Ecuaci\u00f3n de b\u00fasqueda", "Fecha de extracci\u00f3n", "Criterios de inclusi\u00f3n/exclusi\u00f3n", "Huella MD5 del archivo", "Pregunta de investigaci\u00f3n"),
      list(prepared$source_name, prov$base_de_datos, prov$ecuacion_busqueda, prov$fecha_extraccion, prov$criterios, record$datos$md5_archivo, prepared$question)), "",
    "Flujo de documentos:", "", md_table(prepared$audit), "")
  if (length(prepared$issues)) add("Avisos de calidad:", "", paste0("- ", prepared$issues), "")
  # 2. Preparacion
  add("## 2. Preparaci\u00f3n del texto", "",
    kv_table(c("Columna de texto", "Idioma de palabras vac\u00edas", "Lematizaci\u00f3n (UDPipe)", "Filtro gramatical", "Unidad de an\u00e1lisis", "Presencia m\u00ednima (documentos)",
      "Presencia m\u00e1xima (%)", "Frecuencia m\u00ednima", "Longitud m\u00ednima/m\u00e1xima", "Orden del vocabulario", "Unificaci\u00f3n de variantes de etiquetas", "Retirada de avisos de copyright"),
      list(prepared$mapping$text, cfg$language, cfg$lemmatize, if (isTRUE(cfg$pos_filter)) paste(cfg$pos_keep, collapse = "/") else "No", if (isTRUE(cfg$split_sentences)) "frase" else "documento",
        cfg$min_df, cfg$max_df_pct, cfg$min_tf, paste(cfg$min_chars, cfg$max_chars, sep = "\u2013"), cfg$term_order,
        isTRUE(cfg$normalize_labels %||% TRUE), isTRUE(cfg$remove_boilerplate %||% TRUE))), "")
  if (!is.null(corpus$issues)) add(paste0("- ", corpus$issues), "")
  add(paste0("Resumen TF-IDF para ordenar: ",cfg$tfidf_stat %||% "mean","; unidades: ",cfg$tfidf_scope %||% "all","; percentil configurable: ",cfg$tfidf_percentile %||% 75,". Los percentiles usan tipo 7 de R. MAD es mediana de desviaciones absolutas sin escalar (constant = 1); los res\u00famenes globales incluyen ceros entre unidades activas. El umbral m\u00ednimo sigue usando la media global. Estos pesos seleccionan vocabulario; LDA y correspondencias usan conteos."), "")
  if (length(corpus$models)) add("Modelos ling\u00fc\u00edsticos:", "", md_table(data.frame(idioma = names(corpus$models), archivo = vapply(corpus$models, `[[`, "", "file"), md5 = vapply(corpus$models, `[[`, "", "md5"), licencia = vapply(corpus$models, function(m) m$licencia %||% "no registrada", ""))), "", model_license_notice(), "")
  # 3. Bibliometria
  add("## 3. Descripci\u00f3n bibliom\u00e9trica", "",
    "Los indicadores describen el corpus recuperado; los datos ausentes se excluyen de cada c\u00e1lculo y no se convierten en cero. Se informa h del corpus completo y h por autor restringido a sus publicaciones de esta b\u00fasqueda, junto con cobertura de citas. Con citas ausentes es un l\u00edmite inferior. El h por autor no representa su carrera completa y exige desambiguar identidades.", "",
    md_table(bibliography$overview), "")
  nv <- bibliography$normalizacion
  if (!is.null(nv) && nrow(nv)) add(paste0("Se unificaron variantes de escritura en ", length(unique(paste(nv$campo, nv$elemento))), " etiquetas (", nrow(nv), " variantes). La tabla completa est\u00e1 en bibliografia_normalizacion.csv. No se resuelven hom\u00f3nimos ni abreviaturas distintas de una misma revista."), "")
  laws <- bibliometric_laws(bibliography, corpus)
  add("### 3.1 Leyes de Lotka, Bradford y Zipf", "",
    "Se comparan la productividad de autores, la dispersi\u00f3n en fuentes y la frecuencia de palabras con tres patrones cl\u00e1sicos. El resultado es **descriptivo**: indica cu\u00e1nto se parece el corpus al patr\u00f3n seg\u00fan el criterio declarado y no confirma ninguna ley. Con pocos autores, fuentes o t\u00e9rminos no se calcula el ajuste.", "")
  for (nm in names(laws)) { f <- laws[[nm]]
    add(paste0("**", c(lotka = "Lotka (autores)", bradford = "Bradford (fuentes)", zipf = "Zipf (palabras)")[[nm]], ".** ", f$lectura), "",
      if (nzchar(f$criterio)) paste0("Criterio: ", f$criterio), "", if (nrow(f$resumen)) md_table(f$resumen), "") }
  # 4. Modelos
  add("## 4. Modelos y an\u00e1lisis ejecutados", "")
  if (is.null(lda) && is.null(ca) && is.null(pca) && is.null(density) && is.null(network) && is.null(comparison)) add("No se ha ejecutado ning\u00fan modelo en esta sesi\u00f3n.", "")
  if (!is.null(lda)) {
    pr <- lda$params
    add("### 4.1 LDA (Latent Dirichlet Allocation)", "",
      paste0("Muestreo de Gibbs (topicmodels); k = ", pr$k, ", alpha = ", format(pr$alpha, digits = 4), ", delta = ", pr$delta, ", burn-in = ", pr$burnin, ", thin = ", pr$thin,
        ", iteraciones = ", pr$iterations, ", semilla = ", pr$seed, ". Unidades: ", lda$units, "; t\u00e9rminos: ", lda$terms, "."), "",
      md_table(lda$diagnostics$overview), "", "Calidad por tema:", "", md_table(lda$diagnostics$topics), "",
      "Las etiquetas de los temas son interpretaciones del investigador; LDA solo entrega distribuciones de palabras.", "")
  }
  if (!is.null(ca)) add("### 4.2 An\u00e1lisis de correspondencias", "",
      paste0("T\u00e9rminos m\u00e1s frecuentes incluidos: ", ca$params$max_terms, ". Los dos primeros ejes recogen ", fmt_value(sum(ca$dimensions$porcentaje[1:2])), "% de la inercia."), "",
      md_table(ca$dimensions[seq_len(min(6, nrow(ca$dimensions))), ]), "")
  if (!is.null(pca)) add("### 4.3 An\u00e1lisis de componentes principales", "",
      paste0("Representaci\u00f3n: ", pca$params$representation, ". Estandarizaci\u00f3n: ", if (pca$params$standardize) "s\u00ed" else "no", ". Los dos primeros componentes recogen ", fmt_value(sum(pca$dimensions$porcentaje[1:2])), "% de la varianza."), "",
      md_table(pca$dimensions[seq_len(min(6, nrow(pca$dimensions))), ]), "")
  if (!is.null(density)) {
    add("### 4.4 UMAP + HDBSCAN", "",
      paste0("Representaci\u00f3n: ", density$representation$type, ". Vecinos = ", density$params$neighbors, ", dimensiones de agrupaci\u00f3n = ", density$params$cluster_dims,
        ", min_dist = ", density$params$min_dist, ", minPts = ", density$params$min_pts, ", semilla = ", density$params$seed, "."), "",
      md_table(density$quality), "", paste0("- ", density$issues), "")
  }
  if (!is.null(comparison)) {
    add("### 4.5 Divergencia de Jensen-Shannon (JSD)", "",
      paste0(comparison$params$label_A, " frente a ", comparison$params$label_B, "; ponderaci\u00f3n: ", comparison$params$weighting, ". JSD = ", fmt_value(comparison$jsd), " bits (distancia ", fmt_value(comparison$distancia), ")."), "",
      paste0("- ", comparison$issues), "")
  }
  if (!is.null(network)) {
    add("### 4.6 Red", "", network$note, "", md_table(network$summary), "")
  }
  # 5. Validacion
  add("## 5. Validaci\u00f3n y robustez", "")
  checks <- data.frame(verificacion = character(), estado = character(), resultado = character(), stringsAsFactors = FALSE)
  chk <- function(v, e, r) checks[nrow(checks) + 1L, ] <<- list(v, e, r)
  if (!is.null(lda)) {
    conv <- lda$diagnostics$convergence
    chk("Convergencia aproximada de LDA", "Ejecutada", if (isTRUE(conv$converged)) paste0("Cambio relativo de log-verosimilitud ", fmt_value(conv$relative_change), " (estable)") else paste0("Cambio relativo ", fmt_value(conv$relative_change), ": considera m\u00e1s iteraciones"))
    chk("Selecci\u00f3n del n\u00famero de temas", if (is.null(lda_selection)) "No ejecutada" else "Ejecutada", if (is.null(lda_selection)) "k fijado sin comparar soluciones" else lda_selection$recommendation$text)
  }
  if (!is.null(density)) {
    if (is.null(density_sensitivity)) chk("Estabilidad de UMAP + HDBSCAN", "No ejecutada", "Una sola ejecuci\u00f3n: no se conoce la estabilidad entre semillas ni par\u00e1metros")
    else {
      st <- density_sensitivity$runs$estado %||% rep("ejecutada", nrow(density_sensitivity$runs))
      chk("Estabilidad de UMAP + HDBSCAN", if (all(st != "ejecutada" | seq_along(st) == 1L)) "Fallida" else "Ejecutada",
        paste0(density_sensitivity$reading, sprintf(" Repeticiones efectivas: %d de %d.", sum(st == "ejecutada") - 1L, length(st) - 1L)))
    }
  }
  if (!is.null(comparison)) {
    ustate <- comparison$uncertainty_status %||% if (is.null(comparison$uncertainty)) "no_ejecutada" else "ejecutada"
    chk("JSD frente a referencia nula", {lab <- unname(c(ejecutada = "Ejecutada", fallida = "Fallida", no_aplicable = "No aplicable", no_solicitada = "No ejecutada")[ustate]); if (is.na(lab)) "No ejecutada" else lab},
      if (identical(ustate, "ejecutada")) sprintf("JSD nula esperada %.4f; exceso %.4f; p de permutaci\u00f3n %.3f (%d permutaciones v\u00e1lidas)", comparison$uncertainty$null_mean, comparison$uncertainty$excess, comparison$uncertainty$p_value, comparison$uncertainty$valid_null %||% comparison$uncertainty$B)
      else if (nzchar(comparison$uncertainty_cause %||% "")) paste("Sin referencia de ruido de muestreo:", comparison$uncertainty_cause) else "Sin referencia de ruido de muestreo")
  }
  for (m in list(list("Correspondencias", ca), list("ACP", pca))) if (!is.null(m[[2]])) {
    d <- m[[2]]$dimensions
    chk(paste("Ejes de", m[[1]], "frente al azar"), if (isTRUE(m[[2]]$params$baseline$computed)) "Ejecutada" else "No ejecutada",
      if (isTRUE(m[[2]]$params$baseline$computed)) paste0("Ejes por encima del percentil 95 de la permutaci\u00f3n: ", sum(d$supera_azar %in% TRUE), " de ", sum(!is.na(d$supera_azar))) else "Sin l\u00ednea base")
  }
  if (!is.null(network)) {
    st <- network$stability
    if (is.null(st)) {
      value <- network$summary$valor[grepl("Estabilidad de comunidades", network$summary$indicador)][1]
      if (length(value) && is.finite(value)) chk("Estabilidad de comunidades de la red", "Ejecutada", paste0("ARI medio ", fmt_value(value)))
    } else chk("Estabilidad de comunidades de la red", c(ejecutada = "Ejecutada", no_aplicable = "No aplicable", fallida = "Fallida")[[st$status]],
      if (identical(st$status, "ejecutada")) sprintf("ARI medio %s sobre %d repeticiones de Louvain con semillas derivadas", fmt_value(st$ari), st$B) else st$reason)
  }
  chk("Lectura de documentos y validaci\u00f3n de etiquetas", "Pendiente", "La herramienta no puede verificarla: debe hacerla el investigador y documentarla")
  add(md_table(checks), "")
  # 6. Limitaciones
  add("## 6. Limitaciones y cautelas", "",
    "- El corpus es el resultado de una b\u00fasqueda concreta: no representa todo el campo ni permite generalizar fuera de \u00e9l.",
    "- Producci\u00f3n, citas y centralidades describen posiciones en estos datos; no miden calidad, impacto causal ni liderazgo.",
    "- Autores: no se resuelven hom\u00f3nimos ni variantes que difieran m\u00e1s que en may\u00fasculas, acentos o puntuaci\u00f3n.",
    "- Las citas dependen de la base y de la fecha de extracci\u00f3n; los a\u00f1os recientes tienen menos tiempo para acumular citas.",
    "- Los modelos no son equivalentes ni compiten por una puntuaci\u00f3n com\u00fan; una concordancia entre ellos apoya una lectura pero no la prueba.",
    "- Los resultados con semilla fija son repetibles, no necesariamente estables: contrasta semillas y par\u00e1metros.", "")
  # 7. Reproducibilidad
  add("## 7. Reproducibilidad", "",
    kv_table(c("bibliolab", "R", "Plataforma", "Sistema", "Locale", "Zona horaria"),
      list(record$software$bibliolab, record$software$R, record$entorno$plataforma, paste(record$entorno$sistema, record$entorno$version_sistema), record$entorno$locale, record$entorno$zona_horaria)), "",
    "Paquetes:", "", md_table(data.frame(paquete = names(record$software$paquetes), version = unlist(record$software$paquetes, use.names = FALSE), stringsAsFactors = FALSE)), "")
  if (length(record$semillas)) add("Semillas:", "", md_table(data.frame(analisis = names(record$semillas), semilla = unlist(record$semillas, use.names = FALSE), stringsAsFactors = FALSE)), "")
  # 8. Pendiente
  add("## 8. Informaci\u00f3n que debe completar el investigador", "",
    paste0("- [", ifelse(nzchar(prov$base_de_datos %||% ""), "x", " "), "] Base de datos y fecha de extracci\u00f3n."),
    paste0("- [", ifelse(nzchar(prov$ecuacion_busqueda %||% ""), "x", " "), "] Ecuaci\u00f3n de b\u00fasqueda completa."),
    paste0("- [", ifelse(nzchar(prov$criterios %||% ""), "x", " "), "] Criterios de inclusi\u00f3n y exclusi\u00f3n."),
    "- [ ] Justificaci\u00f3n te\u00f3rica de la pregunta y del dise\u00f1o (no se puede inferir de los datos).",
    "- [ ] Procedimiento de lectura y validaci\u00f3n de etiquetas de temas o grupos, y qui\u00e9n lo realiz\u00f3.",
    "- [ ] Declaraci\u00f3n de uso de IA conforme a la instituci\u00f3n y la revista, si procede.", "",
    "## Referencias metodol\u00f3gicas", "",
    "- Blei, D. M., Ng, A. Y., & Jordan, M. I. (2003). Latent Dirichlet allocation. *Journal of Machine Learning Research, 3*, 993-1022.",
    "- Chang, J., Boyd-Graber, J., Gerrish, S., Wang, C., & Blei, D. (2009). Reading tea leaves: How humans interpret topic models. *NIPS*.",
    "- Greene, D., O'Callaghan, D., & Cunningham, P. (2014). How many topics? Stability analysis for topic models. *ECML PKDD*.",
    "- Hubert, L., & Arabie, P. (1985). Comparing partitions. *Journal of Classification, 2*, 193-218.",
    "- Lin, J. (1991). Divergence measures based on the Shannon entropy. *IEEE Transactions on Information Theory, 37*, 145-151.",
    "- Mimno, D., Wallach, H., Talley, E., Leenders, M., & McCallum, A. (2011). Optimizing semantic coherence in topic models. *EMNLP*.",
    "- Wallach, H. M., Mimno, D., & McCallum, A. (2009). Rethinking LDA: Why priors matter. *NIPS*.",
    "- McInnes, L., Healy, J., & Melville, J. (2018). UMAP: Uniform Manifold Approximation and Projection. *arXiv:1802.03426*.",
    "- Campello, R., Moulavi, D., & Sander, J. (2013). Density-based clustering based on hierarchical density estimates. *PAKDD*.",
    "- van Eck, N. J., & Waltman, L. (2009). How to normalize cooccurrence data? *JASIST, 60*, 1635-1651.")
  paste(L, collapse = "\n")
}

#' Convierte el informe metodologico a HTML autonomo
#'
#' Conversor minimo (titulos, listas, tablas, negrita/cursiva y parrafos) sin
#' dependencias externas; el contenido se escapa para evitar HTML inyectado.
#'
#' @param md Cadena Markdown de [methods_report()].
#' @return Cadena HTML completa.
#' @examples
#' cat(methods_report_html("# Titulo\n\nTexto con **negrita**."))
#' @export
methods_report_html <- function(md) {
  esc <- function(x) as.character(htmltools::htmlEscape(x))
  inline <- function(x) {
    x <- esc(x)
    x <- gsub("[*][*]([^*]+)[*][*]", "<strong>\\1</strong>", x)
    x <- gsub("[*]([^*]+)[*]", "<em>\\1</em>", x)
    gsub("_([^_]+)_", "<em>\\1</em>", x)
  }
  lines <- strsplit(md, "\n", fixed = TRUE)[[1]]
  out <- character(); i <- 1L; in_list <- FALSE
  close_list <- function() if (in_list) { out <<- c(out, "</ul>"); in_list <<- FALSE }
  while (i <= length(lines)) {
    ln <- lines[i]
    if (grepl("^[|].*[|]$", ln)) {
      close_list()
      block <- character()
      while (i <= length(lines) && grepl("^[|].*[|]$", lines[i])) { block <- c(block, lines[i]); i <- i + 1L }
      cells <- function(z) trimws(strsplit(sub("^[|]", "", sub("[|]$", "", z)), "|", fixed = TRUE)[[1]])
      head_cells <- cells(block[1]); body <- block[-(1:2)]
      out <- c(out, "<div class='scroll'><table><thead><tr>", paste0("<th>", vapply(head_cells, inline, ""), "</th>", collapse = ""), "</tr></thead><tbody>",
        vapply(body, function(r) paste0("<tr>", paste0("<td>", vapply(cells(r), inline, ""), "</td>", collapse = ""), "</tr>"), ""), "</tbody></table></div>")
      next
    }
    if (grepl("^### ", ln)) { close_list(); out <- c(out, paste0("<h3>", inline(sub("^### ", "", ln)), "</h3>")) }
    else if (grepl("^## ", ln)) { close_list(); out <- c(out, paste0("<h2>", inline(sub("^## ", "", ln)), "</h2>")) }
    else if (grepl("^# ", ln)) { close_list(); out <- c(out, paste0("<h1>", inline(sub("^# ", "", ln)), "</h1>")) }
    else if (grepl("^- ", ln)) { if (!in_list) { out <- c(out, "<ul>"); in_list <- TRUE }; out <- c(out, paste0("<li>", inline(sub("^- ", "", ln)), "</li>")) }
    else if (nzchar(trimws(ln))) { close_list(); out <- c(out, paste0("<p>", inline(ln), "</p>")) }
    else close_list()
    i <- i + 1L
  }
  close_list()
  paste0("<!doctype html><html lang='es'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>Informe metodol\u00f3gico</title><style>",
    "body{font:16px/1.6 Helvetica,Arial,sans-serif;max-width:1000px;margin:40px auto;padding:0 24px;color:#161616}h1{border-top:5px solid #d52b1e;padding-top:18px}",
    "table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #ddd;overflow-wrap:anywhere}th{background:#f2f2f2}.scroll{overflow:auto}",
    "@media print{body{margin:0}}</style></head><body>", paste(out, collapse = "\n"), "</body></html>")
}
