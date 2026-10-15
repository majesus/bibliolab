#' Comprueba que paquetes opcionales estan disponibles
#'
#' Algunas funciones dependen de paquetes en `Suggests`. Esta funcion indica
#' cuales estan instalados y que parte de bibliolab queda deshabilitada si
#' faltan. No instala nada: la instalacion es decision del usuario.
#'
#' @return `data.frame` con `paquete`, `instalado`, `habilita` e `instruccion`.
#' @examples
#' biblio_check_dependencies()
#' @export
biblio_check_dependencies <- function() {
  d <- data.frame(
    paquete = c("topicmodels", "slam", "udpipe", "cld2", "uwot", "dbscan", "irlba", "mgcv", "mclust"),
    habilita = c("LDA y seleccion de k", "LDA y seleccion de k", "Lematizacion y categorias gramaticales",
      "Estimacion automatica del idioma", "UMAP", "HDBSCAN", "LSA para UMAP/HDBSCAN", "Spline temporal de grupos", "ARI / estabilidad y sensibilidad de grupos y comunidades"),
    stringsAsFactors = FALSE)
  d$instalado <- vapply(d$paquete, requireNamespace, logical(1), quietly = TRUE)
  d$instruccion <- ifelse(d$instalado, "", paste0("install.packages('", d$paquete, "')"))
  d[c("paquete", "instalado", "habilita", "instruccion")]
}

# Comprobacion explicita de la aplicacion, tambien cuando run_app() se llama
# directamente. No se ejecuta al cargar/instalar el paquete ni desde .onLoad.
app_prepare_dependencies <- function(installer = NULL) {
  meta <- utils::packageDescription("bibliolab")
  specs <- c(trimws(strsplit(meta[["Imports"]],",",fixed=TRUE)[[1]]),trimws(strsplit(meta[["Config/bibliolab/App-Suggests"]], ",", fixed = TRUE)[[1]]))
  packages <- unique(sub("[[:space:](].*$","",specs))
  ready <- vapply(packages, requireNamespace, TRUE, quietly = TRUE)
  if (all(ready)) return(invisible(TRUE))
  configured <- strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep, fixed = TRUE)[[1]]
  library <- if(length(configured) && nzchar(configured[1])) path.expand(configured[1]) else file.path(path.expand("~"),"R",paste0("library-",getRversion()))
  if(!dir.exists(library) && !dir.create(library,recursive=TRUE)) abort_user(paste("No se puede crear la biblioteca de usuario:",library))
  if(file.access(library,2)!=0) abort_user(paste("No se puede escribir en la biblioteca de usuario:",library))
  .libPaths(c(library,.libPaths()))
  pending <- packages[!ready]
  message("Preparando los an\u00e1lisis antes de abrir: ",paste(pending,collapse=", "))
  if(!is.null(installer)) installer(pending,lib=library,repos="https://cloud.r-project.org",dependencies=NA,type=if(.Platform$OS.type=="windows")"binary" else getOption("pkgType")) else {
    params <- tempfile(fileext=".rds"); script <- tempfile(fileext=".R")
    on.exit(unlink(c(params,script)),add=TRUE)
    saveRDS(list(packages=pending,library=library,libs=.libPaths()),params)
    writeLines(c("a<-readRDS(commandArgs(trailingOnly=TRUE)[1]);.libPaths(a$libs)",
      "options(timeout=600)",
      "utils::install.packages(a$packages,lib=a$library,repos='https://cloud.r-project.org',dependencies=NA,type=if(.Platform$OS.type=='windows')'binary' else getOption('pkgType'))"),script)
    executable <- file.path(R.home("bin"),if(.Platform$OS.type=="windows")"Rscript.exe" else "Rscript")
    status <- system2(executable,c("--vanilla",shQuote(script),shQuote(params)))
    if(status!=0L) abort_user("No se pudo completar la instalaci\u00f3n inicial. Revisa la conexi\u00f3n y ejecuta INSTALAR_V5.cmd con esta versi\u00f3n de R. La aplicaci\u00f3n no se abrir\u00e1 con an\u00e1lisis pendientes.")
  }
  ready <- vapply(packages,requireNamespace,TRUE,quietly=TRUE)
  if(!all(ready)) abort_user(paste0("La preparaci\u00f3n est\u00e1 incompleta: ",paste(packages[!ready],collapse=", "),". Ejecuta INSTALAR_V5.cmd con R ",getRversion(),". En Windows se solicitan binarios; si no existen para tu R, la compilaci\u00f3n aparte requiere Rtools compatible. No se abre la app con t\u00e9cnicas pendientes."))
  invisible(TRUE)
}
