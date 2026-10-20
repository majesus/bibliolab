escape_html <- function(x) as.character(htmltools::htmlEscape(as.character(x)))
html_table <- function(d, max_rows = 30L, show_note = TRUE) {
  if (is.null(d) || !nrow(d)) return("<p class='muted'>No disponible en esta ejecuci\u00f3n.</p>")
  a <- head(d, max_rows)
  cell <- function(x) { x[is.na(x)] <- "No disponible"; escape_html(x) }
  rows <- vapply(seq_len(nrow(a)), function(i) paste0("<tr>", paste0("<td>", vapply(a, function(v) cell(v[i]), ""), "</td>", collapse = ""), "</tr>"), "")
  paste0(if(show_note) paste0("<p class='muted'>Se muestran ", nrow(a), " de ", nrow(d), " filas; consulta el CSV para la tabla completa.</p>"), "<div class='scroll'><table><thead><tr>",
    paste0("<th>", escape_html(names(a)), "</th>", collapse = ""), "</tr></thead><tbody>", paste(rows, collapse = ""), "</tbody></table></div>")
}
report_html <- function(prepared, corpus, bibliography, lda = NULL, ca = NULL, density = NULL, network = NULL, comparison = NULL, pca = NULL, subgraph=NULL) {
  part <- function(title, text, d = NULL) paste0("<section><h2>", title, "</h2><p>", text, "</p>", if (!is.null(d)) html_table(d), "</section>")
  cfg <- prepared$config
  params <- data.frame(parametro = names(cfg), valor = vapply(cfg, function(x) paste(x, collapse = ", "), ""))
  sections <- c(
    part("Pregunta de investigaci\u00f3n", escape_html(prepared$question %||% "No indicada")),
    if(!is.null(prepared$import_info)) part("Importaci\u00f3n Excel",paste0("Se ley\u00f3 la hoja ",escape_html(prepared$import_info$sheet)," mediante readxl ",escape_html(prepared$import_info$reader_version),". Se conservaron las columnas y sus valores; se muestran los encabezados ajustados para evitar ambig\u00fcedad. La relaci\u00f3n completa est\u00e1 en importacion_encabezados.csv. ",escape_html(prepared$import_info$note)),prepared$import_info$headers[prepared$import_info$headers$corregido,,drop=FALSE]),
    part("Trazabilidad", paste0("Fuente local: ", escape_html(prepared$source_name), ". Fecha de preparaci\u00f3n: ", escape_html(prepared$prepared_at), "."), prepared$audit),
    part("Procedencia y b\u00fasqueda", "Los campos vac\u00edos deben completarse antes de presentar un trabajo acad\u00e9mico.",
      if (length(prepared$provenance)) data.frame(campo = names(prepared$provenance), valor = unlist(prepared$provenance)) else data.frame()),
    part("Decisiones de preparaci\u00f3n", "Los par\u00e1metros siguientes describen esta ejecuci\u00f3n; deben acompa\u00f1ar a las tablas.", params),
    if(!is.null(corpus$processing)) part("Ejecuci\u00f3n / preprocesamiento", "Etapas efectivas, trabajadores y tiempos de esta ejecuci\u00f3n. Paralelismo no cambia unidades ni m\u00e9todos estad\u00edsticos. En corpus peque\u00f1os se evita iniciar procesos; si falla un trabajador se intenta la v\u00eda secuencial y se registra.",corpus$processing),
    part("Selecci\u00f3n del vocabulario", "Se documentan t\u00e9rminos retenidos y motivos de exclusi\u00f3n. TF-IDF y entrop\u00eda son criterios opcionales; LDA conserva conteos enteros.", corpus$filter_audit),
    part("Modelos de idioma", "Lematizaci\u00f3n local UDPipe; no traduce. Los archivos y MD5 constan en par\u00e1metros JSON. Los modelos no son MIT: se rigen por la licencia indicada (CC BY-NC-SA 4.0 en los modelos de udpipe.models.ud.2.5).",
      if (length(corpus$models)) data.frame(idioma = names(corpus$models), modelo = vapply(corpus$models, `[[`, "", "file"), md5 = vapply(corpus$models, `[[`, "", "md5"),
        licencia = vapply(corpus$models, function(m) m$licencia %||% "no registrada", ""), origen = vapply(corpus$models, function(m) m$origen %||% "no registrado", "")) else data.frame()),
    part("Asignaci\u00f3n de columnas", "Campos elegidos en el archivo importado.", data.frame(campo = names(prepared$mapping), columna = unlist(prepared$mapping))),
    if(!is.null(prepared$language_audit)) part("Idiomas / estimaci\u00f3n y decisiones", if(is.null(cfg$language_detection)) "Estimaci\u00f3n autom\u00e1tica desactivada: se aplican etiquetas reconocidas del archivo y correcciones manuales." else "CLD2 analiza localmente cada texto. Se conservan etiquetas reconocidas del archivo y las correcciones manuales tienen prioridad. Proporci\u00f3n clasificada no es probabilidad de acierto. Los casos inciertos, breves, mezclados o sin modelo requieren revisi\u00f3n.", prepared$language_audit),
    part("Calidad y cobertura", paste(escape_html(c(prepared$issues, corpus$issues)), collapse = "<br>")),
    part("Indicadores del corpus", "Los datos faltantes se excluyen de los c\u00e1lculos de citas. El \u00edndice h de esta tabla describe el corpus completo. La tabla de autores ofrece h restringido a las publicaciones de cada autor en esta b\u00fasqueda, junto con cobertura de citas; no describe su carrera completa.", bibliography$overview),
    part("Evoluci\u00f3n anual", "Frecuencia entre documentos con a\u00f1o v\u00e1lido. Un a\u00f1o ausente en esta tabla no prueba ausencia de publicaciones del campo. El \u00faltimo a\u00f1o puede ser parcial.", bibliography$annual),
    part("Fuentes", if(isTRUE(cfg$normalize_labels)) "Documentos por revista o fuente; variantes de escritura unificadas seg\u00fan el registro de normalizaci\u00f3n. No se fusionan abreviaturas distintas autom\u00e1ticamente." else "Documentos por revista o fuente; conteo literal, sin unificar variantes.", bibliography$sources),
    part("Autores", "Conteo completo: un autor cuenta una vez por documento. Los porcentajes pueden sumar m\u00e1s del 100%. El h usa solo publicaciones de este corpus con citas v\u00e1lidas; con citas ausentes es un l\u00edmite inferior. No se resuelven hom\u00f3nimos.", bibliography$authors),
    part("Palabras clave", "Presencia por documento; las variantes de escritura requieren revisi\u00f3n.", bibliography$keywords),
    part("Documentos con citas", "Las citas dependen de la fuente y de la fecha de extracci\u00f3n. No equivalen por s\u00ed solas a calidad.", bibliography$cited),
    part("Frecuencias y TF-IDF", paste0("Presencia por documento; TF-IDF por ", if (cfg$split_sentences) "frase" else "documento", ". IDF = log(N/df), media sobre todas las unidades con palabras antes del filtro de vocabulario. Frecuencias mostradas antes del filtro de modelos."), corpus$terms),
    part("Bigramas", "Pares de palabras adyacentes en el original, sin unir a trav\u00e9s de puntuaci\u00f3n o palabras eliminadas. Se cuenta presencia una vez por documento.", corpus$bigrams))
  if(!is.null(corpus$ngrams)) sections<-c(sections,part("N-gramas / frecuencia y distribuci\u00f3n","Secuencias adyacentes normalizadas, antes del l\u00edmite de vocabulario de modelos. TF-IDF y entrop\u00eda por documento; no son pruebas de colocaci\u00f3n.",corpus$ngrams))
  if(!is.null(bibliography$extensiones)) sections<-c(sections,
    part("Cobertura de metadatos bibliogr\u00e1ficos","La falta de referencias impide analizar cocitaci\u00f3n o acoplamiento.",bibliography$extensiones$cobertura),
    part("Referencias citadas","Presencia por documento citante y cadena normalizada exacta, no citas recibidas ni desambiguaci\u00f3n aproximada.",bibliography$extensiones$referencias),
    part("Concentraci\u00f3n de fuentes","Porcentaje acumulado entre documentos con fuente; distribuci\u00f3n descriptiva sin contraste de Bradford.",bibliography$extensiones$concentracion_fuentes),
    part("Citas relativas al mismo a\u00f1o del corpus","Media positiva y al menos cinco registros v\u00e1lidos por cohorte. No normaliza por campo.",bibliography$extensiones$citas_cohorte))
  if(exists("model_comparison_table",mode="function")) sections<-c(sections,part("Resumen de modelos vigentes","Representaciones y resultados distintos; no existe un ganador por una puntuaci\u00f3n com\u00fan.",model_comparison_table(lda,density,pca,ca,prepared,corpus$pca_view$axes %||% c(1L,2L))))
  if (!is.null(lda)) sections <- c(sections,
    part("LDA: t\u00e9rminos por tema", paste0("Modelo exploratorio Gibbs; k = ", lda$params$k, "; semilla = ", lda$params$seed, "; iteraciones = ", lda$params$iterations,
      "; alpha = ",lda$params$alpha,"; delta = ",lda$params$delta,"; burn-in = ",lda$params$burnin,"; thin = ",lda$params$thin,". Usa conteos enteros. Las etiquetas requieren lectura y revisi\u00f3n de estabilidad. Beta es P(palabra|tema)."), lda$top),
    part("LDA: proporciones medias", "Media entre documentos; con frases se promedian primero las proporciones entre frases retenidas de cada documento.", lda$prevalence),
    part("LDA: documentos para leer", "La proporci\u00f3n tem\u00e1tica orienta la selecci\u00f3n, sin demostrar representatividad del campo.", lda$examples))
  if (!is.null(ca)) sections <- c(sections,
    part("Correspondencias: inercia", paste0("Se usan hasta ", ca$params$max_terms, " t\u00e9rminos de mayor frecuencia. La proyecci\u00f3n pierde la variaci\u00f3n de otros ejes. No se calculan pruebas de significaci\u00f3n."), ca$dimensions),
    part("Correspondencias: t\u00e9rminos", "Coordenadas principales, contribuci\u00f3n porcentual por eje y cos\u00b2 del plano. Cos\u00b2 bajo significa representaci\u00f3n insuficiente; no interpretes distancias entre t\u00e9rminos y documentos.", ca$terms))
  if (!is.null(density)) sections <- c(sections,
    part("UMAP / HDBSCAN: representaci\u00f3n", paste0(escape_html(density$representation$type), ". ", paste(escape_html(density$issues), collapse = "<br>"))),
    part("UMAP / HDBSCAN: grupos", "Grupo 0 conserva los documentos sin asignar. El grado de pertenencia al grupo es una medida estimada; no una probabilidad tem\u00e1tica calibrada.", density$summary),
    part("Grupos: palabras c-TF-IDF", "TF normalizado por palabras de cada clase; IDF = log(1 + A/f_t). Las etiquetas requieren lectura de originales.", density$terms),
    part("Grupos: documentos para leer", "Los grados de pertenencia orientan la selecci\u00f3n; no prueban representatividad del campo.", density$examples))
  if (!is.null(network)) sections <- c(sections, part("Red: definici\u00f3n y par\u00e1metros", escape_html(network$note), data.frame(parametro = names(network$params), valor = vapply(network$params,function(v)if(!length(v)) "Ninguna" else paste(fmt_value(v),collapse="; "),""))),
    part("Red: indicadores del grafo filtrado", paste("Centralidades sin pesos en rutas; fuerza y comunidades con pesos.",if(isTRUE(network$params$remove_isolates)) "Aislados retirados y m\u00e9tricas recalculadas." else "Aislados conservados."), network$summary),
    part("Red: selecci\u00f3n de nodos y conexiones", "Las m\u00e9tricas dependen de estos l\u00edmites.", network$audit), part("Red: nodos", "Tabla completa en CSV.", network$nodes),part("Red: candidatos de cobertura conjunta","Heur\u00edstica codiciosa a un salto incluyendo el propio nodo; no garantiza \u00f3ptimo global ni demuestra liderazgo.",network$keyplayers %||% data.frame()))
  if (!is.null(pca)) sections <- c(sections, part("ACP: varianza", escape_html(pca$params$representation), pca$dimensions),
    part("ACP: documentos", "Coordenadas de documentos, contribuciones y cos\u00b2 del plano. No son el plano de variables.", pca$documents),
    part("ACP: variables", "Correlaciones de t\u00e9rminos con componentes, cargas, contribuciones y cos\u00b2.", pca$terms))
  if (!is.null(comparison)) sections <- c(sections, part("Jensen-Shannon: comparaci\u00f3n", paste(escape_html(c(comparison$params$label_A, comparison$params$label_B, comparison$issues)), collapse="<br>"),
    data.frame(indicador=c("JSD / bits base 2", "Distancia sqrt(JSD)"), valor=c(comparison$jsd,comparison$distancia))),
    part("JSD: cobertura", "Denominadores y vocabulario retenido de la comparaci\u00f3n.", comparison$audit),
    part("JSD: aportaciones de t\u00e9rminos", "Las aportaciones no negativas suman JSD. shift_pct solo orienta A/B en la figura.",comparison$terms),
    part("JSD: categor\u00edas de la matriz", "Corpus completo vigente; la comparaci\u00f3n principal utiliza A/B.", comparison$coverage))
  if(!is.null(lda) && exists("lda_yearly",mode="function")) sections<-c(sections,part("LDA / prevalencia anual de temas fijos","Media de mezclas de documentos con a\u00f1o v\u00e1lido; no modelo din\u00e1mico ni asignaci\u00f3n exclusiva.",lda_yearly(lda,prepared)))
  if(!is.null(density) && exists("density_yearly",mode="function")) sections<-c(sections,part("Grupos fijos / proporciones por a\u00f1o","Denominador: asignaciones del modelo con a\u00f1o, incluido sin asignar. No estacionalidad.",density_yearly(density)))
  if(!is.null(density$temporal_spline)) sections<-c(sections,part("Spline penalizada / lectura y diagn\u00f3sticos",escape_html(density$temporal_spline$note),density$temporal_spline$diagnostics))
  if(!is.null(subgraph)) sections<-c(sections,part("Subgrafo / selecci\u00f3n",escape_html(subgraph$note),subgraph$audit),part("Subgrafo / indicadores recalculados","Compara con el universo de la red de origen.",subgraph$summary))
  paste0("<!doctype html><html lang='es'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>Informe \u00b7 Bibliometr\u00eda ",BIBLIO_VERSION,"</title><style>",
    "body{font:16px/1.6 Helvetica,Arial,sans-serif;max-width:1100px;margin:40px auto;padding:0 24px;color:#161616;background:white}h1,h2{line-height:1.2}h1{font-size:44px;border-top:5px solid #d52b1e;padding-top:20px}h2{font-size:24px}section{margin:28px 0;padding:20px 0;background:white;border-top:1px solid #222}.muted{color:#555;font-size:13px}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:left;padding:8px;border-bottom:1px solid #ddd;max-width:360px;overflow-wrap:anywhere}th{background:#f2f2f2}pre{white-space:pre-wrap}@media print{body{margin:0;background:white}section{break-inside:auto}.scroll{overflow:visible}h2{break-after:avoid}}",
    "</style></head><body><p>BIBLIOMETR\u00cdA \u00b7 CUADERNO DE RESULTADOS</p><h1>Informe de la ejecuci\u00f3n</h1><p>Versi\u00f3n ", BIBLIO_VERSION,
    ". Este informe contiene descripciones y tablas; las interpretaciones cient\u00edficas requieren revisi\u00f3n humana.</p>",
    if (isTRUE(prepared$is_demo)) "<p><strong>PR\u00c1CTICA: datos sint\u00e9ticos ficticios. No utilizar como evidencia acad\u00e9mica real.</strong></p>" else "",
    paste(sections, collapse = "\n"), "<section><h2>Informaci\u00f3n por completar para el m\u00e9todo</h2><p>Base de datos, consulta completa, fecha de extracci\u00f3n, criterios de inclusi\u00f3n/exclusi\u00f3n y validaci\u00f3n de etiquetas tem\u00e1ticas. La aplicaci\u00f3n no puede inferirlos del archivo.</p></section></body></html>")
}
#' Exporta una entrega reproducible
#'
#' Escribe tablas CSV, parametros, informe HTML, informe metodologico,
#' registro de reproducibilidad, guion `reproducir_analisis.R` y, si se
#' proporcionan, los resultados de cada modelo.
#'
#' @param directory Carpeta de destino. Debe no existir o estar vacia: la entrega se
#'   escribe primero en una carpeta temporal contigua y solo se publica en
#'   `directory` cuando se ha completado, de modo que nunca se mezclan archivos de
#'   ejecuciones distintas ni queda una entrega a medias. Una carpeta con contenido
#'   se rechaza sin modificarla.
#' @param prepared,corpus,bibliography Resultados de la preparacion.
#' @param lda,ca,density,network,comparison,pca,subgraph Resultados opcionales.
#' @param prompt Texto de prompt a guardar (opcional).
#' @param raw `data.frame` importado original; se guarda como RDS para reproducir.
#'   Sin `raw` la entrega es **parcial**: no se escribe `reproducir_analisis.R`, se
#'   registra en `parametros.json` (`entrega`) y en `LEEME.txt`, y se emite un aviso.
#' @param module_dir Ignorado (compatibilidad con V3).
#' @param reader Cuaderno de lectura enlazada (opcional).
#' @param record Registro de reproducibilidad; se calcula si es `NULL`.
#' @param lda_selection,density_sens Resultados de [lda_select_k()] y [density_sensitivity()].
#' @details Cada archivo queda registrado con su tamano y MD5 en
#'   `manifiesto_archivos.csv`, que puede verificarse con [verify_bundle()].
#'
#'   La entrega es **reproducible** cuando contiene todos los insumos que necesita su
#'   guion: `raw` (siempre), `density$input_vectors` si `run_density()` uso
#'   `representation = "vectors"` (se guarda en `vectores_entrada.rds`) y
#'   `comparison$grouping` si `run_comparison()` no uso `mode = "year"` (se guarda en
#'   `grupos_jsd.rds`). Estos dos campos los devuelven [run_density()] y
#'   [run_comparison()]: no hace falta anadirlos a mano. Si falta alguno, la entrega se
#'   declara parcial en `parametros.json` (`entrega`), en `LEEME.txt` y con un aviso, y no
#'   se escribe `reproducir_analisis.R` ni `reproducir_cuaderno.R`.
#'
#'   Antes de escribir nada se comprueba la coherencia entre los objetos: `raw` debe
#'   reproducir los documentos de `prepared` (mismo contenido, no solo las mismas
#'   dimensiones) y los modelos, la comparacion y la densidad deben proceder de las
#'   unidades y los documentos de `corpus` y `prepared`; si no, la funcion se detiene con
#'   un mensaje y no crea la carpeta. `parametros.json` guarda en `entrega$huellas` las
#'   huellas de contenido de la entrada, de los documentos preparados y de la matriz
#'   documento-termino, que `reproducir_analisis.R` verifica. Cuando falta el objeto que
#'   origino los grupos de una comparacion (`lda` o `density`), los grupos se toman de
#'   `grupos_jsd.rds` y la verificacion de origen se declara omitida en
#'   `entrega$comprobaciones_omitidas`.
#'
#'   `lda_selection` y `density_sens` se registran en `parametros.json` y en
#'   `evidencia_ia.json` aunque no haya modelo final, junto con las repeticiones y el
#'   reparto reservado (`lda_seleccion_k_ejecuciones.csv`,
#'   `lda_seleccion_k_documentos_reservados.csv`, `diagnosticos_decision.rds`); si la
#'   entrega es reproducible, `reproducir_diagnosticos.R` recalcula esos pasos (costoso,
#'   opcional) y los compara con lo guardado.
#'
#'   Las tablas CSV usan UTF-8 con BOM y punto y coma como separador; el texto que podria
#'   interpretarse como formula en una hoja de calculo lleva un apostrofo inicial. Los
#'   valores ausentes se escriben como celdas vacias, no como cero.
#' @return `directory`, de forma invisible.
#' @export
export_bundle <- function(directory, prepared, corpus, bibliography, lda = NULL, ca = NULL, prompt = NULL, density = NULL, raw = NULL, module_dir = NULL, network = NULL, comparison = NULL, pca = NULL, subgraph=NULL,reader=NULL, record = NULL, lda_selection = NULL, density_sens = NULL) {
  if (!is.character(directory) || length(directory) != 1L || is.na(directory) || !nzchar(directory)) abort_user("Indica una carpeta de destino.")
  final <- directory
  if (file.exists(final) && !dir.exists(final)) abort_user("El destino existe y no es una carpeta. Elige una carpeta nueva.")
  if (dir.exists(final) && length(list.files(final, all.files = TRUE, no.. = TRUE)))
    abort_user("La carpeta de destino ya contiene archivos. Elige una carpeta nueva o vac\u00eda para no mezclar resultados de ejecuciones distintas; no se ha modificado nada.")
  # Coherencia entre objetos, antes de escribir nada: una entrega con insumos contradictorios no puede
  # reproducirse y no debe presentarse como si lo hiciera.
  problems <- bundle_consistency_problems(prepared, corpus, raw, lda, ca, density, comparison)
  if (length(problems)) abort_user(paste0("Los objetos de la entrega no son coherentes entre s\u00ed: ", paste(problems, collapse = "; "), ". No se ha escrito nada."))
  dir.create(dirname(final), recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(dirname(final))) abort_user("No se puede crear la carpeta que contendr\u00eda la entrega.")
  stage <- tempfile(pattern = paste0(".", basename(final), "-parcial-"), tmpdir = dirname(normalizePath(final, winslash = "/", mustWork = FALSE)))
  if (!dir.create(stage)) abort_user("No se puede escribir junto al destino. Elige otra carpeta.")
  published <- FALSE
  on.exit(if (!published) unlink(stage, recursive = TRUE), add = TRUE)
  directory <- stage
  # Insumos que exige reproducir la entrega. Si falta alguno, la entrega se declara parcial.
  missing_inputs <- character()
  if (is.null(raw)) missing_inputs <- c(missing_inputs, "entrada_original.rds (argumento `raw`)")
  if (!is.null(density) && identical(density$params$representation, "vectors") && is.null(density$input_vectors)) missing_inputs <- c(missing_inputs, "vectores_entrada.rds (`density$input_vectors`)")
  if (!is.null(comparison) && !identical(comparison$params$mode, "year") && is.null(comparison$grouping)) missing_inputs <- c(missing_inputs, "grupos_jsd.rds (`comparison$grouping`)")
  if (!is.null(density_sens) && identical(density_sens$params$base$representation, "vectors") && is.null(density_sens$reference$input_vectors) && is.null(density$input_vectors))
    missing_inputs <- c(missing_inputs, "vectores de la sensibilidad (`density_sens$reference$input_vectors`)")
  reproducible <- !length(missing_inputs)
  # Huellas de contenido (entrada, documentos preparados y matriz) que el guion comprueba al reproducir,
  # y comprobaciones que no pueden hacerse con los insumos entregados.
  fingerprints <- if (reproducible) list(entrada = raw_fingerprint(raw), documentos = documents_fingerprint(prepared$documents), matriz = corpus_fingerprint(corpus)) else NULL
  omitted <- if (reproducible) reproduction_omissions(comparison, lda, density) else character()
  tables <- list(documentos = prepared$documents, auditoria = prepared$audit, duplicados_detectados = prepared$duplicates, duplicados_ambiguos = prepared$ambiguous %||% data.frame(),
    unidades_textuales = corpus$units, terminos = corpus$terms, filtros_vocabulario = corpus$filter_audit,
    anotacion_linguistica = corpus$annotation, bigramas = corpus$bigrams, ngramas = corpus$ngrams %||% data.frame(),
    indicadores = bibliography$overview, evolucion_anual = bibliography$annual, fuentes = bibliography$sources,
    autores = bibliography$authors, palabras_clave = bibliography$keywords, documentos_citados = bibliography$cited)
  if(!is.null(bibliography$extensiones)) tables <- c(tables,setNames(bibliography$extensiones,paste0("bibliografia_",names(bibliography$extensiones))))
  if(!is.null(bibliography$normalizacion)) tables$bibliografia_normalizacion <- bibliography$normalizacion
  if(!is.null(prepared$language_audit)) tables$idiomas_asignacion<-prepared$language_audit
  if(!is.null(prepared$import_info)) tables$importacion_encabezados<-prepared$import_info$headers
  if(!is.null(corpus$processing)) tables$ejecucion_preprocesamiento<-corpus$processing
  if(!is.null(reader)) {
    tables$cuaderno_indice<-wiki_index_table(reader$index);tables$cuaderno_conceptos<-reader$index$concepts[setdiff(names(reader$index$concepts),"pattern")]
    tables$cuaderno_notas<-reader$notes;tables$cuaderno_enlaces_notas<-wiki_note_links(reader$notes,reader$index)
  }
  if(exists("model_comparison_table",mode="function")) tables$resumen_modelos <- model_comparison_table(lda,density,pca,ca,prepared,corpus$pca_view$axes %||% c(1L,2L))
  if (!is.null(lda)) tables <- c(tables, list(lda_terminos = lda$top, lda_proporciones_unidad = lda$gamma,
    lda_proporciones_documento = lda$document_topics, lda_prevalencia = lda$prevalence, lda_documentos_representativos = lda$examples,
    lda_diagnosticos = lda$diagnostics$overview, lda_calidad_temas = lda$diagnostics$topics,
    lda_traza_loglik = data.frame(estado = seq_along(lda$loglik), loglik = lda$loglik)))
  if (!is.null(ca)) tables <- c(tables, list(ca_terminos = ca$terms, ca_unidades = ca$units, ca_inercia = ca$dimensions))
  if (!is.null(density)) tables <- c(tables, list(umap_asignaciones = density$assignments, hdbscan_grupos = density$summary,
    grupos_c_tfidf = density$terms, grupos_documentos = density$examples, grupos_similitud = density$similarity, grupos_evolucion = density$temporal,
    umap_calidad = density$quality))
  if (!is.null(network)) tables <- c(tables, list(red_nodos = network$nodes, red_conexiones = network$edges, red_indicadores = network$summary,
    red_auditoria = network$audit,red_seleccion_entidades=network$selection %||% data.frame(), red_candidatos=network$keyplayers %||% data.frame(), colaboracion = network$collaboration %||% data.frame()))
  if (!is.null(pca)) tables <- c(tables,list(acp_documentos=pca_plane(pca,"documents",corpus$pca_view$axes %||% c(1L,2L)), acp_variables=pca_plane(pca,"terms",corpus$pca_view$axes %||% c(1L,2L)), acp_varianza=pca$dimensions, acp_exclusiones=pca$excluded))
  if (!is.null(comparison)) tables <- c(tables,list(jsd_terminos=comparison$terms, jsd_matriz=comparison$matrix, jsd_cobertura=comparison$coverage,
    jsd_evolucion=comparison$temporal, jsd_auditoria=comparison$audit, jsd_documentos=comparison$documents,
    jsd_indicadores=data.frame(indicador=c("JSD / bits", "Distancia sqrt(JSD)"),valor=c(comparison$jsd,comparison$distancia))))
  if (!is.null(comparison$uncertainty)) { u <- comparison$uncertainty
    tables$jsd_incertidumbre <- data.frame(indicador = c("JSD observada (bits)", "JSD esperada bajo permutacion", "Percentil 95 de la nula", "Exceso sobre la nula",
        "Valor p de permutacion", paste0("IC bootstrap inferior (", round(100 * u$conf), "%)"), paste0("IC bootstrap superior (", round(100 * u$conf), "%)"), "Permutaciones/remuestreos", "Documentos en A", "Documentos en B"),
      valor = c(u$observed, u$null_mean, u$null_p95, u$excess, u$p_value, u$ci[1], u$ci[2], u$B, u$n_a, u$n_b)) }
  if(!is.null(lda) && exists("lda_yearly",mode="function")) tables$lda_prevalencia_anual<-lda_yearly(lda,prepared)
  if(!is.null(density) && exists("density_yearly",mode="function")) {
    tables$grupos_proporciones_anuales<-density_yearly(density)
    gs<-density$summary$grupo[density$summary$grupo>0]
    tables$grupos_vocabulario_anual<-if(length(gs)) do.call(rbind,lapply(gs,function(g) density_year_terms(corpus,prepared,density,g))) else data.frame()
  }
  if(!is.null(density$temporal_spline)) tables<-c(tables,list(spline_predicciones=density$temporal_spline$predictions,spline_diagnosticos=density$temporal_spline$diagnostics,spline_observados=density$temporal_spline$observed))
  if(!is.null(subgraph)) tables<-c(tables,list(subgrafo_nodos=subgraph$nodes,subgrafo_conexiones=subgraph$edges,subgrafo_indicadores=subgraph$summary,subgrafo_candidatos=subgraph$keyplayers))
  for (nm in names(tables)) safe_csv(tables[[nm]], file.path(directory, paste0(nm, ".csv")))
  manifest <- list(version = BIBLIO_VERSION, fuente = prepared$source_name, practica_sintetica = prepared$is_demo, importacion = prepared$import_info,
    fecha_preparacion = prepared$prepared_at, pregunta = prepared$question, procedencia = prepared$provenance %||% list(), parametros = prepared$config,
    columnas = prepared$mapping, advertencias = c(prepared$issues, corpus$issues),
    vocabulario_modelos = corpus$vocabulary, lda = if (!is.null(lda)) lda$params, ca = if (!is.null(ca)) ca$params,
    acp = if (!is.null(pca)) pca$params, jsd = if (!is.null(comparison)) list(parametros=comparison$params, origen_modelo=comparison$origin, jsd_bits=comparison$jsd, distancia=comparison$distancia, advertencias=comparison$issues),
    red = if (!is.null(network)) list(parametros = network$params, definicion = network$note), modelos_idioma = corpus$models, densidad = if (!is.null(density)) list(parametros = density$params, representacion = density$representation, advertencias = density$issues),
    subgrafo=if(!is.null(subgraph)) subgraph$extraction, spline=if(!is.null(density$temporal_spline)) list(parametros=density$temporal_spline$params,lectura=density$temporal_spline$note),vista_terminos=corpus$term_view %||% NULL,
    vista_acp=corpus$pca_view %||% NULL,vista_ngramas=corpus$gram_view %||% NULL,vista_lda_temporal=corpus$lda_time_view %||% NULL,vista_lda_documentos=corpus$lda_document_view %||% NULL,
    entrega = list(reproducible = reproducible, insumos_faltantes = as.list(missing_inputs), comprobaciones_omitidas = as.list(omitted), huellas = fingerprints),
    seleccion_k = if (!is.null(lda_selection)) lda_selection$params,
    sensibilidad_densidad = if (!is.null(density_sens)) density_sens$params,
    nota_csv = "CSV UTF-8 con BOM y separador punto y coma. Texto que podr\u00eda ser f\u00f3rmula lleva un ap\u00f3strofo inicial para apertura segura en Excel.")
  jsonlite::write_json(manifest, file.path(directory, "parametros.json"), pretty = TRUE, auto_unbox = TRUE, na = "null", digits = NA)
  if(!is.null(reader) && reproducible) {
    manifest$cuaderno<-reader$index$params
    jsonlite::write_json(manifest,file.path(directory,"parametros.json"),pretty=TRUE,auto_unbox=TRUE,na="null",digits=NA)
    export_wiki_vault(file.path(directory,"cuaderno_obsidian"),reader$index,reader$notes,reader$graph,reader$view)
    writeLines(c("# Ejecutar primero reproducir_analisis.R desde esta carpeta.",script_preamble(),"r <- readRDS('resultados_reproducidos.rds')","s <- readRDS('cuaderno_obsidian/cuaderno.rds')","p <- r$preparado; entrada <- readRDS('entrada_original.rds'); campo <- s$index$params$text_field %||% p$mapping$text", "p$documents$text <- clean_value(entrada[[campo]][p$documents$source_row]); p$mapping$text <- campo", "cuaderno <- build_wiki_index(p,r$corpus,s$index$params$mode,s$index$params$dictionary,s$index$params$source_key,text_source=s$index$params$text_source %||% 'prepared')","cuaderno <- wiki_attach_metadata(cuaderno,entrada)","stopifnot(isTRUE(all.equal(cuaderno$counts,s$index$counts)),identical(cuaderno$documents$text,s$index$documents$text))","graph <- if(is.null(s$view)) NULL else do.call(wiki_local_graph,c(list(index=cuaderno,node=s$view$node,notes=s$notes),s$view$params))","if(!is.null(graph))stopifnot(identical(graph$nodes,s$graph$nodes),identical(graph$edges,s$graph$edges))","export_wiki_vault('cuaderno_reproducido',cuaderno,s$notes,graph,s$view)","saveRDS(list(index=cuaderno,notes=s$notes,graph=graph,view=s$view),'cuaderno_reproducido.rds')"),file.path(directory,"reproducir_cuaderno.R"),useBytes=TRUE)
  }
  jsonlite::write_json(evidence_bundle(prepared, corpus, bibliography, lda, ca, density = density, network = network, comparison = comparison, pca = pca,subgraph=subgraph,
    lda_selection = lda_selection, density_sens = density_sens), file.path(directory, "evidencia_ia.json"), pretty = TRUE, auto_unbox = TRUE, na = "null", digits = NA)
  writeLines(enc2utf8(report_html(prepared, corpus, bibliography, lda, ca, density, network, comparison, pca, subgraph)), file.path(directory, "informe.html"), useBytes = TRUE)
  if (!is.null(comparison$grouping)) saveRDS(comparison$grouping, file.path(directory,"grupos_jsd.rds"))
  if(!is.null(subgraph)) saveRDS(subgraph$extraction,file.path(directory,"seleccion_subgrafo.rds"))
  if (!is.null(raw)) saveRDS(raw, file.path(directory, "entrada_original.rds"))
  if(!is.null(prepared$language_audit)) saveRDS(prepared$language_audit,file.path(directory,"idiomas_asignacion.rds"))
  if (!is.null(density$input_vectors)) saveRDS(density$input_vectors, file.path(directory, "vectores_entrada.rds"))
  if (reproducible) writeLines(enc2utf8(reproduction_script(prepared, lda, ca, density, network, comparison, pca, subgraph, corpus = corpus, fingerprints = fingerprints)), file.path(directory, "reproducir_analisis.R"), useBytes = TRUE)
  if (exists("graphics_script",mode="function")) writeLines(enc2utf8(graphics_script()),file.path(directory,"reconstruir_graficos.R"),useBytes=TRUE)
  skills_dir <- system.file("skills", package = "bibliolab")
  if (nzchar(skills_dir) && dir.exists(skills_dir)) {
    for (relative in list.files(skills_dir, recursive = TRUE)) {
      destination <- file.path(directory, "skills", relative); dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      file.copy(file.path(skills_dir, relative), destination, overwrite = TRUE)
    }
  }
  # Registro de reproducibilidad e informe metodologico (nuevo en 4.0).
  if (is.null(record)) record <- reproducibility_record(prepared, corpus, lda = lda, ca = ca, density = density, network = network, comparison = comparison, pca = pca)
  jsonlite::write_json(record, file.path(directory, "registro_reproducibilidad.json"), pretty = TRUE, auto_unbox = TRUE, na = "null", digits = NA)
  md <- methods_report(prepared, corpus, bibliography, lda = lda, ca = ca, density = density, network = network, comparison = comparison, pca = pca,
    record = record, lda_selection = lda_selection, density_sensitivity = density_sens)
  writeLines(enc2utf8(md), file.path(directory, "informe_metodologico.md"), useBytes = TRUE)
  writeLines(enc2utf8(methods_report_html(md)), file.path(directory, "informe_metodologico.html"), useBytes = TRUE)
  if (!is.null(lda_selection)) {
    safe_csv(lda_selection$table, file.path(directory, "lda_seleccion_k.csv"))
    safe_csv(lda_selection$recommendation$summary, file.path(directory, "lda_seleccion_k_resumen.csv"))
    safe_csv(lda_selection$runs, file.path(directory, "lda_seleccion_k_ejecuciones.csv"))
    safe_csv(data.frame(doc_id = lda_selection$params$holdout_doc_ids %||% character()), file.path(directory, "lda_seleccion_k_documentos_reservados.csv"))
  }
  if (!is.null(density_sens)) {
    safe_csv(density_sens$runs, file.path(directory, "umap_hdbscan_sensibilidad.csv"))
    safe_csv(density_sens$summary, file.path(directory, "umap_hdbscan_sensibilidad_resumen.csv"))
  }
  if (!is.null(lda_selection) || !is.null(density_sens)) {
    saveRDS(list(lda_selection = lda_selection, density_sens = density_sens), file.path(directory, "diagnosticos_decision.rds"))
    if (reproducible) writeLines(enc2utf8(diagnostics_script(lda_selection, density_sens, density)), file.path(directory, "reproducir_diagnosticos.R"), useBytes = TRUE)
  }
  write_prompt_bank(file.path(directory, "banco_prompts.md"))
  if (!is.null(prompt)) writeLines(enc2utf8(prompt), file.path(directory, "prompt_seleccionado.txt"), useBytes = TRUE)
  writeLines(capture.output(sessionInfo()), file.path(directory, "entorno_R.txt"))
  writeLines(enc2utf8(c("BIBLIOLAB \u00b7 ENTREGA", "Abre informe.html con un navegador. Las tablas completas est\u00e1n en los CSV.",
    "parametros.json conserva decisiones; entorno_R.txt registra las versiones de R y paquetes.",
    "documentos.csv y unidades_textuales.csv contienen texto original: revisa la privacidad antes de compartir el ZIP.",
    "evidencia_ia.json contiene tablas limitadas a 25 filas por ranking y excluye extractos originales.",
    "Las tablas de LDA, CA, subgrafo y UMAP/HDBSCAN solo se incluyen si sus resultados est\u00e1n vigentes. La spline requiere un ajuste v\u00e1lido; no se inventa si falta cobertura.",
    if (reproducible) "reproducir_analisis.R se ejecuta desde esta carpeta, usa entrada_original.rds y requiere el paquete bibliolab instalado (version registrada en registro_reproducibilidad.json)."
    else paste0("ENTREGA PARCIAL: no incluye reproducir_analisis.R porque faltan insumos de reproduccion: ", paste(missing_inputs, collapse = "; "), "."),
    if (length(omitted)) paste0("Comprobaciones omitidas al reproducir (faltan insumos): ", paste(omitted, collapse = " | ")),
    if (reproducible) "El guion comprueba las huellas de entrada_original.rds, de los documentos preparados y de la matriz documento-t\u00e9rmino (parametros.json, entrega$huellas); si no coinciden, se detiene con un diagn\u00f3stico.",
    if (reproducible && (!is.null(lda_selection) || !is.null(density_sens))) "reproducir_diagnosticos.R (opcional, costoso) repite la seleccion de k y la sensibilidad con los parametros, semillas y documentos reservados registrados y compara con diagnosticos_decision.rds.",
    "manifiesto_archivos.csv lista cada archivo con su tamano y MD5; verify_bundle() lo comprueba.",
    "informe_metodologico.md / .html resume procedimientos, parametros, diagnosticos de validez y limitaciones. registro_reproducibilidad.json guarda versiones, semillas y huella de los datos.",
    "Los modelos UDPipe se descargan por separado y se verifica su MD5.",
    "skills contiene instrucciones de redacci\u00f3n y revisi\u00f3n; lee skills/USO.md para aplicarlas en tu herramienta.",
    "Si faltan gr\u00e1ficos, ejecuta los an\u00e1lisis correspondientes; los mapas no se calculan autom\u00e1ticamente.")), file.path(directory, "LEEME.txt"), useBytes = TRUE)
  write_bundle_manifest(directory)
  # Publicacion: la carpeta vacia previa (si existe) se sustituye por la entrega completa.
  if (dir.exists(final)) unlink(final, recursive = TRUE)
  if (!publish_directory(stage, final)) {
    # Alternativa cuando no se puede renombrar (por ejemplo, otra unidad): copiar, verificar y retirar la copia temporal.
    dir.create(final, showWarnings = FALSE)
    ok <- all(file.copy(list.files(stage, full.names = TRUE, all.files = TRUE, no.. = TRUE), final, recursive = TRUE))
    ok <- ok && all(verify_bundle(final)$estado == "correcto")
    if (!ok) { unlink(final, recursive = TRUE); abort_user("No se ha podido publicar la entrega en la carpeta de destino.") }
    unlink(stage, recursive = TRUE)
  }
  published <- TRUE
  if (!reproducible) warning("Entrega parcial: no se escribi\u00f3 reproducir_analisis.R porque faltan ", paste(missing_inputs, collapse = "; "), ".", call. = FALSE)
  invisible(final)
}

# Publicacion por renombrado; funcion separada para poder simular su fallo en las pruebas.
publish_directory <- function(from, to) isTRUE(file.rename(from, to))

# Documentos que la entrega declararia reproducibles sin que lo sean: se comprueba la relacion entre
# objetos, no solo su presencia. Devuelve un vector de problemas (vacio si todo es coherente).
bundle_consistency_problems <- function(prepared, corpus, raw, lda = NULL, ca = NULL, density = NULL, comparison = NULL) {
  out <- character()
  doc_ids <- prepared$documents$doc_id
  if (!is.null(raw)) {
    again <- tryCatch(prepare_documents(raw, prepared$mapping, prepared$config), error = function(e) e)
    if (inherits(again, "error")) out <- c(out, paste0("la entrada original (`raw`) no se puede preparar con la asignaci\u00f3n de columnas y la configuraci\u00f3n registradas (", conditionMessage(again), ")"))
    else if (!identical(documents_fingerprint(again$documents), documents_fingerprint(prepared$documents)))
      out <- c(out, "la entrada original (`raw`) no reproduce los documentos preparados (`prepared`): su contenido es distinto aunque las dimensiones coincidan")
  }
  m <- corpus$counts
  if (!is.null(m)) {
    if (!is.null(corpus$units) && !all(rownames(m) %in% corpus$units$unit_id)) out <- c(out, "la matriz del corpus contiene unidades que no constan en `corpus$units`")
    if (!is.null(corpus$units) && !all(corpus$units$doc_id %in% doc_ids)) out <- c(out, "el corpus contiene documentos que no constan en `prepared`")
    if (!is.null(lda) && (!all(lda$gamma$unit_id %in% rownames(m)) || !all(lda$top$termino %in% colnames(m))))
      out <- c(out, "el modelo LDA no se ajust\u00f3 con las unidades y t\u00e9rminos de este corpus")
    if (!is.null(ca) && (!all(ca$terms$termino %in% colnames(m)) || !all(ca$units$unit_id %in% rownames(m))))
      out <- c(out, "el mapa de correspondencias no procede de las unidades y t\u00e9rminos de este corpus")
  } else if (!is.null(lda) || !is.null(ca)) out <- c(out, "se entregan modelos de texto sin matriz de corpus")
  if (!is.null(density) && !all(density$assignments$doc_id %in% doc_ids)) out <- c(out, "los grupos UMAP/HDBSCAN incluyen documentos que no constan en `prepared`")
  if (!is.null(comparison$grouping) && !all(comparison$grouping$doc_id %in% doc_ids)) out <- c(out, "la agrupaci\u00f3n de la comparaci\u00f3n incluye documentos que no constan en `prepared`")
  out
}

# Comprobaciones del guion de reproduccion que no pueden hacerse porque falta un objeto de contraste.
# No impiden reproducir: los grupos de la comparacion se leen de grupos_jsd.rds.
reproduction_omissions <- function(comparison = NULL, lda = NULL, density = NULL) {
  out <- character()
  mode <- comparison$params$mode
  if (identical(mode, "lda") && is.null(lda)) out <- c(out, "origen LDA de la comparaci\u00f3n (no se entreg\u00f3 `lda`: los grupos se toman de grupos_jsd.rds sin comprobar que provengan del modelo)")
  if (identical(mode, "density") && is.null(density)) out <- c(out, "origen UMAP/HDBSCAN de la comparaci\u00f3n (no se entreg\u00f3 `density`: los grupos se toman de grupos_jsd.rds sin comprobar que provengan del modelo)")
  out
}

#' Manifiesto de archivos de una entrega
#'
#' `write_bundle_manifest()` registra el tamano y el MD5 de todos los archivos de
#' una carpeta de entrega en `manifiesto_archivos.csv` (sin incluirse a si mismo).
#' `verify_bundle()` recalcula las huellas y devuelve una tabla con el estado de
#' cada archivo: `correcto`, `modificado`, `ausente` o `no registrado`.
#'
#' Antes de comparar, `verify_bundle()` valida el propio manifiesto y se detiene con un
#' error (sin devolver una tabla vacia que pudiera leerse como "todo correcto") si no se
#' puede leer como CSV, no tiene las columnas `archivo`, `bytes` y `md5`, no registra
#' ningun archivo, contiene rutas vacias, absolutas, que salen de la carpeta, repetidas
#' o que apuntan al propio manifiesto, o tiene tamanos o MD5 con formato invalido. Un
#' archivo se considera `correcto` solo si coinciden su MD5 y su tamano.
#'
#' @param directory Carpeta de una entrega creada con [export_bundle()].
#' @return `write_bundle_manifest()` devuelve la tabla escrita de forma invisible;
#'   `verify_bundle()` devuelve un `data.frame` con `archivo` y `estado`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
#' out <- file.path(tempdir(), "entrega-ejemplo")
#' export_bundle(out, p, cp, biblio_summary(p), raw = d)
#' table(verify_bundle(out)$estado)
#' unlink(out, recursive = TRUE)
#' @export
write_bundle_manifest <- function(directory) {
  files <- bundle_files(directory)
  manifest <- data.frame(archivo = files, bytes = as.numeric(file.size(file.path(directory, files))),
    md5 = unname(tools::md5sum(file.path(directory, files))), stringsAsFactors = FALSE)
  utils::write.csv(manifest, file.path(directory, "manifiesto_archivos.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  invisible(manifest)
}
bundle_files <- function(directory) {
  files <- list.files(directory, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  sort(setdiff(files, "manifiesto_archivos.csv"))
}
#' @rdname write_bundle_manifest
#' @export
verify_bundle <- function(directory) {
  path <- file.path(directory, "manifiesto_archivos.csv")
  if (!file.exists(path)) abort_user("La carpeta no contiene manifiesto_archivos.csv.")
  recorded <- tryCatch(suppressWarnings(utils::read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8", colClasses = "character")),
    error = function(e) abort_user("El manifiesto no se puede leer como CSV. No se ha verificado ning\u00fan archivo."))
  if (!all(c("archivo", "bytes", "md5") %in% names(recorded))) abort_user("El manifiesto debe tener las columnas archivo, bytes y md5. No se ha verificado ning\u00fan archivo.")
  if (!nrow(recorded)) abort_user("El manifiesto no registra ning\u00fan archivo: no hay nada que verificar y no puede darse por verificada la entrega.")
  f <- recorded$archivo
  bad <- is.na(f) | !nzchar(f) | grepl("^(/|\\\\|[A-Za-z]:)", f) | grepl("(^|[/\\\\])\\.\\.($|[/\\\\])", f) | f == "manifiesto_archivos.csv"
  if (any(bad)) abort_user("El manifiesto contiene rutas no v\u00e1lidas (vac\u00edas, absolutas, que salen de la carpeta o el propio manifiesto). No se ha verificado ning\u00fan archivo.")
  if (anyDuplicated(f)) abort_user("El manifiesto repite rutas de archivo. No se ha verificado ning\u00fan archivo.")
  size <- suppressWarnings(as.numeric(recorded$bytes))
  if (anyNA(size) || any(size < 0) || !all(grepl("^[0-9a-f]{32}$", recorded$md5))) abort_user("El manifiesto contiene tama\u00f1os o huellas MD5 no v\u00e1lidos. No se ha verificado ning\u00fan archivo.")
  present <- bundle_files(directory)
  state <- vapply(seq_along(f), function(i) {
    full <- file.path(directory, f[i])
    if (!file.exists(full) || dir.exists(full)) "ausente"
    else if (identical(unname(tools::md5sum(full)), recorded$md5[i]) && identical(as.numeric(file.size(full)), size[i])) "correcto" else "modificado"
  }, "")
  extra <- setdiff(present, f)
  data.frame(archivo = c(f, extra), estado = c(unname(state), rep("no registrado", length(extra))), stringsAsFactors = FALSE)
}
