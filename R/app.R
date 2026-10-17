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
#' Antes de abrir, valida los argumentos y comprueba los paquetes. Los paquetes
#' de `Imports` son necesarios; los opcionales (consulta
#' [biblio_check_dependencies()]) solo deshabilitan su capacidad: si faltan, se
#' avisa de que tecnicas quedan fuera y la aplicacion se abre con el resto.
#' `run_app()` nunca instala paquetes por su cuenta. Con `install_missing = TRUE`,
#' en una sesion interactiva y tras una confirmacion explicita, instala los
#' opcionales ausentes desde CRAN en la biblioteca de usuario.
#'
#' @param launch.browser Si se abre el navegador al iniciar. Por defecto, en
#'   sesiones interactivas. Acepta `TRUE`/`FALSE` o una funcion `function(url)`.
#'   Con `TRUE` se usa el navegador predeterminado del sistema (en Windows,
#'   `shell.exec()`), sin depender de `options(browser)`, que a veces apunta a un
#'   programa inexistente en otro equipo.
#' @param port Puerto TCP; `NULL` deja que Shiny elija uno libre.
#' @param model_dir Carpeta donde se guardan los modelos UDPipe descargados
#'   (opcional). Por defecto `tools::R_user_dir("bibliolab", "data")`.
#' @param max_upload_mb Tamano maximo de archivo importado, en megabytes
#'   (entre 1 y 500; 100 por defecto).
#' @param install_missing Si `TRUE`, ofrece instalar los paquetes opcionales
#'   ausentes (solo en sesiones interactivas y con confirmacion). Por defecto
#'   `FALSE`: no se instala ni se modifica ninguna biblioteca.
#'
#' @return Se invoca por su efecto; devuelve `invisible(NULL)` al cerrar la app.
#' @examples
#' if (interactive()) {
#'   run_app()
#' }
#' @export
run_app <- function(launch.browser = interactive(), port = NULL, model_dir = NULL, max_upload_mb = 100, install_missing = FALSE) {
  if (!is.numeric(max_upload_mb) || length(max_upload_mb) != 1L || !is.finite(max_upload_mb) || max_upload_mb < 1 || max_upload_mb > 500)
    stop("max_upload_mb debe estar entre 1 y 500.", call. = FALSE)
  app_prepare_dependencies(install = isTRUE(install_missing))
  for (pkg in c("DT", "plotly", "visNetwork"))
    if (!requireNamespace(pkg, quietly = TRUE))
      stop("Falta el paquete '", pkg, "'. Instalalo con install.packages(\"", pkg, "\").", call. = FALSE)
  www <- app_file("www")
  faltan <- setdiff(c("style.css", "app.js"), list.files(www))
  if (length(faltan))
    warning("Faltan recursos de la interfaz (", paste(faltan, collapse = ", "), ") en ", www,
      ". La aplicacion se abrira sin su aspecto original: reinstale bibliolab desde una copia completa.", call. = FALSE)
  shiny::addResourcePath("assets_bibliolab", www)
  opts <- list(shiny.maxRequestSize = max_upload_mb * 1024^2, bibliolab.max_upload_bytes = max_upload_mb * 1024^2, shiny.sanitize.errors = TRUE)
  if (!is.null(model_dir)) opts[["bibliolab.model_dir"]] <- normalizePath(model_dir, winslash = "/", mustWork = FALSE)
  old <- options(opts)
  on.exit(options(old), add = TRUE)
  app <- shiny::shinyApp(build_ui(), app_server)
  opener <- if (isTRUE(launch.browser)) app_open_url else launch.browser
  shiny::runApp(app, launch.browser = opener, host = "127.0.0.1", port = if (is.null(port)) getOption("shiny.port") else port)
  invisible(NULL)
}

# Abre la direccion de la aplicacion en el navegador predeterminado del sistema.
# No usa options(browser): al compartir ~/.Rprofile entre equipos puede apuntar a
# un programa que no existe en este y shiny::runApp() no abriria nada.
app_open_url <- function(url) {
  message("bibliolab escucha en ", url, ". Si el navegador no se abre solo, copie esa direccion en su barra de direcciones.")
  sistema <- Sys.info()[["sysname"]]
  abierto <- tryCatch({
    if (identical(sistema, "Windows")) {
      shell_exec <- get0("shell.exec", envir = asNamespace("utils"), inherits = FALSE)
      if (is.function(shell_exec)) { shell_exec(url); TRUE } else FALSE
    } else if (identical(sistema, "Darwin")) {
      system2("open", shQuote(url), stdout = FALSE, stderr = FALSE) == 0L
    } else {
      system2("xdg-open", shQuote(url), stdout = FALSE, stderr = FALSE) == 0L
    }
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!isTRUE(abierto))
    abierto <- tryCatch({ utils::browseURL(url); TRUE }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!isTRUE(abierto)) message("No se pudo abrir el navegador automaticamente.")
  invisible(abierto)
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
  if (is.null(code)) abort_user(paste("No est\u00e1 disponible el m\u00f3dulo", name, ". Cierra la aplicaci\u00f3n y reinstala bibliolab desde una copia completa."))
  eval(code, envir = envir)
}
table_view <- function(id) DT::DTOutput(id)
