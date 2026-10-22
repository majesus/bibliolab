# Utilidades de integridad y de representacion canonica: normalizacion Unicode, literales
# numericos exactos y huellas de contenido. Funciones puras, sin dependencia de Shiny.

# ---- Normalizacion Unicode ---------------------------------------------------
# Forma canonica compuesta (NFC) de un vector de texto. "cafe" + U+0301 y "café" son la misma
# palabra para quien lee, pero distintas secuencias de puntos de codigo: sin normalizar, el
# vocabulario las separaria. Se conservan NA, nombres y posiciones. El texto con UTF-8 invalido se
# devuelve sin cambios (no se descarta ni se inventa una lectura). La implementacion es unica y no
# depende de la plataforma ni del locale, de modo que una entrega reproduce el mismo vocabulario.
normalize_unicode <- function(x) {
  if (!length(x)) return(x)
  nm <- names(x)
  chr <- enc2utf8(as.character(x))
  ok <- !is.na(chr) & validUTF8(chr)
  if (any(ok)) {
    todo <- ok
    # Solo se procesan las cadenas con algun caracter no ASCII: el texto ASCII ya es NFC.
    todo[ok] <- grepl("[^\\x01-\\x7f]", chr[ok], perl = TRUE, useBytes = TRUE)
    if (any(todo)) chr[todo] <- enc2utf8(as.character(unclass(utf8::utf8_normalize(chr[todo]))))
  }
  names(chr) <- nm
  chr
}

# ---- Literales numericos exactos ---------------------------------------------
# Representacion decimal mas corta que reproduce exactamente el mismo doble al leerla de nuevo.
# `format(x, digits = 15)` puede perder la ultima cifra (por ejemplo 1/3) y alterar un modelo.
num_literal <- function(x) {
  one <- function(v) {
    if (is.na(v)) return("NA_real_")
    if (!is.finite(v)) return(if (v > 0) "Inf" else "-Inf")
    for (d in 1:17) { s <- sprintf("%.*g", d, v); if (as.numeric(s) == v) return(s) }
    sprintf("%.17g", v)
  }
  vapply(as.numeric(x), one, "")
}

# ---- Huellas de contenido ----------------------------------------------------
# Huella MD5 de una lista de vectores atomicos, independiente de la plataforma, del locale y de la
# marca de codificacion de las cadenas: los textos se codifican en UTF-8 con su longitud, los numeros
# se escriben como dobles IEEE little-endian y cada componente lleva su nombre y tipo. NA se
# distingue de la cadena vacia y de "NA".
content_digest <- function(parts) {
  path <- tempfile(fileext = ".bin")
  on.exit(unlink(path), add = TRUE)
  con <- file(path, open = "wb")
  tryCatch({
    put_int <- function(v) writeBin(as.integer(v), con, size = 4L, endian = "little")
    for (nm in names(parts)) {
      v <- parts[[nm]]
      writeBin(charToRaw(enc2utf8(paste0("[", nm, ":", if (is.character(v)) "c" else "n", ":", length(v), "]"))), con)
      if (is.character(v)) {
        v <- enc2utf8(v)
        put_int(ifelse(is.na(v), -1L, nchar(v, type = "bytes")))
        keep <- v[!is.na(v)]
        if (length(keep)) writeBin(charToRaw(paste0(keep, collapse = "")), con)
      } else writeBin(as.double(v), con, size = 8L, endian = "little")
    }
  }, finally = close(con))
  unname(tools::md5sum(path))
}

# Huella del contenido de una tabla (nombres y valores de todas las columnas, como texto).
table_fingerprint <- function(d) {
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  parts <- list(names = names(d), dim = dim(d))
  for (i in seq_along(d)) {
    col <- d[[i]]
    parts[[paste0("col", i)]] <- if (is.numeric(col) && !is.factor(col)) as.double(col) else as.character(col)
  }
  content_digest(parts)
}

# Huella de los documentos preparados (todas las columnas, tal como entran al analisis).
documents_fingerprint <- function(documents) table_fingerprint(documents)

# Huella del archivo de entrada leido (columnas como texto): detecta que `entrada_original.rds` sea
# otro contenido aunque tenga las mismas dimensiones. Excluye los atributos de procedencia.
raw_fingerprint <- function(raw) {
  d <- as.data.frame(raw, stringsAsFactors = FALSE)
  parts <- list(names = names(d), dim = dim(d))
  for (i in seq_along(d)) parts[[paste0("col", i)]] <- as.character(d[[i]])
  content_digest(parts)
}

# Huella de contenido del corpus analitico: conteos, nombres de unidades y terminos, y la
# correspondencia unidad -> documento. Es canonica: no depende del orden de filas ni de columnas
# (el orden de los terminos puede variar con el locale al ordenar empates) ni del tipo numerico.
# Dos corpus con las mismas dimensiones pero distintos terminos, conteos o documentos tienen
# huellas distintas. Se usa para decidir si un diagnostico guardado sigue describiendo el corpus
# vigente y para comprobar que una entrega reproduce la matriz exacta.
corpus_fingerprint <- function(corpus) {
  m <- corpus$counts
  if (is.null(m)) return("sin-matriz")
  rn <- enc2utf8(rownames(m) %||% character()); cn <- enc2utf8(colnames(m) %||% character())
  ro <- order(rn, method = "radix"); co <- order(cn, method = "radix")
  rrank <- integer(length(ro)); rrank[ro] <- seq_along(ro)
  crank <- integer(length(co)); crank[co] <- seq_along(co)
  trip <- methods::as(m, "TsparseMatrix")
  ii <- rrank[trip@i + 1L]; jj <- crank[trip@j + 1L]
  o <- order(ii, jj, method = "radix")
  doc <- corpus$units$doc_id[match(rn[ro], corpus$units$unit_id)]
  content_digest(list(dim = dim(m), rows = rn[ro], cols = cn[co], i = ii[o], j = jj[o], x = trip@x[o], doc = doc))
}

# Comprobacion de reproduccion con un diagnostico legible (en lugar de "isTRUE(...) is not TRUE").
verify_reproduction <- function(actual, expected, what) {
  if (!identical(as.character(actual), as.character(expected)))
    stop(sprintf("La reproducci\u00f3n no coincide con la entrega: %s. Comprueba que entrada_original.rds, la versi\u00f3n de bibliolab y los modelos de idioma son los registrados.", what), call. = FALSE)
  invisible(TRUE)
}

# ---- Huella del codigo instalado -----------------------------------------------
# El numero de version no identifica por si solo el codigo que se ejecuta: una copia de desarrollo puede
# conservar la version y cambiar el contenido. La huella resume las funciones del espacio de nombres
# (nombre y codigo reescrito por `deparse`, con los caracteres no ASCII escritos como \u para que no dependa
# del locale). Compara dos instalaciones de la misma version de R; con otra version de R, `deparse` puede
# reformatear el mismo codigo, de modo que una diferencia es un aviso para revisar, no una prueba de cambio.
ascii_escape <- function(x) {
  x <- enc2utf8(x)
  vapply(x, function(s) {
    if (!grepl("[^\\x01-\\x7f]", s, perl = TRUE)) return(s)
    cp <- utf8ToInt(s)
    paste0(vapply(cp, function(c) if (c < 128L) intToUtf8(c) else if (c < 65536L) sprintf("\\u%04x", c) else sprintf("\\U%08x", c), ""), collapse = "")
  }, "", USE.NAMES = FALSE)
}
.code_fingerprint_cache <- new.env(parent = emptyenv())
code_fingerprint <- function(package = "bibliolab") {
  key <- paste(package, R.version.string)
  if (!is.null(.code_fingerprint_cache[[key]])) return(.code_fingerprint_cache[[key]])
  env <- asNamespace(package)
  nm <- sort(ls(env, all.names = TRUE), method = "radix")
  nm <- nm[vapply(nm, function(n) is.function(get(n, envir = env, inherits = FALSE)), TRUE)]
  code <- vapply(nm, function(n) ascii_escape(paste(deparse(get(n, envir = env, inherits = FALSE), control = c("keepNA", "keepInteger", "niceNames")), collapse = "\n")), "")
  out <- list(huella = content_digest(list(nombres = nm, codigo = unname(code))), funciones = length(nm))
  .code_fingerprint_cache[[key]] <- out
  out
}
