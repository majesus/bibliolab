# Catalogo unico de paquetes opcionales: alimenta la comprobacion publica, la ayuda de la
# interfaz, el arranque de run_app() y los mensajes de error. Debe coincidir con
# `Config/bibliolab/App-Suggests` de DESCRIPTION (lo verifica una prueba).
dependency_catalog <- function() {
  data.frame(
    paquete = c("topicmodels", "slam", "udpipe", "cld2", "uwot", "dbscan", "irlba", "mgcv", "igraph", "readxl", "ggrepel"),
    habilita = c("LDA y seleccion de k", "LDA y seleccion de k", "Lematizacion y categorias gramaticales",
      "Estimacion automatica del idioma por documento", "UMAP", "HDBSCAN", "LSA para UMAP/HDBSCAN",
      "Spline temporal de grupos", "Redes, comunidades y subgrafos", "Importacion de libros Excel (.xls y .xlsx)",
      "Etiquetas sin solapamiento en graficos"),
    funciones = c("run_lda(), lda_select_k()", "run_lda(), lda_select_k()",
      "prepare_corpus() con lemas o categorias, download_language_model()", "Revision de idiomas de la aplicacion",
      "run_density(), density_sensitivity()", "run_density(), density_sensitivity()", "run_density()",
      "Spline temporal de run_density() en la aplicacion", "run_network(), extract_subgraph(), cuaderno de lectura",
      "read_biblio_file()", "Graficos de redes, mapas y cuaderno"),
    stringsAsFactors = FALSE)
}

#' Comprueba que paquetes opcionales estan disponibles
#'
#' Algunas funciones dependen de paquetes en `Suggests`. Esta funcion indica
#' cuales estan instalados y que parte de bibliolab queda deshabilitada si
#' faltan. No instala nada: la instalacion es decision del usuario.
#'
#' @return `data.frame` con `paquete`, `instalado`, `habilita`, `funciones`
#'   (funciones o pantallas afectadas) e `instruccion`.
#' @examples
#' biblio_check_dependencies()
#' @export
biblio_check_dependencies <- function() {
  d <- dependency_catalog()
  d$instalado <- vapply(d$paquete, requireNamespace, logical(1), quietly = TRUE)
  d$instruccion <- ifelse(d$instalado, "", paste0("install.packages('", d$paquete, "')"))
  d[c("paquete", "instalado", "habilita", "funciones", "instruccion")]
}

# Comprobacion del arranque de run_app(). Los paquetes de Imports son necesarios para abrir la
# interfaz; los opcionales solo deshabilitan su capacidad. Nunca instala nada sin una orden
# explicita (`install = TRUE`), una sesion interactiva y la confirmacion del usuario.
# Devuelve TRUE si todos los paquetes opcionales estan disponibles.
app_prepare_dependencies <- function(install = FALSE, installer = NULL, confirm = NULL) {
  meta <- utils::packageDescription("bibliolab")
  required <- unique(sub("[[:space:](].*$", "", trimws(strsplit(meta[["Imports"]], ",", fixed = TRUE)[[1]])))
  missing_required <- required[!vapply(required, requireNamespace, TRUE, quietly = TRUE)]
  if (length(missing_required))
    abort_user(paste0("Faltan paquetes necesarios para abrir bibliolab: ", paste(missing_required, collapse = ", "),
      ". Instalalos con install.packages(c(", paste0("'", missing_required, "'", collapse = ", "), ")) o reinstala bibliolab con sus dependencias."))
  d <- biblio_check_dependencies()
  pending <- d[!d$instalado, , drop = FALSE]
  if (!nrow(pending)) return(invisible(TRUE))
  detail <- paste0(pending$paquete, " (", pending$habilita, ")", collapse = "; ")
  if (!isTRUE(install)) {
    message("Capacidades deshabilitadas por paquetes opcionales ausentes: ", detail, ". Instalalos con install.packages(c(",
      paste0("'", pending$paquete, "'", collapse = ", "), ")); el resto de la aplicacion funciona sin ellos.")
    return(invisible(FALSE))
  }
  if (is.null(confirm)) {
    if (!interactive()) abort_user("La instalacion de paquetes necesita una sesion interactiva con confirmacion. Instalalos manualmente con install.packages().")
    confirm <- function(text) isTRUE(utils::askYesNo(text, default = FALSE))
  }
  configured <- strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep, fixed = TRUE)[[1]]
  library <- if (length(configured) && nzchar(configured[1])) path.expand(configured[1]) else file.path(path.expand("~"), "R", paste0("library-", getRversion()))
  if (!isTRUE(confirm(paste0("Se instalaran desde CRAN en ", library, ": ", paste(pending$paquete, collapse = ", "), ". Continuar?")))) {
    message("Instalacion cancelada. La aplicacion se abre con las capacidades disponibles.")
    return(invisible(FALSE))
  }
  if (!dir.exists(library) && !dir.create(library, recursive = TRUE)) abort_user(paste("No se puede crear la biblioteca de usuario:", library))
  if (file.access(library, 2) != 0) abort_user(paste("No se puede escribir en la biblioteca de usuario:", library))
  .libPaths(c(library, .libPaths()))
  installer <- installer %||% utils::install.packages
  installer(pending$paquete, lib = library, repos = "https://cloud.r-project.org", dependencies = NA,
    type = if (.Platform$OS.type == "windows") "binary" else getOption("pkgType"))
  still <- pending$paquete[!vapply(pending$paquete, requireNamespace, TRUE, quietly = TRUE)]
  if (length(still)) {
    message("No se pudieron instalar: ", paste(still, collapse = ", "), ". La aplicacion se abre con las capacidades disponibles.")
    return(invisible(FALSE))
  }
  invisible(TRUE)
}
