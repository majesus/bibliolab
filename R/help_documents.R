# Ayudas como documentos. Cada clave de ayuda tiene un archivo inst/app/help/<clave>.md,
# que se edita como texto. Este modulo lo convierte en HTML con un subconjunto deliberadamente
# pequeno de Markdown, sin dependencias adicionales.
#
# Formato de un documento:
#   ---                       cabecera: titulo, objetivo y fuentes ("etiqueta | url")
#   ## Seccion                bloque plegable; solo la primera seccion se muestra abierta
#   ### Subtitulo             encabezado dentro de una seccion
#   texto                     las lineas consecutivas forman un parrafo
#   - vinetas / 1. listas     una linea por elemento; la sangria de dos espacios anida
#   > cita o analogia         bloque destacado (admite parrafos, listas y tablas)
#   | a | b |                 tabla: primera fila = encabezado, segunda = separador
#   $$ formula $$             una sola linea, centrada
#   +++ Titulo                bloque plegado dentro de una seccion (p. ej. nota tecnica);
#   ...                       se cierra con una linea que solo contiene +++
#   **negrita** *cursiva* `codigo`

help_inline <- function(x) {
  x <- htmltools::htmlEscape(x)
  emphasis <- function(s) {
    s <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", s, perl = TRUE)
    gsub("(?<![*\\w])\\*(?![\\s*])(.+?)(?<![\\s*])\\*(?![*\\w])", "<em>\\1</em>", s, perl = TRUE)
  }
  spans <- gregexpr("`[^`]+`", x, perl = TRUE)
  code <- regmatches(x, spans)[[1]]
  plain <- regmatches(x, spans, invert = TRUE)[[1]]
  out <- emphasis(plain[1])
  for (i in seq_along(code)) {
    out <- paste0(out, "<code>", substr(code[i], 2L, nchar(code[i]) - 1L), "</code>", emphasis(plain[i + 1L]))
  }
  out
}

help_cells <- function(line) {
  line <- trimws(line)
  line <- sub("^\\|", "", line)
  line <- sub("\\|$", "", line)
  trimws(strsplit(line, "|", fixed = TRUE)[[1]])
}

help_list_html <- function(items, i, indent) {
  ordered <- items$ordered[i]
  tag <- if (ordered) "ol" else "ul"
  start <- if (ordered && !is.na(items$number[i]) && items$number[i] != 1L) paste0(" start=\"", items$number[i], "\"") else ""
  html <- paste0("<", tag, start, ">")
  while (i <= nrow(items) && items$indent[i] == indent && items$ordered[i] == ordered) {
    li <- paste0("<li>", help_inline(items$text[i]), items$extra[i])
    i <- i + 1L
    if (i <= nrow(items) && items$indent[i] > indent) {
      nested <- help_list_html(items, i, items$indent[i])
      li <- paste0(li, nested$html)
      i <- nested$position
    }
    html <- paste0(html, li, "</li>")
  }
  list(html = paste0(html, "</", tag, ">"), position = i)
}

help_blocks <- function(lines) {
  n <- length(lines)
  blank <- function(l) !nzchar(trimws(l))
  marker <- "^\\s*([-*]|[0-9]+[.)])\\s+\\S"
  special <- function(l) grepl("^(#{2,3}\\s|\\+\\+\\+|>|\\||\\$\\$)", l) || grepl(marker, l)
  out <- character()
  i <- 1L
  while (i <= n) {
    l <- lines[i]
    if (blank(l) || grepl("^-{3,}\\s*$", l) || grepl("^#\\s+", l)) {
      i <- i + 1L
    } else if (grepl("^###\\s+", l)) {
      out <- c(out, paste0("<h4>", help_inline(sub("^###\\s+", "", l)), "</h4>"))
      i <- i + 1L
    } else if (grepl("^\\+\\+\\+\\s*\\S", l)) {
      j <- i + 1L
      while (j <= n && !grepl("^\\+\\+\\+\\s*$", lines[j])) j <- j + 1L
      inner <- if (j > i + 1L) lines[(i + 1L):(j - 1L)] else character()
      out <- c(out, paste0("<details class=\"help-fold\"><summary>", help_inline(sub("^\\+\\+\\+\\s*", "", l)),
        "</summary>", help_blocks(inner), "</details>"))
      i <- j + 1L
    } else if (grepl("^>", l)) {
      j <- i
      while (j <= n && grepl("^>", lines[j])) j <- j + 1L
      out <- c(out, paste0("<blockquote>", help_blocks(sub("^>\\s?", "", lines[i:(j - 1L)])), "</blockquote>"))
      i <- j
    } else if (grepl("^\\|", l)) {
      j <- i
      while (j <= n && grepl("^\\|", lines[j])) j <- j + 1L
      rows <- lines[i:(j - 1L)]
      rows <- rows[!grepl("^\\|[\\s:|-]+\\|?\\s*$", rows, perl = TRUE) | seq_along(rows) == 1L]
      cells <- lapply(rows, help_cells)
      head <- paste0("<thead><tr>", paste0("<th>", vapply(cells[[1]], help_inline, ""), "</th>", collapse = ""), "</tr></thead>")
      body <- vapply(cells[-1], function(r) paste0("<tr>", paste0("<td>", vapply(r, help_inline, ""), "</td>", collapse = ""), "</tr>"), "")
      out <- c(out, paste0("<div class=\"help-scroll\" role=\"region\" tabindex=\"0\" aria-label=\"Tabla desplazable horizontalmente\"><table class=\"help-table\">", head, "<tbody>", paste(body, collapse = ""), "</tbody></table></div>"))
      i <- j
    } else if (grepl("^\\$\\$.*\\$\\$\\s*$", l)) {
      out <- c(out, paste0("<p class=\"help-formula\">", htmltools::htmlEscape(trimws(sub("\\$\\$\\s*$", "", sub("^\\$\\$", "", l)))), "</p>"))
      i <- i + 1L
    } else if (grepl(marker, l)) {
      formula <- "^\\s*\\$\\$.*\\$\\$\\s*$"
      j <- i
      while (j <= n && (grepl(marker, lines[j]) || grepl(formula, lines[j]))) j <- j + 1L
      raw <- lines[i:(j - 1L)]
      is_formula <- grepl(formula, raw) & !grepl(marker, raw)
      # Una formula dentro de una lista pertenece al elemento anterior.
      extra <- character(sum(!is_formula))
      owner <- cumsum(!is_formula)
      for (k in which(is_formula)) {
        text <- trimws(sub("\\$\\$\\s*$", "", sub("^\\s*\\$\\$", "", raw[k])))
        extra[owner[k]] <- paste0(extra[owner[k]], "<p class=\"help-formula\">", htmltools::htmlEscape(text), "</p>")
      }
      raw <- raw[!is_formula]
      indent <- nchar(sub("^(\\s*).*$", "\\1", raw))
      items <- data.frame(indent = indent, ordered = grepl("^\\s*[0-9]+[.)]", raw),
        number = suppressWarnings(as.integer(sub("^\\s*([0-9]+)[.)].*$", "\\1", raw))),
        text = sub("^\\s*([-*]|[0-9]+[.)])\\s+", "", raw), extra = extra, stringsAsFactors = FALSE)
      start <- min(items$indent)
      pos <- 1L
      while (pos <= nrow(items)) {
        built <- help_list_html(items, pos, start)
        out <- c(out, built$html)
        pos <- if (built$position > pos) built$position else pos + 1L
      }
      i <- j
    } else {
      j <- i + 1L
      while (j <= n && !blank(lines[j]) && !special(lines[j])) j <- j + 1L
      out <- c(out, paste0("<p>", help_inline(paste(trimws(lines[i:(j - 1L)]), collapse = " ")), "</p>"))
      i <- j
    }
  }
  paste(out, collapse = "")
}

help_parse_document <- function(text) {
  lines <- strsplit(gsub("\r\n?", "\n", text), "\n", fixed = TRUE)[[1]]
  lines <- sub("[ \t]+$", "", lines)
  meta <- list(titulo = "", objetivo = "", fuentes = character())
  if (length(lines) && grepl("^---\\s*$", lines[1])) {
    close <- which(grepl("^---\\s*$", lines[-1]))[1] + 1L
    if (is.na(close)) stop("La cabecera de la ayuda no se cierra con ---.", call. = FALSE)
    for (l in lines[2:max(2L, close - 1L)]) {
      if (grepl("^titulo:", l)) meta$titulo <- trimws(sub("^titulo:", "", l))
      else if (grepl("^objetivo:", l)) meta$objetivo <- trimws(sub("^objetivo:", "", l))
      else if (grepl("^\\s+-\\s+.+\\|\\s*\\S+\\s*$", l)) {
        label <- trimws(sub("^\\s+-\\s+(.+?)\\s*\\|.*$", "\\1", l, perl = TRUE))
        url <- trimws(sub("^.*\\|\\s*(\\S+)\\s*$", "\\1", l))
        meta$fuentes[label] <- url
      }
    }
    lines <- if (close < length(lines)) lines[(close + 1L):length(lines)] else character()
  }
  starts <- which(grepl("^##\\s+", lines))
  html <- if (length(starts)) help_blocks(lines[seq_len(starts[1] - 1L)]) else help_blocks(lines)
  for (k in seq_along(starts)) {
    end <- if (k < length(starts)) starts[k + 1L] - 1L else length(lines)
    body <- if (end > starts[k]) lines[(starts[k] + 1L):end] else character()
    html <- paste0(html, "<details class=\"help-section\"", if (k == 1L) " open" else "", "><summary>",
      help_inline(sub("^##\\s+", "", lines[starts[k]])), "</summary><div class=\"help-section-body\">", help_blocks(body), "</div></details>")
  }
  list(meta = meta, html = html)
}

help_document_dir <- function() system.file("app", "help", package = "bibliolab")

help_document_keys <- function() {
  dir <- help_document_dir()
  if (!nzchar(dir)) return(character())
  sub("[.]md$", "", sort(list.files(dir, pattern = "[.]md$")))
}

help_document <- function(key) {
  path <- file.path(help_document_dir(), paste0(key, ".md"))
  if (!nzchar(help_document_dir()) || !file.exists(path)) return(NULL)
  text <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  doc <- help_parse_document(enc2utf8(text))
  doc$key <- key
  doc
}

# Cuerpo del modal de ayuda para una clave; NULL si la clave no tiene documento.
help_modal_body <- function(key) {
  doc <- help_document(key)
  if (is.null(doc)) return(NULL)
  tags <- htmltools::tags
  sources <- doc$meta$fuentes
  tags$div(class = "lesson help-doc",
    if (nzchar(doc$meta$objetivo)) tags$p(class = "modal-lead", doc$meta$objetivo),
    htmltools::HTML(doc$html),
    if (length(sources)) tags$div(class = "source-links", tags$h3("Documentación para ampliar"),
      lapply(names(sources), function(label) tags$p(tags$a(href = sources[[label]], target = "_blank", rel = "noopener", label)))))
}
