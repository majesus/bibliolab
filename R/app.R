# Punto de entrada de la aplicacion Shiny y utilidades de rutas del paquete.

#' Lanza la aplicacion Bibliolab
#'
#' Abre la interfaz guiada (Shiny) para importar un corpus bibliografico,
#' prepararlo, explorar indicadores, ejecutar modelos exploratorios y exportar
#' una entrega reproducible. Todo el calculo es local: no se envian datos a
#' servicios externos.
#'
#' @details La aplicacion escucha exclusivamente en `127.0.0.1` (el propio
#' equipo), incluso si la opcion global `shiny.host` indica otra direccion.
#' No necesita aceptar conexiones entrantes desde otros equipos. Las descargas
#' de modelos de idioma se realizan por una accion explicita del usuario.
#' Antes de abrir, comprueba y carga los paquetes de todos los analisis. Si
#' faltan paquetes de analisis, intenta instalarlos desde CRAN en una biblioteca
#' del usuario (binarios en Windows). Si no completa la preparacion, no abre
#' una interfaz con tecnicas pendientes. Esta comprobacion solo se ejecuta al
#' llamar a `run_app()`, nunca al cargar el paquete.
#'
#' @param launch.browser Si se abre el navegador al iniciar. Por defecto, en
#'   sesiones interactivas.
#' @param port Puerto TCP; `NULL` deja que Shiny elija uno libre.
#' @param model_dir Carpeta donde se guardan los modelos UDPipe descargados
#'   (opcional). Por defecto `tools::R_user_dir("bibliolab", "data")`.
#' @param max_upload_mb Tamano maximo de archivo importado, en megabytes
#'   (entre 1 y 500; 100 por defecto).
#'
#' @return Se invoca por su efecto; devuelve `invisible(NULL)` al cerrar la app.
#' @examples
#' if (interactive()) {
#'   run_app()
#' }
#' @export
run_app <- function(launch.browser = interactive(), port = NULL, model_dir = NULL, max_upload_mb = 100) {
  app_prepare_dependencies()
  for (pkg in c("DT", "plotly", "visNetwork"))
    if (!requireNamespace(pkg, quietly = TRUE))
      stop("Falta el paquete '", pkg, "'. Instalalo con install.packages(\"", pkg, "\").", call. = FALSE)
  if (!is.numeric(max_upload_mb) || length(max_upload_mb) != 1L || !is.finite(max_upload_mb) || max_upload_mb < 1 || max_upload_mb > 500)
    stop("max_upload_mb debe estar entre 1 y 500.", call. = FALSE)
  shiny::addResourcePath("assets_bibliolab", app_file("www"))
  opts <- list(shiny.maxRequestSize = max_upload_mb * 1024^2, bibliolab.max_upload_bytes = max_upload_mb * 1024^2, shiny.sanitize.errors = TRUE)
  if (!is.null(model_dir)) opts[["bibliolab.model_dir"]] <- normalizePath(model_dir, winslash = "/", mustWork = FALSE)
  old <- options(opts)
  on.exit(options(old), add = TRUE)
  app <- shiny::shinyApp(build_ui(), app_server)
  shiny::runApp(app, launch.browser = launch.browser, host = "127.0.0.1", port = if (is.null(port)) getOption("shiny.port") else port)
  invisible(NULL)
}

# Rutas dentro de inst/app (instalado: app/)
app_file <- function(...) {
  path <- system.file("app", ..., package = "bibliolab")
  if (!nzchar(path)) stop("No se encuentra el recurso de la aplicacion: ", paste(c(...), collapse = "/"), call. = FALSE)
  path
}
app_extdata <- function(...) {
  path <- system.file("extdata", ..., package = "bibliolab")
  if (!nzchar(path)) stop("No se encuentra el archivo de ejemplo: ", paste(c(...), collapse = "/"), call. = FALSE)
  path
}

# Componentes de interfaz compartidos
panel <- function(title, ..., class = "") tags$section(class = paste("panel-card", class), tags$h2(title), ...)
hint <- function(...) tags$p(class = "hint", ...)
empty_help <- function(text) tags$div(class = "empty-help", text)
btn_next <- function(id, label) actionButton(id, label, class = "btn-next next-step")

# El codigo de sesion pertenece a la misma carga del namespace. Nunca se relee
# un modulo modificado en disco para combinarlo con funciones antiguas en RAM.
.app_modules <- new.env(parent = emptyenv())
.onLoad <- function(libname, pkgname) {
  directory <- system.file("app", "server", package = pkgname)
  files <- list.files(directory, pattern = "[.]R$", full.names = TRUE)
  for (file in files) .app_modules[[basename(file)]] <- parse(file, encoding = "UTF-8")
  .app_modules$version <- BIBLIO_VERSION
}
source_app_module <- function(name, envir) {
  code <- .app_modules[[name]]
  if (is.null(code)) abort_user(paste("No est\u00e1 disponible el m\u00f3dulo", name, ". Cierra la aplicaci\u00f3n y abre ABRIR_V5.cmd para cargar una distribuci\u00f3n completa."))
  eval(code, envir = envir)
}
table_view <- function(id) DT::DTOutput(id)
