help_catalog <- function() list(
  load = list(title = "01 / Del archivo al corpus", goal = "Reconocer qu\u00e9 representa cada fila y comprobar que la importaci\u00f3n conserva los datos.",
    steps = c("Carga CSV, TSV, XLS o XLSX. Las columnas se leen como texto; los ID almacenados como texto conservan ceros. En Excel los nombres repetidos o vac\u00edos se ajustan sin eliminar columnas y se registran en la entrega.", "En Excel confirma la hoja; en CSV/TSV comprueba separador y codificaci\u00f3n. Abre el visor \u00fanico para leer documentos y contrastar la columna reconocida.", "La pr\u00e1ctica es ficticia. En un trabajo real registra base de datos, b\u00fasqueda y fecha de extracci\u00f3n."),
    limits = "No se calculan indicadores sobre un archivo mal formado ni se acepta una lectura parcial. Las traducciones solo existen si se importan: no se generan ni se confunden con lemas.", sources = c("readxl / lectura de XLS y XLSX"="https://readxl.tidyverse.org/reference/read_excel.html", "Web of Science / exportar registros"="https://webofscience.help.clarivate.com/en-us/Content/export-records.htm", "Posit / validaci\u00f3n de entradas" = "https://shiny.posit.co/r/articles/improve/validation/")),
  prepare = list(title = "02 / Decisiones de preparaci\u00f3n", goal = "Construir un corpus reproducible, con exclusiones justificadas.",
    steps = c("Asigna texto, t\u00edtulo y metadatos. La selecci\u00f3n de texto decide qu\u00e9 se analiza: resumen, t\u00edtulo o una traducci\u00f3n ya importada.", "Filtros \u2192 deduplicaci\u00f3n \u2192 muestra. Se conserva la primera coincidencia de DOI; si falta, t\u00edtulo o texto. Revisa hom\u00f3nimos y versiones.", "Normaliza el texto y selecciona vocabulario. Pulsa Preparar corpus: una modificaci\u00f3n posterior invalida los resultados hasta repetir este paso.", "En Control de calidad abre la auditor\u00eda. El visor muestra una versi\u00f3n textual por vez y permite leer cada documento completo."),
    limits = "Los documentos sin texto pueden participar en la bibliometr\u00eda, pero no en modelos textuales. La presencia de palabras se mide por documento incluso cuando se usan frases.", sources = character()),
  lemma = list(title = "Lematizaci\u00f3n / de las formas al lema", goal = "Reunir variantes gramaticales para evitar dispersi\u00f3n del vocabulario.",
    steps = c("Ejemplo ilustrativo: \u00abestudiantes\u00bb y \u00abestudiante\u00bb pueden reunirse como \u00abestudiante\u00bb. El resultado depende del modelo y del contexto.", "UDPipe tokeniza, reconoce categor\u00edas gramaticales y obtiene lemas con un modelo de espa\u00f1ol, ingl\u00e9s, franc\u00e9s, alem\u00e1n, italiano o portugu\u00e9s.", "Descarga el modelo una vez en Modelos de idioma. El an\u00e1lisis posterior es local, en R; no env\u00eda res\u00famenes a servidores.", "En un corpus mixto elige Varios idiomas: CLD2 estima localmente cada texto y completa los casos claros compatibles. Revisa los pendientes, las discrepancias y una muestra de los autom\u00e1ticos. CSV reconocido y correcciones manuales tienen prioridad.", "El filtro gramatical permite conservar, por ejemplo, sustantivos y adjetivos. Puede eliminar verbos importantes; comprueba los originales."),
    limits = "Lematizar no traduce ni hace equivalentes t\u00e9rminos de idiomas diferentes. En Varios idiomas, las palabras vac\u00edas se toman del idioma de cada documento (m\u00e1s las personalizadas), salvo Sin lista. Los nombres propios y tecnicismos pueden lematizarse mal. Conserva el original y contrasta una muestra; el visor distingue lematizado y limpio. La anotaci\u00f3n est\u00e1 limitada a cinco millones de caracteres.",
    sources = c("UDPipe / anotaci\u00f3n en R" = "https://bnosac.github.io/udpipe/docs/doc2.html", "CLD2 / estimaci\u00f3n local y lenguas mezcladas" = "https://docs.ropensci.org/cld2/reference/cld2.html")),
  tokens = list(title = "Tokens / conservar informaci\u00f3n, reducir ruido", goal = "Elegir filtros medibles y revisar qu\u00e9 se elimina, sin sustituir criterio cient\u00edfico por un umbral.",
    steps = c("Longitud y palabras vac\u00edas act\u00faan durante la limpieza. Los acentos se conservan. Los bigramas respetan fronteras y no crean vecinos al eliminar palabras.", "Frecuencia total m\u00ednima elimina palabras con pocas apariciones. Presencia m\u00ednima elimina palabras de pocos documentos; presencia m\u00e1xima reduce palabras casi universales.", "TF = conteo / palabras de la unidad. IDF = log(N / df). TF-IDF medio se promedia sobre las unidades no vac\u00edas antes del filtro de vocabulario; incluye ceros. Con frases, N y df pertenecen a frases.", "El umbral TF-IDF m\u00ednimo sirve para seleccionar palabras distintivas; LDA sigue recibiendo conteos enteros. En UMAP lexical se usa un TF-IDF suavizado y normalizado, documentado aparte.", "Entrop\u00eda = \u2212\u03a3 p log(p) / log(D), donde p distribuye las apariciones entre documentos. Cerca de 1 significa reparto uniforme; cerca de 0, concentraci\u00f3n. Su m\u00e1ximo es un filtro opcional, desactivado con 1.", "La tabla identifica t\u00e9rminos retenidos y razones de exclusi\u00f3n. Los filtros de corpus usan todos los documentos preparados como denominador de presencia, incluidos los sin texto."),
    limits = "Por defecto TF-IDF m\u00ednimo = 0, presencia m\u00e1xima = 100% y entrop\u00eda m\u00e1xima = 1: no eliminan por esos criterios. Los n\u00fameros aislados se pueden eliminar conservando COVID19 o CO2; el filtro separado de c\u00f3digos alfanum\u00e9ricos est\u00e1 desactivado porque puede perder t\u00e9rminos cient\u00edficos. Un TF-IDF alto no demuestra calidad. Los acr\u00f3nimos cortos pueden perderse; usa longitud m\u00ednima 2 o 1 si tu pregunta los necesita. Filtra un criterio cada vez y compara resultados.",
    sources = c("Stanford / ponderaci\u00f3n TF-IDF" = "https://nlp.stanford.edu/IR-book/html/htmledition/tf-idf-weighting-1.html")),
  explore = list(title = "03 / Descripci\u00f3n bibliom\u00e9trica", goal = "Redactar observaciones verificables sobre la cobertura del corpus.",
    steps = c("La evoluci\u00f3n anual cuenta documentos con a\u00f1o v\u00e1lido; los a\u00f1os entre extremos sin registros se dibujan como cero en el corpus.", "Fuentes, autores y keywords son presencias documentales. El conteo completo de autores puede sumar m\u00e1s del 100% y requiere normalizar nombres.", "La distribuci\u00f3n de citas excluye ausencias. El \u00edndice h es del corpus importado: no es el \u00edndice h personal de los autores.", "Usa Ver tabla cuando necesites cifras exactas y Ampliar gr\u00e1fico para estudiar o ense\u00f1ar una figura. Las descargas conservan precisi\u00f3n completa."),
    limits = "Producci\u00f3n y citas no prueban calidad, causalidad ni cobertura exhaustiva del campo. El \u00faltimo a\u00f1o puede estar incompleto.", sources = character()),
  models = list(title = "04 / Modelos como herramientas exploratorias", goal = "Elegir el m\u00e9todo adecuado y validar resultados mediante lectura y sensibilidad.",
    steps = c("LDA modela mezclas tem\u00e1ticas: necesitas fijar k. Correspondencias analiza perfiles de conteos y expresa la variaci\u00f3n mediante ejes.", "UMAP reduce dimensiones; HDBSCAN encuentra agrupaciones por densidad y puede dejar documentos sin asignar. c-TF-IDF describe las palabras de cada grupo.", "En todos los casos, leer documentos y comparar par\u00e1metros es parte del an\u00e1lisis. La semilla ayuda a repetir una ejecuci\u00f3n, pero no prueba estabilidad cient\u00edfica: para LDA usa la comparaci\u00f3n de k con varias semillas y para UMAP/HDBSCAN la evaluaci\u00f3n de estabilidad."),
    limits = "No se fabrican etiquetas autom\u00e1ticamente ni se presentan agrupaciones como taxonom\u00edas validadas. El flujo TF-IDF/LSA no usa BERT ni une idiomas sem\u00e1nticamente.", sources = character()),
  lda = list(title = "LDA / mezclas de temas", goal = "Entender beta, gamma y prevalencia sin confundir sus denominadores.",
    steps = c("Beta = P(palabra | tema). La barra de una palabra no es un porcentaje de documentos.", "Gamma = proporci\u00f3n tem\u00e1tica de una unidad. La composici\u00f3n de documentos se muestra mediante barras apiladas que suman 100%.", "La prevalencia se promedia por documento; si hay frases, primero se promedian las frases retenidas dentro de cada documento.", "Lee los documentos representativos y propone etiquetas provisionales. Cambia una semilla o k cada vez y compara palabras, no solo n\u00fameros de tema."),
    limits = "Unidades sin palabras despu\u00e9s de seleccionar vocabulario no entran al modelo. Gibbs, burn-in, espaciado, alpha y delta quedan registrados. Se devuelve el estado de mayor verosimilitud entre los guardados y un indicador heur\u00edstico de convergencia (cambio relativo de la log-verosimilitud); no es una prueba formal. Con alpha = 1/k por defecto (V4); 50/k suaviza mucho las mezclas en textos cortos.",
    sources = c("topicmodels / LDA" = "https://search.r-project.org/CRAN/refmans/topicmodels/html/lda.html")),
  ca = list(title = "Correspondencias / leer un plano", goal = "Evaluar la calidad de representaci\u00f3n antes de atribuir sentido a las posiciones.",
    steps = c("Los ejes muestran variaciones de perfiles l\u00e9xicos. La suma de inercia de los dos ejes indica la informaci\u00f3n representada.", "La masa indica el peso del t\u00e9rmino. Las contribuciones suman 100% por eje e identifican qu\u00e9 t\u00e9rminos lo construyen.", "Cos\u00b2 del plano cercano a 1 indica buena representaci\u00f3n del t\u00e9rmino; valores bajos requieren consultar otros ejes.", "Solo se muestran t\u00e9rminos con coordenadas principales. Los signos de los ejes pueden invertirse sin cambiar la soluci\u00f3n."),
    limits = "No interpretes distancias entre puntos de tipos diferentes ni cl\u00fasteres estad\u00edsticamente probados. Perfiles id\u00e9nticos o rango insuficiente no permiten un plano interpretable.", sources = character()),
  density = list(title = "UMAP \u2192 HDBSCAN \u2192 c-TF-IDF", goal = "Explorar grupos de documentos y su vocabulario con un flujo inspirado en BERTopic, \u00edntegro en R.",
    steps = c("Ruta lexical: conteos por documento \u2192 TF-IDF suavizado \u2192 LSA por SVD \u2192 normalizaci\u00f3n L2. Es una representaci\u00f3n lexical, no un encoder BERT.", "Ruta de vectores: importa un CSV con doc_id u original_id y dimensiones num\u00e9ricas. Registra el modelo/versi\u00f3n de origen. La app alinea ID, valida cobertura y calcula localmente el resto.", "UMAP usa distancia coseno y reduce a 2\u201310 dimensiones para agrupar. Vecinos controla el alcance local; min_dist influye en compactaci\u00f3n. Menos distancia no significa mejor ciencia.", "HDBSCAN se ejecuta en ese espacio de mayor dimensi\u00f3n. En dbscan, minPts controla tama\u00f1o y suavizado; no es una r\u00e9plica exacta de los dos par\u00e1metros de otras implementaciones.", "El mapa 2D es una reducci\u00f3n independiente para visualizar, con min_dist 0,15. El clustering no se recalcula sobre los dos ejes dibujados.", "Grupo 0 = sin asignar, no error ni tema adicional. Membres\u00eda y atipicidad orientan lectura; no son probabilidades calibradas de un tema.", "c-TF-IDF agrega conteos por grupo, normaliza por palabras de la clase y usa IDF = log(1 + A/f_t), con A = media de palabras por clase y f_t = apariciones totales entre clases. Excluye sin asignar del vocabulario tem\u00e1tico.", "El mapa de similitud compara representaciones c-TF-IDF con coseno; la evoluci\u00f3n cuenta asignaciones por a\u00f1o y conserva el grupo sin asignar."),
    limits = "BERTopic suele usar sentence-transformers sem\u00e1nticos. Nuestra ruta lexical no promete equivalencia. UMAP puede deformar densidades y distancias globales; repetir con semillas/vecinos/minPts y leer documentos. Cero grupos es v\u00e1lido. M\u00e1ximo 3.000 documentos; m\u00ednimo 10 con vocabulario.",
    sources = c("BERTopic / algoritmo" = "https://maartengr.github.io/BERTopic/algorithm/algorithm.html", "uwot / UMAP" = "https://jlmelville.github.io/uwot/reference/umap.html", "dbscan / HDBSCAN" = "https://search.r-project.org/CRAN/refmans/dbscan/html/hdbscan.html")),
  export = list(title = "05 / De resultados a un trabajo acad\u00e9mico", goal = "Entregar evidencia y decisiones suficientes para revisar o repetir el an\u00e1lisis.",
    steps = c("El ZIP contiene tablas completas, im\u00e1genes, datos de entrada exactos en RDS, m\u00f3dulos R, script de reproducci\u00f3n y par\u00e1metros.", "El informe HTML no necesita conexi\u00f3n. Si utilizas lemas, se registran archivo y MD5 de cada modelo; el script comprueba el modelo antes de repetir.", "Los prompts se revisan en un modal y solo incorporan resultados vigentes. La IA debe distinguir observaci\u00f3n, hip\u00f3tesis y l\u00edmite.", "Verifica cada cifra y guarda prompt, herramienta/modelo, fecha y correcciones humanas. Aplica la pol\u00edtica de IA de tu instituci\u00f3n."),
    limits = "El ZIP contiene la entrada original completa en RDS, incluidos registros excluidos por filtros, y puede incluir vectores importados. Revisa datos sensibles antes de compartir. Los prompts no se env\u00edan autom\u00e1ticamente.", sources = character())
)
r_literal <- function(x) paste(capture.output(dput(x)), collapse = "\n")
stage_code <- function(stage, prepared = NULL, lda = NULL, ca = NULL, density = NULL, network = NULL, comparison = NULL, pca = NULL) {
  # Son las definiciones reales de las funciones utilizadas, no pseudocodigo.
  functions <- switch(stage, load = c("biblio_file_format", "biblio_excel_sheets", "read_biblio_file", "read_biblio_excel", "read_biblio_csv"), prepare = c("prepare_documents", "tokenize_one", "prepare_corpus", "apply_language_overrides", "language_diagnostics", "bm25_weights", "ngram_summary", "annotate_corpus_units", "duplicate_audit", "vocabulary_selection"),
    explore = c("biblio_summary", "count_metadata", "run_network", "network_metrics", "extract_subgraph", "collaboration_summary", "network_conclusions", "keyplayers_coverage", "ngram_summary", "bibliography_extensions", "jsd_shift", "run_comparison"), models = c("run_lda", "document_term_counts", "run_ca", "document_counts", "lsa_vectors", "bm25_weights", "class_tfidf", "run_density", "run_pca", "ordination_figure", "swiss_theme"),
    export = c("export_bundle", "safe_csv", "reproduction_script", "write_bundle_manifest", "bundle_files"), c("prepare_corpus"))
  if(stage=="prepare") functions<-c(functions,"estimate_text_languages","estimate_language_one","route_document_languages","processing_map","processing_plan","processing_open","processing_close","processing_dispatch","tokenize_document","annotate_language_batch","normalize_annotation_chunk","normalize_annotation_one")
  if(stage=="models" && exists("density_spline",mode="function")) functions<-c(functions,"density_yearly","density_spline","lda_yearly","density_year_terms")
  source <- vapply(functions, function(nm) paste0(nm, " <- ", paste(deparse(get(nm, mode = "function"), width.cutoff = 100L), collapse = "\n")), "")
  params <- if (is.null(prepared)) "# Todav\u00eda no hay una ejecuci\u00f3n preparada." else paste0("# Par\u00e1metros de la \u00faltima preparaci\u00f3n\nmapping <- ", r_literal(prepared$mapping), "\ncfg <- ", r_literal(prepared$config))
  paste(params, if (!is.null(comparison)) paste0("\n# Comparaci\u00f3n JSD\ncomparison_params <- ", r_literal(comparison$params)) else "",
    if (!is.null(pca)) paste0("\n# ACP\npca_params <- ", r_literal(pca$params)) else "", if (!is.null(network)) paste0("\n# Red ejecutada\nnetwork_params <- ", r_literal(network$params)) else "", if (!is.null(lda)) paste0("\n# LDA ejecutado\nlda_params <- ", r_literal(lda$params)) else "",
    if (!is.null(ca)) paste0("\n# CA ejecutado\nca_params <- ", r_literal(ca$params)) else "",
    if (!is.null(density)) paste0("\n# Densidad ejecutada\ndensity_params <- ", r_literal(density$params)) else "",
    "\n# Funciones R empleadas en este paso\n", paste(source, collapse = "\n\n"), sep = "\n")
}
script_preamble <- function() c(
  paste0("if (!requireNamespace('bibliolab', quietly = TRUE)) stop('Instala el paquete bibliolab (version registrada: ", BIBLIO_VERSION, ").')"),
  paste0("if (as.character(utils::packageVersion('bibliolab')) != '", BIBLIO_VERSION, "') warning('Version distinta de bibliolab: los resultados pueden diferir. Registrada: ", BIBLIO_VERSION, ".')"),
  "if (.Platform$OS.type == 'windows' && !isTRUE(l10n_info()[['UTF-8']])) try(Sys.setlocale('LC_CTYPE', '.UTF-8'), silent = TRUE)",
  "# Funciones del paquete (exportadas e internas) disponibles en esta sesion.",
  "list2env(as.list(asNamespace('bibliolab')), envir = environment())")
reproduction_script <- function(prepared, lda = NULL, ca = NULL, density = NULL, network = NULL, comparison = NULL, pca = NULL, subgraph=NULL, record = NULL, corpus = NULL) {
  lines <- c(paste("# bibliolab", BIBLIO_VERSION, "/ Reproduccion de esta ejecucion"), "# Descomprime el ZIP y ejecuta este archivo desde esa carpeta.",
    "# Los datos exactos estan en entrada_original.rds; los CSV neutralizan formulas para Excel.",
    script_preamble(),
    "options(bibliolab.model_dir = if (dir.exists('models')) normalizePath('models') else getOption('bibliolab.model_dir'))", "datos <- readRDS('entrada_original.rds')",
    paste0("mapping <- ", r_literal(prepared$mapping)), paste0("cfg <- ", r_literal(prepared$config)),
    "# Los idiomas aplicados estan congelados por fila original: no se reestiman al reproducir.",
    "preparado <- prepare_documents(datos, mapping, cfg)",
    "if(file.exists('idiomas_asignacion.rds')) preparado$language_audit <- readRDS('idiomas_asignacion.rds')",
    "preparado$import_info <- attr(datos, 'import_info')")
  if (isTRUE(prepared$config$lemmatize) || isTRUE(prepared$config$pos_filter)) lines <- c(lines,
    paste0("esperados <- ", r_literal(corpus$models %||% prepared$model_info %||% list())),
    "for (idioma in names(esperados)) {", "  archivo <- download_language_model(idioma)",
    "  if (unname(tools::md5sum(archivo)) != esperados[[idioma]]$md5) stop('El modelo de idioma no coincide con el usado. Revisa los par\u00e1metros.')", "}")
  lines <- c(lines, "corpus <- prepare_corpus(preparado)", "bibliometria <- biblio_summary(preparado)")
  # Verificaciones frente a la ejecucion original: huella del archivo y dimensiones del corpus analitico.
  md5 <- prepared$input_md5 %||% NA_character_
  if (!is.na(md5)) lines <- c(lines, paste0("if (!identical(as.character(attr(datos, 'source_md5')), '", md5, "')) warning('La huella MD5 de entrada_original.rds no coincide con la del archivo analizado originalmente (", md5, ").')"))
  lines <- c(lines, sprintf("stopifnot(nrow(preparado$documents) == %dL)", nrow(prepared$documents)))
  if (!is.null(corpus$counts)) lines <- c(lines, sprintf("stopifnot(identical(dim(corpus$counts), c(%dL, %dL)), isTRUE(all.equal(sum(corpus$counts), %s)))", nrow(corpus$counts), ncol(corpus$counts), format(sum(corpus$counts), digits = 15)))
  lines <- c(lines, "lda <- ca <- densidad <- acp <- comparacion <- red <- red_subgrafo <- NULL")
  if (!is.null(lda)) lines <- c(lines, sprintf("lda <- run_lda(corpus, k=%s, seed=%s, iterations=%s, alpha=%s, delta=%s, burnin=%s, thin=%s)", lda$params$k, lda$params$seed, lda$params$iterations, format(lda$params$alpha, digits = 15), format(lda$params$delta, digits = 15),lda$params$burnin,lda$params$thin))
  if (!is.null(ca)) lines <- c(lines, sprintf("ca <- run_ca(corpus, max_terms=%s, baseline=%s, B=%s, seed=%s)", ca$params$max_terms,
    if (isTRUE(ca$params$baseline$computed)) "TRUE" else "FALSE", ca$params$baseline$B %||% 50L, ca$params$baseline$seed %||% 2026L))
  if (!is.null(density)) {
    lines <- c(lines, paste0("density_params <- ", r_literal(density$params)), "vectores <- NULL")
    if (density$params$representation == "vectors") lines <- c(lines, "vectores <- readRDS('vectores_entrada.rds')")
    lines <- c(lines, paste0("densidad <- run_density(corpus, preparado, density_params, vectors=vectores, embedding_model=", r_literal(density$representation$model %||% ""), ")"))
  }
  if(!is.null(density$temporal_spline)) lines<-c(lines,paste0("densidad$temporal_spline <- density_spline(densidad,group=",density$temporal_spline$params$group,",k=",density$temporal_spline$params$k,")"))
  if (!is.null(network)) lines <- c(lines, paste0("network_params <- ", r_literal(network$params)), "red <- run_network(corpus, preparado, network_params)")
  if(!is.null(subgraph)) lines<-c(lines,paste0("subgraph_selection <- ",r_literal(subgraph$extraction)),"red_subgrafo <- extract_subgraph(red,subgraph_selection$method,subgraph_selection$focus,subgraph_selection$order,subgraph_selection$nodes)")
  if (!is.null(pca)) lines <- c(lines, sprintf("acp <- run_pca(corpus, preparado, max_terms=%s, standardize=%s, baseline=%s, B=%s, seed=%s)", pca$params$max_terms,
    if(pca$params$standardize) "TRUE" else "FALSE", if (isTRUE(pca$params$baseline$computed)) "TRUE" else "FALSE", pca$params$baseline$B %||% 50L, pca$params$baseline$seed %||% 2026L))
  if (!is.null(comparison)) {
    lines <- c(lines, paste0("comparison_params <- ", r_literal(comparison$params)), "grupos_jsd <- if (file.exists('grupos_jsd.rds')) readRDS('grupos_jsd.rds') else NULL")
    if (comparison$params$mode == "density") lines <- c(lines,
      "stopifnot(!is.null(densidad))", "verificados <- data.frame(doc_id=densidad$assignments$doc_id, valor=ifelse(densidad$assignments$grupo==0, 'Sin asignar', paste('Grupo',densidad$assignments$grupo)))",
      "stopifnot(identical(as.character(grupos_jsd$valor), as.character(verificados$valor[match(grupos_jsd$doc_id,verificados$doc_id)])))")
    if (comparison$params$mode == "lda") lines <- c(lines,
      "stopifnot(!is.null(lda))", "verificados <- data.frame(doc_id=lda$document_topics$doc_id, valor=paste('Tema',max.col(as.matrix(lda$document_topics[-1]),ties.method='first')))",
      "stopifnot(identical(as.character(grupos_jsd$valor), as.character(verificados$valor[match(grupos_jsd$doc_id,verificados$doc_id)])))")
    lines <- c(lines, "comparacion <- run_comparison(corpus, preparado, comparison_params, grupos_jsd)")
  }
  paste(c(lines, "saveRDS(list(preparado=preparado, corpus=corpus, bibliometria=bibliometria, red=red, lda=lda, ca=ca, densidad=densidad, acp=acp, comparacion=comparacion, subgrafo=red_subgrafo), 'resultados_reproducidos.rds')", ""), collapse = "\n")
}


# Guion opcional que repite los diagnosticos de decision asistida (seleccion de k y sensibilidad de
# UMAP + HDBSCAN) con los parametros, semillas y reparto reservado registrados, y compara el resultado
# con el guardado en diagnosticos_decision.rds. Es costoso: se ejecuta despues de reproducir_analisis.R.
diagnostics_script <- function(lda_selection = NULL, density_sens = NULL, density = NULL) {
  lines <- c(paste("# bibliolab", BIBLIO_VERSION, "/ Reproduccion opcional de los diagnosticos de decision"),
    "# Ejecuta primero reproducir_analisis.R: este guion lee resultados_reproducidos.rds y diagnosticos_decision.rds.",
    script_preamble(), "r <- readRDS('resultados_reproducidos.rds')", "guardado <- readRDS('diagnosticos_decision.rds')",
    "corpus <- r$corpus; preparado <- r$preparado", "comparar <- function(nuevo, previo, nombre) { ok <- isTRUE(all.equal(nuevo, previo, tolerance = 1e-6, check.attributes = FALSE)); message(nombre, ': ', if (ok) 'coincide con la entrega' else 'DIFIERE de la entrega'); ok }")
  if (!is.null(lda_selection)) {
    p <- lda_selection$params
    alpha <- if (is.character(p$alpha)) { if (identical(p$alpha, "1/k")) "NULL" else paste0("function(k) ", p$alpha) } else format(p$alpha, digits = 15)
    lines <- c(lines, sprintf("seleccion <- lda_select_k(corpus, k_range = %s, seeds = %s, iterations = %s, alpha = %s, delta = %s, holdout = %s, top_n = %s)",
      r_literal(as.integer(p$k_range)), r_literal(as.integer(p$seeds)), p$iterations, alpha, format(p$delta, digits = 15), format(p$holdout_fraction %||% 0.1, digits = 15), p$top_n),
      "stopifnot(identical(seleccion$params$holdout_doc_ids, guardado$lda_selection$params$holdout_doc_ids))",
      "comparar(seleccion$table, guardado$lda_selection$table, 'Seleccion de k')")
  }
  if (!is.null(density_sens)) {
    p <- density_sens$params
    lines <- c(lines, "stopifnot(!is.null(r$densidad))",
      sprintf("sensibilidad <- density_sensitivity(corpus, preparado, guardado$density_sens$params$base, seeds = %s, neighbors = %s, min_pts = %s, vectors = r$densidad$input_vectors, embedding_model = %s)",
        r_literal(as.integer(p$seeds)), r_literal(as.integer(p$neighbors)), r_literal(as.integer(p$min_pts)), r_literal(density$representation$model %||% "")),
      "comparar(sensibilidad$runs[c('grupos', 'ari')], guardado$density_sens$runs[c('grupos', 'ari')], 'Sensibilidad de UMAP + HDBSCAN')")
  }
  paste(c(lines, ""), collapse = "\n")
}
