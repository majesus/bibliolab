# Componentes de interfaz de la decision asistida y validacion (V4).

lda_advanced_ui <- function() tags$details(class = "visible-disclosure",
  tags$summary("Opciones avanzadas \u00b7 preferencia previa sobre la mezcla por unidad de texto (alpha)"),
  selectInput("lda_alpha_mode", "Preferencia previa de mezcla por unidad (alpha)",
    c("Disperso \u00b7 1/k (primera soluci\u00f3n; contrasta sensibilidad)" = "sparse", "Moderado \u00b7 5/k" = "moderate", "Est\u00e1ndar de topicmodels \u00b7 50/k (mezclas muy suavizadas)" = "standard")),
  hint("Alpha peque\u00f1o permite que un documento se concentre en pocos temas; alpha grande favorece una mezcla m\u00e1s repartida, sin imponer proporciones iguales. Con textos cortos, 50/k puede aumentar la influencia de la preferencia previa alpha sobre las proporciones por unidad. Esta app usa 1/k por defecto y registra el valor."))

lda_k_panel <- function() panel("Configurar el an\u00e1lisis / elegir el n\u00famero de temas",
  tags$p("Aqu\u00ed comparas soluciones de LDA con distinto n\u00famero de temas: por ejemplo, 2, 3 o 4 temas, cada una con varias semillas. No se comparan t\u00e9cnicas diferentes. La herramienta resume coherencia de las palabras, diversidad, estabilidad entre semillas y, cuando puede calcularse, perplejidad en textos reservados. Estos criterios pueden discrepar: decide leyendo los temas. Si ya tienes un n\u00famero de temas justificado, puedes pasar directamente al ajuste de LDA."),
  actionButton("help_kselect", "Gu\u00eda para comparar n\u00fameros de temas", class = "btn-quiet"),
  tags$div(class = "row control-row",
    column(3, numericInput("kselect_min", "Desde k =", 2, 2, 11)), column(3, numericInput("kselect_max", "Hasta k =", 8, 3, 12)),
    column(3, numericInput("kselect_seeds", "Semillas por k", 3, 1, 5)),
    column(3, actionButton("run_kselect", "Comparar soluciones", class = "btn-primary run-analysis"))),
  uiOutput("kselect_state"), plotOutput("kselect_plot", height = "auto"), DT::DTOutput("kselect_table"),
  uiOutput("kselect_use"))

lda_quality_ui <- function() panel("Calidad del modelo ajustado",
  tags$p("Indicadores de la ejecuci\u00f3n vigente. La coherencia usa la co-ocurrencia de palabras en estos mismos documentos: orienta, pero no sustituye la lectura de los temas."),
  uiOutput("lda_quality_state"),uiOutput("lda_quality_results"))

density_sensitivity_ui <- function() panel("\u00bfEs estable esta agrupaci\u00f3n?",
  tags$p("Un mapa es una sola ejecuci\u00f3n. Aqu\u00ed se repite el flujo con otras semillas y con otros vecinos/minPts, y se mide cu\u00e1nto cambian las asignaciones (\u00edndice de Rand ajustado, ARI). La persistencia comprueba que los mismos documentos siguen juntos en las repeticiones; no valida su interpretaci\u00f3n tem\u00e1tica."),
  actionButton("help_stability", "C\u00f3mo interpretar la estabilidad", class = "btn-quiet"),
  actionButton("run_dsens", "Evaluar estabilidad y sensibilidad", class = "btn-primary run-analysis"),
  uiOutput("dsens_state"),uiOutput("dsens_results"))
