# Leyes bibliometricas clasicas: Lotka (productividad de autores), Bradford (dispersion en revistas) y
# Zipf (frecuencia de palabras). Cada funcion devuelve la misma estructura:
#   estado    "ok" o "insuficiente" (con `motivo`),
#   tabla     cifras que sostienen el grafico,
#   resumen   data.frame de indicadores (criterio, valor),
#   lectura   texto en lenguaje llano con las cifras del corpus,
#   criterio  regla de ajuste declarada (se registra en el informe).
# Principio: describen cuanto se parece el corpus a un patron teorico. No "confirman" ninguna ley.

LEYES_MIN <- list(lotka_autores = 20L, lotka_niveles = 3L, bradford_fuentes = 9L, zipf_terminos = 30L)

fmt_es <- function(x, digits = 2L) format(round(x, digits), decimal.mark = ",", nsmall = 0, trim = TRUE)
pct_es <- function(x, digits = 1L) paste0(format(round(x, digits), decimal.mark = ",", nsmall = digits, trim = TRUE), "\u00a0%")

law_insufficient <- function(law, motivo) {
  list(ley = law, estado = "insuficiente", motivo = motivo, tabla = data.frame(), resumen = data.frame(),
    lectura = paste0("No hay datos suficientes para ajustar esta ley. ", motivo,
      " Con pocos elementos cualquier curva parece ajustarse o no, y la cifra resultante enga\u00f1a: por eso no se calcula."),
    criterio = "", informe = "")
}

# ---- Lotka --------------------------------------------------------------------------------------
# Ley del cuadrado inverso generalizada: la proporcion de autores con x trabajos es proporcional a x^(-n).
# Criterio de ajuste: exponente por maxima verosimilitud discreta truncada en el maximo observado (el metodo clasico de
# minimos cuadrados sobre log-log subestima el exponente con colas poco pobladas y se informa solo como contraste). La discrepancia
# se mide con la distancia maxima entre acumuladas (Kolmogorov-Smirnov) frente a 1,63 / sqrt(autores).
lotka_fit <- function(productivity) {
  x <- productivity[is.finite(productivity) & productivity >= 1]; x <- as.integer(x)
  k <- length(x)
  if (k < LEYES_MIN$lotka_autores) return(law_insufficient("lotka", paste0("Se necesitan al menos ", LEYES_MIN$lotka_autores, " autores y hay ", k, ".")))
  tab <- table(x); niveles <- as.integer(names(tab)); y <- as.numeric(tab)
  if (length(niveles) < LEYES_MIN$lotka_niveles) return(law_insufficient("lotka", paste0("Se necesitan al menos ", LEYES_MIN$lotka_niveles, " niveles distintos de productividad (1 trabajo, 2 trabajos, 3\u2026) y hay ", length(niveles), ".")))
  fit <- stats::lm(log10(y) ~ log10(niveles)); n_ls <- -unname(stats::coef(fit)[2]); r2 <- summary(fit)$r.squared
  xmax <- max(niveles); grid <- seq_len(xmax)
  neg_ll <- function(n) n * sum(log(x)) + k * log(sum(grid^(-n)))
  n_ml <- stats::optimize(neg_ll, c(0.2, 8))$minimum
  law <- function(n) { p <- grid^(-n); p / sum(p) }
  obs <- tabulate(x, nbins = xmax) / k
  fitted <- law(n_ml); lotka2 <- law(2)
  d_ks <- max(abs(cumsum(obs) - cumsum(fitted))); crit <- 1.63 / sqrt(k)
  tabla <- data.frame(trabajos = grid, autores = tabulate(x, nbins = xmax), proporcion_observada = obs,
    proporcion_ajustada = fitted, proporcion_lotka_2 = lotka2)
  tabla <- tabla[tabla$autores > 0 | tabla$trabajos <= 3L, , drop = FALSE]
  unico <- 100 * obs[1]
  coherente <- d_ks <= crit
  resumen <- data.frame(
    indicador = c("Autores analizados", "Trabajos m\u00e1ximos de un autor", "Autores con un solo trabajo (%)", "Exponente de Lotka (m\u00e1xima verosimilitud)", "Exponente de Lotka (m\u00ednimos cuadrados, m\u00e9todo cl\u00e1sico)",
      "Ajuste lineal cl\u00e1sico en escala logar\u00edtmica (R\u00b2)", "Distancia m\u00e1xima entre acumuladas (K-S)", "Valor de referencia 1,63/\u221aautores", "Autores con un solo trabajo si n = 2 (%)"),
    valor = c(k, xmax, unico, n_ml, n_ls, r2, d_ks, crit, 100 * lotka2[1]))
  lectura <- paste0(
    "De ", k, " autores, ", pct_es(unico), " firma un \u00fanico trabajo", " (la ley de Lotka con exponente 2 esperar\u00eda ", pct_es(100 * lotka2[1]), "). ",
    "El exponente ajustado es ", fmt_es(n_ml), ": cuanto mayor, m\u00e1s dominan los autores de un solo trabajo y menos los muy productivos. ",
    if (coherente) paste0("La curva observada no se aparta de la curva de Lotka con ese exponente m\u00e1s de lo que cabe esperar por azar (distancia ", fmt_es(d_ks, 3), " frente a ", fmt_es(crit, 3), "). Esto indica compatibilidad con el patr\u00f3n, no lo demuestra: con pocos autores la prueba detecta poco.")
    else paste0("La curva observada se aparta de la curva de Lotka con ese exponente (distancia ", fmt_es(d_ks, 3), " frente a ", fmt_es(crit, 3), "): en este corpus la productividad no sigue ese patr\u00f3n con claridad."),
    if (abs(n_ls - n_ml) > 0.3) paste0(" Atenci\u00f3n: el m\u00e9todo cl\u00e1sico (m\u00ednimos cuadrados sobre el gr\u00e1fico logar\u00edtmico) da ", fmt_es(n_ls), ", porque subestima el exponente cuando muchos niveles tienen pocos autores; por eso se usa la m\u00e1xima verosimilitud. No cites el exponente con muchos decimales.") else "",
    " Cada firma cuenta una vez por art\u00edculo y el nombre se toma tal como est\u00e1 escrito: si un mismo autor figura con variantes del nombre, se contar\u00e1 como varias personas.")
  informe <- paste0("En el corpus analizado, de ", k, " autores, el ", pct_es(unico), " firma un \u00fanico trabajo. El exponente de Lotka estimado por m\u00e1xima verosimilitud es ", fmt_es(n_ml),
    " (distancia de Kolmogorov-Smirnov = ", fmt_es(d_ks, 3), "; valor de referencia = ", fmt_es(crit, 3), "). La distribuci\u00f3n observada ", if (coherente) "es compatible con la curva de Lotka con ese exponente" else "se aparta de la curva de Lotka con ese exponente",
    ". Se trata de una descripci\u00f3n del ajuste y no de una confirmaci\u00f3n de la ley; los nombres de autor se han tomado tal como figuran en el archivo.")
  list(ley = "lotka", estado = "ok", motivo = "", tabla = tabla, resumen = resumen, lectura = lectura, informe = informe,
    criterio = "Lotka: exponente por m\u00e1xima verosimilitud discreta truncada en el m\u00e1ximo observado (se informa tambi\u00e9n el m\u00e9todo cl\u00e1sico de m\u00ednimos cuadrados en escala logar\u00edtmica); discrepancia con Kolmogorov-Smirnov frente a 1,63/\u221aautores. Descriptivo, no confirma la ley.",
    exponente = n_ml, exponente_ls = n_ls, d_ks = d_ks, critico = crit, compatible = coherente, autores = k)
}

# ---- Bradford -----------------------------------------------------------------------------------
# Se ordenan las revistas de mayor a menor productividad y se forman tres zonas con (casi) el mismo numero de
# articulos. La ley predice que el numero de revistas crece con un multiplicador parecido de una zona a la siguiente
# (1 : k : k2). Una revista pertenece a la zona en la que empieza. Criterio orientativo propio: los dos cocientes se
# consideran "parecidos" si el mayor no supera al menor en mas de un 50 %.
bradford_fit <- function(sources) {
  if (is.null(sources) || !nrow(sources)) return(law_insufficient("bradford", "No hay una columna de fuente con valores."))
  d <- sources[order(-sources$documentos, sources$elemento), c("elemento", "documentos"), drop = FALSE]
  s <- nrow(d); total <- sum(d$documentos)
  if (s < LEYES_MIN$bradford_fuentes) return(law_insufficient("bradford", paste0("Se necesitan al menos ", LEYES_MIN$bradford_fuentes, " fuentes (tres por zona) y hay ", s, ".")))
  d$posicion <- seq_len(s); d$acumulado <- cumsum(d$documentos); previo <- d$acumulado - d$documentos
  d$zona <- 1L + (previo >= total / 3) + (previo >= 2 * total / 3)
  zonas <- do.call(rbind, lapply(1:3, function(z) { i <- d$zona == z
    data.frame(zona = z, fuentes = sum(i), documentos = sum(d$documentos[i]), porcentaje_documentos = 100 * sum(d$documentos[i]) / total) }))
  if (any(zonas$fuentes == 0L)) return(law_insufficient("bradford", "Las fuentes con m\u00e1s art\u00edculos concentran por s\u00ed solas m\u00e1s de un tercio del corpus y no se pueden formar tres zonas."))
  k21 <- zonas$fuentes[2] / zonas$fuentes[1]; k32 <- zonas$fuentes[3] / zonas$fuentes[2]
  zonas$multiplicador <- c(NA, k21, k32)
  parecidos <- max(k21, k32) / min(k21, k32) <= 1.5
  resumen <- data.frame(indicador = c("Fuentes analizadas", "Documentos con fuente", "Fuentes de la zona 1 (n\u00facleo)", "Multiplicador zona 2 / zona 1", "Multiplicador zona 3 / zona 2"),
    valor = c(s, total, zonas$fuentes[1], k21, k32))
  lectura <- paste0(
    "Las ", zonas$fuentes[1], " fuentes m\u00e1s productivas (el n\u00facleo) re\u00fanen ", pct_es(zonas$porcentaje_documentos[1], 0), " de los art\u00edculos; hacen falta ", zonas$fuentes[2], " fuentes para el siguiente tercio y ", zonas$fuentes[3], " para el \u00faltimo. ",
    "El n\u00famero de fuentes se multiplica por ", fmt_es(k21), " y luego por ", fmt_es(k32), ". ",
    if (parecidos) "Los dos multiplicadores son parecidos, que es lo que describe la ley de Bradford (1 : k : k\u00b2). " else "Los dos multiplicadores difieren mucho, de modo que el reparto no se parece al esquema 1 : k : k\u00b2 de Bradford. ",
    "Es una descripci\u00f3n de esta b\u00fasqueda: depende de c\u00f3mo se haya delimitado el tema y de que los nombres de las revistas est\u00e9n unificados. No prueba la ley ni la calidad de las revistas.")
  informe <- paste0("Las ", zonas$fuentes[1], " revistas del n\u00facleo re\u00fanen el ", pct_es(zonas$porcentaje_documentos[1], 0), " de los art\u00edculos; se necesitan ", zonas$fuentes[2], " para la segunda zona y ", zonas$fuentes[3],
    " para la tercera (multiplicadores ", fmt_es(k21), " y ", fmt_es(k32), "). Los multiplicadores ", if (parecidos) "son similares, por lo que el reparto se aproxima" else "difieren, por lo que el reparto no se aproxima",
    " al esquema 1 : k : k\u00b2 de Bradford. La descripci\u00f3n se refiere a esta b\u00fasqueda y depende de que los nombres de las revistas est\u00e9n unificados.")
  list(ley = "bradford", estado = "ok", motivo = "", tabla = d, zonas = zonas, resumen = resumen, lectura = lectura, informe = informe,
    criterio = "Bradford: tres zonas con \u2248 un tercio de los art\u00edculos cada una; multiplicadores de fuentes entre zonas comparados (parecidos si el mayor no supera al menor en m\u00e1s del 50 %). Descriptivo, no confirma la ley.",
    multiplicadores = c(k21, k32), compatible = parecidos)
}

# ---- Zipf ---------------------------------------------------------------------------------------
# Frecuencia de una palabra ? 1 / rango^s, con s cercano a 1 en textos largos. Criterio de ajuste: minimos cuadrados
# sobre log(frecuencia) frente a log(rango) con todos los terminos evaluados. Criterio orientativo propio: se dice
# "cercano a 1" si s esta entre 0,8 y 1,2 y la recta explica al menos el 90 % (R2) de la variacion.
zipf_fit <- function(terms, frequency = NULL) {
  if (is.null(frequency)) { f <- terms$frecuencia; nm <- terms$termino } else { f <- frequency; nm <- terms }
  ok <- is.finite(f) & f > 0; f <- f[ok]; nm <- nm[ok]
  o <- order(-f, nm); f <- f[o]; nm <- nm[o]
  m <- length(f)
  if (m < LEYES_MIN$zipf_terminos) return(law_insufficient("zipf", paste0("Se necesitan al menos ", LEYES_MIN$zipf_terminos, " t\u00e9rminos distintos y hay ", m, ".")))
  rango <- seq_len(m); fit <- stats::lm(log10(f) ~ log10(rango)); s <- -unname(stats::coef(fit)[2]); r2 <- summary(fit)$r.squared
  ajustada <- 10^stats::predict(fit)
  tabla <- data.frame(rango = rango, termino = nm, frecuencia = f, frecuencia_ajustada = ajustada, stringsAsFactors = FALSE)
  cercano <- s >= 0.8 && s <= 1.2 && r2 >= 0.9
  resumen <- data.frame(indicador = c("T\u00e9rminos evaluados", "Apariciones totales", "Exponente de Zipf (s)", "Ajuste lineal en escala logar\u00edtmica (R\u00b2)", "Frecuencia de la palabra n\u00ba 1"),
    valor = c(m, sum(f), s, r2, f[1]))
  lectura <- paste0(
    "La palabra m\u00e1s frecuente (", nm[1], ") aparece ", f[1], " veces y la que ocupa el puesto ", m, " aparece ", f[m], ". ",
    "El exponente ajustado es ", fmt_es(s), " y la recta explica ", pct_es(100 * r2, 0), " de la variaci\u00f3n. ",
    if (cercano) "Se aproxima al patr\u00f3n de Zipf (exponente cerca de 1). " else if (s < 0.8) "La frecuencia cae m\u00e1s despacio que en el patr\u00f3n de Zipf: el vocabulario est\u00e1 repartido de forma m\u00e1s uniforme (frecuente en corpus peque\u00f1os o con vocabulario filtrado). " else if (s > 1.2) "La frecuencia cae m\u00e1s r\u00e1pido que en el patr\u00f3n de Zipf: unas pocas palabras dominan. " else "La relaci\u00f3n no es lo bastante lineal en escala logar\u00edtmica para hablar de patr\u00f3n de Zipf. ",
    "Se calcula con los t\u00e9rminos que la app ha evaluado tras limpiar el texto (sin palabras vac\u00edas), no con el texto completo, y con res\u00famenes cortos el resultado es poco estable. Es una descripci\u00f3n, no una prueba.")
  informe <- paste0("Con ", m, " t\u00e9rminos evaluados tras la limpieza del texto (sin palabras vac\u00edas), el exponente de Zipf estimado es ", fmt_es(s), " (R\u00b2 = ", fmt_es(r2), " en escala logar\u00edtmica), ",
    if (cercano) "un valor cercano a 1" else if (s < 0.8) "un valor inferior a 0,8" else if (s > 1.2) "un valor superior a 1,2" else "con una relaci\u00f3n poco lineal para hablar de patr\u00f3n de Zipf",
    ". Es una descripci\u00f3n del vocabulario evaluado y no una prueba de la ley.")
  list(ley = "zipf", estado = "ok", motivo = "", tabla = tabla, resumen = resumen, lectura = lectura, informe = informe,
    criterio = "Zipf: ajuste por m\u00ednimos cuadrados de log(frecuencia) frente a log(rango) con los t\u00e9rminos evaluados; \"cercano\" si 0,8 \u2264 s \u2264 1,2 y R\u00b2 \u2265 0,90. Descriptivo, no confirma la ley.",
    exponente = s, r2 = r2, compatible = cercano)
}

# ---- Graficos ----------------------------------------------------------------------------------------
wrap_sub <- function(x, width = 95L) paste(strwrap(x, width), collapse = "\n")
law_empty_graph <- function(fit, title) {
  ggplot2::ggplot() + ggplot2::annotate("text", x = 0, y = 0, label = paste(strwrap(fit$motivo, 60), collapse = "\n"), size = 5, colour = "#555555") +
    ggplot2::labs(title = title, subtitle = "No hay datos suficientes para dibujar el ajuste") + ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold", size = 17), plot.subtitle = ggplot2::element_text(colour = "#555555"))
}
lotka_graph <- function(fit) {
  title <- "Lotka / cu\u00e1ntos autores firman cada n\u00famero de trabajos"
  if (!identical(fit$estado, "ok")) return(law_empty_graph(fit, title))
  d <- fit$tabla; d <- d[d$autores > 0, , drop = FALSE]
  ggplot2::ggplot(d, ggplot2::aes(trabajos)) +
    ggplot2::geom_line(ggplot2::aes(y = proporcion_lotka_2, linetype = "Lotka con exponente 2"), colour = "#777777", linewidth = .7) +
    ggplot2::geom_line(ggplot2::aes(y = proporcion_ajustada, linetype = "Ajuste a este corpus"), colour = "#245579", linewidth = .9) +
    ggplot2::geom_point(ggplot2::aes(y = proporcion_observada), colour = "#c7281e", size = 3) +
    ggplot2::scale_x_log10(breaks = function(l) unique(round(10^pretty(log10(l), 5)))) + ggplot2::scale_y_log10(labels = function(v) paste0(format(100 * v, digits = 2, decimal.mark = ","), "\u00a0%")) +
    ggplot2::scale_linetype_manual(values = c("Lotka con exponente 2" = "dashed", "Ajuste a este corpus" = "solid"), name = NULL) +
    ggplot2::labs(title = title, subtitle = wrap_sub(paste0("Puntos rojos: datos observados. Exponente ajustado = ", fmt_es(fit$exponente), ". Ambos ejes en escala logar\u00edtmica.")),
      x = "N\u00famero de trabajos del autor", y = "Proporci\u00f3n de autores") + swiss_theme() + ggplot2::theme(legend.position = "bottom")
}
bradford_graph <- function(fit) {
  title <- "Bradford / c\u00f3mo se reparten los art\u00edculos entre revistas"
  if (!identical(fit$estado, "ok")) return(law_empty_graph(fit, title))
  d <- fit$tabla; z <- fit$zonas; colores <- c("1" = "#c7281e", "2" = "#245579", "3" = "#2d7164")
  d$zona <- factor(d$zona); etiquetas <- paste0("Zona ", z$zona, ": ", z$fuentes, " fuentes")
  ggplot2::ggplot(d, ggplot2::aes(posicion, acumulado, colour = zona)) +
    ggplot2::geom_line(ggplot2::aes(group = 1), colour = "#999999", linewidth = .5) + ggplot2::geom_point(size = 2.6) +
    ggplot2::scale_x_log10(breaks = function(l) unique(round(10^pretty(log10(l), 5)))) +
    ggplot2::scale_colour_manual(values = colores, labels = etiquetas, name = NULL) +
    ggplot2::labs(title = title, subtitle = wrap_sub("Las revistas se ordenan de la m\u00e1s a la menos productiva; cada color agrupa aproximadamente un tercio de los art\u00edculos."),
      x = "Posici\u00f3n de la revista (escala logar\u00edtmica)", y = "Art\u00edculos acumulados") + swiss_theme() + ggplot2::theme(legend.position = "bottom")
}
zipf_graph <- function(fit) {
  title <- "Zipf / frecuencia de las palabras seg\u00fan su rango"
  if (!identical(fit$estado, "ok")) return(law_empty_graph(fit, title))
  d <- fit$tabla; top <- head(d, 8)
  g <- ggplot2::ggplot(d, ggplot2::aes(rango, frecuencia)) +
    ggplot2::geom_line(ggplot2::aes(y = frecuencia_ajustada), colour = "#245579", linewidth = .9) +
    ggplot2::geom_point(colour = "#c7281e", size = 2, alpha = .8) +
    ggplot2::scale_x_log10() + ggplot2::scale_y_log10() +
    ggplot2::labs(title = title, subtitle = paste0("Puntos: palabras observadas; l\u00ednea: ajuste (exponente ", fmt_es(fit$exponente), "). Ambos ejes en escala logar\u00edtmica."),
      x = "Rango de la palabra (1 = la m\u00e1s frecuente)", y = "Apariciones") + swiss_theme()
  if (requireNamespace("ggrepel", quietly = TRUE)) g + ggrepel::geom_text_repel(data = top, ggplot2::aes(label = termino), size = 3.6, min.segment.length = 0, max.overlaps = Inf)
  else g + ggplot2::geom_text(data = top, ggplot2::aes(label = termino), size = 3.4, hjust = -0.1, vjust = -0.3, check_overlap = TRUE)
}

#' Leyes de Lotka, Bradford y Zipf
#'
#' Ajusta tres regularidades clasicas de la bibliometria al corpus observado.
#' El resultado es descriptivo: indica cuanto se parece el corpus al patron
#' teorico segun un criterio declarado en `criterio`, y no confirma ninguna ley.
#' Con pocos autores, fuentes o terminos devuelve `estado = "insuficiente"`.
#'
#' @param bibliography Resultado de [biblio_summary()].
#' @param corpus Resultado de [prepare_corpus()] (necesario para Zipf).
#' @return Lista con `lotka`, `bradford` y `zipf`; cada una trae `estado`,
#'   `tabla`, `resumen`, `lectura` y `criterio`.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d))
#' bibliometric_laws(biblio_summary(p), prepare_corpus(p))$lotka$estado
#' @export
bibliometric_laws <- function(bibliography, corpus = NULL) {
  list(lotka = lotka_fit(bibliography$authors$documentos),
    bradford = bradford_fit(bibliography$extensiones$concentracion_fuentes),
    zipf = if (!is.null(corpus) && nrow(corpus$terms)) zipf_fit(corpus$terms) else law_insufficient("zipf", "No hay vocabulario evaluado."))
}
laws_tables <- function(laws) {
  out <- list()
  for (nm in names(laws)) { f <- laws[[nm]]
    out[[paste0("ley_", nm, "_resumen")]] <- if (nrow(f$resumen)) f$resumen else data.frame(estado = f$estado, motivo = f$motivo)
    if (nrow(f$tabla)) out[[paste0("ley_", nm, "_tabla")]] <- f$tabla
    if (!is.null(f$zonas)) out[[paste0("ley_", nm, "_zonas")]] <- f$zonas }
  out
}
