# Decision asistida y validacion (V4). Modulo de sesion: no cambia modelos existentes;
# aporta comparaciones, diagnosticos y el informe metodologico.

# ---- Seleccion asistida de k (LDA) ----------------------------------------
kselect_settings <- reactive(list(k_min = as.integer(input$kselect_min %||% 2L), k_max = as.integer(input$kselect_max %||% 8L),
  seeds = as.integer(input$kselect_seeds %||% 3L), iterations = as.numeric(input$iterations %||% 500),
  alpha_mode = input$lda_alpha_mode %||% "sparse", base_seed = as.integer(input$lda_seed %||% 2026L),
  units = if (!is.null(rv$corpus$counts)) nrow(rv$corpus$counts) else 0L, terms = if (!is.null(rv$corpus$counts)) ncol(rv$corpus$counts) else 0L,
  corpus = if (!is.null(rv$corpus)) corpus_fingerprint(rv$corpus) else ""))
kselect_current <- reactive({ current(); if (is.null(rv$kselect) || !identical(rv$kselect_signature, kselect_settings())) return(NULL); rv$kselect })
observeEvent(input$run_kselect, task("Comparando soluciones LDA con varias semillas…", {
  if (is.null(rv$prepared) || stale()) abort_user("Prepara un corpus vigente antes de comparar soluciones.")
  s <- kselect_settings()
  if (is.na(s$k_min) || is.na(s$k_max) || s$k_min >= s$k_max) abort_user("El rango de temas necesita al menos dos valores: elige un máximo mayor que el mínimo.")
  rv$kselect <- NULL; rv$kselect_signature <- NULL
  alpha_rule <- switch(s$alpha_mode, moderate = function(k) 5 / k, standard = function(k) 50 / k, NULL)
  fit <- lda_select_k(rv$corpus, k_range = seq.int(s$k_min, s$k_max), seeds = derive_seed(s$base_seed, seq_len(s$seeds) - 1L),
    iterations = s$iterations, alpha = alpha_rule,
    progress = function(i, total) setProgress(value = .1 + .85 * i / total, detail = sprintf("Ajuste %d de %d", i, total)))
  rv$kselect <- fit; rv$kselect_signature <- s
  showNotification("Comparación terminada. Contrasta los criterios y lee los temas de las soluciones candidatas.", type = "message", duration = 8)
}))
output$kselect_state <- renderUI({
  f <- kselect_current()
  if (is.null(f)) return(empty_help(if (is.null(rv$kselect)) "Elige el rango de k y pulsa Comparar soluciones. Con corpus grandes puede tardar un par de minutos." else "Cambió el corpus, el rango o los parámetros: vuelve a comparar."))
  r <- f$recommendation
  tagList(tags$p(class = "chart-caption", r$text),
    tags$p(class = "hint", sprintf("%d soluciones ajustadas (%d valores de k × %d semillas); %d unidades de %d documentos y %d términos; %d documentos (%d unidades) reservados para la perplejidad.",
      nrow(f$runs), length(f$params$k_range), length(f$params$seeds), f$params$units, f$params$documents %||% f$params$units, f$params$terms, f$params$holdout_documents %||% f$params$holdout_units, f$params$holdout_units)),
    tags$p(class = "hint", "Alcance: la reserva se hace por documento, pero el vocabulario y los filtros se aprendieron antes con el corpus completo, y la coherencia se calcula con todos los documentos. Es un diagn\u00f3stico interno condicionado al vocabulario, no una validaci\u00f3n externa de todo el flujo."),
    DT::DTOutput("kselect_best"))
})
output$kselect_best <- table_render(function() { f <- kselect_current(); validate(need(!is.null(f), "Compara soluciones para ver los mejores valores."))
  d <- f$recommendation$summary; names(d) <- c("Criterio", "k con mejor valor", "Valor"); d })
output$kselect_plot <- renderPlot({
  f <- kselect_current(); validate(need(!is.null(f), "Compara soluciones para ver la figura."))
  t <- f$table
  long <- rbind(
    data.frame(k = t$k, valor = t$coherencia_npmi, de = t$coherencia_npmi_de, criterio = "Coherencia NPMI (mayor es mejor)"),
    data.frame(k = t$k, valor = t$diversidad, de = NA_real_, criterio = "Diversidad de palabras (mayor es mejor)"),
    data.frame(k = t$k, valor = t$estabilidad, de = NA_real_, criterio = "Estabilidad entre semillas (mayor es mejor)"),
    data.frame(k = t$k, valor = t$perplejidad, de = t$perplejidad_de, criterio = "Perplejidad reservada (menor es mejor)"))
  long <- long[is.finite(long$valor), , drop = FALSE]
  g <- ggplot2::ggplot(long, ggplot2::aes(k, valor)) + ggplot2::geom_line(colour = "#245579", linewidth = .7) + ggplot2::geom_point(colour = "#c7281e", size = 2.4) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = valor - de, ymax = valor + de), width = .15, colour = "#777777", na.rm = TRUE) +
    ggplot2::facet_wrap(~criterio, scales = "free_y", ncol = 2) + ggplot2::scale_x_continuous(breaks = t$k) +
    ggplot2::labs(x = "Número de temas (k)", y = NULL, title = "Comparación de soluciones LDA",
      subtitle = "Media entre semillas; barras = desviación típica. Los criterios pueden discrepar: ninguno decide por sí solo.") + swiss_theme()
  if (is.finite(f$recommendation$compromise)) g <- g + ggplot2::geom_vline(xintercept = f$recommendation$compromise, linetype = "dashed", colour = "#333333")
  g
}, height = function() 560, res = 96)
output$kselect_table <- table_render(function() { f <- kselect_current(); validate(need(!is.null(f), "Compara soluciones para ver la tabla."))
  d <- f$table; d$puntuacion_compromiso <- f$recommendation$scores$puntuacion_compromiso[match(d$k, f$recommendation$scores$k)]
  d <- d[c("k", "coherencia_npmi", "coherencia_umass", "diversidad", "estabilidad", "perplejidad", "tema_minimo_pct", "puntuacion_compromiso")]
  names(d) <- c("Temas (k)", "Coherencia NPMI", "Coherencia UMass", "Diversidad", "Estabilidad", "Perplejidad", "Tema menos prevalente (%)", "Compromiso (maximin 0-1)"); d })
output$kselect_use <- renderUI(model_parameter_guidance({
  f <- kselect_current(); if (is.null(f)) return(NULL)
  ks <- f$params$k_range; sel <- f$recommendation$compromise; if (!is.finite(sel)) sel <- ks[1]
  tags$div(class = "row control-row",
    column(5, selectInput("kselect_choice", "Número de temas que quieres probar", ks, selected = sel)),
    column(7, actionButton("use_k", "Usar este k en el modelo LDA", class = "btn-primary"),
      hint("Se actualiza el número de temas de arriba; pulsa Calcular LDA para ajustar el modelo final.")))
}))
observeEvent(input$use_k, {
  req(input$kselect_choice); updateNumericInput(session, "k", value = as.integer(input$kselect_choice))
  showNotification(paste0("Se ha asignado k = ", input$kselect_choice, " al control de temas. El modelo final todav\u00eda no est\u00e1 calculado: pulsa Calcular LDA."), type = "message", duration = 8)
})
observeEvent(input$help_kselect, open_help("kselect"))

# ---- Calidad del LDA ajustado -------------------------------------------------
output$lda_quality_state <- renderUI({
  f <- lda_current()
  if (is.null(f)) return(empty_help("Calcula LDA para ver sus indicadores de calidad."))
  conv <- f$diagnostics$convergence
  tagList(tags$p(class = "chart-caption", sprintf("k = %d, alpha = %s, delta = %s, %d estados guardados; se muestra el de mayor verosimilitud.", f$params$k, format(f$params$alpha, digits = 3), format(f$params$delta, digits = 3), f$params$saved_states %||% NA)),
    if (isTRUE(conv$converged)) hint("La log-verosimilitud no muestra deriva apreciable entre mitades según el criterio heurístico del 1 %. Esto no demuestra convergencia; contrasta más iteraciones y otras semillas.")
    else if (isFALSE(conv$converged)) tags$p(class = "quality-notes", "La log-verosimilitud sigue cambiando: aumenta las iteraciones antes de interpretar los temas.")
    else hint("Con tan pocos estados guardados no se puede evaluar la convergencia; aumenta las iteraciones."))
})
output$lda_diagnostics_table <- table_render(function() { f <- lda_current(); validate(need(!is.null(f), "Calcula LDA con parámetros vigentes."))
  d <- f$diagnostics$overview; names(d) <- c("Indicador", "Valor"); d })
output$lda_topic_quality <- table_render(function() { f <- lda_current(); validate(need(!is.null(f), "Calcula LDA con parámetros vigentes."))
  d <- f$diagnostics$topics; names(d) <- c("Tema", "Prevalencia documental (%)", "Coherencia UMass", "Coherencia NPMI", "Palabras principales", "Pares NPMI informativos"); d })
output$lda_quality_reading<-table_render(function(){f<-lda_current();validate(need(!is.null(f),"Calcula LDA para interpretar sus indicadores."));d<-lda_quality_reading(f);names(d)<-c("Aspecto","Cómo leer esta ejecución","Qué comprobar después");d})
output$lda_quality_results<-renderUI({if(is.null(lda_current()))return(NULL)
  tagList(tags$section(class="lda-quality-block",DT::DTOutput("lda_diagnostics_table")),
    tags$section(class="lda-quality-block",tags$h3("Lectura orientativa de esta ejecución / qué comprobar después"),DT::DTOutput("lda_quality_reading")),
    tags$section(class="lda-quality-block",tags$h3("Calidad por tema"),DT::DTOutput("lda_topic_quality")))})

# ---- Estabilidad y sensibilidad de UMAP + HDBSCAN ----------------------------
dsens_current <- reactive({ f <- density_current(); if (is.null(f) || is.null(rv$dsens) || !identical(rv$dsens_signature, density_settings())) return(NULL); rv$dsens })
observeEvent(input$run_dsens, task("Repitiendo UMAP + HDBSCAN con otras semillas y parámetros…", {
  f <- density_current()
  if (is.null(f)) abort_user("Calcula primero UMAP + HDBSCAN con los parámetros actuales.")
  rv$dsens <- NULL; rv$dsens_signature <- NULL
  s <- density_settings()
  fit <- density_sensitivity(rv$corpus, rv$prepared, f$params, vectors = f$input_vectors, embedding_model = s$model,
    progress = function(i, total) setProgress(value = .1 + .85 * i / total, detail = sprintf("Ejecución %d de %d", i, total)))
  rv$dsens <- fit; rv$dsens_signature <- s
  showNotification("Evaluación terminada. Revisa el ARI y la persistencia de cada grupo.", type = "message", duration = 8)
}))
output$dsens_state <- renderUI({
  f <- dsens_current()
  if (is.null(f)) return(empty_help(if (is.null(rv$dsens)) "Calcula UMAP + HDBSCAN y pulsa Evaluar para saber si los grupos son reproducibles. Con muchos documentos puede tardar." else "Cambió la ejecución de referencia: vuelve a evaluar."))
  tags$p(class = "chart-caption", f$reading)
})
output$dsens_results<-renderUI({if(is.null(dsens_current()))return(NULL)
  tagList(DT::DTOutput("dsens_summary"),tags$section(class="stability-groups",tags$h3("Persistencia de cada grupo"),DT::DTOutput("dsens_clusters")),tags$details(class="visible-disclosure",tags$summary("Todas las repeticiones"),DT::DTOutput("dsens_runs")))})
output$dsens_summary <- table_render(function() { f <- dsens_current(); validate(need(!is.null(f), "Evalúa la estabilidad para ver el resumen."))
  d <- f$summary; names(d) <- c("Indicador", "Valor"); d })
output$dsens_clusters <- table_render(function() { f <- dsens_current(); validate(need(!is.null(f), "Evalúa la estabilidad para ver los grupos."))
  d <- f$cluster_stability; names(d) <- c("Grupo", "Documentos", "Jaccard medio", "Jaccard mínimo"); d })
output$dsens_runs <- table_render(function() { f <- dsens_current(); validate(need(!is.null(f), "Evalúa la estabilidad para ver las repeticiones."))
  d <- f$runs; names(d) <- c("Tipo", "Semilla", "Vecinos", "minPts", "Grupos", "Sin asignar (%)", "ARI con la referencia", "ARI solo asignados", "Estado", "Causa"); d })
observeEvent(input$help_stability, open_help("stability"))

# ---- Diagnostico de vocabulario -------------------------------------------------
vocab_diag <- reactive({ p <- current(); vocabulary_diagnostics(rv$corpus, p) })
observeEvent(input$vocab_diagnostics, {
  if (is.null(rv$prepared) || stale()) { showNotification("Prepara un corpus vigente para diagnosticar su vocabulario.", type = "warning"); return() }
  showModal(modalDialog(title = "Diagnóstico de vocabulario", size = "l", easyClose = TRUE,
    tags$p(class = "modal-lead", "Antes de modelar, comprueba qué vocabulario se está reteniendo. Esta pantalla no cambia nada: te ayuda a decidir umbrales y palabras vacías propias del corpus."),
    tags$h3("Cómo cambia el vocabulario al exigir más documentos"),
    hint("Cada fila repite la selección real del corpus con esa presencia mínima y el resto de tus criterios (frecuencia, TF-IDF, entropía, presencia máxima y máximo de términos): la fila marcada coincide con el vocabulario retenido. Subir la presencia mínima elimina términos raros (a menudo erratas o nombres propios) pero también vocabulario específico; mira cuántos tokens se conservan."),
    DT::DTOutput("vocab_sensitivity"),
    tags$h3("Términos presentes en muchos documentos"),
    hint("Los términos muy extendidos describen el campo pero separan poco unos documentos de otros. Los marcados como genéricos académicos son candidatos a palabras vacías propias del corpus; la decisión es tuya."),
    DT::DTOutput("vocab_generic"),
    uiOutput("vocab_apply"),
    tags$h3("Cobertura de vocabulario por documento"), DT::DTOutput("vocab_coverage"),
    footer = modalButton("Cerrar")))
})
output$vocab_sensitivity <- table_render(function() { d <- vocab_diag()$sensitivity; names(d) <- c("Presencia mínima (documentos)", "Términos retenidos", "Términos retenidos (%)", "Tokens conservados (%)", "Términos que solo cumplen la presencia", "Valor actual"); d })
output$vocab_generic <- table_render(function() { d <- vocab_diag()$generic; names(d) <- c("Término", "Documentos", "Documentos (%)", "Apariciones", "TF-IDF medio", "Retenido", "Genérico académico"); d })
output$vocab_coverage <- table_render(function() { v <- vocab_diag(); d <- rbind(v$coverage, v$boilerplate); names(d) <- c("Indicador", "Valor"); d })
output$vocab_apply <- renderUI({ s <- vocab_diag()$suggestion
  if (!length(s)) return(hint("No hay términos genéricos académicos con presencia alta en este corpus."))
  tags$div(tags$p(paste("Sugerencia:", paste(s, collapse = ", "))), actionButton("apply_vocab_suggestion", "Añadir estas palabras a la lista de excluidas", class = "btn-primary"),
    hint("Se añaden al campo «Excluir otras palabras». Después pulsa Preparar corpus y compara los resultados con y sin ellas."))
})
observeEvent(input$apply_vocab_suggestion, {
  s <- vocab_diag()$suggestion
  current_stop <- trimws(strsplit(input$custom_stop %||% "", ",", fixed = TRUE)[[1]])
  updateTextInput(session, "custom_stop", value = paste(unique(c(current_stop[nzchar(current_stop)], s)), collapse = ", "))
  removeModal()
  showNotification("Palabras añadidas. Pulsa Preparar corpus para aplicarlas.", type = "message")
})

# ---- Informe metodologico ---------------------------------------------------------
methods_text <- function() {
  p <- current()
  methods_report(p, rv$corpus, rv$bib, lda = lda_current(), ca = ca_current(), pca = pca_current(), density = density_export_current(),
    network = network_current(), comparison = comparison_current(), lda_selection = kselect_current(), density_sensitivity = dsens_current(), thematic = thematic_current())
}
output$download_methods <- downloadHandler(filename = "informe_metodologico_bibliolab.html", contentType = "text/html",
  content = function(file) writeLines(enc2utf8(methods_report_html(methods_text())), file, useBytes = TRUE))
output$download_methods_md <- downloadHandler(filename = "informe_metodologico_bibliolab.md", contentType = "text/markdown",
  content = function(file) writeLines(enc2utf8(methods_text()), file, useBytes = TRUE))
