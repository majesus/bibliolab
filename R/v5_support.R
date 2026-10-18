# Funciones comunes V5: decisiones explicitas, estadisticos dispersos y ayudas.
sparse_quantile <- function(values, size, probs) {
    values <- sort(values[values > 0]); zero <- size - length(values)
    if (!size) return(rep(NA_real_, length(probs)))
    at <- function(k) ifelse(k <= zero, 0, values[pmax(1L, k - zero)])
    if (!length(values)) return(rep(0, length(probs)))
    h <- 1 + (size - 1) * probs; lo <- floor(h); hi <- ceiling(h)
    at(lo) + (h - lo) * (at(hi) - at(lo))
}
sparse_weight_summary <- function(weights) {
  m <- methods::as(weights, "CsparseMatrix")
  n <- nrow(m)
  out <- lapply(seq_len(ncol(m)), function(j) {
    a <- m@p[j] + 1L; b <- m@p[j + 1L]
    x <- if (a <= b) m@x[a:b] else numeric()
    x <- x[x > 0]; q <- sparse_quantile(x, n, c(.25, .5, .75, .9))
    avg <- sum(x) / max(1, n)
    mad <- if(q[2]==0) 0 else stats::median(c(abs(x - q[2]), rep(abs(q[2]), n - length(x))))
    present <- if (length(x)) stats::median(x) else 0
    c(mean = avg, sd = if (n > 1) sqrt(max(0, (sum(x^2) - n * avg^2) / (n - 1))) else 0,
      q25 = q[1], median = q[2], q75 = q[3], q90 = q[4],
      mad = mad, present_mean = if (length(x)) mean(x) else 0,
      present_median = present, present_mad = if (length(x)) stats::mad(x, constant = 1) else 0)
  })
  if (!length(out)) return(data.frame())
  as.data.frame(do.call(rbind, out))
}

tfidf_rank_score <- function(weights, statistic = "mean", scope = "all", percentile = 75) {
  if (!statistic %in% c("mean", "median", "q25", "q75", "q90", "percentile")) abort_user("Elige media, mediana o un percentil de TF-IDF.")
  if (!scope %in% c("all", "present")) abort_user("Elige todas las unidades o solo aquellas donde aparece el t\u00e9rmino.")
  check_number(percentile, "El percentil de TF-IDF", 0, 100, FALSE)
  m <- methods::as(weights, "CsparseMatrix")
  vapply(seq_len(ncol(m)), function(j) {
    a <- m@p[j]+1L;b <- m@p[j+1L];x<-if(a<=b)m@x[a:b] else numeric();x<-x[x>0]
    size<-if(scope=="present")length(x) else nrow(m)
    if (!size) return(0)
    if (statistic == "mean") return(sum(x)/size)
    prob <- switch(statistic, median = .5, q25 = .25, q75 = .75, q90 = .9, percentile = percentile / 100)
    sparse_quantile(x,size,prob)
  }, numeric(1))
}

author_citation_metrics <- function(prepared, authors) {
  d <- prepared$documents
  entries <- lapply(metadata_split(d$authors,metadata_separator(prepared,"authors")), function(x) unique(trimws(x)))
  if (isTRUE(prepared$config$normalize_labels %||% TRUE)) {
    vm <- variant_map(unlist(entries), "author")
    entries <- lapply(entries, function(x) unname(vm$map[x[nzchar(x)]]))
  }
  # Indice autor -> documentos construido en una sola pasada (coste lineal en las apariciones),
  # en lugar de recorrer todos los conjuntos de autores para cada autor.
  entries <- lapply(entries, function(x) unique(x[!is.na(x)]))
  index <- split(rep(seq_along(entries), lengths(entries)), factor(unlist(entries, use.names = FALSE)))
  ans <- lapply(authors$elemento, function(a) {
    ids <- as.integer(index[[a]] %||% integer())
    ct <- d$citations[ids]; valid <- ct[is.finite(ct)]
    s <- sort(valid, decreasing = TRUE)
    data.frame(citas_validas = length(valid), citas_ausentes = sum(!is.finite(ct)),
      citas_suma = if (length(valid)) sum(valid) else NA_real_,
      h_corpus = if (length(valid)) sum(s >= seq_along(s)) else NA_integer_)
  })
  if (!length(ans)) return(authors)
  out <- cbind(authors, do.call(rbind, ans))
  attr(out,"variantes") <- attr(authors,"variantes")
  out
}

model_resource_check <- function(m, method) {
  # Limites de recursos del motor local; no son requisitos estadisticos.
  if (is.null(m)) abort_user("Prepara vocabulario antes de ejecutar el modelo.")
  cells <- as.double(nrow(m)) * ncol(m)
  if (method == "LDA") {
    tokens <- sum(m)
    if (nrow(m) > BIBLIO_LIMITS$units || ncol(m) > 2500 || tokens > BIBLIO_LIMITS$tokens)
      abort_user(sprintf("LDA recibe %s unidades, %s t\u00e9rminos y %s tokens. El motor local admite hasta 20.000 unidades, 2.500 t\u00e9rminos y un mill\u00f3n de tokens. En 02 reduce M\u00e1ximo de t\u00e9rminos o Muestra (%%); si dividiste en frases, usa documentos. Despu\u00e9s pulsa Preparar corpus.", nrow(m), ncol(m), tokens))
  } else if (cells > 5000000) {
    abort_user(sprintf("%s recibe %s unidades \u00d7 %s t\u00e9rminos (%s celdas). El c\u00e1lculo denso se limita a cinco millones de celdas. Reduce M\u00e1ximo de t\u00e9rminos de este modelo; si a\u00fan lo supera, en 02 reduce Muestra (%%) y prepara de nuevo.", method, nrow(m), ncol(m), format(cells, scientific = FALSE)))
  }
  invisible(TRUE)
}

display_label <- function(x, kind = "title") {
  vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) return(s)
    # Solo presentacion: las claves, textos originales y exportaciones mantienen su escritura.
    if (s != toupper(s) && s != tolower(s)) return(s)
    if (kind == "source") {
      words <- strsplit(tolower(s), " ", fixed = TRUE)[[1]]
      small <- c("of", "and", "the", "in", "for", "de", "del", "la", "y", "et", "on")
      acronyms <- c("ieee", "acm", "jama", "plos", "bmj", "pnas")
      words <- vapply(seq_along(words), function(i) {
        w <- words[i]
        if (w %in% acronyms) toupper(w) else if (i > 1 && w %in% small) w else paste0(toupper(substr(w, 1, 1)), substring(w, 2))
      }, "")
      return(paste(words, collapse = " "))
    }
    paste0(toupper(substr(s, 1, 1)), substring(tolower(s), 2))
  }, "", USE.NAMES = FALSE)
}

predictive_options <- function(max_options = 100L) list(maxOptions = max_options, diacritics = TRUE,
  placeholder = "Escribe parte del t\u00edtulo, nombre o ID\u2026", searchConjunction = "and",
  score = I("function(search){var fold=function(s){return String(s).normalize('NFD').replace(/[\\u0300-\\u036f]/g,'').toLowerCase();};var q=fold(search).trim().split(/\\s+/);return function(item){var t=fold(item.label || item.text || '');return q.every(function(w){return t.indexOf(w)>=0;}) ? 1 : 0;};}"))

rank_controls <- function(key, author = FALSE) tagList(
  tags$div(class = "row control-row", column(if (author) 4 else 6,
    selectInput(paste0(key, "_n"), "Registros que quieres explorar", c(10, 25, 50, 100, 250, 1000), selected = 25)),
    column(if (author) 4 else 6, numericInput(paste0(key, "_page"), "P\u00e1gina del gr\u00e1fico / 50 barras por p\u00e1gina", 1, 1, 20)),
    if (author) column(4, selectInput("authors_order", "Ordenar autores por", c("Documentos" = "documentos", "\u00cdndice h del corpus" = "h_corpus", "Suma de citas v\u00e1lidas" = "citas_suma")))),
  hint(paste0("Estos controles cambian lo que consultas, no los documentos ni los c\u00e1lculos. El gr\u00e1fico presenta hasta 50 filas por p\u00e1gina para mantener las etiquetas legibles. Elige 100 o 1.000 registros y cambia la p\u00e1gina. Ver tabla permite consultar y ordenar todas las filas.",
    if (author) " Documentos es la presencia del autor en el corpus; citas v\u00e1lidas son las citas disponibles en los registros; el \u00edndice h se calcula solo con las publicaciones de este corpus. Ninguna de las tres medidas es una evaluaci\u00f3n integral de la persona.")))

rank_slice <- function(d, n = 25L, page = 1L, metric = "documentos") {
  n <- suppressWarnings(as.integer(n)); page <- suppressWarnings(as.integer(page))
  if (!length(n) || is.na(n) || n < 1 || n > 1000) n <- 25L
  if (!length(page) || is.na(page) || page < 1) page <- 1L
  if (metric %in% names(d)) d <- d[order(-d[[metric]], d$elemento, na.last = TRUE), , drop = FALSE]
  d <- head(d, n); total <- nrow(d); page <- min(page, max(1, ceiling(total / 50)))
  idx <- if (total) seq.int((page - 1) * 50 + 1, min(page * 50, total)) else integer()
  list(data = d[idx, , drop = FALSE], total = total, page = page, pages = max(1, ceiling(total / 50)))
}

year_axis <- function(years) ggplot2::scale_x_continuous(breaks = unique(round(pretty(range(years), n = min(12, length(unique(years)))))), minor_breaks = NULL)

ordination_quadrant <- function(d, quadrant = "all") {
  keep <- switch(quadrant,pp=d$eje_1>=0 & d$eje_2>=0,np=d$eje_1<0 & d$eje_2>=0,nn=d$eje_1<0 & d$eje_2<0,pn=d$eje_1>=0 & d$eje_2<0,rep(TRUE,nrow(d)))
  d[keep,,drop=FALSE]
}

quadrant_labels <- function(d, n = 16L) {
  priority <- order(-(d$contribucion_eje_1+d$contribucion_eje_2))
  keys <- ifelse(d$eje_1>=0,ifelse(d$eje_2>=0,"pp","pn"),ifelse(d$eje_2>=0,"np","nn"))
  first <- unlist(lapply(c("pp","np","nn","pn"),function(k)head(priority[keys[priority]==k],ceiling(n/4))),use.names=FALSE)
  # Una seleccion equilibrada de candidatos y separacion espacial conservadora.
  spaced_labels(d,"eje_1","eje_2",unique(c(first,priority)),as.integer(n))
}

citation_categories <- function(citations, method = "quartile", cutoff = 10) {
  valid <- is.finite(citations); ans <- rep("",length(citations))
  if (method == "cutoff") {
    check_number(cutoff,"El umbral de citas",0,10000000)
    ans[valid] <- ifelse(citations[valid] <= cutoff,paste0("Citas \u2264 ",cutoff),paste0("Citas > ",cutoff))
  } else {
    breaks <- unique(as.numeric(stats::quantile(citations[valid],c(0,.25,.5,.75,1),type=7)))
    if(length(breaks)<2) abort_user("Las citas v\u00e1lidas son iguales. No se pueden formar categor\u00edas diferentes; elige otra agrupaci\u00f3n.")
    ans[valid] <- as.character(cut(citations[valid],breaks=breaks,include.lowest=TRUE,dig.lab=8))
  }
  ans
}

vocabulary_decision_text <- function() tagList(
  tags$p("Empieza con documentos completos, presencia m\u00ednima 2 y sin filtros de TF-IDF o entrop\u00eda. Examina t\u00e9rminos y documentos antes de eliminar palabras. Para un corpus grande, compara una presencia m\u00ednima de aproximadamente 0,5\u20131 %: es una comprobaci\u00f3n de sensibilidad, no un umbral universal."),
  tags$p("Frecuencia conserva palabras comunes; TF-IDF favorece t\u00e9rminos que distinguen textos; BM25 limita el efecto de repeticiones y corrige longitud. Ninguno valida un concepto. Conserva t\u00e9rminos centrales para tu pregunta aunque aparezcan en muchos documentos."),
  tags$p("La media usa todas las unidades, incluidos ceros. La mediana y los percentiles resisten mejor valores extremos, pero suelen valer cero en matrices dispersas. Solo unidades con peso positivo describe el uso donde el t\u00e9rmino distingue textos; consulta tambi\u00e9n presencia para no favorecer una palabra aislada. MAD es mediana de desviaciones absolutas, sin factor 1,4826. Es dispersi\u00f3n, no un criterio de relevancia."),
  tags$p("Las cifras de TF-IDF no coinciden entre pantallas porque cada salida usa su propia versi\u00f3n. Preparaci\u00f3n multiplica la frecuencia relativa de cada texto por ln(N / df). LSA y ACP usan la rareza suavizada ln((N + 1) / (df + 1)) + 1; el ACP, adem\u00e1s, centra y reescala cada columna. Lectura enlazada suma log(1 + frecuencia) \u00d7 ln(N / df) sobre las fichas. Compara el orden dentro de una misma pantalla, no la cifra entre pantallas."))

keyword_availability <- function(prepared) {
  col <- prepared$mapping$keywords %||% ""; n <- sum(nzchar(prepared$documents$keywords))
  if (!nzchar(col)) return("No hay columna de palabras clave asignada. En 02 / Correspondencia de campos, asigna DE (Author Keywords) o la columna de palabras clave de tu exportaci\u00f3n. Los res\u00famenes no contienen autom\u00e1ticamente keywords declaradas.")
  if (!n) return(paste0("La columna \u00ab", col, "\u00bb est\u00e1 asignada, pero no contiene palabras clave en los documentos retenidos. Comprueba el archivo y exporta ese campo desde la base de datos. El n\u00famero de res\u00famenes no resuelve esta ausencia."))
  paste(n, "de", nrow(prepared$documents), "documentos tienen palabras clave declaradas. Un documento puede aportar varias: sus porcentajes no tienen por qu\u00e9 sumar 100 %.")
}

keyword_field_audit <- function(raw,prepared) {
  keys<-gsub("[^a-z0-9]","",ascii_fold(tolower(names(raw))))
  known<-c("authorkeywords","keywordsauthor","authorskeywords","keywords","palabrasclave","de","indexkeywords","keywordsplus","id")
  identifier<-guess_columns(raw)$id
  ix<-which((keys %in% known & !(keys=="id" & names(raw)==identifier)) | names(raw)==(prepared$mapping$keywords %||% ""))
  if(!length(ix)) return(data.frame(Campo=character(),Origen=character(),Documentos_archivo=integer(),Documentos_retenidos=integer(),Asignado=logical()))
  data.frame(Campo=names(raw)[ix],Origen=ifelse(keys[ix] %in% c("indexkeywords","keywordsplus","id"),"Indizaci\u00f3n / verificar significado del campo", "Palabras clave / verificar exportaci\u00f3n"),
    Documentos_archivo=vapply(raw[ix],function(z)sum(nzchar(clean_value(z))),1L),
    Documentos_retenidos=vapply(raw[ix],function(z)sum(nzchar(clean_value(z[prepared$documents$source_row]))),1L),
    Asignado=names(raw)[ix]==(prepared$mapping$keywords %||% ""),stringsAsFactors=FALSE)
}
