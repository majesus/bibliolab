# Referencias descriptivas independientes del preprocesamiento y los modelos.
# Se usan tablas completas: nunca el ranking recortado para dibujar una figura.
lotka_regularity <- function(authors) {
  empty <- data.frame(documentos_por_autor = integer(), autores = integer(),
    porcentaje_autores = numeric(), autores_referencia = numeric())
  if (!nrow(authors)) return(empty)
  productivity <- as.integer(authors$documentos)
  productivity <- productivity[is.finite(productivity) & productivity > 0L]
  if (!length(productivity)) return(empty)
  x <- seq_len(max(productivity))
  observed <- tabulate(productivity, nbins = length(x))
  reference <- x^(-2)
  data.frame(documentos_por_autor = x, autores = observed,
    porcentaje_autores = 100 * observed / length(productivity),
    autores_referencia = length(productivity) * reference / sum(reference))
}

bradford_regularity <- function(sources) {
  empty_sources <- data.frame(fuente = character(), documentos = integer(),
    rango = integer(), documentos_acumulados = numeric(), porcentaje_acumulado = numeric(), zona = integer())
  zones <- data.frame(zona = 1:3, fuentes = integer(3), documentos = numeric(3),
    porcentaje_documentos = numeric(3), fuentes_relativas_nucleo = rep(NA_real_, 3),
    multiplicador_anterior = rep(NA_real_, 3))
  if (!nrow(sources)) return(list(fuentes = empty_sources, zonas = zones, empates = FALSE))
  d <- sources[is.finite(sources$documentos) & sources$documentos > 0, , drop = FALSE]
  if (!nrow(d)) return(list(fuentes = empty_sources, zonas = zones, empates = FALSE))
  d <- d[order(-d$documentos, enc2utf8(d$elemento), method = "radix"), , drop = FALSE]
  total <- sum(d$documentos)
  accumulated <- cumsum(d$documentos)
  # Se incluye entera la fuente que alcanza cada tercio; no se divide una revista.
  cuts <- vapply(c(1/3, 2/3), function(p) which(accumulated >= total * p)[1], 1L)
  rank <- seq_len(nrow(d))
  zone <- 1L + as.integer(rank > cuts[1]) + as.integer(rank > cuts[2])
  sources_out <- data.frame(fuente = d$elemento, documentos = d$documentos,
    rango = rank, documentos_acumulados = accumulated,
    porcentaje_acumulado = 100 * accumulated / total, zona = zone)
  zones$fuentes <- tabulate(zone, nbins = 3L)
  zones$documentos <- vapply(1:3, function(z) sum(d$documentos[zone == z]), 0)
  zones$porcentaje_documentos <- 100 * zones$documentos / total
  zones$fuentes_relativas_nucleo <- zones$fuentes / zones$fuentes[1]
  for (z in 2:3) if (zones$fuentes[z - 1] > 0 && zones$fuentes[z] > 0)
    zones$multiplicador_anterior[z] <- zones$fuentes[z] / zones$fuentes[z - 1]
  valid_cuts <- unique(cuts[cuts < nrow(d)])
  ties <- any(d$documentos[valid_cuts] == d$documentos[valid_cuts + 1L])
  list(fuentes = sources_out, zonas = zones, empates = ties)
}

zipf_regularity <- function(terms) {
  empty <- data.frame(rango = integer(), termino = character(), frecuencia = numeric(),
    porcentaje_apariciones = numeric(), frecuencia_referencia = numeric())
  if (!nrow(terms)) return(empty)
  d <- terms[is.finite(terms$frecuencia) & terms$frecuencia > 0, , drop = FALSE]
  if (!nrow(d)) return(empty)
  d <- d[order(-d$frecuencia, enc2utf8(d$termino), method = "radix"), , drop = FALSE]
  rank <- seq_len(nrow(d)); total <- sum(d$frecuencia)
  reference <- 1 / rank
  data.frame(rango = rank, termino = d$termino, frecuencia = d$frecuencia,
    porcentaje_apariciones = 100 * d$frecuencia / total,
    frecuencia_referencia = total * reference / sum(reference))
}

biblio_regularities <- function(prepared, corpus, bibliography = NULL) {
  if (is.null(bibliography)) bibliography <- biblio_summary(prepared)
  documents <- prepared$documents
  coverage <- data.frame(campo = c("Autores", "Fuentes", "Texto limpio"),
    documentos_con_datos = c(sum(nzchar(clean_value(documents$authors))),
      sum(nzchar(clean_value(documents$source))),
      length(unique(corpus$units$doc_id[nzchar(clean_value(corpus$units$cleaned))]))),
    documentos_totales = nrow(documents))
  list(lotka = lotka_regularity(bibliography$authors),
    bradford = bradford_regularity(bibliography$sources),
    zipf = zipf_regularity(corpus$terms), cobertura = coverage)
}

regularity_tables <- function(fit) list(regularidades_cobertura = fit$cobertura,
  lotka_productividad = fit$lotka, bradford_zonas = fit$bradford$zonas,
  bradford_fuentes = fit$bradford$fuentes, zipf_rango_frecuencia = fit$zipf)

regularity_numbered_points <- function(values, compact = FALSE, canvas_width = 1000) {
  # Seleccion de rotulos en coordenadas de pantalla; no mueve ni elimina datos.
  d <- values[values$observado > 0, , drop = FALSE]
  if (!nrow(d)) return(d)
  xr <- range(log10(values$x)); yr <- range(log10(c(d$observado, values$referencia)))
  span <- pmax(c(diff(xr), diff(yr)), 1e-8)
  width <- max(120, canvas_width - if (compact) 115 else 160)
  height <- if (compact) 290 else 480
  px <- (log10(d$x) - xr[1]) / (span[1] * 1.16) * width
  py <- (log10(d$observado) - yr[1]) / (span[2] * 1.21) * height
  diameter <- max(if (compact) 30 else 27, max(nchar(as.character(d$x))) * 8 + 10)
  keep <- integer()
  for (i in seq_len(nrow(d))) {
    if (!length(keep) || all(abs(px[i] - px[keep]) >= diameter | abs(py[i] - py[keep]) >= diameter))
      keep <- c(keep, i)
  }
  d[keep, , drop = FALSE]
}

regularity_reading <- function(fit, kind) {
  number <- function(value, digits = 1L) formatC(value, format = "f", digits = digits, decimal.mark = ",")
  if (kind == "lotka") {
    d <- fit$lotka
    if (!nrow(d)) return("No hay autores reconocidos para describir la productividad. Revisa el campo y su separador en 02.")
    count <- function(x) sum(d$autores[d$documentos_por_autor == x])
    first <- count(1); total <- sum(d$autores)
    base <- sprintf("Se reconocen %d autores: %d con un documento, %d con dos y %d con tres; la productividad m\u00e1xima es %d documentos por autor.", total, first, count(2), count(3), max(d$documentos_por_autor))
    comparison <- if (first > 0) sprintf("Por cada 100 autores con un documento, se observan %s con dos y %s con tres; las proporciones cl\u00e1sicas son 25 y aproximadamente 11,1.", number(100 * count(2)/first), number(100 * count(3)/first)) else
      "No hay autores con un solo documento: no puede calcularse la comparaci\u00f3n relativa por cada 100 autores de esa clase."
    return(paste(base, comparison, "Es una comparaci\u00f3n descriptiva de estas clases, no un contraste de la distribuci\u00f3n completa."))
  }
  if (kind == "bradford") {
    d <- fit$bradford
    if (!nrow(d$fuentes)) return("No hay fuentes reconocidas para formar las zonas.")
    base <- sprintf("Los %d documentos con fuente se distribuyen entre %d fuentes. Las zonas 1, 2 y 3 contienen %s fuentes y re\u00fanen, respectivamente, %s %% de esos documentos.", sum(d$fuentes$documentos), nrow(d$fuentes), paste(d$zonas$fuentes, collapse = " / "), paste(number(d$zonas$porcentaje_documentos), collapse = " / "))
    comparison <- if (all(d$zonas$fuentes > 0)) sprintf("Las razones de fuentes entre zonas consecutivas son %s y %s; la progresi\u00f3n cl\u00e1sica esperar\u00eda un multiplicador aproximadamente com\u00fan y creciente dispersi\u00f3n de fuentes.", number(d$zonas$multiplicador_anterior[2], 2), number(d$zonas$multiplicador_anterior[3], 2)) else
      "Hay al menos una zona vac\u00eda: no puede interpretarse una progresi\u00f3n de tres zonas."
    return(paste(base, comparison, "Revisa tambi\u00e9n el equilibrio de documentos entre zonas; estas razones no constituyen una prueba estad\u00edstica de Bradford."))
  }
  d <- fit$zipf
  if (!nrow(d)) return("No quedan palabras tras la limpieza para describir su frecuencia.")
  top <- head(d, 3)
  base <- sprintf("El vocabulario evaluado contiene %d t\u00e9rminos y %s apariciones. Los primeros puestos son: %s.", nrow(d), format(sum(d$frecuencia), trim = TRUE, scientific = FALSE), paste(sprintf("%d / %s (%s apariciones)", top$rango, top$termino, format(top$frecuencia, trim = TRUE, scientific = FALSE)), collapse = "; "))
  comparison <- if (nrow(d) >= 3) sprintf("El segundo t\u00e9rmino tiene el %s %% de las apariciones del primero y el tercero el %s %%; Zipf cl\u00e1sico propone aproximadamente el 50 %% y el 33,3 %%.", number(100*d$frecuencia[2]/d$frecuencia[1]), number(100*d$frecuencia[3]/d$frecuencia[1])) else
    "Hay menos de tres t\u00e9rminos: no puede compararse el ejemplo de los tres primeros puestos."
  paste(base, comparison, "Esta lectura de los primeros puestos no contrasta el ajuste de toda la distribuci\u00f3n.")
}

regularity_plot <- function(fit, kind, compact = FALSE, canvas_width = if (compact) 300 else 1200) {
  chart_title <- function(text) paste(strwrap(text, width = if (compact) 24 else 70), collapse = "\n")
  theme <- swiss_theme(if (compact) 10 else 12) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 0, hjust = .5),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 10)),
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 10)),
      legend.box.margin = ggplot2::margin(t = 4),
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      plot.margin = ggplot2::margin(12, 18, 12, 12),
      plot.title = ggplot2::element_text(size = if (compact) 13 else 17),
      plot.subtitle = ggplot2::element_text(size = if (compact) 9 else 11))
  if (kind == "bradford") {
    d <- fit$bradford$fuentes
    if (!nrow(d)) return(NULL)
    line <- if (nrow(d) > 1L) ggplot2::geom_line(ggplot2::aes(group = 1), colour = "#6c7d88") else NULL
    return(ggplot2::ggplot(d, ggplot2::aes(rango, porcentaje_acumulado, colour = factor(zona))) + line +
      ggplot2::geom_point(size = 2) +
      ggplot2::geom_hline(yintercept = c(100/3, 200/3), linetype = "dashed", colour = "#999999") +
      ggplot2::scale_colour_manual(values = c("1" = "#245579", "2" = "#a76d16", "3" = "#60816b"), drop = FALSE) +
      ggplot2::scale_x_log10(breaks = unique(round(seq(1, nrow(d), length.out = min(8, nrow(d)))))) +
      ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25), expand = ggplot2::expansion(mult = c(.02, .05))) +
      ggplot2::labs(x = chart_title("Puesto de la fuente por productividad (escala logar\u00edtmica)"), y = "Documentos acumulados (%)",
        colour = "Zona", title = chart_title("Bradford / tres zonas observadas"), subtitle = chart_title("X logar\u00edtmico; Y lineal / documentos con fuente conocida")) + theme)
  }
  d <- fit[[kind]]
  if (!nrow(d)) return(NULL)
  if (kind == "lotka") {
    values <- data.frame(x = d$documentos_por_autor, observado = d$autores, referencia = d$autores_referencia)
    xlab <- "Documentos por autor (escala logar\u00edtmica)"
    ylab <- "Autores (escala logar\u00edtmica)"
    title <- "Lotka / productividad de autores"
  } else {
    values <- data.frame(x = d$rango, observado = d$frecuencia, referencia = d$frecuencia_referencia)
    xlab <- "Puesto en el ranking (escala logar\u00edtmica)"
    ylab <- "Apariciones (escala logar\u00edtmica)"
    title <- "Zipf / rango y frecuencia de palabras"
  }
  reference_layer <- if (nrow(values) > 1L)
    ggplot2::geom_line(ggplot2::aes(y = referencia, colour = "Referencia cl\u00e1sica"), linetype = "dashed") else
    ggplot2::geom_point(ggplot2::aes(y = referencia, colour = "Referencia cl\u00e1sica"), shape = 1, size = 4)
  graph <- ggplot2::ggplot(values, ggplot2::aes(x)) + reference_layer
  observed <- values[values$observado > 0, , drop = FALSE]
  if (kind == "lotka") {
    numbered <- regularity_numbered_points(values, compact, canvas_width)
    marker_size <- max(7, 1.8 * max(nchar(as.character(numbered$x))) + 2)
    graph <- graph + ggplot2::geom_point(data = observed, ggplot2::aes(y = observado, colour = "Observado"),
      shape = 21, fill = "white", size = 2.5, stroke = .8)
    if (compact && pkg_available("ggrepel")) {
      labels <- if (nrow(observed) <= 12L) observed else numbered
      graph <- graph + ggrepel::geom_label_repel(data = labels, ggplot2::aes(y = observado, label = x),
        fill = "white", colour = "#245579", size = 3, fontface = "bold", seed = 2026,
        label.r = grid::unit(.5, "lines"), label.padding = grid::unit(.2, "lines"),
        direction = "y", box.padding = .4, point.padding = .4, force = 3,
        max.overlaps = Inf, max.time = 2, max.iter = 20000, min.segment.length = 0,
        segment.colour = "#7895a6")
    } else graph <- graph + ggplot2::geom_point(data = numbered, ggplot2::aes(y = observado),
        shape = 21, fill = "white", colour = "#245579", size = marker_size, stroke = .9) +
      ggplot2::geom_text(data = numbered, ggplot2::aes(y = observado, label = x),
        colour = "#245579", size = if (compact) 2.7 else 3, fontface = "bold")
  } else {
    graph <- graph + ggplot2::geom_point(data = observed, ggplot2::aes(y = observado, colour = "Observado"), size = 2, alpha = .8)
    labels <- d
    wrap_word <- function(word) {
      width <- if (compact) 12L else 20L
      starts <- seq.int(1L, max(1L, nchar(word)), by = width)
      paste(substring(word, starts, starts + width - 1L), collapse = "\n")
    }
    labels$etiqueta <- ifelse(labels$rango <= if (compact) 5L else 8L, vapply(labels$termino, wrap_word, ""), "")
    graph <- graph + label_layer(labels, ggplot2::aes(x = .data$rango, y = .data$frecuencia, label = .data$etiqueta),
      size = if (compact) 2.8 else 3.5, colour = "#173f5f", seed = 2026,
      repel = list(max.overlaps = Inf, max.time = 2, max.iter = 20000, force = 2,
        box.padding = .7, point.padding = .5, min.segment.length = 0, segment.colour = "#7895a6"))
  }
  graph + ggplot2::scale_x_log10(expand = ggplot2::expansion(mult = c(.06, .10))) +
    ggplot2::scale_y_log10(expand = ggplot2::expansion(mult = c(.06, .15))) +
    ggplot2::scale_colour_manual(values = c("Observado" = "#245579", "Referencia cl\u00e1sica" = "#b36819")) +
    ggplot2::labs(x = chart_title(xlab), y = if (compact) sub(" \\(", "\n(", ylab) else ylab, colour = NULL, title = chart_title(title),
      subtitle = chart_title("Ambos ejes usan escala logar\u00edtmica de base 10")) + theme +
    ggplot2::guides(colour = ggplot2::guide_legend(nrow = if (compact) 2L else 1L, byrow = TRUE))
}

regularities_ui <- function() tabPanel("Regularidades", value = "regularities",
  panel("Regularidades bibliom\u00e9tricas / Lotka, Bradford y Zipf",
    tags$p("Compara los recuentos de tu corpus con tres referencias cl\u00e1sicas. Revisa primero la cobertura y despu\u00e9s cada distribuci\u00f3n. Una semejanza visual no confirma una ley."),
    ui_subblock("Punto de partida / cobertura y alcance", DT::DTOutput("regularities_coverage"),
      hint("Se usan todos los autores, fuentes y t\u00e9rminos disponibles de la preparaci\u00f3n vigente, sin recortar por los rankings de pantalla. Los nombres siguen la normalizaci\u00f3n elegida en 02.")),
    tabsetPanel(id = "regularity_kind",
      tabPanel("Lotka / autores", value = "lotka",
        ui_subblock("Qu\u00e9 dice Lotka", tags$p(tags$strong("Qu\u00e9 dice. "), "La formulaci\u00f3n cl\u00e1sica propone que el n\u00famero de autores con x art\u00edculos es aproximadamente el n\u00famero de autores con uno dividido entre x\u00b2. Por cada 100 autores con un art\u00edculo se esperar\u00edan unos 25 con dos y unos 11 con tres: son proporciones de referencia, no cifras que deba cumplir cualquier corpus."),
          tags$p(tags$strong("C\u00f3mo se representa aqu\u00ed. "), "X cuenta documentos por autor; Y cuenta autores con esa productividad. Ambos ejes son logar\u00edtmicos: distancias iguales representan multiplicaciones iguales, por ejemplo de 1 a 10 y de 10 a 100, no incrementos iguales. La l\u00ednea de exponente 2 se normaliza al total de autores en el intervalo de 1 hasta la productividad m\u00e1xima observada; no se fuerza a pasar por el recuento de autores con un documento."),
          hint("Conteo completo: cada firma cuenta una vez por documento. Los hom\u00f3nimos y las variantes sin resolver afectan al resultado; no describe la carrera completa de una persona.")),
        ui_subblock("Qu\u00e9 muestran nuestros datos", uiOutput("lotka_reading")),
        ui_subblock("Leer la distribuci\u00f3n de productividad", plotOutput("lotka_plot", height = "auto"),
          hint("Cada n\u00famero dentro de un c\u00edrculo indica documentos por autor; la altura del punto indica cu\u00e1ntos autores tienen esa productividad. En pantallas peque\u00f1as los n\u00fameros pueden desplazarse y se conectan con su punto mediante una l\u00ednea. Si hay clases demasiado pr\u00f3ximas para numerarlas todas, se conserva su marcador sin n\u00famero y la tabla permite consultar cada valor. Los recuentos cero no se dibujan en la escala logar\u00edtmica. La l\u00ednea discontinua es una referencia, no un ajuste estad\u00edstico."), DT::DTOutput("lotka_table"))),
      tabPanel("Bradford / fuentes", value = "bradford",
        ui_subblock("Qu\u00e9 dice Bradford", tags$p(tags$strong("Qu\u00e9 dice. "), "Ordenadas las revistas de mayor a menor productividad sobre un tema, la formulaci\u00f3n cl\u00e1sica propone zonas con aproximadamente el mismo n\u00famero de art\u00edculos y un n\u00famero creciente de revistas en proporci\u00f3n 1 : n : n\u00b2. Por ejemplo, 5, 10 y 20 revistas podr\u00edan aportar una cantidad similar de art\u00edculos por zona; son cifras ilustrativas, no resultados de este corpus."),
          tags$p(tags$strong("C\u00f3mo se aplica aqu\u00ed. "), "Las fuentes se ordenan por documentos. La zona 1 incluye hasta la fuente que alcanza un tercio; la zona 2, hasta la que alcanza dos tercios; la zona 3 contiene el resto. Cada fuente se conserva entera y los tercios pueden quedar desequilibrados. X es el puesto de la fuente en escala logar\u00edtmica: la misma distancia representa multiplicar por el mismo factor, como de 1 a 10 y de 10 a 100. Y suma el porcentaje de documentos hasta esa fuente y usa escala lineal, con incrementos iguales para distancias iguales."),
          hint("Se habla de fuentes porque la columna puede contener revistas u otros medios de publicaci\u00f3n. Una zona vac\u00eda o tercios muy desiguales impiden una lectura \u00fatil de la progresi\u00f3n.")),
        ui_subblock("Qu\u00e9 muestran nuestros datos", uiOutput("bradford_reading")),
        ui_subblock("Leer zonas y fuentes", DT::DTOutput("bradford_zones"),
          plotOutput("bradford_plot", height = "auto"), DT::DTOutput("bradford_sources"))),
      tabPanel("Zipf / palabras", value = "zipf",
        ui_subblock("Qu\u00e9 dice Zipf", tags$p(tags$strong("Qu\u00e9 dice. "), "Al ordenar las palabras por frecuencia decreciente, la formulaci\u00f3n cl\u00e1sica propone que la frecuencia del puesto r es aproximadamente inversa a r: la segunda palabra tendr\u00eda la mitad de apariciones que la primera y la tercera un tercio. Si la primera tuviera 1.000 apariciones, la referencia ser\u00eda aproximadamente 500 y 333 para las siguientes; es un ejemplo te\u00f3rico."),
          tags$p(tags$strong("C\u00f3mo se representa aqu\u00ed. "), "X es el puesto del t\u00e9rmino y Y sus apariciones totales, ambos en escala logar\u00edtmica: la misma distancia representa multiplicar por el mismo factor, como de 1 a 10 y de 10 a 100. La referencia 1/r se normaliza al total de apariciones de todos los t\u00e9rminos evaluados tras la limpieza, incluidos los excluidos de los modelos; no se fuerza a pasar por la palabra m\u00e1s frecuente."),
          hint("No usa TF-IDF ni presencia documental. La limpieza, los lemas y las palabras vac\u00edas de 02 condicionan esta distribuci\u00f3n: es Zipf sobre el texto preparado, no sobre el texto original completo. Si dos palabras tienen las mismas apariciones, se ordenan alfab\u00e9ticamente por su texto.")),
        ui_subblock("Qu\u00e9 muestran nuestros datos", uiOutput("zipf_reading")),
        ui_subblock("Leer rango y frecuencia", plotOutput("zipf_plot", height = "auto"),
          hint("Se escriben junto a sus puntos hasta ocho palabras de los primeros puestos (cinco en pantallas peque\u00f1as), con separaci\u00f3n de r\u00f3tulos y l\u00edneas de conexi\u00f3n al punto cuando se desplazan. Si no est\u00e1 disponible el recurso que separa los nombres en el dibujo, se omiten los r\u00f3tulos que se solapar\u00edan. La referencia tiene exponente 1; no se estima un exponente ni se contrasta el ajuste."), DT::DTOutput("zipf_table")))),
    ui_subblock("Guardar y documentar", downloadButton("download_regularities", "Descargar tablas de las tres regularidades"),
      hint("Las mismas tablas se incorporan al ZIP y al informe HTML de 05 / Entrega. Documenta cobertura, limpieza y alcance del corpus antes de interpretar."),
      tags$details(tags$summary("Referencias y f\u00f3rmulas"),
        tags$p("Lotka: E(x) = A \u00b7 x\u207b\u00b2 / \u03a3(k\u207b\u00b2), para k = 1,\u2026,m\u00e1ximo observado. Zipf: E(r) = T \u00b7 r\u207b\u00b9 / \u03a3(k\u207b\u00b9), para k = 1,\u2026,n\u00famero de t\u00e9rminos. A es el total de autores y T el total de apariciones. Son referencias finitas normalizadas, sin inferencia estad\u00edstica."),
        tags$ul(tags$li(tags$a(href = "https://www.jstor.org/stable/24529203", target = "_blank", rel = "noopener", "Lotka (1926). The frequency distribution of scientific productivity.")),
          tags$li(tags$a(href = "https://doi.org/10.1177/016555158501000407", target = "_blank", rel = "noopener", "Bradford (1934; reimpresi\u00f3n 1985). Sources of information on specific subjects.")),
          tags$li(tags$a(href = "https://doi.org/10.1371/journal.pone.0181987", target = "_blank", rel = "noopener", "Lestrade (2017). Unzipping Zipf\u2019s law.")))))))
