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
    part("Modelos de idioma", "Lematizaci\u00f3n local UDPipe; no traduce. Los archivos y MD5 constan en par\u00e1metros JSON.",
      if (length(corpus$models)) data.frame(idioma = names(corpus$models), modelo = vapply(corpus$models, `[[`, "", "file"), md5 = vapply(corpus$models, `[[`, "", "md5")) else data.frame()),
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
    part("UMAP / HDBSCAN: grupos", "Grupo 0 conserva los documentos sin asignar. La membres\u00eda es una medida de pertenencia estimada; no una probabilidad tem\u00e1tica calibrada.", density$summary),
    part("Grupos: palabras c-TF-IDF", "TF normalizado por palabras de cada clase; IDF = log(1 + A/f_t). Las etiquetas requieren lectura de originales.", density$terms),
    part("Grupos: documentos para leer", "Las membres\u00edas orientan selecci\u00f3n; no prueban representatividad del campo.", density$examples))
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
#' @param directory Carpeta de destino (se crea si no existe).
#' @param prepared,corpus,bibliography Resultados de la preparacion.
#' @param lda,ca,density,network,comparison,pca,subgraph Resultados opcionales.
#' @param prompt Texto de prompt a guardar (opcional).
#' @param raw `data.frame` importado original; se guarda como RDS para reproducir.
#' @param module_dir Ignorado (compatibilidad con V3).
#' @param reader Cuaderno de lectura enlazada (opcional).
#' @param record Registro de reproducibilidad; se calcula si es `NULL`.
#' @param lda_selection,density_sens Resultados de [lda_select_k()] y [density_sensitivity()].
#' @return `directory`, de forma invisible.
#' @export
export_bundle <- function(directory, prepared, corpus, bibliography, lda = NULL, ca = NULL, prompt = NULL, density = NULL, raw = NULL, module_dir = NULL, network = NULL, comparison = NULL, pca = NULL, subgraph=NULL,reader=NULL, record = NULL, lda_selection = NULL, density_sens = NULL) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  tables <- list(documentos = prepared$documents, auditoria = prepared$audit, duplicados_detectados = prepared$duplicates,
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
    nota_csv = "CSV UTF-8 con BOM y separador punto y coma. Texto que podr\u00eda ser f\u00f3rmula lleva un ap\u00f3strofo inicial para apertura segura en Excel.")
  jsonlite::write_json(manifest, file.path(directory, "parametros.json"), pretty = TRUE, auto_unbox = TRUE, na = "null", digits = NA)
  if(!is.null(reader)) {
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
  if (exists("reproduction_script", mode = "function")) writeLines(enc2utf8(reproduction_script(prepared, lda, ca, density, network, comparison, pca, subgraph)), file.path(directory, "reproducir_analisis.R"), useBytes = TRUE)
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
  }
  if (!is.null(density_sens)) {
    safe_csv(density_sens$runs, file.path(directory, "umap_hdbscan_sensibilidad.csv"))
    safe_csv(density_sens$summary, file.path(directory, "umap_hdbscan_sensibilidad_resumen.csv"))
  }
  write_prompt_bank(file.path(directory, "banco_prompts.md"))
  if (!is.null(prompt)) writeLines(enc2utf8(prompt), file.path(directory, "prompt_seleccionado.txt"), useBytes = TRUE)
  writeLines(capture.output(sessionInfo()), file.path(directory, "entorno_R.txt"))
  writeLines(enc2utf8(c("BIBLIOLAB \u00b7 ENTREGA", "Abre informe.html con un navegador. Las tablas completas est\u00e1n en los CSV.",
    "parametros.json conserva decisiones; entorno_R.txt registra las versiones de R y paquetes.",
    "documentos.csv y unidades_textuales.csv contienen texto original: revisa la privacidad antes de compartir el ZIP.",
    "evidencia_ia.json contiene tablas limitadas a 25 filas por ranking y excluye extractos originales.",
    "Las tablas de LDA, CA, subgrafo y UMAP/HDBSCAN solo se incluyen si sus resultados est\u00e1n vigentes. La spline requiere un ajuste v\u00e1lido; no se inventa si falta cobertura.",
    "reproducir_analisis.R se ejecuta desde esta carpeta, usa entrada_original.rds y requiere el paquete bibliolab instalado (version registrada en registro_reproducibilidad.json).",
    "informe_metodologico.md / .html resume procedimientos, parametros, diagnosticos de validez y limitaciones. registro_reproducibilidad.json guarda versiones, semillas y huella de los datos.",
    "Los modelos UDPipe se descargan por separado y se verifica su MD5.",
    "skills contiene instrucciones de redacci\u00f3n y revisi\u00f3n; lee skills/USO.md para aplicarlas en tu herramienta.",
    "Si faltan gr\u00e1ficos, ejecuta los an\u00e1lisis correspondientes; los mapas no se calculan autom\u00e1ticamente.")), file.path(directory, "LEEME.txt"), useBytes = TRUE)
  invisible(directory)
}
