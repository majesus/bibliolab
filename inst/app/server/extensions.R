# Módulo de sesión; fuera de R/ para evitar la carga automática global de Shiny.
density_settings <- reactive(list(params = list(representation = input$density_rep %||% "lexical",
  lsa_dims = input$lsa_dims %||% 30L, neighbors = input$umap_neighbors %||% 10L,
  cluster_dims = input$umap_dims %||% 5L, min_dist = input$umap_min_dist %||% 0,
  min_pts = input$hdb_min_pts %||% 5L, seed = input$density_seed %||% 2026L,
  epochs = as.numeric(input$umap_epochs %||% 300), weighting=input$density_weighting %||% "tfidf", bm25_k1=input$density_k1 %||% 1.2, bm25_b=input$density_b %||% .75),
  file = if (identical(input$density_rep, "vectors")) input$vectors_file$datapath %||% "" else "",
  id = if (identical(input$density_rep, "vectors")) input$vector_id %||% "doc_id" else "",
  model = if (identical(input$density_rep, "vectors")) input$embedding_model %||% "" else "",
  vectors_md5 = if (identical(input$density_rep, "vectors") && nzchar(input$vectors_file$datapath %||% "") && file.exists(input$vectors_file$datapath)) unname(tools::md5sum(input$vectors_file$datapath)) else "",
  corpus = if (!is.null(rv$corpus)) corpus_fingerprint(rv$corpus) else ""))
density_current <- reactive({ current(); if (is.null(rv$density) || !identical(rv$density_signature, density_settings())) return(NULL); rv$density })
observeEvent(input$run_density, task("Representando documentos y calculando UMAP / HDBSCAN…", {
  if (is.null(rv$prepared) || stale()) abort_user("Prepara un corpus vigente antes de calcular UMAP y HDBSCAN.")
  s <- density_settings(); vectors <- NULL
  rv$density <- NULL; rv$density_signature <- NULL
  if (s$params$representation == "vectors") {
    if (!nzchar(s$file)) abort_user("Selecciona el CSV de vectores antes de ejecutar esta ruta.")
    vectors <- read_document_vectors(s$file, rv$prepared, s$id)
  }
  fit <- run_density(rv$corpus, rv$prepared, s$params, vectors, s$model)
  rv$density <- fit; rv$density_signature <- s
  showNotification(paste("Análisis completado:", sum(fit$summary$grupo > 0), "grupos;", sum(fit$assignments$grupo == 0), "documentos sin asignar."), type = "message", duration = 7)
}))
output$density_state <- renderUI({ current(); fit <- density_current()
  if (is.null(fit)) return(empty_help(if (is.null(rv$density)) "Calcula el flujo para representar documentos." else "Parámetros o vectores modificados. Vuelve a calcular."))
  tagList(tags$strong(paste(nrow(fit$assignments), "documentos /", sum(fit$summary$grupo > 0), "grupos /", sum(fit$assignments$grupo == 0), "sin asignar")),
    hint(fit$representation$type), tags$details(tags$summary("Cobertura y reservas de interpretación"), tags$ul(lapply(fit$issues, tags$li))))
})
output$export_ready <- renderText(if (!is.null(rv$prepared) && !stale()) "yes" else "no")
outputOptions(output, "export_ready", suspendWhenHidden = FALSE)

source_app_module("inspector.R", environment())
source_app_module("languages.R", environment())
output$processing_results<-table_render(function(){current();d<-rv$corpus$processing;names<-c(language="Estimación de idiomas",lexical="Segmentación y limpieza",annotate="Lemas y categorías",normalize="Normalización lingüística");d$etapa<-unname(names[d$etapa]);d})

# Ayudas por paso y por método.
open_help <- function(key) {
  h <- help_catalog()[[key]]; lesson <- enrich_lesson(key,c(lesson_catalog(), extra_lesson_catalog())[[key]])
  if (is.null(h)) h <- list(title = lesson$title %||% "Redes / relaciones e indicadores", goal = lesson$goal %||% "Definir conexiones y entender sus indicadores.", sources = lesson$sources %||% c("igraph / centralidades" = "https://r.igraph.org/reference/harmonic_centrality.html"))
  showModal(modalDialog(title = h$title, size = "l", easyClose = TRUE,
    tags$div(class = "lesson", tags$p(class = "modal-lead", lesson$goal %||% h$goal), narrative_ui(key, open = TRUE),
      if(key=="tokens") tags$section(class="lesson-example",tags$h3("Media, mediana, percentiles y dispersión"),vocabulary_decision_text()),
      if(key=="bm25") tags$section(class="lesson-example",tags$h3("Una primera decisión que puedes contrastar"),tags$p("Con resúmenes de longitud similar, empieza con TF-IDF. Si los textos tienen longitudes muy distintas o repiten mucho una palabra, compara BM25. Reduce el aporte de cada repetición adicional mediante el parámetro de repeticiones (k1) y ajusta el peso por longitud mediante el parámetro de longitud (b). Por ejemplo, cinco menciones no equivalen a cinco veces el peso de una mención. La app usa estos pesos para representar vocabulario; comprueba qué cambia leyendo textos y comparando estabilidad."),tags$p("En selección de vocabulario cambia el orden de términos; LDA y correspondencias usan conteos. En UMAP + LSA cambia la representación del modelo. Guarda ambas ejecuciones y compara sus resultados.")),
      if(key=="bradford") tags$section(class="lesson-example",tags$h3("Leer el porcentaje acumulado"),tags$p("De 100 documentos con fuente conocida, la revista más frecuente tiene 30 y la segunda 20. En la posición 1 la curva marca 30 %; en la 2, 50 %. Si otros 10 documentos no tienen fuente, no entran en ese denominador. El gráfico muestra concentración de la búsqueda. Las zonas de Bradford se calculan en la pestaña Leyes bibliométricas; ninguna de las dos vistas prueba la ley ni mide la calidad de las revistas.")),
      tags$section(class = "lesson-section", tags$p(class = "eyebrow", "01 / COMPRENDER"), tags$h3("Qué estás haciendo y para qué sirve"), lapply(lesson$meaning,tags$p)),
      tags$section(class = "lesson-example", tags$p(class = "eyebrow", "02 / EJEMPLO ILUSTRATIVO"), tags$h3("Un caso para entenderlo"), lapply(lesson$example,tags$p),if(!is.null(lesson$worked)) HTML(html_table(lesson$worked,show_note=FALSE))),
      tags$section(class = "lesson-section", tags$h3("Del resultado a una interpretación"), lapply(lesson$reading,tags$p)),
      tags$section(class = "lesson-section", tags$p(class = "eyebrow", "03 / DECIDIR"), tags$h3("Cómo continuar con tu corpus"), lapply(lesson$action,tags$p)),
      tags$section(class = "lesson-example", tags$h3("Cómo explicarlo en tu trabajo"), lapply(lesson$reporting,tags$p)),
      if(!is.null(lesson$study)) tags$details(class="visible-disclosure",tags$summary("Para estudiar el cálculo y sus límites"),lapply(lesson$study,tags$p)),
      if (!is.null(lesson$decisions)) tags$div(class = "lesson-table", HTML(sub("<p class='muted'>[^<]*</p>", "", html_table(lesson$decisions)))),
      if (!is.null(h$limits)) tags$details(tags$summary("Ampliación metodológica y límites"), lapply(h$steps, tags$p), tags$p(h$limits)),
      if (length(h$sources)) tags$div(class = "source-links", tags$h3("Documentación para ampliar"), lapply(names(h$sources), function(label) tags$p(tags$a(href = h$sources[[label]], target = "_blank", rel = "noopener", label))))),
    footer = modalButton("Volver al análisis")))
}
helps <- c(help_load = "load", help_prepare = "prepare", help_explore = "explore", help_models = "models", help_export = "export",
  help_lemma = "lemma", help_tokens = "tokens", help_tokens_explore = "tokens", help_density = "density", help_lda = "lda", help_ca = "ca", help_network = "networks", help_jsd = "jsd", help_pca = "pca", help_bm25="bm25",help_bm25_density="bm25",help_seed="seed",help_ngrams="ngrams",help_network_roles="roles",help_skills="skills",help_references="references",help_subgraphs="subgraphs",help_temporal="temporal",help_topic_labels="topic_labels",help_lda_time="lda_time",help_bradford="bradford",help_bradford_law="bradford",help_lotka="lotka",help_zipf="zipf",help_coverage="coverage",help_parallel="parallel")
for (id in names(helps)) local({ button <- id; key <- helps[[id]]; observeEvent(input[[button]], open_help(key)) })
for (key in c("load", "prepare", "explore", "models", "export")) local({ stage <- key
  observeEvent(input[[paste0("code_", stage)]], {
    rv$code_stage <- stage
    showModal(modalDialog(title = paste("Código R /", help_catalog()[[stage]]$title), size = "l", easyClose = TRUE,
      hint(if (!is.null(rv$prepared) && stale()) "Hay cambios pendientes: se muestran los parámetros de la última preparación, no de una ejecución nueva." else "Definiciones reales de las funciones utilizadas y parámetros de la última ejecución. El script de reproducción se descarga en Entrega."),
      tabsetPanel(tabPanel("Análisis y parámetros", tags$pre(class = "code-view", textOutput("code_text", inline = TRUE))),
        tabPanel("Gráficos y modales", hint("Archivo R real del módulo compartido de gráficos y modales."), tags$pre(class = "code-view", textOutput("plot_code_text", inline = TRUE)))),
      footer = modalButton("Cerrar código")))
  })
})
output$code_text <- renderText(stage_code(rv$code_stage, rv$prepared,
  if (!is.null(rv$prepared) && !stale()) lda_current() else NULL,
  if (!is.null(rv$prepared) && !stale()) ca_current() else NULL,
  if (!is.null(rv$prepared) && !stale()) density_current() else NULL,
  if (!is.null(rv$prepared) && !stale()) network_current() else NULL,
  if (!is.null(rv$prepared) && !stale()) comparison_current() else NULL,
  if (!is.null(rv$prepared) && !stale()) pca_current() else NULL))
output$plot_code_text <- renderText({
  paths <- c(app_file("server", "extensions.R"), list.files(app_file("server"), pattern = "[.]R$", full.names = TRUE))
  paths <- unique(paths)
  paste(vapply(paths, function(path) paste(c(paste("# ARCHIVO:", basename(path)), readLines(path, encoding = "UTF-8", warn = FALSE)), collapse = "\n"), ""), collapse = "\n\n")
})
observeEvent(input$model_manager, {
  showModal(modalDialog(title = "Modelos locales / UDPipe", size = "l", easyClose = TRUE,
    tags$p(class="modal-lead","Cada idioma necesita su propio modelo de UDPipe. La aplicación propone los modelos correspondientes a los idiomas asignados: combina los casos aceptados de CLD2, las etiquetas del archivo y tus correcciones. Antes de preparar el corpus, resuelve los textos que aún no tienen un idioma compatible."),
    tags$p("Por ejemplo, si tu corpus reúne resúmenes españoles e ingleses, necesitas ambos modelos. Descargar solo español no prepara los textos ingleses. Pulsa Descargar todos los modelos necesarios para obtener los que faltan; si ya están guardados, la app los reutiliza. El selector individual sirve para preparar otro idioma de forma anticipada, no para cambiar la lengua de tus documentos."),
    tags$p(class="hint",model_license_notice()),
    uiOutput("models_needed"),actionButton("download_required_models","Descargar todos los modelos necesarios",class="btn-primary run-analysis"),
    hint(paste("Descarga una vez cada idioma que utilices. No se transmiten textos. Carpeta configurada:",model_directory(),". Se reutilizan los modelos existentes y cada ejecución registra su MD5.")),
    selectInput("model_language", "Idioma a preparar", language_choices(), selected = if ((input$lemma_language %||% "es") %in% names(language_models())) input$lemma_language %||% "es" else "es"),
    actionButton("download_model", "Descargar modelo oficial", class = "btn-primary run-analysis"), uiOutput("model_inventory"), footer = modalButton("Cerrar")))
})
observeEvent(input$download_model, task("Descargando y verificando modelo de idioma…", {
  file <- download_language_model(input$model_language)
  rv$models_revision <- rv$models_revision + 1L
  showNotification(paste("Modelo preparado:", basename(file)), type = "message", duration = 8)
}))
output$model_inventory <- renderUI({
  rv$models_revision
  langs<-required_languages();all<-names(language_models())
  HTML(html_table(data.frame(Idioma=unname(language_labels()[all]),Necesario=ifelse(all %in% langs,"Sí / según la asignación actual","No para esta selección"),Estado=vapply(all,function(x){f<-model_file(x);if(is.null(f)) "Pendiente de descargar" else if(!model_usable(f)) "Modelo local dañado: vuelve a descargarlo" else "Modelo local disponible"},""))))
})

output$models_needed<-renderUI({langs<-required_languages();tags$p(class="chart-caption",if(length(langs)) paste("Necesitas:",paste(language_labels()[langs],collapse=", "),". El botón descarga solo los que aún no están preparados.") else "No se han identificado idiomas. Abre Asignar o revisar idiomas en Normalización antes de descargar.")})

# Gráficos adicionales. Unidades y denominadores quedan visibles.
authors_graph <- reactive({ current(); metric<-input$authors_order %||% "documentos";d<-rank_slice(rv$bib$authors,input$authors_n %||% 25,input$authors_page %||% 1,metric)$data
  d<-d[is.finite(d[[metric]]),,drop=FALSE];bar_graph(d,"elemento",metric,"Autores / corpus observado",switch(metric,documentos="Documentos",h_corpus="Índice h del corpus",citas_suma="Citas válidas / suma")) })
keywords_graph <- reactive({ p<-current();validate(need(nrow(rv$bib$keywords)>0,keyword_availability(p)));bar_graph(rank_slice(rv$bib$keywords,input$keywords_n %||% 25,input$keywords_page %||% 1)$data, "elemento", "documentos", "Keywords / presencia en el corpus", "Documentos") })
citations_graph <- reactive({ p <- current(); c <- p$documents$citations; c <- c[!is.na(c)]
  validate(need(length(c), "No hay citas válidas. Asigna una columna con enteros sin separadores de miles."))
  d <- data.frame(citas = sort(c, decreasing = TRUE), rango = seq_along(c))
  ggplot2::ggplot(d, ggplot2::aes(rango, citas)) + ggplot2::geom_segment(ggplot2::aes(xend = rango, yend = 0), colour = "#bcbcbc") +
    ggplot2::geom_point(colour = "#d52b1e", size = 2) + ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "#333333") +
    ggplot2::labs(x = "Rango del documento · de más a menos citas", y = "Citas registradas", title = "Distribución e índice h del corpus", subtitle = "La línea discontinua muestra citas = rango; las ausencias se excluyen") + plot_theme()
})
token_graph <- reactive({ current(); d <- rv$corpus$terms
  validate(need(nrow(d)>0, "No quedan términos tras la limpieza."))
  labels <- head(d[order(-d$tfidf_medio, d$termino), ], 6)
  d$estado <- ifelse(d$incluido, "Retenido", "Excluido")
  g <- ggplot2::ggplot(d, ggplot2::aes(porcentaje_documentos, tfidf_medio)) +
    ggplot2::geom_point(ggplot2::aes(size = frecuencia, colour = estado), alpha = .7) +
    ggplot2::scale_colour_manual(values = c(Retenido = "#d52b1e", Excluido = "#999999")) +
    ggplot2::scale_size_area(max_size = 9) + ggplot2::labs(x = "Presencia en documentos (%)", y = "TF-IDF medio por unidad",
      title = "Presencia y especificidad de términos", colour = NULL, size = "Apariciones") + plot_theme()
  g + label_layer(labels, ggplot2::aes(label = termino), size = 3, seed = 2026, repel = list(max.overlaps = 20))
})
lda_display_documents<-reactive({f<-lda_current();validate(need(!is.null(f),"Calcula LDA para consultar documentos."));lda_document_rows(f,if(identical(input$lda_document_mode,"selected"))input$lda_documents %||% character() else NULL,input$lda_document_page %||% 1L,input$lda_document_page_size %||% 18L)})
output$lda_document_controls<-renderUI({f<-lda_current();if(is.null(f))return(NULL);choices<-lda_document_labels(f,rv$prepared);selected<-isolate(input$lda_documents %||% head(unname(choices),1))
  session$onFlushed(function()updateSelectizeInput(session,"lda_documents",choices=choices,selected=intersect(selected,unname(choices)),server=TRUE),once=TRUE)
  tagList(radioButtons("lda_document_mode","Qué documentos quieres consultar",c("Recorrer páginas / orden de la tabla"="page","Buscar y seleccionar por ID, título o DOI"="selected"),selected=isolate(input$lda_document_mode %||% "page"),inline=TRUE),
    conditionalPanel("input.lda_document_mode === 'page'",fluidRow(column(6,numericInput("lda_document_page","Página",1,1,max(1,ceiling(nrow(f$document_topics)/18)))),column(6,numericInput("lda_document_page_size","Documentos por página",18,1,100))),hint("El orden es el de la tabla del modelo. No es aleatorio ni representa importancia.")),
    conditionalPanel("input.lda_document_mode === 'selected'",selectizeInput("lda_documents","Documentos / escribe parte del título, DOI o ID",choices=NULL,multiple=TRUE,options=modifyList(predictive_options(),list(maxItems=100)))))})
lda_heatmap_graph<-reactive({f<-lda_current();validate(need(!is.null(f),"Calcula LDA para consultar la composición de documentos."));d<-lda_display_documents();validate(need(nrow(d)>0,"Selecciona al menos un documento."));lda_composition_figure(f,rv$prepared,d)})
observeEvent(list(lda_current(),input$lda_document_page_size),{f<-lda_current();if(is.null(f))return();pages<-max(1,ceiling(nrow(f$document_topics)/(input$lda_document_page_size %||% 18L)));updateNumericInput(session,"lda_document_page",max=pages,value=min(input$lda_document_page %||% 1L,pages))},ignoreInit=FALSE)
output$lda_document_composition<-table_render(function(){d<-lda_display_documents();p<-rv$prepared$documents[match(d$doc_id,rv$prepared$documents$doc_id),];cbind(data.frame(ID=d$doc_id,Titulo=p$title,DOI=p$doi),d[-1])})
density_graph <- reactive({ fit <- density_current(); validate(need(!is.null(fit), "Calcula UMAP y HDBSCAN con los parámetros actuales."))
  d <- density_display(fit); colours <- density_palette(d$plot_label)
  ggplot2::ggplot(d, ggplot2::aes(umap_1, umap_2, colour = plot_label)) + ggplot2::geom_point(size = 2.5, alpha = .8) +
    ggplot2::scale_colour_manual(values = colours) + ggplot2::coord_equal() +
    ggplot2::labs(x = "UMAP 1 · vista 2D", y = "UMAP 2 · vista 2D", colour = NULL, title = "Documentos por grupo",
      subtitle = paste("Agrupación en", fit$params$cluster_dims, "dimensiones · vista independiente")) + plot_theme()
})
density_terms_graph <- reactive({ fit <- density_current(); validate(need(!is.null(fit), "Calcula el flujo de densidad."))
  d <- fit$terms[fit$terms$posicion <= 6, ]; validate(need(nrow(d)>0, "No se detectaron grupos; no hay vocabulario temático que representar."))
  # Mostrar hasta 12 grupos para mantener legibilidad; CSV conserva todos.
  shown <- head(sort(unique(d$grupo)), 12); d <- d[d$grupo %in% shown, ]; d$key <- paste(d$grupo, d$termino, sep = "::")
  d$key <- factor(d$key, levels = rev(d$key))
  ggplot2::ggplot(d, ggplot2::aes(c_tfidf, key,fill=factor(grupo))) + ggplot2::geom_col(width=.65,show.legend=FALSE) + ggplot2::scale_fill_manual(values=swiss_colours(length(shown))) +
    ggplot2::facet_wrap(~grupo, ncol = 3, scales = "free_y", labeller = ggplot2::label_both) +
    ggplot2::scale_y_discrete(labels = function(x) sub("^[0-9]+::", "", x)) + ggplot2::labs(x = "c-TF-IDF · especificidad por clase", y = NULL,
      title = "Vocabulario de grupos", subtitle = paste("Se muestran", length(shown), "grupos; consultar CSV completo")) + plot_theme()
})
density_similarity_graph <- reactive({ fit <- density_current(); validate(need(!is.null(fit) && nrow(fit$similarity), "La similitud requiere al menos dos grupos detectados."))
  shown <- head(sort(unique(fit$similarity$grupo_a)), 30); d <- fit$similarity[fit$similarity$grupo_a %in% shown & fit$similarity$grupo_b %in% shown, ]
  ggplot2::ggplot(d, ggplot2::aes(factor(grupo_a), factor(grupo_b), fill = similitud_coseno)) + ggplot2::geom_tile(colour = "white") +
    ggplot2::scale_fill_gradient(low = "#f5f5f5", high = "#d52b1e", limits = c(0, 1)) + ggplot2::coord_equal() +
    ggplot2::labs(x = "Grupo", y = "Grupo", fill = "Coseno", title = "Similitud lexical entre grupos", subtitle = "Representaciones c-TF-IDF · hasta 30 grupos") + plot_theme()
})
density_stacked_graph <- reactive({ fit <- density_current(); validate(need(!is.null(fit) && nrow(fit$temporal), "La evolución requiere asignaciones y años válidos."))
  d <- fit$temporal; shown <- head(fit$summary$grupo[order(-fit$summary$documentos)][fit$summary$grupo[order(-fit$summary$documentos)] > 0], 10)
  d$grupo_label <- ifelse(d$grupo == 0, "Sin asignar", ifelse(d$grupo %in% shown, paste("Grupo", d$grupo), "Otros grupos"))
  d <- stats::aggregate(d$documentos, list(ano = d$ano, grupo_label = d$grupo_label), sum); names(d)[3] <- "documentos"
  ggplot2::ggplot(d, ggplot2::aes(factor(ano), documentos, fill = grupo_label)) + ggplot2::geom_col(position = "stack", width = .65) +
    ggplot2::scale_fill_manual(values = density_palette(d$grupo_label)) + ggplot2::labs(x = "Año con registros", y = "Documentos asignados", fill = NULL, title = "Composición del corpus por año", subtitle = "Hasta 10 grupos principales; los restantes se agregan en Otros grupos") + plot_theme() + ggplot2::theme(axis.text.x=ggplot2::element_text(angle=60,hjust=1,size=9))
})
output$authors_plot <- renderPlot(authors_graph(),height=function() max(420,35*nrow(rank_slice(rv$bib$authors %||% data.frame(),input$authors_n %||% 25,input$authors_page %||% 1)$data)+110), res = 96)
output$keywords_plot <- renderPlot(keywords_graph(),height=function() max(420,35*nrow(rank_slice(rv$bib$keywords %||% data.frame(),input$keywords_n %||% 25,input$keywords_page %||% 1)$data)+110), res = 96)
output$citations_plot <- renderPlot(citations_graph(), res = 96)
output$token_plot <- renderPlot(token_graph(), res = 96)
output$lda_heatmap <- renderPlot(lda_heatmap_graph(), height = function() { if(is.null(lda_current()))540 else max(420,nrow(lda_display_documents())*29+170) }, res = 96)
output$density_plot <- renderPlot(density_graph(), res = 96)
output$density_terms_plot <- renderPlot(density_terms_graph(), height = function() { f <- density_current(); if (is.null(f)) 480 else max(480,ceiling(min(12,length(unique(f$terms$grupo)))/3)*230+80) }, res = 96)
output$density_similarity_plot <- renderPlot(density_similarity_graph(), height = function() { f <- density_current(); if(is.null(f)) 480 else max(480,min(30,length(unique(f$similarity$grupo_a)))*23+120) }, res = 96)
output$density_time_plot <- renderPlot(density_time_graph(), res = 96)
if (requireNamespace("plotly", quietly = TRUE)) {
  output$density_interactive <- plotly::renderPlotly({
    fit <- density_current(); validate(need(!is.null(fit), "Calcula UMAP y HDBSCAN para explorar documentos."))
    d <- density_display(fit); colours <- density_palette(d$plot_label)
    d$hover <- paste0(escape_html(d$doc_id), "<br>", escape_html(substr(d$title, 1, 180)), "<br>", d$grupo_label,
      "<br>Membresía: ", sprintf("%.3f", d$membresia))
    chart <- plotly::plot_ly(source = "density_map")
    for (label in names(colours)) chart <- plotly::add_trace(chart, data = d[d$plot_label == label, ],
      x = ~umap_1, y = ~umap_2, type = "scatter", mode = "markers", name = label,
      customdata = ~doc_id, text = ~hover, hoverinfo = "text", marker = list(color = colours[[label]], size = 8, opacity = .85))
    chart <- plotly::layout(chart, paper_bgcolor = "white", plot_bgcolor = "white", font = list(family = "Arial, Helvetica, sans-serif", size = 14, color = "#161616"),
      xaxis = list(tickangle=90,title = list(text="UMAP 1 / vista independiente",standoff=24),automargin=TRUE, zeroline = FALSE), yaxis = list(tickangle=0,title = "UMAP 2 · vista independiente", zeroline = FALSE, scaleanchor = "x"),
      legend = list(orientation="v",x=1.03,y=1),margin=list(l=85,r=175,t=25,b=85))
    plotly::event_register(plotly::config(chart, displaylogo = FALSE, modeBarButtonsToRemove = c("select2d", "lasso2d")), "plotly_click")
  })
  observeEvent(input[["plotly_click-density_map"]], {
    event <- plotly::event_data("plotly_click", source = "density_map")
    req(event$customdata); p <- current(); d <- p$documents[p$documents$doc_id == event$customdata[1], ]; req(nrow(d) == 1)
    showModal(modalDialog(title = paste(d$doc_id, "·", d$title), tags$p(d$text), size = "l", easyClose = TRUE, footer = modalButton("Cerrar lectura")))
  }, ignoreInit = TRUE)
}

# Tablas bajo demanda y figuras ampliadas. No se repite el dataset en la página.
result_choices <- function(key) switch(key,
  jsd = c("Aportaciones de palabras" = "jsd_terms", "Valores completos para reproducir (R)" = "jsd_full", "Valor global y distancia" = "jsd_summary", "Cobertura de categorías" = "jsd_coverage", "Matriz JSD completa" = "jsd_matrix", "Evolución por años" = "jsd_temporal", "Auditoría de comparación" = "jsd_audit", "Documentos de A y B" = "jsd_documents"),
  pca = c("Coordenadas de documentos" = "pca_documents", "Variables / correlaciones y cargas" = "pca_terms", "Varianza por componente" = "pca_dimensions", "Variables sin variación" = "pca_excluded"),
  tokens = c("Vocabulario evaluado · retenidos y excluidos" = "tokens"),
  audit = c("Flujo de registros" = "audit", "Cobertura y avisos" = "issues", "Duplicados detectados" = "duplicates", "Filtros del vocabulario" = "filters"),
  citations = c("Indicadores" = "overview", "Ranking de documentos" = "cited"),
  lda = c("Palabras beta" = "lda_terms", "Proporciones medias" = "lda_prevalence"),
  ca = c("Coordenadas, contribuciones y cos²" = "ca_terms", "Inercia por eje" = "ca_dimensions"),
  density = c("Grupos y cobertura" = "density_summary", "Asignaciones por documento" = "density_assignments"),
  law_lotka = c("Cifras del ajuste" = "law_lotka_resumen", "Autores por número de trabajos" = "law_lotka_tabla"),
  law_bradford = c("Cifras del ajuste" = "law_bradford_resumen", "Zonas de Bradford" = "law_bradford_zonas", "Revistas ordenadas y acumulado" = "law_bradford_tabla"),
  law_zipf = c("Cifras del ajuste" = "law_zipf_resumen", "Palabras por rango" = "law_zipf_tabla"),
  setNames(key, key))
open_result_table <- function(key) {
  if (is.null(rv$prepared) || stale()) { showNotification("Prepara un corpus vigente para consultar resultados.", type = "warning"); return() }
  rv$table_key <- key; choices <- result_choices(key)
  showModal(modalDialog(title = "Tabla de resultados", size = "l", easyClose = TRUE,
    tags$p(class="modal-lead", "Esta tabla permite comprobar las cifras que hay detrás del gráfico. El selector cambia el resultado consultado; los filtros actúan sobre esta lectura. Para interpretarla, distingue el conjunto de documentos que aporta datos y la medida que estás comparando."),
    selectInput("result_detail", "Resultado", choices, selected = unname(choices[1])),
    if (key %in% c("jsd","pca")) tags$p(class="chart-caption",figure_explanation(key)),
    hint("Valores de pantalla redondeados; precisión completa en CSV. Si hay ID de documento, selecciona su fila para leer el original."),
    if (key == "tokens") tagList(fluidRow(column(5, textInput("term_search", "Buscar término o motivo · admite búsqueda sin acentos", "")),
      column(3, selectInput("term_status", "Estado", c("Todos" = "all", "Retenidos" = "kept", "Excluidos" = "excluded"))),
      column(4, selectInput("term_reason", "Motivo de exclusión", c("Todos los motivos" = "all", setNames(term_reasons(rv$corpus$terms), term_reasons(rv$corpus$terms)))))),
      uiOutput("term_count")),
    if(key %in% c("lda","lda_examples")) {fit<-lda_current();if(!is.null(fit)) selectInput("result_topic","Filtrar por tema LDA",c("Todos los temas"="all",setNames(as.character(seq_len(fit$params$k)),paste("Tema",seq_len(fit$params$k)))),selected="all")},
    DT::DTOutput("result_table"), uiOutput("result_reading"), footer = modalButton("Cerrar tabla")))
}
term_reasons <- function(d) sort(unique(unlist(strsplit(d$motivo_exclusion[!d$incluido & nzchar(d$motivo_exclusion)], "; ", fixed = TRUE))))
term_query <- debounce(reactive(input$term_search %||% ""), 250)
output$term_count <- renderUI({ req(rv$table_key == "tokens"); hint(paste(nrow(result_data()), if (nrow(result_data()) == 1) "término coincide de" else "términos coinciden de", nrow(rv$corpus$terms), "evaluados. La tabla se actualiza mientras escribes.")) })
result_data <- reactive({ current(); key <- input$result_detail %||% unname(result_choices(rv$table_key)[1])
  if (key %in% c("annual", "sources", "authors", "keywords", "cited", "overview")) return(rv$bib[[key]])
  if (key == "audit") return(rv$prepared$audit)
  if (key == "issues") return(data.frame(avisos = c(rv$prepared$issues, rv$corpus$issues)))
  if (key == "duplicates") return(rv$prepared$duplicates)
  if (key == "filters") return(rv$corpus$filter_audit)
  if (key == "tokens") { d <- filter_term_table(rv$corpus$terms, term_query(), input$term_status %||% "all", input$term_reason %||% "all"); d$tfidf_mean <- NULL; return(d) }  # tfidf_mean es un alias de compatibilidad de tfidf_medio: una sola columna a la vista
  if (startsWith(key, "jsd")) {
    f <- comparison_current(); validate(need(!is.null(f), "Calcula una comparación JSD vigente."))
    if (key == "jsd_summary") return(data.frame(indicador = c("JSD / bits base 2", "Distancia sqrt(JSD)"), valor = c(f$jsd, f$distancia)))
    if (key == "jsd_full") return(f$terms)
    if (key == "jsd_terms") {
      d <- f$terms; d$frecuencia_relativa_A_pct <- 100*d$proporcion_A; d$frecuencia_relativa_B_pct <- 100*d$proporcion_B
      return(d[c("termino","frecuencia_relativa_A_pct","frecuencia_relativa_B_pct","cambio_pp","aporte_bits","aporte_pct","direccion","aporte_acumulado_pct")])
    }
    return(f[[sub("^jsd_", "", key)]])
  }
  if (startsWith(key, "pca")) { f <- pca_current(); validate(need(!is.null(f), "Calcula un ACP vigente.")); part<-sub("^pca_", "", key);d<-if(part %in% c("documents","terms"))pca_plane(f,part,pca_axes()) else f[[part]];if(part %in% c("documents","terms")){a<-pca_axes();names(d)[names(d)=="eje_1"]<-paste("Coordenada componente",a[1]);names(d)[names(d)=="eje_2"]<-paste("Coordenada componente",a[2]);names(d)[names(d)=="contribucion_eje_1"]<-paste("Contribución componente",a[1],"(%)");names(d)[names(d)=="contribucion_eje_2"]<-paste("Contribución componente",a[2],"(%)")};return(d) }
  if (startsWith(key, "law_")) { t <- laws_tables(laws_current()); return(t[[sub("^law_", "ley_", key)]] %||% data.frame()) }
  if (key == "bigrams") return(gram_data())
  if (startsWith(key, "lda")) {
    fit <- lda_current(); validate(need(!is.null(fit), "Calcula LDA con parámetros vigentes."))
    d<-switch(key, lda_terms=fit$top,lda_prevalence=fit$prevalence,lda_examples=fit$examples)
    topic<-input$result_topic %||% "all";if(topic!="all" && "tema" %in% names(d)) d<-d[d$tema==as.integer(topic),,drop=FALSE]
    return(d)
  }
  if (startsWith(key, "ca")) {
    fit <- ca_current(); validate(need(!is.null(fit), "Calcula correspondencias con parámetros vigentes."))
    return(if (key == "ca_terms") fit$terms else fit$dimensions)
  }
  if (startsWith(key, "density")) {
    fit <- density_current(); validate(need(!is.null(fit), "Calcula UMAP y HDBSCAN con parámetros vigentes."))
    return(switch(key, density_summary = fit$summary, density_assignments = fit$assignments,
      density_terms = fit$terms, density_examples = fit$examples))
  }
  data.frame()
})
output$result_table <- table_render(result_data, selection = "single", searching = reactive(rv$table_key != "tokens"))
output$result_reading <- renderUI({
  rows <- input$result_table_rows_selected; req(length(rows) == 1); d <- result_data(); req("doc_id" %in% names(d), rows[1] <= nrow(d))
  p <- current(); doc <- p$documents[p$documents$doc_id == d$doc_id[rows[1]], ]; req(nrow(doc) == 1)
  tags$article(class = "document-reading", tags$h3(paste(doc$doc_id, "·", doc$title)), tags$p(doc$text))
})
tables <- c("audit", "annual", "sources", "authors", "citations", "tokens", "bigrams", "keywords", "lda", "lda_examples", "ca", "density", "density_terms", "density_examples", "jsd", "pca", "law_lotka", "law_bradford", "law_zipf")
for (key in tables) local({ k <- key; observeEvent(input[[paste0("table_", k)]], open_result_table(k)) })
observeEvent(input$table_tokens_prepare, open_result_table("tokens"))
source_app_module("networks.R", environment())
source_app_module("laws.R", environment())
source_app_module("interactive.R", environment())
source_app_module("comparisons.R", environment())
source_app_module("pedagogy.R", environment())
source_app_module("subgraphs.R", environment())
source_app_module("temporal.R", environment())
source_app_module("validation.R", environment())
figure_functions <- list(jsd = jsd_graph, jsd_cumulative = jsd_cumulative_graph, jsd_matrix = jsd_matrix_graph, jsd_time = jsd_time_graph,
  pca_documents = pca_documents_graph, pca_terms = pca_terms_graph, pca_variance = pca_variance_graph, ca_variance = ca_variance_graph,annual = annual_graph, sources = sources_graph, authors = authors_graph,
  citations = citations_graph, tokens = token_bars_graph, bigrams = bigrams_graph, keywords = keywords_graph,
  lda = lda_graph, lda_heatmap = lda_heatmap_graph, ca = ca_graph, density = density_graph,
  density_terms = density_terms_graph, density_similarity = density_similarity_graph, density_time = density_time_graph, density_membership = density_membership_graph, network = network_graph,lda_time=lda_time_graph,law_lotka=law_lotka_graph,law_bradford=law_bradford_graph,law_zipf=law_zipf_graph)
for (key in names(figure_functions)) local({ k <- key; observeEvent(input[[paste0("expand_", k)]], {
  if (is.null(rv$prepared) || stale()) { showNotification("Prepara un corpus vigente antes de ampliar gráficos.", type = "warning"); return() }
  rv$figure_key <- k
  showModal(modalDialog(title = if(k=="ca") "Correspondencias / perfiles léxicos" else if(k %in% c("pca_documents","pca_terms"))"ACP / documentos y variables" else "Figura / vista ampliada", size = "l", easyClose = TRUE,
    if(!k %in% c("ca","pca_documents","pca_terms"))tags$p(class="chart-caption",if(k=="jsd" && !is.null(rv$comparison) && rv$comparison$jsd==0) "JSD = 0 bits. Las proporciones coinciden y no hay barras de aportación. Es un resultado válido, no un fallo de dibujo." else figure_explanation(k)),
    if(k %in% c("sources","authors","keywords","tokens")) tagList(hint(if(k=="tokens")"La vista conserva el estadístico, el estado y los rankings elegidos; desplázate para leer ambos estados completos." else "Esta vista conserva la página y el orden elegidos. Para explorar más registros, usa Registros que quieres explorar y Página del gráfico en la pantalla principal."),tags$div(class="rank-scroll",plotOutput("expanded_plot",height="auto")))
    else if(k %in% c("pca_documents","pca_terms")) {f<-pca_current();validate(need(!is.null(f),"Calcula ACP antes de ampliar."));expanded_ordination_ui(f,if(k=="pca_terms")"terms" else "documents",quadrant=input$pca_quadrant %||% "all")}
    else if(k=="ca") {f<-ca_current();validate(need(!is.null(f),"Calcula correspondencias antes de ampliar."));expanded_ordination_ui(f,"ca",focus=input$ca_focus %||% "")}
    else if(k=="lda_heatmap") {f<-lda_current();validate(need(!is.null(f),"Calcula LDA antes de ampliar."));choices<-lda_document_labels(f,rv$prepared);selected<-lda_display_documents()$doc_id;session$onFlushed(function()updateSelectizeInput(session,"expanded_lda_documents",choices=choices,selected=selected,server=TRUE),once=TRUE);tagList(selectizeInput("expanded_lda_documents","Elegir documentos / ID, título o DOI",choices=NULL,multiple=TRUE,options=modifyList(predictive_options(),list(maxItems=100))),hint("Puedes consultar hasta 100 documentos elegidos. No se restringe a los 18 iniciales; las proporciones proceden del mismo modelo."),tags$div(class="rank-scroll",plotOutput("expanded_lda_plot",height="auto")),DT::DTOutput("expanded_lda_table"))}
    else if(k=="network") visNetwork::visNetworkOutput("network_expanded",height="calc(96vh - 290px)") else plotOutput("expanded_plot",height="66vh"), footer = modalButton("Cerrar figura")))
}) })
output$expanded_plot <- renderPlot({if(identical(rv$figure_key,"pca_terms")){f<-pca_current();req(f);d<-ordination_quadrant(pca_plane(f,"terms",pca_axes()),input$expanded_pca_quadrant %||% "all");validate(need(nrow(d)>0,"No hay variables en este cuadrante."));return(ordination_figure(d,f$dimensions,"ACP / variables del cuadrante",circle=identical(input$expanded_pca_quadrant %||% "all","all"),max_labels=input$expanded_pca_labels %||% 24))};figure_functions[[rv$figure_key]]()},height=function(){k<-rv$figure_key;if(k=="tokens")return(max(480,nrow(token_view())*32+210));if(k %in% c("sources","authors","keywords")) return(max(480,35*nrow(rank_slice(rv$bib[[k]] %||% data.frame(),input[[paste0(k,"_n")]] %||% 25,input[[paste0(k,"_page")]] %||% 1)$data)+110));650},res = 110)
output$expanded_pca_table<-table_render(function(){f<-pca_current();req(f);d<-ordination_quadrant(pca_plane(f,"terms",pca_axes()),input$expanded_pca_quadrant %||% "all");d[order(-(d$contribucion_eje_1+d$contribucion_eje_2)),]})
output$pca_expanded<-plotly::renderPlotly({f<-pca_current();req(f);type<-input$expanded_pca_view %||% if(identical(rv$figure_key,"pca_terms"))"terms" else "documents";d<-pca_plane(f,type,pca_axes());if(type=="terms")d<-ordination_quadrant(d,input$expanded_pca_quadrant %||% "all");validate(need(nrow(d)>0,"No hay variables en este cuadrante."));ordination_widget(d,f$dimensions,label_field=if(type=="documents")"doc_id" else "termino",focus=input$expanded_pca_focus %||% "",circle=type=="terms"&&identical(input$expanded_pca_quadrant %||% "all","all"),max_labels=input$expanded_pca_labels %||% 40L,label_canvas=c(max(300,(session$clientData$output_pca_expanded_width %||% 1200)-170),max(250,(session$clientData$output_pca_expanded_height %||% 750)-115)))})
expanded_lda_rows<-reactive({f<-lda_current();req(f);lda_document_rows(f,input$expanded_lda_documents %||% character())})
output$expanded_lda_plot<-renderPlot({f<-lda_current();req(f);d<-expanded_lda_rows();validate(need(nrow(d)>0,"Selecciona al menos un documento por título, DOI o ID."));lda_composition_figure(f,rv$prepared,d)},height=function()max(420,nrow(expanded_lda_rows())*29+170),res=110)
output$expanded_lda_table<-table_render(function(){d<-expanded_lda_rows();p<-rv$prepared$documents[match(d$doc_id,rv$prepared$documents$doc_id),];cbind(data.frame(ID=d$doc_id,Titulo=p$title,DOI=p$doi),d[-1])})
observeEvent(input$preview_prompt, showModal(modalDialog(title = "Prompt / evidencia de la ejecución", size = "l", easyClose = TRUE,
  tags$pre(class = "code-view", textOutput("prompt_text", inline = TRUE)), footer = modalButton("Cerrar prompt"))))
output$download_code <- downloadHandler(filename = "reproducir_analisis.R", content = function(file) {
  p <- current(); writeLines(enc2utf8(reproduction_script(p, lda_current(), ca_current(), density_export_current(), network_current(), comparison_current(), pca_current(),subgraph_current())), file, useBytes = TRUE)
})
