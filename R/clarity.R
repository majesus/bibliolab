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
lda_result_reading <- function(fit) {
  d<-fit$prevalence
  rows<-vapply(seq_len(nrow(d)),function(i){topic<-d$tema[i];terms<-head(fit$top$termino[fit$top$tema==topic],4);paste0("Tema ",topic," (",paste(terms,collapse=", "),"): ",sprintf("%.1f",100*d$proporcion_media[i])," % de la mezcla media")},"")
  paste0("La soluci\u00f3n tiene ",fit$params$k," temas. ",paste(rows,collapse="; "),". La proporci\u00f3n media resume la mezcla de los documentos con vocabulario. Si usaste frases, primero se promedian las frases retenidas de cada documento; no es el porcentaje de art\u00edculos que pertenecen exclusivamente al tema. Por ejemplo, un documento con 0,60 en tema 1 y 0,40 en tema 2 aporta a ambos. Las palabras ayudan a proponer nombres; confirma cada nombre leyendo los documentos representativos y sus mezclas. Contrasta coherencia, diversidad y estabilidad con otras semillas y valores de k antes de fijar una interpretaci\u00f3n.")
}
