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
  fit <- lda_select_k(rv$corpus, k_range = seq.int(s$k_min, s$k_max), seeds = s$base_seed + seq_len(s$seeds) - 1L,
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
output$kselect_use <- renderUI({
  f <- kselect_current(); if (is.null(f)) return(NULL)
  ks <- f$params$k_range; sel <- f$recommendation$compromise; if (!is.finite(sel)) sel <- ks[1]
  tags$div(class = "row control-row",
    column(5, selectInput("kselect_choice", "Número de temas que quieres probar", ks, selected = sel)),
    column(7, actionButton("use_k", "Fijar este k y volver a calcular LDA", class = "btn-primary"),
      hint("Se actualiza el número de temas de arriba; pulsa Calcular LDA para ajustar el modelo final.")))
})
observeEvent(input$use_k, { req(input$kselect_choice); updateNumericInput(session, "k", value = as.integer(input$kselect_choice)) })
observeEvent(input$help_kselect, showModal(modalDialog(title = "Elegir el número de temas / leer la comparación", size = "l", easyClose = TRUE,
  tags$div(class = "lesson",
    tags$p(class = "modal-lead", "La comparación ajusta cada k varias veces (semillas distintas) y resume cuatro aspectos. Ninguno decide por sí solo: sirven para reducir el rango y, después, leer los temas."),
    tags$section(class = "lesson-section", tags$h3("Qué mide cada criterio"),
      tags$p(tags$strong("Coherencia NPMI: "), "si las palabras principales de un tema tienden a aparecer en los mismos documentos. Mayor es mejor. Se calcula con los propios documentos, así que orienta pero no reemplaza a un juicio humano."),
      tags$p(tags$strong("Diversidad: "), "proporción de palabras principales distintas entre temas. Si baja, los temas se repiten entre sí."),
      tags$p(tags$strong("Estabilidad: "), "cuánto coinciden los temas entre semillas (solapamiento de palabras principales con emparejamiento óptimo). Baja estabilidad indica que el modelo no encuentra una estructura firme con ese k."),
      tags$p(tags$strong("Perplejidad reservada: "), "qué tan bien predice documentos que no usó. Suele mejorar al aumentar k y no equivale a interpretabilidad (Chang et al., 2009); por eso no entra en el valor de compromiso.")),
    tags$section(class = "lesson-example", tags$h3("El valor de compromiso"),
      tags$p("Es el k que maximiza el peor de los tres criterios (coherencia, estabilidad, diversidad) tras reescalarlos entre 0 y 1. Evita que uno solo domine, pero es un resumen: dos valores cercanos son prácticamente equivalentes.")),
    tags$section(class = "lesson-section", tags$h3("Cómo decidir"),
      tags$p("Elige dos o tres valores candidatos, ajusta cada uno, lee los documentos más representativos y quédate con el que permita etiquetas defendibles y no mezcle ideas distintas. Documenta el rango comparado, los criterios y por qué elegiste ese k: el informe metodológico lo registra."))),
  footer = modalButton("Cerrar"))))

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
  d <- f$diagnostics$topics; names(d) <- c("Tema", "Prevalencia (%)", "Coherencia UMass", "Coherencia NPMI", "Palabras principales"); d })
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
observeEvent(input$help_stability, showModal(modalDialog(title = "Estabilidad de la agrupación / cómo interpretarla", size = "l", easyClose = TRUE,
  tags$div(class = "lesson",
    tags$p(class = "modal-lead", "UMAP incluye azar y HDBSCAN depende de minPts: dos ejecuciones razonables pueden dar agrupaciones distintas. Medirlo evita presentar como hallazgo lo que es una de varias soluciones posibles."),
    tags$section(class = "lesson-section", tags$h3("Qué es el ARI"),
      tags$p("El índice de Rand ajustado compara dos agrupaciones del mismo conjunto de documentos: 1 significa que coinciden; 0, lo esperable entre asignaciones al azar. Aquí el grupo «sin asignar» cuenta como una clase más. La columna «solo asignados» ignora los documentos sin grupo en alguna de las dos."),
      tags$p("Una convención orientativa (Steinley, 2004) habla de acuerdo excelente por encima de 0,90, bueno desde 0,80 y moderado desde 0,65. No es un contraste de hipótesis.")),
    tags$section(class = "lesson-example", tags$h3("Persistencia de cada grupo"),
      tags$p("Para cada grupo de la referencia se busca, en cada otra semilla, el grupo que más documentos comparte y se calcula el solapamiento (Jaccard). Un grupo con Jaccard medio alto reaparece; uno con valores bajos es probablemente un artefacto de esa semilla.")),
    tags$section(class = "lesson-section", tags$h3("Qué hacer con el resultado"),
      tags$p("Si la estabilidad es baja, prueba otra representación (BM25), más vecinos o un minPts mayor, o informa solo los grupos persistentes. Documenta las repeticiones: el informe metodológico las incluye."))),
  footer = modalButton("Cerrar"))))

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
    network = network_current(), comparison = comparison_current(), lda_selection = kselect_current(), density_sensitivity = dsens_current())
}
output$download_methods <- downloadHandler(filename = "informe_metodologico_bibliolab.html", contentType = "text/html",
  content = function(file) writeLines(enc2utf8(methods_report_html(methods_text())), file, useBytes = TRUE))
output$download_methods_md <- downloadHandler(filename = "informe_metodologico_bibliolab.md", contentType = "text/markdown",
  content = function(file) writeLines(enc2utf8(methods_text()), file, useBytes = TRUE))
