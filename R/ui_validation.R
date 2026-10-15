# Componentes de interfaz de la decision asistida y validacion (V4).

lda_advanced_ui <- function() tags$details(class = "visible-disclosure",
  tags$summary("Opciones avanzadas \u00b7 prior de mezcla por documento (alpha)"),
  selectInput("lda_alpha_mode", "Prior alpha de los temas por documento",
    c("Disperso \u00b7 1/k (primera soluci\u00f3n; contrasta sensibilidad)" = "sparse", "Moderado \u00b7 5/k" = "moderate", "Est\u00e1ndar de topicmodels \u00b7 50/k (mezclas muy suavizadas)" = "standard")),
  hint("Alpha peque\u00f1o permite que un documento se concentre en pocos temas; alpha grande lo empuja hacia una mezcla casi uniforme. Con textos cortos, 50/k hace que las proporciones por documento dependan m\u00e1s del prior que de las palabras. Esta app usa 1/k por defecto y registra el valor."))

lda_k_panel <- function() panel("Elegir el n\u00famero de temas con apoyo",
  tags$p("No existe un n\u00famero de temas \u00abcorrecto\u00bb. Esta herramienta ajusta varias soluciones con varias semillas y las compara con criterios que a veces se contradicen: coherencia de las palabras, diversidad, estabilidad entre semillas y perplejidad en documentos reservados. T\u00fa decides leyendo los temas."),
  actionButton("help_kselect", "C\u00f3mo leer esta comparaci\u00f3n", class = "btn-quiet"),
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
  tags$p("Un mapa es una sola ejecuci\u00f3n. Aqu\u00ed se repite el flujo con otras semillas y con otros vecinos/minPts, y se mide cu\u00e1nto cambian las asignaciones (\u00edndice de Rand ajustado, ARI). Los grupos que persisten merecen m\u00e1s confianza."),
  actionButton("help_stability", "C\u00f3mo interpretar la estabilidad", class = "btn-quiet"),
  actionButton("run_dsens", "Evaluar estabilidad y sensibilidad", class = "btn-primary run-analysis"),
  uiOutput("dsens_state"),uiOutput("dsens_results"))
