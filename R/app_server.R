# Servidor de la aplicacion. Se define aqui (y no en app.R) para que el paquete
# pueda resolver sus funciones internas; los modulos de sesion se cargan con source(local = TRUE)
# desde inst/app/server.
app_server <- function(input, output, session) {
  rv <- reactiveValues(raw = NULL, source_name = NULL, is_demo = FALSE, prepared = NULL, corpus = NULL,
    bib = NULL, lda = NULL, ca = NULL, density = NULL, density_signature = NULL, network = NULL, network_signature = NULL, comparison = NULL, comparison_signature = NULL, pca = NULL, pca_signature = NULL,
    import_file=NULL, excel_sheets=character(), import_signature=NULL,
    language_overrides=character(), language_text_column=NULL, signature = NULL, error = NULL, table_key = "audit", figure_key = "annual", code_stage = "load", models_revision = 0L,
    kselect = NULL, kselect_signature = NULL, dsens = NULL, dsens_signature = NULL)
  invalidate <- function() { rv$comparison <- NULL; rv$comparison_signature <- NULL; rv$pca <- NULL; rv$pca_signature <- NULL; rv$network <- NULL; rv$network_signature <- NULL; rv$prepared <- NULL; rv$corpus <- NULL; rv$bib <- NULL; rv$lda <- NULL; rv$ca <- NULL; rv$density <- NULL; rv$density_signature <- NULL; rv$signature <- NULL; rv$kselect <- NULL; rv$kselect_signature <- NULL; rv$dsens <- NULL; rv$dsens_signature <- NULL }
  task <- function(message, expr) {
    rv$error <- NULL
    session$sendCustomMessage("analysisBusy", TRUE)
    on.exit(session$sendCustomMessage("analysisBusy", FALSE))
    tryCatch(withProgress(message = message, value = 0.1, { force(expr); incProgress(0.9) }),
      error = function(e) { rv$error <- conditionMessage(e); showNotification(rv$error, type = "error", duration = 12); invisible(NULL) })
  }
  set_data <- function(d, source_name, demo) {
    invalidate(); rv$language_overrides<-character(); rv$language_text_column<-NULL; rv$raw <- d; rv$source_name <- source_name; rv$is_demo <- demo
    updateTextInput(session, "source_db", value = if (demo) "Corpus sint\u00e9tico de pr\u00e1ctica" else "")
    if (demo) { rv$excel_sheets <- character(); rv$import_signature <- NULL; rv$import_file <- NULL }
    updateTextAreaInput(session, "search_query", value = "")
    updateTextInput(session, "extraction_date", value = "")
    updateTextAreaInput(session, "inclusion", value = "")
  }
  observeEvent(list(input$file, input$separator, input$encoding, input$excel_sheet), {
    req(input$file)
    id <- paste(input$file$datapath, input$file$name)
    new_file <- !identical(rv$import_file, id)
    if(new_file) { invalidate(); rv$raw <- NULL; rv$excel_sheets <- character(); rv$import_signature <- NULL; rv$import_file <- id }
    task("Leyendo archivo\u2026", {
      fmt <- biblio_file_format(input$file$datapath, input$file$name)
      sheet <- NULL
      if(fmt != "text") {
        if(new_file || !length(rv$excel_sheets)) rv$excel_sheets <- biblio_excel_sheets(input$file$datapath)
        sheet <- if(new_file || !(input$excel_sheet %||% "") %in% rv$excel_sheets) rv$excel_sheets[1] else input$excel_sheet
        if(is.null(input$excel_sheet) || !identical(input$excel_sheet,sheet)) updateSelectInput(session,"excel_sheet",choices=rv$excel_sheets,selected=sheet)
      }
      sig <- list(id=id,format=fmt,sheet=sheet,separator=if(fmt=="text") input$separator %||% "auto" else NULL,encoding=if(fmt=="text") input$encoding %||% "UTF-8" else NULL)
      if(identical(rv$import_signature,sig)) return(invisible(NULL))
      invalidate(); rv$raw <- NULL; rv$import_signature <- NULL
      d <- read_biblio_file(input$file$datapath, input$file$name, sig$separator %||% "auto", sig$encoding %||% "UTF-8", sheet)
      set_data(d, paste0(basename(input$file$name),if(!is.null(sheet)) paste0(" \u00b7 hoja ",sheet) else ""), FALSE)
      rv$import_signature <- sig
      showNotification(paste("Archivo cargado. Texto propuesto:", guess_columns(d)$text %||% "sin asignar", "\u00b7 puedes leerlo directamente en el visor."), type = "message", duration = 6)
    })
  }, ignoreInit = TRUE)
  output$import_format <- renderText(if(length(rv$excel_sheets)) "excel" else "text")
  outputOptions(output,"import_format",suspendWhenHidden=FALSE)
  output$excel_sheet_ui <- renderUI({ if(!length(rv$excel_sheets)) return(NULL)
    selectInput("excel_sheet","Hoja que contiene los documentos",rv$excel_sheets,selected=if((input$excel_sheet %||% "") %in% rv$excel_sheets) input$excel_sheet else rv$excel_sheets[1]) })
  observeEvent(input$demo, task("Cargando pr\u00e1ctica\u2026", {
    set_data(read_biblio_csv(app_extdata("practica.csv"), ";"), "practica.csv \u00b7 DATOS FICTICIOS", TRUE)
    updateTabsetPanel(session, "steps", selected = "prepare")
  }))
  output$mapping_ui <- renderUI({
    if (is.null(rv$raw)) return(empty_help("Carga un CSV, TSV, Excel o los datos de pr\u00e1ctica en el paso 1."))
    guesses <- guess_columns(rv$raw)
    labels <- c(text = "Texto para analizar *", title = "T\u00edtulo", id = "Identificador original", year = "A\u00f1o de publicaci\u00f3n",
      source = "Revista / fuente", authors = "Autores", citations = "N\u00famero de citas", references = "Referencias citadas / CR (opcional)", keywords = "Palabras clave", doi = "DOI", language = "Idioma (corpus mixto)", translated = "Traducci\u00f3n importada (opcional)")
    make <- function(nm) selectInput(paste0("col_", nm), labels[[nm]],
      c("No asignar" = "", setNames(names(rv$raw), names(rv$raw))), selected = guesses[[nm]])
    langs <- language_columns(rv$raw)
    tagList(make("text"), hint(paste("Lectura propuesta:", if (nzchar(guesses$text)) guesses$text else "no se reconoce una columna de texto; selecci\u00f3nala aqu\u00ed.", "Puedes confirmarla leyendo el visor.")),
      make("title"), make("id"), make("keywords"), hint("Author Keywords / DE son palabras declaradas por los autores. Keywords Plus / ID e Index Keywords son \u00edndices de la base: as\u00edgnalos solo si esa es tu decisi\u00f3n y documenta su origen."), tags$details(open = if (nzchar(guesses$source) || nzchar(guesses$authors)) "open" else NULL,
        tags$summary("Metadatos bibliom\u00e9tricos \u00b7 detectados autom\u00e1ticamente"), lapply(c("year", "source", "authors", "citations", "doi", "references"), make)),
      tags$details(tags$summary("Traducciones y corpus de varios idiomas \u00b7 opcional"), make("translated"),
        selectInput("col_language", "Columna con el idioma de cada documento", c("No se necesita para un \u00fanico idioma" = "", setNames(langs, langs)), selected = if(nzchar(guesses$language)) guesses$language else if(length(langs)==1) langs[1] else ""),
        hint("Si los textos est\u00e1n en una lengua, elige esa lengua en Normalizaci\u00f3n ling\u00fc\u00edstica. Para varios idiomas, CLD2 estima el idioma del texto seleccionado. Esta columna es opcional: contiene etiquetas de idioma, no t\u00edtulos ni res\u00famenes. La tabla permite revisar estimaciones y corregir casos dudosos sin modificar el CSV.")))
  })
  output$filter_ui <- renderUI({ req(rv$raw); selectInput("filter_col", "Columna del filtro", names(rv$raw)) })
  execution_settings<-reactive(processing_execution(list(enabled=if(is.null(input$parallel_enabled)) TRUE else isTRUE(input$parallel_enabled),workers=input$parallel_workers %||% min(2L,processing_worker_limit()))))
  output$processing_controls<-renderUI(tagList(checkboxInput("parallel_enabled","Usar procesamiento paralelo en tareas grandes",TRUE),
    conditionalPanel("input.parallel_enabled",numericInput("parallel_workers","M\u00e1ximo de trabajadores R locales",min(2L,processing_worker_limit()),1,processing_worker_limit())),
    hint("Se deja al menos un n\u00facleo libre y se usan como m\u00e1ximo cuatro trabajadores. Para lotes peque\u00f1os se evita iniciar procesos. M\u00e1s trabajadores tambi\u00e9n requieren m\u00e1s memoria.")))
  settings <- reactive({
    fields <- c("text", "title", "id", "year", "source", "authors", "citations", "keywords", "doi", "language", "translated", "references")
    mapping <- setNames(lapply(fields, function(nm) input[[paste0("col_", nm)]] %||% ""), fields)
    config <- list(language = if(isTRUE(input$lemmatize)||isTRUE(input$pos_filter)) {if(identical(input$lemma_language,"column")) "by_document" else input$lemma_language %||% "es"} else input$language, remove_stop = isTRUE(input$remove_stop), custom_stop = input$custom_stop %||% "",
      min_chars = input$min_chars, remove_numbers = isTRUE(input$remove_numbers), remove_links = isTRUE(input$remove_links),
      remove_codes = isTRUE(input$remove_codes),
      lemmatize = isTRUE(input$lemmatize), split_sentences = isTRUE(input$split_sentences), deduplicate = isTRUE(input$dedup),
      year_min = if (isTRUE(input$year_filter)) input$year_min else NULL, year_max = if (isTRUE(input$year_filter)) input$year_max else NULL,
      sample_pct = input$sample_pct, seed = input$sample_seed, min_df = input$min_df, max_terms = input$max_terms,
      max_chars = input$max_chars %||% 40L, min_tf = input$min_tf %||% 1L, max_df_pct = input$max_df_pct %||% 100,
      min_tfidf = input$min_tfidf %||% 0, max_entropy = input$max_entropy %||% 1, term_order = input$term_order %||% "frequency",
      tfidf_stat = input$tfidf_stat %||% "mean", tfidf_scope = input$tfidf_scope %||% "all", tfidf_percentile = input$tfidf_percentile %||% 75,
      language_overrides=if(identical(input$lemma_language,"column")) language_route()$overrides else character(),
      language_detection=if(identical(input$lemma_language,"column")) language_route()$detector else NULL,execution=execution_settings(),
      lemma_language = input$lemma_language %||% "es", pos_filter = isTRUE(input$pos_filter), pos_keep = if (isTRUE(input$pos_filter)) input$pos_keep %||% character() else c("NOUN", "PROPN", "ADJ"),
      normalize_labels = isTRUE(input$normalize_labels %||% TRUE), remove_boilerplate = isTRUE(input$remove_boilerplate %||% TRUE),
      metadata_sep = input$metadata_sep %||% ";", authors_sep=input$authors_sep %||% "auto", keywords_sep=input$keywords_sep %||% "auto", filter_col = if (isTRUE(input$value_filter)) input$filter_col %||% "" else "",
      filter_value = if (isTRUE(input$value_filter)) input$filter_value %||% "" else "")
    provenance <- list(base_de_datos = input$source_db %||% "", ecuacion_busqueda = input$search_query %||% "",
      fecha_extraccion = input$extraction_date %||% "", criterios = input$inclusion %||% "")
    list(mapping = mapping, config = config, question = input$question %||% "", provenance = provenance)
  })
  stale <- reactive(!is.null(rv$prepared) && !identical(rv$signature, settings()))
  current <- reactive({
    validate(need(!is.null(rv$prepared), "Prepara un corpus en el paso 2 para ver resultados."),
      need(!stale(), "Hay cambios pendientes. Pulsa \u00abPreparar corpus\u00bb en el paso 2."))
    rv$prepared
  })
  lda_alpha_value <- function() {
    k <- as.numeric(input$k %||% 4)
    switch(input$lda_alpha_mode %||% "sparse", moderate = 5 / k, standard = 50 / k, 1 / k)
  }
  lda_current <- reactive({ current(); if (is.null(rv$lda)) return(NULL)
    # Comparacion numerica elemento a elemento: las entradas pueden ser texto ("500") y alpha no es entero.
    if (!isTRUE(all.equal(as.numeric(c(rv$lda$params$k, rv$lda$params$seed, rv$lda$params$iterations, rv$lda$params$alpha)),
                          c(as.numeric(input$k), as.numeric(input$lda_seed), as.numeric(input$iterations), lda_alpha_value())))) return(NULL)
    rv$lda
  })
  ca_current <- reactive({ current(); if (is.null(rv$ca) || !identical(as.numeric(rv$ca$params$max_terms), as.numeric(input$ca_terms))) return(NULL); rv$ca })
  observeEvent(input$prepare, task("Preparando corpus y calculando indicadores\u2026", {
    if (is.null(rv$raw)) abort_user("Carga un archivo o usa los datos de pr\u00e1ctica antes de preparar.")
    s <- settings(); p <- prepare_documents(rv$raw, s$mapping, s$config)
    date_text <- trimws(s$provenance$fecha_extraccion)
    if (nzchar(date_text)) {
      valid_date <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date_text) &&
        !is.na(tryCatch(as.Date(date_text, format = "%Y-%m-%d"), error = function(e) as.Date(NA)))
      if (!valid_date) abort_user("La fecha de extracci\u00f3n debe ser una fecha v\u00e1lida con formato AAAA-MM-DD, o quedar vac\u00eda.")
    }
    p$source_name <- rv$source_name; p$is_demo <- rv$is_demo; p$input_md5 <- attr(rv$raw, "source_md5"); p$question <- s$question; p$import_info <- attr(rv$raw,"import_info")
    p$provenance <- s$provenance
    if(identical(input$lemma_language,"column")) p$language_audit<-language_route()$audit
    p$prepared_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    cp <- prepare_corpus(p,progress=function(stage,current,total) setProgress(value=.1+.7*current/max(1,total),detail=switch(stage,lexical="Segmentaci\u00f3n y limpieza",annotate="Lematizaci\u00f3n y categor\u00edas",normalize="Normalizaci\u00f3n de lemas y tokens",stage)))
    if(identical(input$lemma_language,"column")) cp$processing<-rbind(attr(language_estimates(),"processing"),cp$processing)
    b <- biblio_summary(p); p$model_info <- cp$models
    rv$comparison <- NULL; rv$comparison_signature <- NULL; rv$pca <- NULL; rv$pca_signature <- NULL; rv$network <- NULL; rv$network_signature <- NULL; rv$prepared <- p; rv$corpus <- cp; rv$bib <- b; rv$signature <- s; rv$lda <- NULL; rv$ca <- NULL; rv$density <- NULL; rv$density_signature <- NULL
    rv$kselect <- NULL; rv$kselect_signature <- NULL; rv$dsens <- NULL; rv$dsens_signature <- NULL
    showNotification("Corpus preparado. Revisa la auditor\u00eda y explora los resultados.", type = "message", duration = 6)
  }))
  observeEvent(input$run_lda, task("Calculando temas LDA\u2026", {
    if (is.null(rv$prepared) || stale()) abort_user("Prepara el corpus con las opciones actuales antes de calcular temas.")
    rv$lda <- NULL
    rv$lda <- run_lda(rv$corpus, input$k, input$lda_seed, as.numeric(input$iterations), alpha = lda_alpha_value())
    showNotification("Temas calculados. Revisa sus palabras, su calidad y lee los documentos representativos.", type = "message", duration = 6)
  }))
  observeEvent(input$run_ca, task("Calculando mapa de correspondencias\u2026", {
    if (is.null(rv$prepared) || stale()) abort_user("Prepara el corpus con las opciones actuales antes de calcular el mapa.")
    rv$ca <- NULL; rv$ca <- run_ca(rv$corpus, input$ca_terms)
    showNotification("Mapa calculado. Comprueba la inercia y el cos\u00b2 antes de interpretarlo.", type = "message", duration = 6)
  }))
  output$session_status <- renderUI({
    status <- if (is.null(rv$raw)) "Sin datos \u00b7 carga un archivo o prueba el ejemplo" else if (is.null(rv$prepared)) "Datos cargados \u00b7 prepara el corpus en el paso 2" else if (stale()) "Cambios pendientes \u00b7 vuelve a preparar el corpus" else "Corpus preparado \u00b7 resultados vigentes"
    tags$div(class = paste("status-bar", if (stale()) "warning" else ""), role = "status", `aria-live` = "polite",
      tags$strong(status), tags$span(if (!is.null(rv$raw)) paste(nrow(rv$raw), "filas \u00b7", rv$source_name) else "Todo empieza con una fila por documento"),
      if (rv$is_demo) tags$span(class = "demo-badge", "PR\u00c1CTICA FICTICIA"))
  })
  output$error_box <- renderUI({ if (is.null(rv$error)) return(NULL)
    tags$div(class = "error-box", role = "alert", tags$strong("No se ha completado esta acci\u00f3n. "), rv$error, " Revisa las opciones y vuelve a intentarlo.") })
  output$file_summary <- renderUI({ if (is.null(rv$raw)) return(empty_help("Tu vista previa aparecer\u00e1 aqu\u00ed al cargar datos."))
    info <- attr(rv$raw,"import_info")
    tags$div(class = "import-summary", tags$strong(paste(nrow(rv$raw), "documentos /", ncol(rv$raw), "campos")),
      if(!is.null(info)) tagList(tags$p(paste("Excel",toupper(info$format),"\u00b7 hoja",info$sheet,"\u00b7",sum(info$headers$corregido),"encabezados ajustados; todas las columnas se conservan.")),actionButton("import_details","Ver c\u00f3mo se ha le\u00eddo el Excel",class="btn-quiet")),
      tags$details(tags$summary("Campos disponibles"),hint(paste(names(rv$raw), collapse = " \u00b7 "))), tags$p(paste("Texto reconocido:", if (nzchar(guess_columns(rv$raw)$text)) guess_columns(rv$raw)$text else "ninguno; elige el campo en Preparaci\u00f3n."))) })
  observeEvent(input$import_details,{ info<-attr(rv$raw,"import_info");req(info)
    showModal(modalDialog(title="Tu Excel / qu\u00e9 se ha conservado",size="l",easyClose=TRUE,
      tags$p(class="modal-lead",paste("Se ha le\u00eddo la hoja",info$sheet,"con",nrow(rv$raw),"documentos. Cada columna del libro tiene una columna en la aplicaci\u00f3n, incluidas las vac\u00edas.")),
      tags$p("Web of Science puede exportar encabezados repetidos, por ejemplo dos columnas Abstract - Foreign. Para que puedas elegirlas sin ambig\u00fcedad, la segunda recibe un sufijo. Si falta un encabezado, usamos Columna y su posici\u00f3n. El contenido y el orden de las filas permanecen intactos. La tabla permite comprobar cada nombre original y el utilizado."),
      tags$p(info$note),tags$p("La aplicaci\u00f3n lee los valores guardados de las f\u00f3rmulas; no recalcula Excel. Guarda primero el libro en Excel si has editado f\u00f3rmulas. El registro de hoja, lector y encabezados se incluye en la entrega para rastrear la importaci\u00f3n."),
      DT::DTOutput("import_headers"),footer=modalButton("Volver al corpus"))) })
  output$import_headers <- DT::renderDT({req(rv$raw);DT::datatable(attr(rv$raw,"import_info")$headers,rownames=FALSE,options=list(pageLength=8,scrollX=TRUE),escape=TRUE)})
  table_render <- function(data, before = NULL, selection = "none", searching = TRUE) DT::renderDT({
    if (!is.null(before)) before()
    d <- data()
    validate(need(!is.null(d) && ncol(d) > 0, "No hay datos para esta tabla. Comprueba las columnas, filtros o vocabulario."))
    for(nm in intersect(c("title","titulo"),names(d))) d[[nm]]<-display_label(d[[nm]],"title")
    if("source" %in% names(d)) d$source<-display_label(d$source,"source")
    if("elemento" %in% names(d) && identical(rv$table_key,"sources")) d$elemento<-display_label(d$elemento,"source")
    # Acortar solo la vista; exportaciones y modelos conservan los valores completos.
    for (nm in names(d)) if (is.character(d[[nm]])) d[[nm]] <- ifelse(nchar(d[[nm]]) > 500, paste0(substr(d[[nm]], 1, 500), "\u2026"), d[[nm]])
    for (nm in names(d)[vapply(d, is.logical, logical(1))]) d[[nm]] <- ifelse(d[[nm]], "S\u00ed", "No")
    labels <- c(documentos_modelo="Documentos en el modelo",cobertura_documentos_pct="Cobertura de documentos (%)",unidades_modelo="Unidades analizadas",terminos_modelo="T\u00e9rminos del modelo",hallazgos="Resultados / palabras y proporciones",diagnosticos_observados="Diagn\u00f3sticos de esta ejecuci\u00f3n",fila="Fila del archivo",id="ID original",titulo="T\u00edtulo",idioma_declarado="Idioma indicado",idioma_reconocido="Modelo que se utilizar\u00e1",texto_ejemplo="Extracto para revisar",grupo="Grupo",total="Documentos del modelo ese a\u00f1o",porcentaje_anual="Peso del grupo ese a\u00f1o (%)",porcentaje_tematico_medio="Participaci\u00f3n tem\u00e1tica media (%)",comunidad_origen="Comunidad en la red original",grado_origen="Grado en la red original",documentos_con_termino="Documentos con el t\u00e9rmino",documentos_del_grupo="Documentos del grupo/a\u00f1o",porcentaje_tokens="Apariciones entre tokens del grupo/a\u00f1o (%)", metodo="M\u00e9todo",estado="Estado",representacion="Representaci\u00f3n",resultado="Resultado observado",interpretacion="C\u00f3mo interpretarlo",lectura="Aspecto de la red",bm25_medio="BM25 medio",expresion="Expresi\u00f3n",n="Longitud / n",concentracion="1 menos entrop\u00eda",documentos_validos="Documentos con datos",porcentaje_acumulado="Documentos acumulados (%)",citas_relativas_cohorte="Citas / media del mismo a\u00f1o",documentos_cohorte="Registros v\u00e1lidos de la cohorte",name="Nodo",grado="Grado",fuerza="Fuerza",intermediacion="Intermediaci\u00f3n",centralidad_armonica="Centralidad arm\u00f3nica",nucleo_k="N\u00facleo k",articulacion="Articulaci\u00f3n",participacion="Participaci\u00f3n entre comunidades",rol_observado="Rol topol\u00f3gico observado",orden="Paso de selecci\u00f3n",nodo="Candidato",nuevos_cubiertos="Nodos nuevos cubiertos",cubiertos_acumulados="Nodos cubiertos",porcentaje_cubierto="Cobertura (%)", codigo = "C\u00f3digo", frecuencia_relativa_A_pct = "Frecuencia relativa A (%)", frecuencia_relativa_B_pct = "Frecuencia relativa B (%)", proporcion_A = "Proporci\u00f3n A", proporcion_B = "Proporci\u00f3n B", cambio_pp = "Cambio B \u2212 A (puntos %)", aporte_bits = "Aportaci\u00f3n JSD (bits)", aporte_pct = "JSD explicada (%)", aporte_acumulado_pct = "JSD acumulada (%)", direccion = "Mayor proporci\u00f3n", shift_pct = "Orientaci\u00f3n gr\u00e1fica (% JSD)", valor_A = "Valor agregado A", valor_B = "Valor agregado B", jsd_bits = "JSD (bits)", distancia = "Ra\u00edz de JSD", varianza = "Varianza", carga_1 = "Carga eje 1", carga_2 = "Carga eje 2", cos2_plano = "Cos\u00b2 del plano", incluido = "Retenido", entropia = "Entrop\u00eda", motivo_exclusion = "Motivo / estado", doc_id = "ID documento", unit_id = "ID unidad", original_id = "ID original", source_row = "Fila original", title = "T\u00edtulo", text = "Texto", year = "A\u00f1o", source = "Fuente", citations = "Citas", sentence = "Frase", original = "Texto original", cleaned = "Texto limpio", ano = "A\u00f1o", elemento = "Nombre", documentos = "Documentos", porcentaje_documentos = "% de documentos", termino = "T\u00e9rmino", frecuencia = "Apariciones", tfidf_medio = "TF-IDF medio", tema = "Tema", beta = "Beta", posicion = "Posici\u00f3n", proporcion_media = "Proporci\u00f3n media", proporcion = "Proporci\u00f3n", contribucion_eje_1 = "Contribuci\u00f3n eje 1 (%)", contribucion_eje_2 = "Contribuci\u00f3n eje 2 (%)", eje_1 = "Eje 1", eje_2 = "Eje 2")
    labels<-c(labels,motivo="Motivo de selecci\u00f3n",criterio_seleccion="Valor usado para seleccionar",supera_umbral="Supera el umbral",prioridad="Prioridad expl\u00edcita",en_red="Incluido en esta red",cantidad="Cantidad",campo="Campo",indicador="Indicador",valor="Valor",menciones="Menciones",inicio="Posici\u00f3n inicial",fin="Posici\u00f3n final",antes="Texto anterior",coincidencia="Expresi\u00f3n encontrada",despues="Texto posterior",h_corpus="\u00cdndice h del corpus",citas_suma="Suma de citas v\u00e1lidas",citas_validas="Documentos con citas v\u00e1lidas",citas_ausentes="Documentos sin citas",
      tfidf_mean="TF-IDF / media global",tfidf_sd="TF-IDF / desviaci\u00f3n t\u00edpica",tfidf_median="TF-IDF / mediana global",tfidf_mediana="TF-IDF / mediana global",tfidf_mad="TF-IDF / MAD sin escalar",tfidf_q25="TF-IDF / P25",tfidf_q75="TF-IDF / P75",tfidf_q90="TF-IDF / P90",tfidf_present_mean="TF-IDF / media con peso positivo",tfidf_present_median="TF-IDF / mediana con peso positivo",tfidf_mediana_presente="TF-IDF / mediana con peso positivo",tfidf_present_mad="TF-IDF / MAD con peso positivo",tfidf_orden="TF-IDF / estad\u00edstico usado para ordenar",
      etapa="Etapa",modo="V\u00eda utilizada",trabajadores="Trabajadores R",lotes="Lotes",elementos="Elementos",segundos="Tiempo (s)",nota="Motivo / lectura",idioma_csv="Etiqueta del CSV",origen_idioma="Origen de la asignaci\u00f3n",idioma_estimado="Estimaci\u00f3n CLD2",estado_estimacion="Lectura de la estimaci\u00f3n",porcentaje_texto_clasificado="Texto clasificado en lengua dominante (%)",discrepancia="Discrepancia con CLD2")
    display_names <- ifelse(names(d) %in% names(labels), labels[names(d)], names(d))
    widget <- DT::datatable(d, rownames = FALSE, escape = TRUE, selection = selection, colnames = unname(display_names),
    options = list(searching = if (is.function(searching)) searching() else searching, pageLength = 8, lengthMenu = c(8, 15, 30,100), scrollX = TRUE, autoWidth = FALSE,
        language = list(search = "Buscar:", lengthMenu = "Mostrar _MENU_ filas", info = "_START_\u2013_END_ de _TOTAL_ filas",
          infoEmpty = "Sin filas", infoFiltered = "(de _MAX_)", zeroRecords = "No hay coincidencias", emptyTable = "No hay registros que coincidan con esta selecci\u00f3n",
          aria = list(sortAscending = ": ordenar de menor a mayor", sortDescending = ": ordenar de mayor a menor"),
          paginate = list(first = "Primera", last = "\u00daltima", `next` = "Siguiente", previous = "Anterior"))))
    for (nm in names(d)[vapply(d, is.numeric, logical(1))]) {
      vals <- d[[nm]][is.finite(d[[nm]])]
      digits <- if (!length(vals) || all(vals == floor(vals))) 0 else if (grepl("porcentaje|contribucion", nm)) 2 else 4
      thousands <- if (nm %in% c("year", "ano", "sentence", "tema", "eje", "source_row", "posicion")) "" else "."
      widget <- DT::formatRound(widget, columns = nm, digits = digits, mark = thousands, dec.mark = ",")
    }
    widget
  }, server = TRUE)
  output$preparation_summary <- renderUI({
    if (is.null(rv$prepared)) return(empty_help("Todav\u00eda no has preparado el corpus. Asigna el texto, revisa las opciones y pulsa Preparar corpus. Este aviso desaparece cuando finaliza el c\u00e1lculo."))
    if (stale()) return(tags$div(class="status-bar warning",role="status","Opciones modificadas. Los resultados anteriores requieren una nueva preparaci\u00f3n. Pulsa Preparar corpus."))
    tags$div(class = "preparation-summary status-success", role="status",
    tags$strong("\u2713 Corpus preparado correctamente. Resultados vigentes."), tags$br(),
    tags$strong(paste(nrow(rv$prepared$documents), "documentos /", length(rv$corpus$vocabulary), "t\u00e9rminos retenidos /", rv$corpus$n_active, "unidades textuales")),
    hint("Consulta auditor\u00eda, cobertura y razones de exclusi\u00f3n en las tablas. Los originales y versiones de texto se encuentran en el visor \u00fanico.")) })
  output$metrics <- renderUI({
    p <- current(); d <- p$documents; yr <- d$year[!is.na(d$year)]; ct <- d$citations[!is.na(d$citations)]
    metric <- function(value, label, detail) tags$div(class = "metric", tags$span(class = "metric-value", value), tags$strong(label), tags$small(detail))
    tags$div(class = "metrics", metric(nrow(d), "Documentos", "Despu\u00e9s de filtros y muestra"),
      metric(if (length(yr)) paste(min(yr), max(yr), sep = "\u2013") else "\u2014", "Periodo registrado", paste(length(yr), "con a\u00f1o v\u00e1lido")),
      metric(if (length(ct)) format(sum(ct), big.mark = ".", decimal.mark = ",", scientific = FALSE) else "\u2014", "Citas registradas", paste(length(ct), "con citas v\u00e1lidas")),
      metric(rv$corpus$total_tokens, "Palabras retenidas", paste(rv$corpus$n_active, "unidades con palabras")))
  })
  plot_theme <- swiss_theme
  annual_graph <- reactive({ current(); d <- rv$bib$annual
    validate(need(nrow(d) > 0, "Asigna una columna de a\u00f1o con valores v\u00e1lidos para ver la evoluci\u00f3n."))
    # Completar anos entre extremos solo para el grafico del corpus observado.
    full <- data.frame(ano = seq(min(d$ano), max(d$ano))); full$documentos <- d$documentos[match(full$ano, d$ano)]; full$documentos[is.na(full$documentos)] <- 0
    ggplot2::ggplot(full, ggplot2::aes(ano, documentos)) + ggplot2::geom_col(fill = "#c7281e", width = .75) +
      ggplot2::labs(x = "A\u00f1o", y = "Documentos del corpus", title = "Producci\u00f3n observada por a\u00f1o") + year_axis(full$ano) + plot_theme() + ggplot2::theme(axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5))
  })
  bar_graph <- function(d, label, value, title, axis) {
    validate(need(nrow(d) > 0, "No hay datos suficientes para este gr\u00e1fico."))
    d$etiqueta <- factor(seq_len(nrow(d)), levels = rev(seq_len(nrow(d)))); d$valor <- d[[value]]
    ggplot2::ggplot(d, ggplot2::aes(etiqueta, valor)) + ggplot2::geom_col(fill="#c7281e", width = .7) +
      ggplot2::geom_point(data=d[d$valor==0,,drop=FALSE],colour="#c7281e",size=2) +
      ggplot2::geom_text(ggplot2::aes(label=ifelse(valor==floor(valor),format(valor,big.mark=".",decimal.mark=",",trim=TRUE,scientific=FALSE),formatC(valor,digits=3,format="fg",decimal.mark=","))),hjust=-.15,size=3.1) +
      ggplot2::scale_x_discrete(labels=setNames(vapply(d[[label]],function(x)paste(strwrap(x,width=52),collapse="\n"),""),as.character(seq_len(nrow(d))))) +
      ggplot2::scale_y_continuous(expand=ggplot2::expansion(mult=c(0,.2))) + ggplot2::coord_flip(clip="off") +
      ggplot2::labs(x = NULL, y = axis, title = title) + plot_theme()
  }
  sources_graph <- reactive({ current(); d<-rank_slice(rv$bib$sources,input$sources_n %||% 25,input$sources_page %||% 1)$data; d$elemento<-display_label(d$elemento,"source"); bar_graph(d, "elemento", "documentos", "Fuentes m\u00e1s frecuentes", "Documentos") })
  terms_graph <- reactive({ current(); bar_graph(head(rv$corpus$terms,25), "termino", "frecuencia", "Palabras m\u00e1s frecuentes", "Apariciones") })
  gram_data <- reactive({current();d<-rv$corpus$ngrams %||% data.frame(); if(!nrow(d)) return(d)
    d<-d[d$n==as.integer(input$gram_order %||% 2) & d$documentos >= (input$gram_min_df %||% 1),]; d$concentracion<-1-d$entropia
    metric<-input$gram_metric %||% "documentos";d[order(-d[[metric]],-d$documentos,d$expresion),]})
  bigrams_graph <- reactive({ d<-gram_data(); metric<-input$gram_metric %||% "documentos"
    bar_graph(head(d,25),"expresion",metric,paste("Expresiones / n =",input$gram_order %||% 2),switch(metric,documentos="Documentos",frecuencia="Apariciones",tfidf_medio="Peso TF-IDF medio",tfidf_mediana="Mediana de TF-IDF",tfidf_q75="Percentil 75 de TF-IDF",concentracion="1 menos entrop\u00eda normalizada")) })
  output$annual_plot <- renderPlot(annual_graph(), res = 110)
  output$sources_plot <- renderPlot(sources_graph(),height=function() max(420,35*nrow(rank_slice(rv$bib$sources %||% data.frame(),input$sources_n %||% 25,input$sources_page %||% 1)$data)+110), res = 110)

  output$bigrams_plot <- renderPlot(bigrams_graph(),height=function()max(460,32*min(25,nrow(gram_data()))+145), res = 110)
  output$lda_state <- renderUI({ current(); fit <- lda_current()
    if (is.null(fit)) return(empty_help(if (is.null(rv$lda)) "Pulsa \u00abCalcular temas\u00bb para ejecutar LDA." else "Par\u00e1metros modificados. Vuelve a calcular los temas."))
    hint(paste(fit$units, "unidades \u00b7", fit$terms, "t\u00e9rminos \u00b7", fit$params$k, "temas \u00b7", fit$ran_at)) })
  output$ca_state <- renderUI({ current(); fit <- ca_current()
    if (is.null(fit)) return(empty_help(if (is.null(rv$ca)) "Pulsa \u00abCalcular mapa\u00bb para ejecutar correspondencias." else "N\u00famero de t\u00e9rminos modificado. Vuelve a calcular el mapa."))
    above <- if (isTRUE(fit$params$baseline$computed)) sprintf(" Ejes por encima del azar (percentil 95 de permutaciones): %d de los %d primeros.", sum(fit$dimensions$supera_azar %in% TRUE), sum(!is.na(fit$dimensions$supera_azar))) else ""
    hint(sprintf("El plano recoge %.1f%% de la inercia. %d t\u00e9rminos y %d unidades.%s", sum(fit$dimensions$porcentaje[1:2]), nrow(fit$terms), nrow(fit$units), above)) })
  lda_graph <- reactive({ fit <- lda_current(); validate(need(!is.null(fit), "Calcula los temas con los par\u00e1metros actuales."))
    d <- fit$top[fit$top$posicion <= 7, ]; d$etiqueta <- paste(d$tema, d$termino, sep = "::")
    d$etiqueta <- factor(d$etiqueta, levels = rev(d$etiqueta))
    ggplot2::ggplot(d, ggplot2::aes(beta, etiqueta, fill=factor(tema))) + ggplot2::geom_col(width = .7, show.legend=FALSE) + ggplot2::scale_fill_manual(values=swiss_colours(fit$params$k)) +
      ggplot2::facet_wrap(~tema, scales = "free_y", ncol = 2, labeller = ggplot2::label_both) +
      ggplot2::scale_y_discrete(labels = function(x) sub("^[0-9]+::", "", x)) +
      ggplot2::labs(x = "Beta \u00b7 P(palabra | tema)", y = NULL, title = "Palabras principales por tema") + plot_theme()
  })
  ca_graph <- reactive({ fit <- ca_current(); validate(need(!is.null(fit), "Calcula el mapa con los par\u00e1metros actuales."))
    ordination_figure(fit$terms, fit$dimensions, "Correspondencias / perfiles l\u00e9xicos")
  })
  output$lda_plot <- renderPlot(lda_graph(), height = function() { fit <- lda_current(); if (is.null(fit)) 480 else max(480, ceiling(fit$params$k / 2) * 250) }, res = 96)
  output$ca_plot <- renderPlot(ca_graph(), res = 110)
  evidence <- reactive({ p <- current(); evidence_bundle(p, rv$corpus, rv$bib, lda_current(), ca_current(), isTRUE(input$include_text), density = density_export_current(), network = network_current(), comparison = comparison_current(), pca = pca_current(),subgraph=subgraph_current(),
    lda_selection = kselect_current(), density_sens = dsens_current()) })
  prompt_ready <- reactive({
    entry <- prompt_catalog()[[input$prompt_key %||% "inicio"]]
    current()
    if (entry$requires == "text") validate(need(nrow(rv$corpus$terms) > 0, "Este prompt necesita palabras retenidas. Revisa la limpieza."))
    if (entry$requires == "lda") validate(need(!is.null(lda_current()), "Este prompt necesita temas LDA vigentes. Calc\u00falalos en el paso 4."))
    if (entry$requires == "ca") validate(need(!is.null(ca_current()), "Este prompt necesita un mapa vigente. Calc\u00falalo en el paso 4."))
    if (entry$requires == "comparison") validate(need(!is.null(comparison_current()), "Este prompt necesita una comparaci\u00f3n JSD vigente. Calc\u00falala en Indicadores / JSD shifts."))
    if (entry$requires == "pca") validate(need(!is.null(pca_current()), "Este prompt necesita ACP vigente. Calc\u00falalo en Modelos / ACP."))
    if (entry$requires == "network") validate(need(!is.null(network_current()), "Este prompt necesita una red vigente. Calc\u00falala en Indicadores / Redes."))
    if (entry$requires == "density") validate(need(!is.null(density_current()), "Este prompt necesita UMAP y HDBSCAN vigentes. Calc\u00falalos en el paso 04."))
    build_prompt(input$prompt_key %||% "inicio", rv$prepared$question, evidence(), input$extra_context %||% "")
  })
  output$prompt_help <- renderUI({ entry <- prompt_catalog()[[input$prompt_key %||% "inicio"]]; hint(entry$task) })
  output$prompt_text <- renderText(prompt_ready())
  observeEvent(input$copy_prompt, {
    p <- tryCatch(prompt_ready(), error = function(e) NULL)
    if (is.null(p)) showNotification("Prepara los resultados necesarios para este prompt.", type = "warning")
    else session$sendCustomMessage("copyPrompt", p)
  })
  output$template <- downloadHandler(filename = "practica_bibliometria.csv", content = function(file) file.copy(app_extdata("practica.csv"), file))
  output$download_bank <- downloadHandler(filename = "banco_prompts_bibliometria_v5.md", content = function(file) write_prompt_bank(file))
  output$download_prompt <- downloadHandler(filename = function() paste0("prompt_", input$prompt_key, ".txt"),
    content = function(file) writeLines(enc2utf8(prompt_ready()), file, useBytes = TRUE))
  output$download_report <- downloadHandler(filename = "informe_bibliometria_v5.html", contentType = "text/html",
    content = function(file) { p <- current(); writeLines(enc2utf8(report_html(p, rv$corpus, rv$bib, lda_current(), ca_current(), density_export_current(), network_current(), comparison_current(), pca_current(),subgraph_current())), file, useBytes = TRUE) })
  output$download_zip <- downloadHandler(filename = "resultados_bibliometria_v5.zip", contentType = "application/zip", content = function(file) {
    p <- current(); lda <- lda_current(); ca <- ca_current(); density <- density_export_current(); network <- network_current(); comparison <- comparison_current(); pca <- pca_current();subgraph<-subgraph_current()
    dir <- tempfile("bibliometria_")
    on.exit(unlink(dir, recursive = TRUE))
    prompt <- tryCatch(prompt_ready(), error = function(e) NULL)
    export_corpus<-rv$corpus;export_corpus$term_view<-list(metric=input$token_rank_metric %||% "frecuencia",status=input$token_rank_status %||% "all",n=input$token_rank_n %||% 12,compare_states=TRUE,tfidf_metric=token_display_metric(),terms=token_view()$termino);export_corpus$gram_view<-list(n=as.integer(input$gram_order %||% 2),indicador=input$gram_metric %||% "documentos",presencia_minima=input$gram_min_df %||% 1)
    export_corpus$pca_view<-list(axes=pca_axes());export_corpus$lda_time_view<-list(spline=isTRUE(input$lda_time_spline),metodo="Interpolaci\u00f3n Hermite c\u00fabica por tramos / tangentes cero / sin extrapolaci\u00f3n ni relleno de huecos")
    export_corpus$lda_document_view<-if(!is.null(lda))list(ids=lda_display_documents()$doc_id,criterio=if(identical(input$lda_document_mode,"selected"))"Selecci\u00f3n expl\u00edcita por ID, t\u00edtulo o DOI" else "P\u00e1gina / orden de la tabla del modelo") else NULL
    export_bundle(dir, p, export_corpus, rv$bib, lda, ca, prompt, density = density, raw = rv$raw, network = network, comparison = comparison, pca = pca,subgraph=subgraph,reader=wiki_export_current(),
      lda_selection = kselect_current(), density_sens = dsens_current())
    graphs <- list()
    if (!is.null(comparison)) {
      graphs$jsd_shifts <- jsd_graph(); graphs$jsd_acumulada <- jsd_cumulative_graph(); graphs$jsd_matriz <- jsd_matrix_graph()
      if (nrow(comparison$temporal)) graphs$jsd_evolucion <- jsd_time_graph()
    }
    if (!is.null(pca)) { graphs$acp_documentos <- pca_documents_graph(); graphs$acp_variables <- pca_terms_graph(); graphs$acp_varianza <- pca_variance_graph() }
    if (!is.null(ca)) graphs$ca_inercia <- ca_variance_graph()
    if (!is.null(network)) graphs$red <- network_graph()
    if(!is.null(subgraph)) graphs$subgrafo<-make_network_graph(subgraph)
    if(nrow(token_view())) graphs$terminos_comparacion<-token_bars_graph()
    if (nrow(rv$bib$annual)) graphs$evolucion_anual <- annual_graph()
    if (nrow(rv$bib$sources)) graphs$fuentes <- sources_graph()
    if (nrow(rv$corpus$terms)) graphs$palabras <- terms_graph()
    if (nrow(gram_data())) graphs$ngramas <- bigrams_graph()
    if (!is.null(lda)) graphs$temas_lda <- lda_graph()
    if (!is.null(ca)) graphs$mapa_ca <- ca_graph()
    if (!is.null(lda)) graphs$composicion_lda <- lda_heatmap_graph()
    if(!is.null(lda) && nrow(lda_yearly(lda,p))) graphs$lda_prevalencia_anual<-lda_time_graph()
    if (nrow(rv$bib$authors)) graphs$autores <- authors_graph()
    if (nrow(rv$bib$keywords)) graphs$keywords <- keywords_graph()
    if (any(!is.na(rv$prepared$documents$citations))) graphs$citas <- citations_graph()
    if (nrow(rv$corpus$terms)) graphs$seleccion_vocabulario <- token_graph()
    if (!is.null(density)) {
      graphs$umap_hdbscan <- density_graph()
      if (any(density$assignments$grupo > 0)) graphs$membresias <- density_membership_graph()
      if (nrow(density$terms)) graphs$grupos_c_tfidf <- density_terms_graph()
      if (nrow(density$similarity)) graphs$similitud_grupos <- density_similarity_graph()
      if (nrow(density$temporal)) {graphs$evolucion_grupos<-density_stacked_graph();graphs$grupos_proporciones<-density_temporal_figure(density);if(!is.null(density$temporal_spline)) graphs$grupos_spline<-density_temporal_figure(density,"spline",density$temporal_spline)}
    }
    for (nm in names(graphs)) ggplot2::ggsave(file.path(dir, paste0(nm, ".png")), plot = graphs[[nm]], width = 11, height = if (nm == "temas_lda") max(6, ceiling(lda$params$k / 2) * 2.8) else 7, dpi = 180, bg = "white")
    for (nm in names(graphs)) ggplot2::ggsave(file.path(dir,paste0(nm,".pdf")),plot=graphs[[nm]],width=11,
      height=if(nm=="temas_lda") max(6,ceiling(lda$params$k/2)*2.8) else 7,
      device=if(capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf,bg="white")
    write_bundle_manifest(dir)
    zip::zipr(file, files = list.files(dir, full.names = TRUE), include_directories = TRUE)
  })
  transitions <- c(to_prepare = "prepare", to_explore = "explore", to_models = "models", to_export = "export")
  for (id in names(transitions)) local({ key <- id; target <- transitions[[id]]
    observeEvent(input[[key]], {
      if (target == "prepare" && is.null(rv$raw)) { showNotification("Carga un CSV o usa el ejemplo de pr\u00e1ctica.", type = "warning"); return() }
      if (target != "prepare" && (is.null(rv$prepared) || stale())) { showNotification("Pulsa \u00abPreparar corpus\u00bb antes de continuar.", type = "warning"); return() }
      updateTabsetPanel(session, "steps", selected = target)
    })
  })
  source_app_module("extensions.R", environment())
  source_app_module("wiki.R", environment())
  source_app_module("v5_guidance.R", environment())
}
