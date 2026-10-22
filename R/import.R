# Importacion Excel por firma real, incluidas rutas temporales sin extension de Shiny.
biblio_file_format <- function(path, name = basename(path)) {
  size <- file.info(path)$size
  if (is.na(size) || size == 0) abort_user("El archivo est\u00e1 vac\u00edo o no se puede leer.")
  if (size > biblio_max_bytes()) abort_user(paste0("El archivo supera ", biblio_max_mb(), " MB. Divide la exportaci\u00f3n o elimina columnas que no necesites antes de cargarla. Eliminar las referencias citadas (CR) inutiliza la cocitaci\u00f3n, el acoplamiento bibliogr\u00e1fico y el an\u00e1lisis de referencias: si los necesitas, conserva esa columna y divide la exportaci\u00f3n por periodos."))
  sig <- readBin(path, "raw", n = 8L)
  if (identical(sig, as.raw(c(208,207,17,224,161,177,26,225)))) return("xls")
  if (length(sig) >= 4 && identical(sig[1:4], as.raw(c(80,75,3,4)))) return("xlsx")
  ext <- tolower(tools::file_ext(name))
  if (ext %in% c("xls", "xlsx")) abort_user("El archivo tiene extensi\u00f3n Excel, pero no contiene un libro XLS o XLSX v\u00e1lido. \u00c1brelo en Excel y gu\u00e1rdalo como Libro de Excel (.xlsx); cambiar solo el nombre no convierte el formato.")
  if (!ext %in% c("csv", "tsv", "txt")) abort_user("Selecciona un archivo CSV, TSV, XLS o XLSX.")
  "text"
}
biblio_excel_sheets <- function(path) {
  if (!requireNamespace("readxl", quietly = TRUE)) abort_user("Falta el paquete readxl para importar Excel. Inst\u00e1lalo con install.packages(\"readxl\") y reinicia la aplicaci\u00f3n.")
  fmt <- biblio_file_format(path, "archivo.xlsx")
  tmp <- tempfile(fileext = paste0(".", fmt))
  on.exit(unlink(tmp), add = TRUE)
  if (!file.copy(path, tmp)) abort_user("No se ha podido leer el libro Excel. Vuelve a seleccionarlo.")
  tryCatch(readxl::excel_sheets(tmp), error = function(e) abort_user("No se puede abrir el libro Excel. Puede estar da\u00f1ado o protegido por contrase\u00f1a; guarda una copia sin protecci\u00f3n en formato XLSX."))
}
read_biblio_excel <- function(path, sheet = NULL) {
  fmt <- biblio_file_format(path, "archivo.xlsx")
  sheets <- biblio_excel_sheets(path)
  if (!length(sheets)) abort_user("El libro Excel no contiene hojas de c\u00e1lculo.")
  if (is.null(sheet) || !length(sheet)) sheet <- sheets[1]
  if (!is.character(sheet) || length(sheet) != 1L || is.na(sheet) ||
      !nzchar(sheet) || !sheet %in% sheets)
    abort_user("La hoja seleccionada ya no existe. Elige una de las hojas de este libro.")
  reader <- if (fmt == "xls") readxl::read_xls else readxl::read_xlsx
  warnings <- character()
  d <- tryCatch(withCallingHandlers(reader(path, sheet = sheet, col_types = "text",
      n_max = BIBLIO_LIMITS$rows + 1L, na = "", trim_ws = FALSE, .name_repair = "minimal"),
      warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = function(e) abort_user("No se puede leer la hoja Excel. Comprueba que tiene encabezados en la primera fila de datos y guarda una copia sin protecci\u00f3n como XLSX."))
  if (length(warnings)) abort_user("Excel contiene celdas que no se pudieron leer sin p\u00e9rdida. Corrige las celdas con errores y vuelve a importar; no se han aceptado datos parciales.")
  if (!nrow(d)) abort_user("La hoja est\u00e1 vac\u00eda o solo contiene encabezados. Selecciona otra hoja o a\u00f1ade registros.")
  if (nrow(d) > BIBLIO_LIMITS$rows) abort_user("La hoja supera 10.000 filas. Usa un subconjunto de la b\u00fasqueda.")
  if (ncol(d) > BIBLIO_LIMITS$columns) abort_user("La hoja supera 100 columnas. Conserva los metadatos necesarios.")
  original <- names(d); named <- trimws(original)
  blank <- is.na(named) | !nzchar(named)
  named[blank] <- paste0("Columna ", which(blank))
  named <- make.unique(named, sep = " / ")
  names(d) <- named
  d <- as.data.frame(d, stringsAsFactors = FALSE, check.names = FALSE)
  if (any(vapply(d, function(x) any(nchar(x, type = "chars") > BIBLIO_LIMITS$text_chars, na.rm = TRUE), logical(1))))
    abort_user(oversize_cells_message(d))
  attr(d, "import_info") <- list(format = fmt, sheet = sheet, sheets = sheets,
    headers = data.frame(columna = seq_along(named), encabezado_original = original,
      nombre_importado = named, corregido = is.na(original) | original != named,
      stringsAsFactors = FALSE),
    reader = "readxl", reader_version = as.character(utils::packageVersion("readxl")),
    note = "Se conserva el contenido de las celdas como texto; los formatos visuales de Excel no se convierten en datos. Una celda num\u00e9rica 1 con formato 000 no es el identificador textual 001.")
  d
}
#' Importa CSV, TSV, XLS o XLSX de una exportacion bibliografica
#'
#' Detecta el formato por su firma binaria, no por la extension. En Excel lee
#' la hoja indicada como texto y ajusta encabezados repetidos o vacios sin
#' eliminar columnas (se registra en `import_info`).
#'
#' @param path Ruta del archivo.
#' @param name Nombre original (para detectar extension en rutas temporales).
#' @param sep,encoding Solo para texto; ver [read_biblio_csv()].
#' @param sheet Hoja de Excel (por defecto la primera).
#' @return `data.frame` de caracteres con atributos `source_md5` e `import_info` (Excel).
#' @examples
#' f <- system.file("extdata", "practica.csv", package = "bibliolab")
#' d <- read_biblio_file(f, "practica.csv", sep = ";")
#' nrow(d)
#' @export
read_biblio_file <- function(path, name = basename(path), sep = "auto", encoding = "UTF-8", sheet = NULL) {
  fmt <- biblio_file_format(path, name)
  d <- if (fmt %in% c("xls", "xlsx")) read_biblio_excel(path, sheet) else read_biblio_csv(path, sep, encoding)
  attr(d, "source_md5") <- unname(tools::md5sum(path))
  d
}
