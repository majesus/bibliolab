# Funciones puras: importacion, trazabilidad y analisis. No dependen de Shiny.
BIBLIO_VERSION <- "5.0.2"
BIBLIO_LIMITS <- list(bytes = 100 * 1024^2, rows = 10000L, columns = 100L,
                  text_chars = 50000L, units = 20000L, tokens = 1000000L)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
abort_user <- function(message) stop(shiny::safeError(message))
# Tamano maximo de archivo importado: 100 MB por defecto; run_app(max_upload_mb =) lo ajusta (1-500 MB).
biblio_max_bytes <- function() {
  v <- getOption("bibliolab.max_upload_bytes", BIBLIO_LIMITS$bytes)
  if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 1024^2) BIBLIO_LIMITS$bytes else v
}
biblio_max_mb <- function() format(round(biblio_max_bytes() / 1024^2), big.mark = ".", decimal.mark = ",", trim = TRUE, scientific = FALSE)
check_number <- function(x, label, low, high, integer = TRUE) {
  if (length(x) != 1L || !is.numeric(x) || !is.finite(x) || x < low || x > high ||
      (integer && x != floor(x))) abort_user(sprintf("%s debe estar entre %s y %s%s.", label, low, high, if (integer) " y ser entero" else ""))
  x
}
# Estado del generador aleatorio: se guarda y restaura sin alterar el del usuario.
rng_state <- function() {
  env <- globalenv()
  if (exists(".Random.seed", envir = env, inherits = FALSE)) get(".Random.seed", envir = env, inherits = FALSE) else NULL
}
rng_restore <- function(state) {
  env <- globalenv()
  if (is.null(state)) {
    if (exists(".Random.seed", envir = env, inherits = FALSE)) rm(list = ".Random.seed", envir = env)
  } else assign(".Random.seed", state, envir = env)
  invisible(NULL)
}
# Deriva semillas de repeticiones a partir de una semilla base sin desbordar el entero de R:
# la secuencia rota dentro de 1..integer.max (la base mas 1 vuelve a 1 si la base es el maximo).
derive_seed <- function(seed, offset = 0L) {
  check_number(seed, "La semilla", 1, .Machine$integer.max)
  as.integer((as.numeric(seed) - 1 + as.numeric(offset)) %% .Machine$integer.max + 1)
}
with_seed <- function(seed, code) {
  check_number(seed, "La semilla", 1, .Machine$integer.max)
  old <- rng_state()
  on.exit(rng_restore(old))
  set.seed(as.integer(seed)); force(code)
}
clean_value <- function(x) { x <- as.character(x); x[is.na(x)] <- ""; trimws(enc2utf8(x)) }
normalize_key <- function(x) tolower(gsub("\\s+", " ", clean_value(x), perl = TRUE))
#' Lee un CSV/TSV bibliografico con validaciones estrictas
#'
#' Importa un archivo de texto sin aceptar lecturas parciales: rechaza archivos
#' vacios, bytes nulos, filas con numero de campos inconsistente, encabezados
#' duplicados o vacios y celdas de mas de 50 000 caracteres. Todas las columnas
#' se leen como texto para conservar identificadores como `001`.
#'
#' @param path Ruta del archivo.
#' @param sep Separador: `"auto"`, `","`, `";"` o tabulador.
#' @param encoding `"UTF-8"` o `"Latin-1"`.
#' @return `data.frame` de caracteres con el atributo `source_md5`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' dim(d)
#' @export
read_biblio_csv <- function(path, sep = "auto", encoding = "UTF-8") {
  size <- file.info(path)$size
  if (is.na(size) || size == 0) abort_user("El archivo est\u00e1 vac\u00edo o no se puede leer.")
  if (size > biblio_max_bytes()) abort_user(paste0("El CSV supera ", biblio_max_mb(), " MB. Divide el archivo o elimina columnas que no necesites (por ejemplo, las referencias citadas) antes de cargarlo."))
  if (!sep %in% c("auto", ",", ";", "\t")) abort_user("Separador no admitido.")
  if (!encoding %in% c("UTF-8", "Latin-1")) abort_user("Codificaci\u00f3n no admitida.")
  # Convertir explicitamente antes de leer; no eliminar silenciosamente caracteres.
  bytes <- readBin(path, "raw", n = size)
  if (any(bytes == as.raw(0))) abort_user("El archivo contiene bytes nulos. Exporta de nuevo como CSV UTF-8.")
  txt <- iconv(rawToChar(bytes), from = if (encoding == "Latin-1") "latin1" else "UTF-8", to = "UTF-8", sub = NA)
  if (is.na(txt)) abort_user("No se puede decodificar el CSV. Prueba Latin-1 o exp\u00f3rtalo como UTF-8.")
  txt <- sub("^\ufeff", "", txt)
  warnings <- character()
  d <- tryCatch(withCallingHandlers(data.table::fread(text = txt, sep = sep, header = TRUE,
    colClasses = "character", encoding = "UTF-8", na.strings = c("", "NA", "N/A"),
    check.names = FALSE, fill = FALSE, nrows = BIBLIO_LIMITS$rows + 1L, showProgress = FALSE),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = function(e) abort_user("CSV no v\u00e1lido. Comprueba el separador, las comillas y que todas las filas tengan las mismas columnas."))
  if (length(warnings)) abort_user("El CSV tiene filas o comillas inconsistentes. Corr\u00edgelo o selecciona otro separador; no se han importado datos parciales.")
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  if (!nrow(d)) abort_user("El CSV solo contiene encabezados; a\u00f1ade al menos un registro.")
  if (nrow(d) > BIBLIO_LIMITS$rows) abort_user("El CSV supera 10.000 filas. Usa un subconjunto de la b\u00fasqueda.")
  if (ncol(d) > BIBLIO_LIMITS$columns) abort_user("El CSV supera 100 columnas. Conserva los metadatos necesarios.")
  if (ncol(d) == 1L && grepl("[,;\\t]", names(d), perl = TRUE)) abort_user("Solo se ha detectado una columna con separadores en el encabezado. Revisa el separador del archivo.")
  if (any(!nzchar(trimws(names(d)))) || anyDuplicated(names(d))) abort_user("Los encabezados deben ser \u00fanicos y no estar vac\u00edos.")
  if (any(vapply(d, function(x) any(nchar(x, type = "chars") > BIBLIO_LIMITS$text_chars, na.rm = TRUE), logical(1))))
    abort_user("Una celda supera 50.000 caracteres. Usa t\u00edtulos o res\u00famenes, en lugar de textos completos.")
  attr(d, "source_md5") <- unname(tools::md5sum(path))
  d
}
#' Propone que columna cumple cada papel bibliometrico
#'
#' Reconoce encabezados habituales de Web of Science (etiquetas de dos letras y
#' nombres largos), Scopus y exportaciones en espanol/ingles. En exportaciones
#' etiquetadas de WoS, `ID` (Keywords Plus) no se toma como identificador.
#' La propuesta debe revisarse: el investigador decide la correspondencia final.
#'
#' @param d `data.frame` importado.
#' @return Lista con las columnas propuestas para `text`, `title`, `id`, `year`,
#'   `source`, `authors`, `citations`, `keywords`, `doi`, `language`,
#'   `references` y `translated` (`""` si no se reconoce).
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' guess_columns(d)$text
#' @export
guess_columns <- function(d) {
  nm <- trimws(tolower(ascii_fold(names(d))))
  nm <- gsub("[_ .-]+", " ", nm)
  # En exportaciones etiquetadas de WoS, ID es Keywords Plus y el identificador es UT.
  wos_tags <- c("ab", "ti", "py", "so", "au", "de", "cr", "tc", "ut")
  wos_tagged <- sum(nm %in% wos_tags) >= 4L
  id_aliases <- c(if (!wos_tagged) "id", "review_id", "document_id", "eid", "ut", "ut (unique id)", "unique id", "key")
  aliases <- list(text = c("abstract", "abstract note", "resumen", "texto", "text", "review", "description", "ab", "abstract text", "summary", "resumo", "resume", "abstracts", "resumen del articulo"),
    title = c("title", "titulo", "article title", "document title", "ti"),
    id = id_aliases, year = c("year", "ano", "anio", "publication year", "publication_year", "py"),
    source = c("source title", "source_title", "publication title", "revista", "journal", "source", "so"),
    authors = c("authors", "autores", "author", "author full names", "au"),
    citations = c("cited by", "cited_by", "times cited", "times cited, wos core", "times cited, all databases", "citas", "citations", "tc"),
    keywords = c("author keywords", "keywords author", "authors keywords", "author_keywords", "keywords", "palabras clave", "palabras_clave", "de"), doi = c("doi", "di"), language = c("language", "idioma", "la"),
    references = c("cr", "references", "cited references", "referencias", "referencias citadas"),
    translated = c("translated", "translated_text", "texto_traducido", "traduccion"))
  out <- lapply(aliases, function(a) { a <- gsub("[_ .-]+", " ", a); i <- match(a, nm); i <- i[!is.na(i)]; if (length(i)) names(d)[i[1]] else "" })
  if (!nzchar(out$text)) {
    # Solo inferir prosa; nunca usar ID, autores, DOI o codigos como texto.
    candidates <- setdiff(names(d), unlist(out[setdiff(names(out), c("text", "title"))]))
    scores <- vapply(d[candidates], function(x) {
      x <- head(clean_value(x), 200); x <- x[nzchar(x)]
      if (!length(x) || mean(grepl("\\p{L}+\\s+\\p{L}", x, perl = TRUE)) < .5) return(0)
      stats::median(nchar(x))
    }, 0)
    if (length(scores) && max(scores) >= 40) out$text <- names(scores)[which.max(scores)]
    else if (nzchar(out$title)) out$text <- out$title
  }
  out
}

language_columns <- function(d) {
  roles<-guess_columns(d);alias <- roles$language
  valid <- c("es", "en", "fr", "de", "it", "pt", "spanish", "english", "french", "german", "italian", "portuguese", "espanol", "ingles", "frances", "aleman", "italiano", "portugues")
  found <- names(d)[vapply(d, function(x) { x<-clean_value(x);x<-x[nzchar(x)];if(!length(x)) return(FALSE);if(exists("normalize_language",mode="function")) return(all(!is.na(normalize_language(x))));x<-ascii_fold(normalize_key(x));all(x %in% valid) }, TRUE)]
  found<-setdiff(found,unlist(roles[setdiff(names(roles),"language")],use.names=FALSE))
  unique(c(if (nzchar(alias)) alias, found))
}

filter_term_table <- function(d, query = "", status = "all", reason = "all") {
  if (status == "kept") d <- d[d$incluido, , drop = FALSE]
  if (status == "excluded") d <- d[!d$incluido, , drop = FALSE]
  if (reason != "all") d <- d[grepl(reason, d$motivo_exclusion, fixed = TRUE), , drop = FALSE]
  q <- normalize_key(query)
  if (nzchar(q)) {
    flat <- function(x) ascii_fold(normalize_key(x))
    d <- d[grepl(flat(q), flat(paste(d$termino, d$motivo_exclusion)), fixed = TRUE), , drop = FALSE]
  }
  d
}
#' Configuracion por defecto de la preparacion
#'
#' Devuelve la lista completa de opciones que consumen [prepare_documents()] y
#' [prepare_corpus()]. Se modifica con `utils::modifyList(default_config(), list(...))`
#' y se pasa como argumento `config` de [prepare_documents()]; la configuracion
#' efectiva queda en `prepared$config` y se registra en la entrega.
#'
#' @section Documentos (prepare_documents):
#' * `deduplicate` (logico, `TRUE`): elimina duplicados con evidencia compatible
#'   (DOI identico, o titulo/texto normalizado sin DOI, ano o autores contradictorios).
#'   Los casos dudosos se conservan y se listan en `prepared$ambiguous`.
#' * `year_min`, `year_max` (entero entre 1500 y 2200, o `NULL`): filtran por ano
#'   de publicacion; exigen una columna de ano asignada y excluyen los registros
#'   sin ano cuando se fija alguno de los dos limites.
#' * `filter_col`, `filter_value` (texto): conserva solo las filas cuya columna
#'   `filter_col` es igual a `filter_value`. `""` desactiva el filtro.
#' * `sample_pct` (numerico, 1 a 100): porcentaje de documentos de una muestra
#'   aleatoria reproducible con `seed`; 100 conserva todos.
#' * `seed` (entero): semilla del muestreo.
#' * `metadata_sep` (`";"` o `"|"`): separador de autores y palabras clave cuando
#'   no se fija una regla propia.
#' * `authors_sep`, `keywords_sep` (`NULL`, `"auto"`, `";"`, `"|"`, `","` o `"none"`):
#'   regla de separacion de cada campo. `NULL` usa `metadata_sep`; `"auto"` la
#'   detecta; la coma no se admite para autores, porque puede pertenecer al nombre.
#' * `reference_year` (entero): ano de referencia para validar anos y calcular
#'   edades de citacion; por defecto, el ano actual.
#' * `normalize_labels` (logico, `TRUE`): unifica variantes de mayusculas, acentos
#'   y puntuacion de autores, palabras clave y revistas (no desambigua personas).
#'
#' @section Texto y vocabulario (prepare_corpus):
#' * `language` (`"es"`, `"en"`, `"fr"`, `"de"`, `"it"`, `"pt"`, `"both"`, `"none"`
#'   o `"by_document"`): idioma de las palabras vacias. `"both"` aplica espanol e
#'   ingles; `"by_document"` usa la columna de idioma de cada documento y aborta si
#'   alguno con texto no tiene un idioma reconocido.
#' * `remove_stop` (logico): elimina palabras vacias; `custom_stop` (texto separado
#'   por comas) anade las propias.
#' * `min_chars`, `max_chars` (entero, 1 a 12 y hasta 100): longitud minima y
#'   maxima de los terminos.
#' * `remove_numbers`, `remove_links`, `remove_codes` (logico): eliminan numeros,
#'   enlaces y correos, y terminos que mezclan letras y digitos.
#' * `remove_boilerplate` (logico, `TRUE`): retira avisos editoriales
#'   (derechos de autor, licencias) antes del analisis.
#' * `split_sentences` (logico): una unidad textual por frase en lugar de por documento.
#' * `lemmatize`, `pos_filter` (logico): lematizacion y filtro por categoria
#'   gramatical con modelos UDPipe locales; `pos_keep` (`"NOUN"`, `"PROPN"`,
#'   `"ADJ"`, `"VERB"`, `"ADV"`) fija las categorias conservadas y `lemma_language`
#'   (`"es"`, `"en"`, `"fr"`, `"de"`, `"it"`, `"pt"` o `"column"`) el modelo.
#' * `min_df` (entero, 1 a 10000): numero minimo de documentos con el termino;
#'   `min_tf` (frecuencia total minima, al menos 1); `max_df_pct` (1 a 100, porcentaje maximo
#'   de documentos); `min_tfidf` (TF-IDF medio minimo); `max_entropy` (0 a 1,
#'   entropia maxima entre documentos).
#' * `max_terms` (entero, 20 a 2500): tamano maximo del vocabulario de los modelos.
#' * `term_order` (`"frequency"`, `"tfidf"` o `"bm25"`): criterio que ordena los
#'   terminos elegibles antes de aplicar `max_terms`.
#' * `tfidf_stat` (`"mean"`, `"median"`, `"q25"`, `"q75"`, `"q90"` o
#'   `"percentile"`), `tfidf_scope` (`"all"` o `"present"`) y `tfidf_percentile`
#'   (0 a 100): resumen de TF-IDF usado cuando `term_order = "tfidf"`.
#'
#' @return Lista con los parametros de limpieza, filtrado y vocabulario.
#' @examples
#' cfg <- default_config()
#' names(cfg)
#' cfg <- utils::modifyList(cfg, list(min_df = 3L, split_sentences = TRUE))
#' cfg$min_df
#' @export
default_config <- function() list(language = "es", remove_stop = TRUE, custom_stop = "", min_chars = 3L,
  remove_numbers = TRUE, remove_links = TRUE, lemmatize = FALSE, split_sentences = FALSE,
  deduplicate = TRUE, year_min = NULL, year_max = NULL, sample_pct = 100, seed = 2026L,
  min_df = 2L, max_terms = 1000L, metadata_sep = ";", authors_sep = NULL, keywords_sep = NULL, filter_col = "", filter_value = "",
  max_chars = 40L, min_tf = 1L, max_df_pct = 100, min_tfidf = 0,
  max_entropy = 1, term_order = "frequency", tfidf_stat = "mean", tfidf_scope = "all", tfidf_percentile = 75,
  lemma_language = "es", pos_filter = FALSE, remove_codes = FALSE,
  pos_keep = c("NOUN", "PROPN", "ADJ"), reference_year = as.integer(format(Sys.Date(), "%Y")),
  normalize_labels = TRUE, remove_boilerplate = TRUE)
mapped <- function(d, mapping, field) {
  col <- mapping[[field]] %||% ""
  if (!nzchar(col)) return(rep("", nrow(d)))
  if (!col %in% names(d)) abort_user(paste("La columna asignada a", field, "ya no existe. Revisa la asignaci\u00f3n."))
  clean_value(d[[col]])
}
parse_numeric <- function(x, type = "citations", reference_year = as.integer(format(Sys.Date(), "%Y"))) {
  # Sin adivinar separadores de miles o convertir basura en cero.
  x <- clean_value(x); ok <- grepl("^[0-9]+$", x)
  val <- suppressWarnings(as.numeric(x))
  val[!ok | !is.finite(val)] <- NA_real_
  if (type == "year") val[val != floor(val) | val < 1500 | val > reference_year + 1] <- NA_real_
  else val[val < 0 | val != floor(val)] <- NA_real_
  val
}
# Auditoria de duplicados. Un registro solo se marca como duplicado cuando la
# coincidencia es segura: mismo DOI, o mismo titulo (o texto, si falta el titulo)
# sin evidencia contradictoria. Los homonimos, las versiones con otro anio y las
# coincidencias con varios candidatos se conservan y se describen en `ambiguous`.
duplicate_audit <- function(docs) {
  n <- nrow(docs)
  empty_amb <- data.frame(doc_id = character(), coincide_con = character(), clave = character(), motivo = character(), stringsAsFactors = FALSE)
  if (!n) return(list(duplicate = logical(), kept = integer(), criterion = character(), ambiguous = empty_amb))
  doi <- normalize_key(sub("^(https?://(dx\\.)?doi\\.org/|doi:\\s*)", "", docs$doi, ignore.case = TRUE, perl = TRUE))
  tkey <- label_key(docs$title, "keyword"); xkey <- label_key(docs$text, "keyword"); akey <- label_key(docs$authors, "author")
  year <- docs$year
  pool_key <- ifelse(nzchar(tkey), paste0("t:", tkey), ifelse(nzchar(xkey), paste0("x:", xkey), ""))
  words <- lengths(strsplit(sub("^[tx]:", "", pool_key), " ", fixed = TRUE)) * nzchar(pool_key)
  kept <- seq_len(n); criterion <- rep("", n)
  rep_dois <- vector("list", n); rep_year <- year
  doi_owner <- new.env(hash = TRUE, parent = emptyenv()); pools <- new.env(hash = TRUE, parent = emptyenv())
  amb <- list()
  verdict <- function(i, r) {
    if (nzchar(doi[i]) && length(rep_dois[[r]]) && !doi[i] %in% rep_dois[[r]]) return("DOI distinto")
    if (!is.na(year[i]) && !is.na(rep_year[r]) && year[i] != rep_year[r]) return("A\u00f1o distinto")
    if (words[i] < 4L) {
      same_year <- !is.na(year[i]) && !is.na(rep_year[r]) && year[i] == rep_year[r]
      same_authors <- nzchar(akey[i]) && identical(akey[i], akey[r])
      same_text <- nzchar(xkey[i]) && identical(xkey[i], xkey[r])
      if (!(same_year && (same_authors || same_text))) return("T\u00edtulo gen\u00e9rico sin corroboraci\u00f3n")
    }
    ""
  }
  for (i in seq_len(n)) {
    target <- NA_integer_
    if (nzchar(doi[i]) && !is.null(owner <- doi_owner[[doi[i]]])) {
      target <- owner; criterion[i] <- "DOI"
    } else if (nzchar(pool_key[i])) {
      cand <- pools[[pool_key[i]]]
      if (length(cand)) {
        v <- vapply(cand, function(r) verdict(i, r), "")
        ok <- cand[!nzchar(v)]
        if (length(ok) == 1L) {
          target <- ok; criterion[i] <- if (startsWith(pool_key[i], "t:")) "T\u00edtulo normalizado" else "Texto normalizado"
        } else if (length(ok) > 1L) {
          amb[[length(amb) + 1L]] <- data.frame(doc_id = docs$doc_id[i], coincide_con = docs$doc_id[ok[1L]], clave = pool_key[i], motivo = "Varias coincidencias posibles", stringsAsFactors = FALSE)
        } else amb[[length(amb) + 1L]] <- data.frame(doc_id = docs$doc_id[i], coincide_con = docs$doc_id[cand[1L]], clave = pool_key[i], motivo = v[1L], stringsAsFactors = FALSE)
      }
    }
    if (is.na(target)) {
      if (nzchar(pool_key[i])) pools[[pool_key[i]]] <- c(pools[[pool_key[i]]], i)
      if (nzchar(doi[i])) doi_owner[[doi[i]]] <- i
      rep_dois[[i]] <- doi[i][nzchar(doi[i])]
    } else {
      kept[i] <- target
      if (nzchar(doi[i])) { doi_owner[[doi[i]]] <- target; rep_dois[[target]] <- union(rep_dois[[target]], doi[i]) }
      if (is.na(rep_year[target])) rep_year[target] <- year[i]
    }
  }
  list(duplicate = kept != seq_len(n), kept = kept, criterion = criterion,
    ambiguous = if (length(amb)) do.call(rbind, amb) else empty_amb)
}
#' Construye el conjunto de documentos y su auditoria
#'
#' Aplica, en este orden, filtro por valor, filtro temporal, deduplicacion
#' (DOI, titulo normalizado, texto normalizado) y muestreo con semilla. Los
#' valores ausentes de anio o citas se conservan como `NA` (nunca como cero).
#'
#' @param d `data.frame` de [read_biblio_csv()] o [read_biblio_file()].
#' @param mapping Lista de columnas, normalmente de [guess_columns()].
#' @param config Lista parcial de opciones; ver [default_config()].
#' @details La deduplicacion no elimina un registro salvo coincidencia segura.
#'   Dos registros son el mismo si comparten DOI. Si falta el DOI en alguno,
#'   coinciden en titulo normalizado (o, sin titulo, en texto normalizado), no
#'   tienen DOI distintos ni anios distintos y, cuando el titulo tiene menos de
#'   cuatro palabras (por ejemplo `Editorial`), coinciden ademas en anio y en
#'   autores o texto. Las coincidencias con evidencia contradictoria o con
#'   varios candidatos se conservan y se listan en `ambiguous`.
#' @return Lista con `documents`, `audit`, `duplicates` (con el criterio y el
#'   registro conservado), `ambiguous` (coincidencias no eliminadas), `issues`,
#'   `config`, `mapping` e `input_md5` (huella del archivo leido con
#'   [read_biblio_csv()], o `NULL`).
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' p$audit
#' @export
prepare_documents <- function(d, mapping, config = default_config()) {
  cfg <- utils::modifyList(default_config(), config)
  if (!nzchar(mapping$text %||% "")) abort_user("Selecciona la columna de texto (resumen o t\u00edtulo).")
  check_number(cfg$sample_pct, "El porcentaje de muestra", 1, 100, FALSE)
  check_number(cfg$seed, "La semilla", 1, .Machine$integer.max)
  if (!cfg$metadata_sep %in% c(";", "|")) abort_user("Usa punto y coma o barra vertical para separar autores y palabras clave.")
  cfg$authors_sep <- metadata_rule(mapped(d,mapping,"authors"),cfg$authors_sep,cfg$metadata_sep)
  cfg$keywords_sep <- metadata_rule(mapped(d,mapping,"keywords"),cfg$keywords_sep,cfg$metadata_sep)
  if(identical(cfg$authors_sep,","))abort_user("No se separan autores por comas: pueden pertenecer al apellido y las iniciales. Reexporta con punto y coma o barra vertical.")
  yr <- mapped(d, mapping, "year"); ct <- mapped(d, mapping, "citations")
  docs <- data.frame(doc_id = sprintf("D%05d", seq_len(nrow(d))), source_row = seq_len(nrow(d)),
    original_id = mapped(d, mapping, "id"), title = mapped(d, mapping, "title"),
    text = mapped(d, mapping, "text"), year = parse_numeric(yr, "year", cfg$reference_year),
    source = mapped(d, mapping, "source"), authors = mapped(d, mapping, "authors"),
    citations = parse_numeric(ct), keywords = mapped(d, mapping, "keywords"),
    references = mapped(d, mapping, "references"), doi = mapped(d, mapping, "doi"), language = apply_language_overrides(mapped(d, mapping, "language"), cfg$language_overrides %||% character()), translated = mapped(d, mapping, "translated"), stringsAsFactors = FALSE)
  issues <- c(sprintf("CSV importado: a\u00f1os ausentes o no v\u00e1lidos, %d/%d.", sum(is.na(docs$year)), nrow(docs)),
    sprintf("CSV importado: citas ausentes o no v\u00e1lidas, %d/%d (no se consideran cero).", sum(is.na(docs$citations)), nrow(docs)))
  if (anyDuplicated(docs$original_id[nzchar(docs$original_id)])) issues <- c(issues, "Hay ID originales repetidos; se han asignado ID internos \u00fanicos.")
  rows_in <- nrow(docs)
  if (nzchar(cfg$filter_col)) {
    if (!cfg$filter_col %in% names(d)) abort_user("La columna del filtro no existe.")
    docs <- docs[clean_value(d[[cfg$filter_col]]) == trimws(cfg$filter_value), , drop = FALSE]
  }
  rows_filter <- nrow(docs)
  if (!is.null(cfg$year_min) || !is.null(cfg$year_max)) {
    if (!nzchar(mapping$year %||% "")) abort_user("Asigna una columna de a\u00f1o antes de aplicar el filtro temporal.")
    low <- cfg$year_min %||% 1500; high <- cfg$year_max %||% (cfg$reference_year + 1)
    check_number(low, "El a\u00f1o inicial", 1500, 2200); check_number(high, "El a\u00f1o final", 1500, 2200)
    if (low > high) abort_user("El a\u00f1o inicial no puede superar el a\u00f1o final.")
    docs <- docs[!is.na(docs$year) & docs$year >= low & docs$year <= high, , drop = FALSE]
  }
  rows_year <- nrow(docs)
  dup <- duplicate_audit(docs)
  duplicates <- dup$duplicate
  duplicate_records <- docs[duplicates, , drop = FALSE]
  if (nrow(duplicate_records)) {
    duplicate_records$criterio_duplicado <- dup$criterion[duplicates]
    duplicate_records$conservado_doc_id <- docs$doc_id[dup$kept[duplicates]]
    duplicate_records$conservado_fila <- docs$source_row[dup$kept[duplicates]]
  }
  ambiguous_records <- dup$ambiguous
  if (cfg$deduplicate) docs <- docs[!duplicates, , drop = FALSE]
  rows_dedup <- nrow(docs)
  if (!nrow(docs)) abort_user("Los filtros han dejado cero documentos. Ampl\u00eda el periodo o elimina el filtro.")
  if (cfg$sample_pct < 100) {
    n <- max(1L, floor(nrow(docs) * cfg$sample_pct / 100))
    idx <- with_seed(cfg$seed, sort(sample.int(nrow(docs), n)))
    docs <- docs[idx, , drop = FALSE]
    issues <- c(issues, "Se analiza una muestra aleatoria: los indicadores describen esa muestra.")
  }
  audit <- data.frame(etapa = c("Importaci\u00f3n", "Filtro por valor", "Filtro temporal", "Deduplicaci\u00f3n", "Muestra final"),
    documentos = c(rows_in, rows_filter, rows_year, rows_dedup, nrow(docs)))
  issues <- c(issues, sprintf("Duplicados detectados tras los filtros: %d. Criterio: DOI id\u00e9ntico; sin DOI en alguno de los registros, t\u00edtulo normalizado (sin acentos, may\u00fasculas ni puntuaci\u00f3n) o, si falta el t\u00edtulo, texto normalizado, siempre que no haya DOI ni a\u00f1o contradictorios y que los t\u00edtulos gen\u00e9ricos (menos de cuatro palabras) coincidan tambi\u00e9n en a\u00f1o y en autores o texto. Cada duplicado remite al registro conservado.", sum(duplicates)))
  if (nrow(ambiguous_records)) issues <- c(issues, sprintf("Coincidencias de t\u00edtulo o texto no tratadas como duplicado seguro: %d registros (DOI o a\u00f1o distintos, t\u00edtulo gen\u00e9rico sin corroboraci\u00f3n o varias coincidencias posibles). Se conservan; revisa `ambiguous`.", nrow(ambiguous_records)))
  issues <- c(issues, sprintf("Corpus final: %d/%d documentos con a\u00f1o v\u00e1lido; %d/%d con citas v\u00e1lidas; %d/%d con texto no vac\u00edo.",
    sum(!is.na(docs$year)), nrow(docs), sum(!is.na(docs$citations)), nrow(docs), sum(nzchar(docs$text)), nrow(docs)))
  if (!nzchar(mapping$authors %||% "")) issues <- c(issues, "No hay columna de autores asignada; no se calcular\u00e1 productividad de autores.")
  list(documents = docs, audit = audit, duplicates = duplicate_records, ambiguous = ambiguous_records, issues = issues, config = cfg, mapping = mapping,
    input_md5 = attr(d, "source_md5", exact = TRUE))
}
tokenize_one <- function(text, cfg, stops) {
  text <- tolower(enc2utf8(text))
  if (cfg$remove_links) text <- gsub("https?://\\S+|www\\.\\S+|[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]+", ".", text, perl = TRUE)
  # Se conserva puntuacion como frontera; no se crean bigramas entre frases.
  text <- gsub("(?<!\\p{L})['\u2019]|['\u2019](?!\\p{L})", ".", text, perl = TRUE)
  parts <- strsplit(text, "(?:(?!['\u2019])[\\p{P}\\p{S}\\r\\n])+", perl = TRUE)[[1]]
  lapply(parts, function(part) {
    words <- regmatches(part, gregexpr("[\\p{L}\\p{N}]+(?:['\u2019][\\p{L}\\p{N}]+)?", part, perl = TRUE))[[1]]
    # Marcas vacias impiden unir vecinos artificiales al eliminar stopwords.
    keep <- nchar(words) >= cfg$min_chars & nchar(words) <= cfg$max_chars & !words %in% stops
    if (cfg$remove_numbers) keep <- keep & !grepl("^\\p{N}+$", words, perl = TRUE)
    if (cfg$remove_codes) keep <- keep & !(grepl("\\p{L}", words, perl = TRUE) & grepl("\\p{N}", words, perl = TRUE))
    words[!keep] <- ""; words
  })
}
# Aplica a la tabla de terminos los criterios de presencia, frecuencia, TF-IDF y entropia, ordena los
# elegibles y recorta el vocabulario al maximo. Se usa al preparar el corpus y al simular umbrales
# alternativos en vocabulary_diagnostics(), de modo que ambos recorridos sean identicos.
vocabulary_selection <- function(term_table, cfg, n_docs) {
  reasons <- rep("", nrow(term_table))
  flag <- function(condition, label) { reasons[condition] <<- ifelse(nzchar(reasons[condition]), paste(reasons[condition], label, sep = "; "), label) }
  flag(term_table$documentos < cfg$min_df, "Presencia m\u00ednima")
  flag(100 * term_table$documentos / n_docs > cfg$max_df_pct + 1e-8, "Presencia m\u00e1xima")
  flag(term_table$frecuencia < cfg$min_tf, "Frecuencia m\u00ednima")
  flag(term_table$tfidf_medio + 1e-12 < cfg$min_tfidf, "TF-IDF m\u00ednimo")
  flag(term_table$entropia > cfg$max_entropy + 1e-10, "Entrop\u00eda m\u00e1xima")
  eligible_rows <- which(!nzchar(reasons))
  if (cfg$term_order == "tfidf") eligible_rows <- eligible_rows[order(-term_table$tfidf_orden[eligible_rows], -term_table$documentos[eligible_rows], term_table$termino[eligible_rows])]
  if (cfg$term_order == "bm25") eligible_rows <- eligible_rows[order(-term_table$bm25_medio[eligible_rows], term_table$termino[eligible_rows])]
  eligible <- term_table$termino[eligible_rows]; vocab <- head(eligible, cfg$max_terms)
  flag(!nzchar(reasons) & !term_table$termino %in% vocab, "L\u00edmite de vocabulario")
  list(reasons = reasons, eligible = eligible, vocabulary = vocab)
}
#' Segmenta, limpia y selecciona el vocabulario
#'
#' Tokeniza el texto (puntuacion como frontera), aplica palabras vacias, lemas
#' y categorias gramaticales si se solicitan, y construye la matriz
#' unidad x termino con criterios de presencia, frecuencia, TF-IDF y entropia.
#' Cada termino excluido conserva su motivo en `terms`.
#'
#' @param prepared Resultado de [prepare_documents()].
#' @param progress Funcion opcional `function(stage, current, total)`.
#' @return Lista con `units`, `counts`, `terms`, `ngrams`, `bigrams`, `issues`,
#'   `vocabulary`, `models` y `processing`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' cp <- prepare_corpus(prepare_documents(d, guess_columns(d)))
#' head(cp$terms)
#' @export
prepare_corpus <- function(prepared,progress=NULL) {
  cfg <- prepared$config; docs <- prepared$documents
  check_number(cfg$min_chars, "La longitud m\u00ednima", 1, 12)
  check_number(cfg$min_df, "La presencia m\u00ednima", 1, 10000)
  check_number(cfg$max_terms, "El m\u00e1ximo de t\u00e9rminos", 20, 2500)
  check_number(cfg$max_chars, "La longitud m\u00e1xima", cfg$min_chars, 100)
  check_number(cfg$min_tf, "La frecuencia m\u00ednima", 1, 1000000)
  check_number(cfg$max_df_pct, "La presencia m\u00e1xima (%)", 1, 100, FALSE)
  check_number(cfg$min_tfidf, "El TF-IDF m\u00ednimo", 0, 10, FALSE)
  check_number(cfg$max_entropy, "La entrop\u00eda m\u00e1xima", 0, 1, FALSE)
  if (!cfg$term_order %in% c("frequency", "tfidf", "bm25")) abort_user("Criterio de orden del vocabulario no admitido.")
  if (!cfg$language %in% c("es", "en", "fr", "de", "it", "pt", "both", "none", "by_document")) abort_user("Idioma no admitido.")
  linguistic <- isTRUE(cfg$lemmatize) || isTRUE(cfg$pos_filter)
  if (linguistic && cfg$remove_stop && cfg$lemma_language %in% c("es", "en", "fr", "de", "it", "pt") &&

      cfg$language %in% c("es", "en", "fr", "de", "it", "pt") && cfg$language != cfg$lemma_language)

    abort_user("El idioma de las palabras vac\u00edas y el modelo ling\u00fc\u00edstico no coinciden. Selecciona el mismo idioma o usa el modo por columna para un corpus mixto.")

  if (linguistic && !exists("annotate_corpus_units", mode = "function")) abort_user("La lematizaci\u00f3n multiling\u00fce necesita el m\u00f3dulo nlp.R y modelos UDPipe locales.")
  stops <- character()
  if (cfg$remove_stop && !cfg$language %in% c("none","by_document")) stops <- unique(unlist(lapply(if (cfg$language == "both") c("es", "en") else cfg$language,
    function(lang) stopwords::stopwords(lang, source = "snowball"))))
  custom <- trimws(tolower(strsplit(cfg$custom_stop %||% "", ",", fixed = TRUE)[[1]]))
  stops <- unique(c(stops, custom[nzchar(custom)]))
  # Idioma por documento sin anotacion linguistica: cada documento usa las palabras vacias de su idioma.
  lexical_stops <- stops; lexical_language <- rep(NA_character_, nrow(docs))
  if (cfg$remove_stop && identical(cfg$language, "by_document") && !linguistic) {
    lexical_language <- normalize_language(docs$language)
    bad <- is.na(lexical_language) & nzchar(trimws(docs$text))
    if (any(bad)) {
      ix <- head(which(bad), 5L)
      abort_user(paste0("El modo de palabras vac\u00edas por documento necesita un idioma reconocido en cada documento con texto; faltan o no se reconocen ", sum(bad),
        " (por ejemplo ", paste(docs$doc_id[ix], collapse = ", "), "). Asigna la columna de idioma o elige un idioma fijo."))
    }
    langs <- unique(lexical_language[!is.na(lexical_language)])
    lexical_stops <- stats::setNames(lapply(langs, function(l) unique(c(stopwords::stopwords(l, source = "snowball"), custom[nzchar(custom)]))), langs)
  }
  pool<-new.env(parent=emptyenv());pool$cluster<-NULL;pool$log<-NULL
  on.exit({processing_close(pool);if(!is.null(pool$log)) unlink(pool$log)},add=TRUE)
  # Avisos finales de derechos de autor: se retiran solo del texto que se tokeniza; documents$text conserva el original.
  analysed_text <- if (isTRUE(cfg$remove_boilerplate %||% TRUE)) strip_boilerplate(docs$text) else docs$text
  boilerplate_removed <- sum(analysed_text != docs$text)
  jobs<-lapply(seq_len(nrow(docs)),function(i) list(doc_id=docs$doc_id[i],text=analysed_text[i],language=lexical_language[i]))
  mapped_units<-processing_map(jobs,"lexical",list(cfg=cfg,stops=lexical_stops),cfg$execution,sum(nchar(docs$text)),pool,progress)
  processing_audit<-attr(mapped_units,"processing")
  all_units<-unlist(lapply(mapped_units,`[[`,"units"),recursive=FALSE)
  all_pairs<-unlist(lapply(mapped_units,`[[`,"pairs"),recursive=FALSE)
  all_sequences<-unlist(lapply(mapped_units,`[[`,"sequences"),recursive=FALSE)
  total_tokens<-sum(vapply(all_units,function(x) length(x$tokens),1L))
  units <- data.frame(unit_id = vapply(all_units, `[[`, "", "unit_id"), doc_id = vapply(all_units, `[[`, "", "doc_id"),
    sentence = vapply(all_units, `[[`, 1L, "sentence"), original = vapply(all_units, `[[`, "", "original"),
    cleaned = vapply(all_units, `[[`, "", "cleaned"), stringsAsFactors = FALSE)
  unit_tokens <- lapply(all_units, `[[`, "tokens")
  annotation <- data.frame(); model_info <- list()
  if (linguistic) {
    ling <- annotate_corpus_units(units, docs, cfg, stops,pool=pool,progress=progress)
    processing_audit<-rbind(processing_audit,ling$processing)
    annotation <- ling$annotation; model_info <- ling$models
    unit_tokens <- ling$tokens; all_pairs <- ling$pairs; all_sequences <- ling$sequences
    units$lemmatized <- ling$lemmatized
    units$cleaned <- vapply(unit_tokens, paste, "", collapse = " ")
    total_tokens <- sum(lengths(unit_tokens))
    if (total_tokens > BIBLIO_LIMITS$tokens) abort_user("El corpus lematizado supera un mill\u00f3n de palabras. Usa una muestra.")
  } else units$lemmatized <- NA_character_
  active <- lengths(unit_tokens) > 0
  if (!any(active)) return(list(units = units, counts = NULL, terms = data.frame(), bigrams = data.frame(),
    issues = "No quedan palabras tras la limpieza. Reduce la longitud m\u00ednima o las palabras vac\u00edas; los indicadores bibliom\u00e9tricos siguen disponibles.",
    n_active = 0L, total_tokens = 0L, vocabulary = character(), annotation = annotation, models = model_info, filter_audit = data.frame(),processing=processing_audit))
  tabs <- lapply(unit_tokens[active], table)
  terms <- sort(unique(unlist(lapply(tabs, names), use.names = FALSE)))
  sparse <- Matrix::sparseMatrix(i = rep(seq_along(tabs), lengths(tabs)),
    j = match(unlist(lapply(tabs, names), use.names = FALSE), terms), x = as.numeric(unlist(tabs, use.names = FALSE)),
    dims = c(length(tabs), length(terms)), dimnames = list(units$unit_id[active], terms))
  # La presencia documental se calcula por documento, incluso con frases.
  doc_idx <- match(units$doc_id[active], docs$doc_id)
  doc_map <- Matrix::sparseMatrix(i = doc_idx, j = seq_along(doc_idx), x = 1, dims = c(nrow(docs), length(doc_idx)))
  doc_counts <- doc_map %*% sparse
  df <- as.numeric(Matrix::colSums(doc_counts > 0)); freq <- as.numeric(Matrix::colSums(sparse))
  tf <- sparse / as.numeric(Matrix::rowSums(sparse))
  idf <- log(nrow(sparse) / as.numeric(Matrix::colSums(sparse > 0)))
  tfidf_weights <- tf %*% Matrix::Diagonal(x = idf)
  weight_stats <- sparse_weight_summary(tfidf_weights)
  mean_tfidf <- weight_stats$mean
  rank_score <- tfidf_rank_score(tfidf_weights, cfg$tfidf_stat %||% "mean", cfg$tfidf_scope %||% "all", cfg$tfidf_percentile %||% 75)
  occurrence <- doc_counts %*% Matrix::Diagonal(x = 1 / pmax(freq, 1))
  occ_triplet <- methods::as(occurrence, "TsparseMatrix")
  entropy_parts <- -occ_triplet@x * log(pmax(occ_triplet@x, .Machine$double.eps))
  ent <- numeric(length(terms)); ent_sum <- tapply(entropy_parts, occ_triplet@j + 1L, sum)
  ent[as.integer(names(ent_sum))] <- ent_sum
  ent <- if (nrow(docs) > 1) ent / log(nrow(docs)) else rep(0, length(terms))
  term_table <- data.frame(termino = terms, frecuencia = freq, documentos = df,
    porcentaje_documentos = round(100 * df / nrow(docs), 2), tfidf_medio = mean_tfidf,
    entropia = pmin(1, pmax(0, ent)), bm25_medio = as.numeric(Matrix::colSums(bm25_weights(doc_counts))) / sum(Matrix::rowSums(doc_counts)>0))
  names(weight_stats) <- paste0("tfidf_", names(weight_stats))
  term_table <- cbind(term_table, weight_stats, tfidf_orden = rank_score)
  term_table <- term_table[order(-term_table$frecuencia, term_table$termino), , drop = FALSE]
  choice <- vocabulary_selection(term_table, cfg, nrow(docs))
  reasons <- choice$reasons; eligible <- choice$eligible; vocab <- choice$vocabulary
  term_table$incluido <- term_table$termino %in% vocab
  term_table$motivo_exclusion <- ifelse(term_table$incluido, "Retenido", reasons)
  filter_audit <- as.data.frame(table(term_table$motivo_exclusion), stringsAsFactors = FALSE)
  names(filter_audit) <- c("criterio", "terminos")
  counts <- sparse[, match(vocab, terms), drop = FALSE]
  counts <- counts[Matrix::rowSums(counts) > 0, , drop = FALSE]
  # Presencia de bigramas por documento: una frase repetida cuenta una vez.
  doc_pairs <- split(seq_along(all_pairs), units$doc_id)
  pair_vec <- unlist(lapply(doc_pairs, function(idx) unique(unlist(all_pairs[idx], use.names = FALSE))), use.names = FALSE)
  pair_tab <- sort(table(pair_vec), decreasing = TRUE)
  bigrams <- data.frame(bigrama = names(pair_tab), documentos = as.integer(pair_tab), stringsAsFactors = FALSE)
  if (nrow(bigrams)) bigrams$porcentaje_documentos <- round(100 * bigrams$documentos / nrow(docs), 2)
  issues <- c(sprintf("Unidades sin palabras: %d/%d. Unidades fuera de la matriz por el filtro de vocabulario: %d.", sum(!active), nrow(units), sum(active) - nrow(counts)),
    sprintf("Vocabulario de modelos: %d de %d t\u00e9rminos elegibles; orden: %s.", length(vocab), length(eligible), cfg$term_order))
  if (boilerplate_removed > 0L) issues <- c(issues, sprintf("Avisos finales de derechos de autor retirados del texto analizado en %d documentos (el original se conserva).", boilerplate_removed))
  ngrams <- ngram_summary(all_sequences, units$doc_id, nrow(docs))
  list(units = units, counts = counts, terms = term_table, bigrams = bigrams, ngrams = ngrams, issues = issues,
    n_active = sum(active), total_tokens = total_tokens, vocabulary = vocab, annotation = annotation,
    models = model_info, filter_audit = filter_audit,processing=processing_audit)
}
count_metadata <- function(x, sep = NULL, n_docs = length(x), kind = NULL) {
  # kind = NULL: conteo literal (V3). kind = "keyword"/"author"/"source": unifica variantes de
  # escritura (mayusculas, acentos, puntuacion) y muestra la variante mas frecuente.
  per_doc <- metadata_split(x,sep)
  per_doc <- lapply(per_doc, function(z) z[nzchar(z)])
  merged <- NULL
  if (!is.null(kind)) {
    vm <- variant_map(unlist(per_doc, use.names = FALSE), kind)
    per_doc <- lapply(per_doc, function(z) if (length(z)) unname(vm$map[z]) else z)
    v <- vm$variants
    multi <- v$etiqueta %in% v$etiqueta[duplicated(v$etiqueta)]
    merged <- v[multi, c("etiqueta", "variante", "n"), drop = FALSE]
    names(merged) <- c("elemento", "variante", "documentos_con_variante")
  }
  values <- unlist(lapply(per_doc, unique), use.names = FALSE)
  tb <- sort(table(values), decreasing = TRUE)
  out <- data.frame(elemento = names(tb), documentos = as.integer(tb), porcentaje_documentos = round(100 * as.numeric(tb) / max(1, n_docs), 2), stringsAsFactors = FALSE)
  if (!nrow(out)) out <- data.frame(elemento = character(), documentos = integer(), porcentaje_documentos = numeric(), stringsAsFactors = FALSE)
  if (!is.null(kind)) {
    nv <- if (is.null(merged) || !nrow(merged)) integer() else table(merged$elemento)
    out$variantes_unificadas <- as.integer(ifelse(out$elemento %in% names(nv), nv[out$elemento], 1L))
    attr(out, "variantes") <- merged
  }
  out
}
#' Indicadores bibliometricos descriptivos
#'
#' Produccion anual, fuentes, autores y palabras clave (con unificacion de
#' variantes de escritura si `normalize_labels` esta activo), citas e indice h
#' del corpus observado, y tablas de cobertura y referencias.
#'
#' @param prepared Resultado de [prepare_documents()].
#' @return Lista con `overview`, `annual`, `sources`, `authors`, `keywords`,
#'   `cited`, `extensiones` y `normalizacion`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' biblio_summary(prepare_documents(d, guess_columns(d)))$overview
#' @export
biblio_summary <- function(prepared) {
  d <- prepared$documents; n <- nrow(d); cites <- d$citations[!is.na(d$citations)]
  years <- sort(unique(d$year[!is.na(d$year)]))
  annual <- data.frame(ano = years, documentos = vapply(years, function(y) sum(d$year == y, na.rm = TRUE), 1L))
  ranking <- d[!is.na(d$citations), c("doc_id", "original_id", "title", "year", "source", "citations"), drop = FALSE]
  ranking <- ranking[order(-ranking$citations, ranking$doc_id), , drop = FALSE]
  sorted <- sort(cites, decreasing = TRUE)
  h <- if (length(sorted)) sum(sorted >= seq_along(sorted)) else NA_integer_
  overview <- data.frame(indicador = c("Documentos analizados", "Documentos con a\u00f1o v\u00e1lido", "Documentos con citas v\u00e1lidas",
    "Citas registradas (suma)", "Media de citas (solo valores v\u00e1lidos)", "Mediana de citas (solo valores v\u00e1lidos)", "\u00cdndice h del corpus observado"),
    valor = c(n, sum(!is.na(d$year)), length(cites), if (length(cites)) sum(cites) else NA,
      if (length(cites)) mean(cites) else NA, if (length(cites)) stats::median(cites) else NA, h))
  norm <- isTRUE(prepared$config$normalize_labels %||% TRUE)
  sources <- count_metadata(d$source, kind = if (norm) "source")
  authors <- count_metadata(d$authors, metadata_separator(prepared,"authors"), kind = if (norm) "author")
  authors <- author_citation_metrics(prepared, authors)
  keywords <- count_metadata(d$keywords, metadata_separator(prepared,"keywords"), kind = if (norm) "keyword")
  variants <- do.call(rbind, Filter(Negate(is.null), list(
    if (!is.null(attr(sources, "variantes")) && nrow(attr(sources, "variantes"))) cbind(campo = "Fuente", attr(sources, "variantes")),
    if (!is.null(attr(authors, "variantes")) && nrow(attr(authors, "variantes"))) cbind(campo = "Autor", attr(authors, "variantes")),
    if (!is.null(attr(keywords, "variantes")) && nrow(attr(keywords, "variantes"))) cbind(campo = "Palabra clave", attr(keywords, "variantes")))))
  if (is.null(variants)) variants <- data.frame(campo = character(), elemento = character(), variante = character(), documentos_con_variante = integer())
  rownames(variants) <- NULL
  list(overview = overview, annual = annual, sources = sources, authors = authors, keywords = keywords,
    cited = ranking, extensiones = bibliography_extensions(prepared), normalizacion = variants)
}
#' Modelo LDA (Gibbs) con diagnosticos
#'
#' Ajusta un LDA sobre los conteos de las unidades del corpus. A diferencia de
#' V3, el prior de mezcla por documento `alpha` es explicito y por defecto `1/k`
#' (el valor de `topicmodels`, `50/k`, produce mezclas casi uniformes en textos
#' cortos). Devuelve ademas indicadores de calidad: coherencia, diversidad y
#' convergencia aproximada de la log-verosimilitud.
#'
#' @param corpus Resultado de [prepare_corpus()].
#' @param k Numero de temas (2-12). Para elegirlo con apoyo, usa [lda_select_k()].
#' @param seed Semilla (la ejecucion es reproducible con la misma semilla y corpus).
#' @param iterations Iteraciones de Gibbs tras el burn-in (100-2000).
#' @param alpha Prior de Dirichlet de los temas por documento; `NULL` usa `1/k`.
#' @param delta Prior de Dirichlet de las palabras por tema.
#' @param burnin,thin Iteraciones descartadas y espaciado de las muestras.
#'
#' @return Lista con `top`, `gamma`, `document_topics`, `prevalence`, `examples`,
#'   `diagnostics`, `loglik`, `params`, `units`, `terms` y `ran_at`.
#' @references
#' Blei, D., Ng, A., Jordan, M. (2003). Latent Dirichlet allocation. JMLR.
#' Griffiths, T., Steyvers, M. (2004). Finding scientific topics. PNAS.
#' Wallach, H., Mimno, D., McCallum, A. (2009). Rethinking LDA: why priors matter. NIPS.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' cp <- prepare_corpus(prepare_documents(d, guess_columns(d)))
#' if (requireNamespace("topicmodels", quietly = TRUE)) {
#'   fit <- run_lda(cp, k = 3, iterations = 200)
#'   fit$diagnostics$overview
#' }
#' @export
run_lda <- function(corpus, k = 4L, seed = 2026L, iterations = 500L, alpha = NULL, delta = 0.1, burnin = 100L, thin = 10L) {
  if (!requireNamespace("topicmodels", quietly = TRUE) || !requireNamespace("slam", quietly = TRUE))
    abort_user("LDA necesita los paquetes topicmodels y slam. Inst\u00e1lalos con install.packages(c('topicmodels', 'slam')); el resto de la aplicaci\u00f3n sigue disponible.")
  check_number(k, "El n\u00famero de temas", 2, 12); check_number(iterations, "Las iteraciones", 100, 2000)
  if (is.null(alpha)) alpha <- 1 / k
  check_number(alpha, "El prior alpha", 0.001, 100, FALSE); check_number(delta, "El prior delta", 0.001, 10, FALSE)
  check_number(burnin, "El burn-in", 0, 5000); check_number(thin, "El espaciado (thin)", 1, 1000)
  m <- corpus$counts
  if (is.null(m) || nrow(m) < 3 || ncol(m) < 3) abort_user("LDA necesita al menos tres unidades con palabras y tres t\u00e9rminos. Reduce la presencia m\u00ednima.")
  if (k >= min(dim(m))) abort_user("El n\u00famero de temas debe ser menor que el n\u00famero de unidades y de t\u00e9rminos. Prueba con 2 temas.")
  model_resource_check(m, "LDA")
  dtm <- dtm_from_counts(m)
  gf <- fit_lda_gibbs(dtm, k, seed, burnin = burnin, iter = iterations, thin = thin, alpha = alpha, delta = delta)
  post <- topicmodels::posterior(gf$fit)
  top <- do.call(rbind, lapply(seq_len(k), function(t) {
    ord <- head(order(post$terms[t, ], decreasing = TRUE), 10)
    data.frame(tema = t, termino = colnames(post$terms)[ord], beta = post$terms[t, ord], posicion = seq_along(ord))
  }))
  gamma <- data.frame(unit_id = rownames(post$topics), post$topics, check.names = FALSE)
  names(gamma)[-1] <- paste0("tema_", seq_len(k))
  gamma$doc_id <- corpus$units$doc_id[match(gamma$unit_id, corpus$units$unit_id)]
  weights <- stats::aggregate(gamma[paste0("tema_", seq_len(k))], list(doc_id = gamma$doc_id), mean)
  prevalence <- data.frame(tema = seq_len(k), proporcion_media = colMeans(weights[-1]))
  examples <- do.call(rbind, lapply(seq_len(k), function(t) {
    ord <- head(order(weights[[t + 1]], decreasing = TRUE), 3)
    data.frame(tema = t, doc_id = weights$doc_id[ord], proporcion = weights[[t + 1]][ord])
  }))
  loglik <- gf$loglik
  diagnostics <- lda_diagnostics(post$terms, post$topics, document_term_counts(m, corpus$units), loglik)
  list(top = top, gamma = gamma, document_topics = weights, prevalence = prevalence, examples = examples,
    diagnostics = diagnostics, loglik = loglik,
    params = list(k = k, seed = seed, iterations = iterations, method = "Gibbs", burnin = burnin, thin = gf$thin, alpha = alpha, delta = delta,
      selected_state = "max log-verosimilitud entre los estados guardados", saved_states = gf$states),
    units = nrow(m), terms = ncol(m), ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}

#' Analisis de correspondencias de terminos frecuentes
#'
#' @param corpus Resultado de [prepare_corpus()].
#' @param max_terms Terminos mas frecuentes incluidos (3-150).
#' @param baseline Si se calcula una linea base por permutacion de la inercia por eje.
#' @param B Permutaciones de la linea base.
#' @param seed Semilla de la linea base.
#'
#' @return Lista con `terms`, `units`, `dimensions` (con `umbral_azar_pct` y
#'   `supera_azar` si `baseline = TRUE`), `params` y `ran_at`.
#' @details La linea base permuta, columna a columna, las unidades en las que
#'   aparece cada termino (se conservan los totales por termino). Un eje cuyo
#'   porcentaje de inercia no supera el percentil 95 de esa distribucion no se
#'   distingue de lo esperable por azar con esos totales.
#' @references Greenacre, M. (2017). Correspondence Analysis in Practice (3rd ed.). CRC Press.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' cp <- prepare_corpus(prepare_documents(d, guess_columns(d)))
#' ca <- run_ca(cp, 30, B = 20)
#' ca$dimensions[1:3, ]
#' @export
run_ca <- function(corpus, max_terms = 60L, baseline = TRUE, B = 50L, seed = 2026L) {
  check_number(max_terms, "Los t\u00e9rminos del mapa", 3, 150)
  m <- corpus$counts
  if (is.null(m) || nrow(m) < 3 || ncol(m) < 3) abort_user("El mapa necesita al menos tres unidades y tres t\u00e9rminos. Reduce la presencia m\u00ednima.")
  cols <- head(order(-Matrix::colSums(m), colnames(m)), max_terms)
  m <- m[, cols, drop = FALSE]; m <- m[Matrix::rowSums(m) > 0, , drop = FALSE]
  model_resource_check(m, "Correspondencias")
  if (min(dim(m)) < 3) abort_user("Quedan menos de tres unidades o t\u00e9rminos en el mapa.")
  dense <- as.matrix(m)
  p <- dense / sum(dense); r <- rowSums(p); c <- colSums(p)
  s <- (p - outer(r, c)) / sqrt(outer(r, c))
  decomp <- svd(s, nu = 2, nv = 2)
  eig <- decomp$d^2; inertia <- sum(eig)
  if (!is.finite(inertia) || inertia < 1e-12) abort_user("Las unidades tienen perfiles de palabras iguales; no hay variaci\u00f3n para construir el mapa.")
  if (decomp$d[2] < 1e-10) abort_user("El corpus solo permite una dimensi\u00f3n interpretable. Usa documentos m\u00e1s variados para un mapa de dos ejes.")
  rowcoord <- sweep(decomp$u[, 1:2, drop = FALSE], 1, sqrt(r), "/") %*% diag(decomp$d[1:2])
  colcoord <- sweep(decomp$v[, 1:2, drop = FALSE], 1, sqrt(c), "/") %*% diag(decomp$d[1:2])
  contributions <- sweep(sweep(colcoord^2, 1, c, "*"), 2, eig[1:2], "/") * 100
  # Cos2 respecto a la distancia total al centro, no solo a los dos ejes mostrados.
  distance2 <- colSums(s^2) / c
  cos2 <- rowSums(colcoord^2) / pmax(distance2, .Machine$double.eps)
  terms <- data.frame(termino = colnames(m), eje_1 = colcoord[, 1], eje_2 = colcoord[, 2], masa = c,
    contribucion_eje_1 = contributions[, 1], contribucion_eje_2 = contributions[, 2], cos2_plano = pmin(1, cos2))
  units <- data.frame(unit_id = rownames(m), eje_1 = rowcoord[, 1], eje_2 = rowcoord[, 2])
  dimensions <- data.frame(eje = seq_along(eig), inercia = eig, porcentaje = 100 * eig / inertia)
  base_info <- list(computed = FALSE)
  if (isTRUE(baseline)) {
    check_number(B, "Las permutaciones de la l\u00ednea base", 10, 1000)
    null_pct <- with_seed(seed, perm_ca_pct(dense, as.integer(B)))
    dimensions <- baseline_table(dimensions, null_pct)
    base_info <- list(computed = TRUE, B = as.integer(B), seed = seed, quantile = 0.95,
      description = "Permutaci\u00f3n por columna de las unidades de cada t\u00e9rmino; percentil 95 del porcentaje de inercia por eje.")
  }
  list(terms = terms, units = units, dimensions = dimensions,
    params = list(max_terms = max_terms, normalization = "principal", baseline = base_info),
    ran_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}
safe_csv <- function(d, path) {
  # Evitar que Excel interprete texto importado como formulas.
  out <- d
  for (nm in names(out)) if (is.character(out[[nm]])) {
    danger <- !is.na(out[[nm]]) & grepl("^[[:space:]]*[=+@-]", out[[nm]])
    out[[nm]][danger] <- paste0("'", out[[nm]][danger])
  }
  con <- file(path, open = "wb"); on.exit(close(con))
  writeBin(as.raw(c(0xef, 0xbb, 0xbf)), con)
  txt <- paste(capture.output(utils::write.table(out, sep = ";", row.names = FALSE, na = "", qmethod = "double")), collapse = "\r\n")
  writeBin(charToRaw(enc2utf8(paste0(txt, "\r\n"))), con)
}

# BM25 positivo (IDF Lucene): ponderacion sin consulta, no relevancia validada.
bm25_weights <- function(counts, k1 = 1.2, b = .75) {
  check_number(k1, "k1 BM25", .1, 3, FALSE); check_number(b, "b BM25", 0, 1, FALSE)
  # Validar sobre los valores almacenados: evita densificar matrices dispersas.
  stored <- if (inherits(counts, "sparseMatrix")) as.numeric(methods::as(methods::as(counts, "generalMatrix"), "CsparseMatrix")@x) else as.numeric(counts)
  if (anyNA(stored) || any(!is.finite(stored)) || any(stored < 0)) abort_user("BM25 exige conteos finitos y no negativos.")
  lengths <- as.numeric(Matrix::rowSums(counts)); active <- lengths > 0
  if (!any(active)) return(counts * 0)
  n <- sum(active); df <- as.numeric(Matrix::colSums(counts > 0))
  idf <- log(1 + (n - df + .5) / (df + .5))
  trip <- methods::as(counts, "TsparseMatrix")
  norm <- k1 * (1 - b + b * lengths / mean(lengths[active]))
  values <- idf[trip@j + 1L] * trip@x * (k1 + 1) / (trip@x + norm[trip@i + 1L])
  Matrix::sparseMatrix(i=trip@i+1L, j=trip@j+1L, x=values, dims=dim(counts), dimnames=dimnames(counts))
}
ngram_summary <- function(sequences, doc_ids, n_docs, orders = 1:3) {
  empty <- data.frame(n=integer(), expresion=character(), frecuencia=integer(), documentos=integer(), porcentaje_documentos=numeric(), tfidf_medio=numeric(), entropia=numeric())
  out <- list()
  for (n in orders) {
    rows <- lapply(seq_along(sequences), function(i) {
      grams <- unlist(lapply(sequences[[i]], function(w) {
        if (length(w) < n) return(character())
        idx <- seq_len(length(w)-n+1L)
        windows <- lapply(seq_len(n), function(j) w[idx+j-1L])
        valid <- Reduce(`&`, lapply(windows, nzchar))
        do.call(paste, windows)[valid]
      }), use.names=FALSE)
      if (!length(grams)) return(NULL)
      data.frame(doc_id=doc_ids[i], expresion=grams, stringsAsFactors=FALSE)
    })
    d <- data.table::rbindlist(rows)
    if (!nrow(d)) next
    tab <- d[, list(frecuencia=.N), by=c("doc_id", "expresion")]
    ids <- unique(doc_ids); terms <- sort(unique(tab$expresion))
    m <- Matrix::sparseMatrix(i=match(tab$doc_id,ids),j=match(tab$expresion,terms),x=tab$frecuencia,dims=c(length(ids),length(terms)))
    f <- as.numeric(Matrix::colSums(m)); df <- as.numeric(Matrix::colSums(m>0)); totals <- as.numeric(Matrix::rowSums(m)); active <- totals>0
    tf <- Matrix::Diagonal(x=1/pmax(totals,1)) %*% m
    weights <- tf[active, , drop = FALSE] %*% Matrix::Diagonal(x = log(sum(active)/df))
    weight_stats <- sparse_weight_summary(weights)
    score <- weight_stats$mean
    trip <- methods::as(m, "TsparseMatrix"); prob <- trip@x/f[trip@j+1L]
    entropy <- numeric(length(terms)); e <- tapply(-prob*log(prob),trip@j+1L,sum); entropy[as.integer(names(e))]<-e
    if(n_docs>1) entropy<-entropy/log(n_docs) else entropy[]<-0
    out[[as.character(n)]] <- data.frame(n=n,expresion=terms,frecuencia=f,documentos=df,porcentaje_documentos=100*df/n_docs,tfidf_medio=score,entropia=entropy,
      tfidf_mediana=weight_stats$median,tfidf_mad=weight_stats$mad,tfidf_sd=weight_stats$sd,tfidf_q75=weight_stats$q75,tfidf_mediana_presente=weight_stats$present_median)
  }
  if(!length(out)) return(empty)
  d <- do.call(rbind,out); rownames(d)<-NULL
  d[order(d$n,-d$documentos,-d$frecuencia,d$expresion),]
}
reference_sets <- function(prepared) {
  x <- prepared$documents$references %||% rep("",nrow(prepared$documents))
  lapply(strsplit(clean_value(x), prepared$config$metadata_sep, fixed=TRUE), function(z) {
    z <- normalize_key(z); sort(unique(z[nzchar(z)]))
  })
}
bibliography_extensions <- function(prepared) {
  d<-prepared$documents; sets<-reference_sets(prepared)
  refs<-count_metadata(vapply(sets,paste,"",collapse=prepared$config$metadata_sep),prepared$config$metadata_sep,nrow(d))
  src<-count_metadata(d$source,kind=if(isTRUE(prepared$config$normalize_labels %||% TRUE)) "source"); if(nrow(src)) {src$posicion<-seq_len(nrow(src));src$porcentaje_acumulado<-100*cumsum(src$documentos)/sum(src$documentos)}
  cohort<-d[c("doc_id","year","citations")]; cohort$documentos_cohorte<-NA_integer_;cohort$citas_relativas_cohorte<-NA_real_
  for(y in unique(d$year[!is.na(d$year)])) {
    ix<-which(!is.na(d$year)&d$year==y&!is.na(d$citations));cohort$documentos_cohorte[ix]<-length(ix)
    if(length(ix)>=5 && mean(d$citations[ix])>0) cohort$citas_relativas_cohorte[ix]<-d$citations[ix]/mean(d$citations[ix])
  }
  list(referencias=refs,concentracion_fuentes=src,citas_cohorte=cohort,
    cobertura=data.frame(campo=c("Referencias citadas","Revista / fuente","Autores","A\u00f1o","Citas registradas"),documentos_validos=c(sum(lengths(sets)>0),sum(nzchar(d$source)),sum(nzchar(d$authors)),sum(!is.na(d$year)),sum(!is.na(d$citations))),total=nrow(d)))
}

apply_language_overrides <- function(values, overrides=character()) {
  if(!length(overrides)) return(values)
  idx<-suppressWarnings(as.integer(names(overrides)))
  if(is.null(names(overrides)) || anyNA(idx) || anyDuplicated(idx) || any(idx<1 | idx>length(values))) abort_user("Las asignaciones manuales de idioma no corresponden a filas del CSV actual. Revisa los idiomas.")
  values[idx]<-as.character(overrides);values
}
