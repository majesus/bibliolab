# Decisiones visibles y lecturas ligadas a los resultados de esta ejecucion.
pca_available_axes <- function(fit) which(fit$dimensions$varianza > max(fit$dimensions$varianza)*1e-12)
pca_plane <- function(fit,part="terms",axes=c(1L,2L)) {
  if(length(axes)!=2L||anyNA(axes)||anyDuplicated(axes)||!all(axes %in% pca_available_axes(fit)))abort_user("Elige dos componentes diferentes con variaci\u00f3n \u00fatil.")
  d<-fit[[part]];coordinates<-fit$coordinates[[part]]
  if(is.null(coordinates)) {
    if(!identical(as.integer(axes),c(1L,2L)))abort_user("Esta ejecuci\u00f3n solo conserva el plano 1 / 2. Recalcula ACP para consultar otros componentes.")
    return(d)
  }
  d$eje_1<-coordinates[,axes[1]];d$eje_2<-coordinates[,axes[2]]
  ct<-fit$coordinates[[if(part=="terms")"term_contributions" else "document_contributions"]]
  d$contribucion_eje_1<-ct[,axes[1]];d$contribucion_eje_2<-ct[,axes[2]]
  if(part=="terms") {d$carga_1<-fit$coordinates$loadings[,axes[1]];d$carga_2<-fit$coordinates$loadings[,axes[2]]}
  denominator<-if(part=="terms")rep(1,nrow(d)) else pmax(fit$coordinates$document_distance2,.Machine$double.eps)
  d$cos2_plano<-pmin(1,rowSums(coordinates[,axes,drop=FALSE]^2)/denominator)
  attr(d,"axes")<-axes;d
}
metadata_detect <- function(x) {
  x <- clean_value(x); x <- x[nzchar(x)]
  hits <- vapply(c(";","|"),function(s)sum(grepl(s,x,fixed=TRUE)),1L)
  if(!length(x)) return(list(sep="none",note="Campo sin contenido; no hay elementos que separar."))
  if(sum(hits>0)>1) return(list(sep=c(";","|")[which.max(hits)],note="Se observan dos separadores distintos. Revisa los ejemplos y confirma la regla: la app no une ambos autom\u00e1ticamente."))
  if(any(hits>0)) return(list(sep=c(";","|")[which.max(hits)],note=paste("Detectado en",max(hits),"de",length(x),"filas con contenido.")))
  list(sep="none",note="No se observa punto y coma ni barra vertical. Se conserva un elemento por celda. Las comas pueden separar apellido e iniciales: no se dividen autom\u00e1ticamente.")
}
metadata_split <- function(x,sep) {
  if(is.null(sep)||identical(sep,"none")) return(as.list(clean_value(x)))
  lapply(strsplit(clean_value(x),sep,fixed=TRUE),trimws)
}
metadata_separator <- function(prepared,field) prepared$config[[paste0(field,"_sep")]] %||% prepared$config$metadata_sep
metadata_rule <- function(x,selected,fallback=";") {
  if(is.null(selected))return(fallback)
  if(identical(selected,"auto"))return(metadata_detect(x)$sep)
  if(!selected %in% c(";","|",",","none"))abort_user("Separador de metadatos no admitido.")
  selected
}
metadata_preview <- function(raw,mapping,field,selected) {
  x<-mapped(raw,mapping,field);rule<-metadata_rule(x,selected)
  rows<-head(which(nzchar(x)),3)
  items<-metadata_split(x[rows],rule)
  data.frame(Fila=rows,Original=x[rows],"Elementos reconocidos"=vapply(items,function(z)paste(z,collapse=" / "),""),"N\u00famero de elementos"=lengths(items),check.names=FALSE)
}
jsd_result_reading <- function(fit,top_n=20L) {
  if(fit$jsd==0)return("A y B tienen las mismas proporciones en el vocabulario analizado: JSD = 0. No hay barras de aportaci\u00f3n. Igualdad l\u00e9xica no demuestra igualdad de todo el contenido.")
  d<-head(fit$terms[fit$terms$aporte_bits>0,],top_n)
  words<-function(side){z<-head(d$termino[d$direccion==side],4);if(length(z))paste(z,collapse=", ") else "ninguna entre las mostradas"}
  sprintf("JSD resume cu\u00e1nto difieren las proporciones de palabras de A y B. Las barras de la izquierda tienen mayor proporci\u00f3n en A (%s); las de la derecha, en B (%s). Una barra m\u00e1s larga aporta m\u00e1s al contraste total (%s son las primeras por aportaci\u00f3n). Estas %d palabras explican %.1f %% de la diferencia. La direcci\u00f3n indica en qu\u00e9 grupo pesa m\u00e1s la palabra; la aportaci\u00f3n a la divergencia siempre es no negativa. Abre sus documentos para comprobar qu\u00e9 significa el contraste.",words("Mayor en A"),words("Mayor en B"),paste(head(d$termino,3),collapse=", "),nrow(d),sum(d$aporte_pct))
}
# Frase modelo para el informe con las cifras de la comparacion vigente. Es descriptiva: no atribuye causa ni valida los grupos.
jsd_report_sentence <- function(fit, top_n = 3L) {
  if (is.null(fit) || is.null(fit$jsd)) return("")
  p <- fit$params; a <- fit$audit$valor
  weight <- if (identical(p$weighting, "documents")) "documentos equilibrados" else "tokens agrupados"
  intro <- paste0("Se compararon ", p$label_A, " (n = ", a[3], " documentos) y ", p$label_B, " (n = ", a[4], " documentos) con el vocabulario retenido y la ponderaci\u00f3n de ", weight,
    ". La divergencia de Jensen-Shannon (JSD) es ", fmt_es(fit$jsd, 4), " bits (0 = reparto de palabras id\u00e9ntico; 1 = vocabularios sin palabras en com\u00fan).")
  if (fit$jsd == 0) return(paste0(intro, " Con este vocabulario los dos grupos tienen las mismas proporciones; esto no demuestra igualdad de todo su contenido."))
  u <- fit$uncertainty
  azar <- if (is.list(u) && is.finite(u$null_mean)) paste0(" Al redistribuir al azar los documentos entre ambos grupos se esperar\u00eda una JSD media de ", fmt_es(u$null_mean, 4), " bits; el exceso observado es ", fmt_es(u$excess, 4), " bits (p de permutaci\u00f3n = ", fmt_es(u$p_value, 3), ").") else ""
  d <- fit$terms[fit$terms$aporte_bits > 0, , drop = FALSE]
  words <- function(side) { z <- head(d$termino[d$direccion == side], top_n); if (length(z)) paste(z, collapse = ", ") else "ninguna entre las principales" }
  paste0(intro, azar, " Las palabras que m\u00e1s contribuyen son ", words("Mayor en A"), " (mayor proporci\u00f3n en A) y ", words("Mayor en B"), " (mayor proporci\u00f3n en B). La comparaci\u00f3n describe diferencias de vocabulario y no establece su causa; si los grupos se formaron con el mismo vocabulario, no constituye una validaci\u00f3n independiente de ellos.")
}
# Frase modelo para el informe con las cifras de la red vigente: define que es una conexion y declara filtros y limites.
network_report_sentence <- function(fit) {
  if (is.null(fit) || is.null(fit$summary)) return("")
  v <- function(name) { i <- match(name, fit$summary$indicador); if (is.na(i)) NA_real_ else fit$summary$valor[i] }
  p <- fit$params
  relation <- switch(p$type, authors = "dos autores est\u00e1n unidos si han firmado una misma publicaci\u00f3n", words = "dos palabras est\u00e1n unidas si coinciden en al menos un documento",
    sources = "dos revistas est\u00e1n unidas si comparten vocabulario retenido", references = "dos obras est\u00e1n unidas si una misma publicaci\u00f3n las cita", coupling = "dos documentos est\u00e1n unidos si comparten referencias citadas", "dos entidades est\u00e1n unidas si cumplen la relaci\u00f3n elegida")
  weight <- switch(p$weighting %||% "", full = "el n\u00famero de coincidencias", fractional = "coincidencias fraccionadas", cosine = "el coseno", association = "la fuerza de asociaci\u00f3n", "el peso elegido")
  n <- v("Nodos"); e <- v("Conexiones"); dens <- v("Densidad"); comp <- v("Componentes"); com <- v("Comunidades louvain"); mod <- v("Modularidad")
  paste0("En la red analizada, ", relation, ". Con los filtros declarados (presencia m\u00ednima ", p$min_presence %||% "\u2014", ", hasta ", p$max_nodes %||% "\u2014", " nodos y ponderaci\u00f3n por ", weight, ") la red tiene ", n, " nodos y ", e, " conexiones, con una densidad de ", fmt_es(dens, 3),
    " y ", comp, if (identical(as.integer(comp), 1L)) " componente" else " componentes", ". ",
    if (is.finite(com)) paste0("El m\u00e9todo ", p$community_method, " propone ", com, if (identical(as.integer(com), 1L)) " comunidad" else " comunidades", if (is.finite(mod)) paste0(" (modularidad = ", fmt_es(mod, 3), ")") else "", ". ") else "",
    "Los nodos y las comunidades dependen de los filtros y del m\u00e9todo; la posici\u00f3n en el dibujo es una disposici\u00f3n visual y las cifras describen la red, sin implicar influencia ni causalidad.")
}
jsd_time_reading <- function(fit) {
  d<-fit$temporal
  if(!nrow(d))return("Compara per\u00edodos con varios a\u00f1os observados para estudiar d\u00f3nde cambia el vocabulario. Cada punto compara dos a\u00f1os observados sucesivos, con la misma ponderaci\u00f3n y el mismo vocabulario retenido.")
  i<-which.max(d$jsd_bits)
  sprintf("Cada punto compara el reparto de palabras entre dos a\u00f1os observados sucesivos: 0 significa proporciones iguales y un valor mayor significa una diferencia mayor. Sirve para localizar per\u00edodos cuyos documentos conviene leer y contrastar. En esta ejecuci\u00f3n el mayor contraste es %s / %s (JSD %.4f bits). Por ejemplo, si hotel aumenta su proporci\u00f3n mientras servicio la reduce, cambia el reparto aunque el n\u00famero de art\u00edculos sea igual. No mide cu\u00e1nto ha crecido la producci\u00f3n, ni prueba un cambio de teor\u00eda. Los c\u00edrculos vac\u00edos se\u00f1alan saltos entre a\u00f1os sin datos; compara tama\u00f1os de muestra y cobertura antes de atribuir el cambio al campo.",d$ano_A[i],d$ano_B[i],d$jsd_bits[i])
}
ordination_reading <- function(fit,kind="ACP",axes=c(1L,2L)) {
  d<-if(kind=="ACP")pca_plane(fit,"terms",axes) else fit$terms
  information<-sum(fit$dimensions$porcentaje[axes])
  best<-head(d$termino[order(-(d$contribucion_eje_1+d$contribucion_eje_2))],4)
  representative<-sum(d$cos2_plano>=.5,na.rm=TRUE)
  sides<-function(column,positive){v<-d[[column]];ids<-which(if(positive)v>0 else v<0);head(d$termino[ids[order(-abs(v[ids]))]],3)}
  mention<-function(z)if(length(z))paste(z,collapse=", ") else "sin t\u00e9rminos en ese lado"
  paste0("El plano ",axes[1]," / ",axes[2]," recoge ",sprintf("%.1f",information)," % de la ",if(kind=="ACP")"varianza" else "inercia"," total. Las palabras con mayor contribuci\u00f3n a este plano son (",paste(best,collapse=", "),"). El eje horizontal contrasta (",mention(sides("eje_1",FALSE)),") con (",mention(sides("eje_1",TRUE)),"); el vertical contrasta (",mention(sides("eje_2",FALSE)),") con (",mention(sides("eje_2",TRUE)),"). Estas listas describen extremos, no etiquetas tem\u00e1ticas validadas. ",representative," de ",nrow(d)," t\u00e9rminos conservan al menos la mitad de su informaci\u00f3n en el plano (cos\u00b2 \u2265 0,5, referencia de lectura, no criterio universal). Un cos\u00b2 de 0,20 significa que aqu\u00ed se ve el 20 % de la informaci\u00f3n de ese punto: examina otros ejes antes de interpretar proximidad. ",
  if(kind=="ACP")"Las variables son correlaciones con componentes: flechas de direcci\u00f3n parecida sugieren asociaci\u00f3n positiva bien representada; direcciones opuestas sugieren asociaci\u00f3n negativa. El plano de documentos muestra semejanza de perfiles TF-IDF centrados; abre los textos para explicar los contrastes." else "Correspondencias compara c\u00f3mo se reparte cada palabra entre las unidades de texto mediante distancias chi-cuadrado. Cerca del origen, su perfil es pr\u00f3ximo al promedio; lejos, es distinto en los ejes mostrados. La cercan\u00eda entre palabras bien representadas sugiere perfiles parecidos, sin demostrar sinonimia. Lee documentos con esas palabras y comprueba masa y contribuci\u00f3n: una palabra rara puede ocupar un extremo."," El signo puede invertirse sin cambiar el resultado. Estos m\u00e9todos no asignan grupos por s\u00ed solos.")
}
# Frases modelo para el informe de ACP, Correspondencias, LDA y grupos de documentos. Usan las cifras de la ejecuci\u00f3n vigente y declaran qu\u00e9 no se afirma.
ordination_report_sentence <- function(fit, kind = "ACP", axes = c(1L, 2L)) {
  if (is.null(fit) || is.null(fit$dimensions)) return("")
  dm <- fit$dimensions; axes <- axes[axes %in% dm$eje]
  if (length(axes) < 2L) return("")
  pct <- sum(dm$porcentaje[match(axes, dm$eje)])
  chance <- all(dm$supera_azar[match(axes, dm$eje)] %in% TRUE)
  measure <- if (identical(kind, "ACP")) "varianza" else "inercia"
  n_terms <- nrow(fit$terms)
  paste0("El ", kind, " se calcul\u00f3 sobre ", n_terms, " t\u00e9rminos del vocabulario retenido. El plano formado por los ejes ", axes[1], " y ", axes[2], " recoge el ", fmt_es(pct, 1), " % de la ", measure, " total",
    if (chance) ", y ambos ejes superan la referencia obtenida por permutaci\u00f3n" else ", pero al menos uno de los dos ejes no supera la referencia obtenida por permutaci\u00f3n, por lo que su lectura debe tomarse con cautela", ". ",
    "Los ejes resumen contrastes entre perfiles de vocabulario; no son temas ni valoraciones, y el signo positivo o negativo de una posici\u00f3n solo indica el lado del contraste. Antes de interpretar un punto, comprueba que su cos\u00b2 en este plano sea suficiente y lee los textos que lo sustentan.")
}
lda_report_sentence <- function(fit) {
  if (is.null(fit) || is.null(fit$prevalence) || !nrow(fit$prevalence)) return("")
  d <- fit$prevalence; i <- which.max(d$proporcion_media)
  terms <- head(fit$top$termino[fit$top$tema == d$tema[i]], 4)
  paste0("Se estim\u00f3 un modelo LDA con ", fit$params$k, " temas, un n\u00famero fijado por el analista y no descubierto por el modelo. El tema ", d$tema[i], " (", paste(terms, collapse = ", "), ") es el de mayor proporci\u00f3n media de la mezcla, con el ", fmt_es(100 * d$proporcion_media[i], 1), " %. ",
    "Cada documento se describe como una mezcla de temas, no como perteneciente a uno solo; los temas son distribuciones de palabras y su etiqueta es una interpretaci\u00f3n que debe contrastarse leyendo los documentos con mayor peso en cada uno. La soluci\u00f3n depende del n\u00famero de temas, de la semilla y del vocabulario retenido.")
}
density_report_sentence <- function(fit) {
  if (is.null(fit) || is.null(fit$summary) || is.null(fit$assignments)) return("")
  groups <- sum(fit$summary$grupo > 0); n <- nrow(fit$assignments); un <- sum(fit$assignments$grupo == 0)
  paste0("La agrupaci\u00f3n por densidad (UMAP + HDBSCAN, representaci\u00f3n ", fit$representation$type %||% "no declarada", ") detect\u00f3 ", groups, if (groups == 1L) " grupo" else " grupos", " entre ", n, " documentos; ", un, " (", fmt_es(100 * un / n, 1), " %) quedaron sin asignar. ",
    "Con minPts = ", fit$params$min_pts, " y semilla ", fit$params$seed, ". Los grupos son agrupaciones de documentos con vocabulario parecido, no temas validados; la membres\u00eda describe la estabilidad de la asignaci\u00f3n y no una probabilidad, y las distancias globales del mapa no deben leerse como distancias sem\u00e1nticas exactas. Lee los documentos representativos de cada grupo antes de nombrarlo.")
}
lda_result_reading <- function(fit) {
  d<-fit$prevalence
  rows<-vapply(seq_len(nrow(d)),function(i){topic<-d$tema[i];terms<-head(fit$top$termino[fit$top$tema==topic],4);paste0("Tema ",topic," (",paste(terms,collapse=", "),"): ",sprintf("%.1f",100*d$proporcion_media[i])," % de la mezcla media")},"")
  paste0("La soluci\u00f3n tiene ",fit$params$k," temas. ",paste(rows,collapse="; "),". La proporci\u00f3n media resume la mezcla de los documentos con vocabulario. Si usaste frases, primero se promedian las frases retenidas de cada documento; no es el porcentaje de art\u00edculos que pertenecen exclusivamente al tema. Por ejemplo, un documento con 0,60 en tema 1 y 0,40 en tema 2 aporta a ambos. Las palabras ayudan a proponer nombres; confirma cada nombre leyendo los documentos representativos y sus mezclas. Contrasta coherencia, diversidad y estabilidad con otras semillas y valores de k antes de fijar una interpretaci\u00f3n.")
}
