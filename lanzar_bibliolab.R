# Abre bibliolab desde la carpeta de codigo, sin instalar el paquete.
# RStudio: abra este archivo y pulse "Source"; o doble clic en ABRIR_BIBLIOLAB.cmd.
# Opciones (solo con Rscript): --no-browser
local({
  frames <- unlist(lapply(rev(sys.frames()), function(f) if (is.character(f$ofile)) f$ofile else NULL), use.names = FALSE)
  cli <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  starts <- unique(c(dirname(normalizePath(c(frames, cli), winslash = "/", mustWork = FALSE)), getwd()))
  root <- NULL
  for (s in starts) {
    d <- s
    for (i in 1:3) {
      if (file.exists(file.path(d, "DESCRIPTION")) && dir.exists(file.path(d, "inst", "app", "www"))) { root <- d; break }
      d <- dirname(d)
    }
    if (!is.null(root)) break
  }
  if (is.null(root)) stop("No se encuentra la carpeta de bibliolab (DESCRIPTION e inst/app/www). Guarde este archivo dentro de ella.", call. = FALSE)
  www <- file.path(root, "inst", "app", "www")
  falta <- setdiff(c("style.css", "app.js"), list.files(www))
  if (length(falta)) stop("Faltan archivos de la interfaz en ", www, ": ", paste(falta, collapse = ", "), call. = FALSE)
  legible <- tryCatch({ readLines(file.path(www, "style.css"), n = 1L, warn = FALSE); TRUE }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!legible) stop("No se puede leer style.css. Si la carpeta esta en OneDrive, haga clic derecho en ella y elija 'Mantener siempre en este dispositivo'; espere a que termine la descarga.", call. = FALSE)
  if (!requireNamespace("pkgload", quietly = TRUE)) utils::install.packages("pkgload", repos = "https://cloud.r-project.org")
  pkgload::load_all(root, export_all = FALSE, quiet = TRUE)
  cat("bibliolab ", as.character(utils::packageVersion("bibliolab")), " cargado desde ", root, "\n", sep = "")
  bibliolab::run_app(launch.browser = !"--no-browser" %in% commandArgs(trailingOnly = TRUE))
})
