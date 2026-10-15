# Proyeccion concepto-concepto. Las coapariciones no son enlaces semanticos.
# Roles de Guimera y Amaral (2005, Nature 433:895-900) sobre las comunidades de la red: z de grado
# dentro de la comunidad (desviacion tipica poblacional entre los nodos de su comunidad) y coeficiente de
# participacion P = 1 - suma de (enlaces a cada comunidad / enlaces totales)^2. Umbrales originales:
# eje si z >= 2,5; P <= 0,05 / 0,62 / 0,80 en no ejes y P <= 0,30 / 0,75 en ejes.
wiki_network_roles <- function(edges,nodes,z_hub=2.5) {
  n<-nrow(nodes);member<-nodes$community;eps<-1e-9
  out<-data.frame(within_degree=rep(NA_integer_,n),z=rep(NA_real_,n),participation=rep(NA_real_,n),role_code=rep(NA_character_,n),linked=rep("",n),stringsAsFactors=FALSE)
  labels<-c(R1="Apoyo exclusivo de su comunidad",R2="Apoyo de su comunidad",R3="Puente entre comunidades",R4="Puente sin comunidad clara",R5="Eje de su comunidad",R6="Eje y puente",R7="Eje sin comunidad clara")
  groups<-c(R1="Apoyo",R2="Apoyo",R3="Puente",R4="Puente",R5="Eje",R6="Eje y puente",R7="Eje y puente")
  comms<-sort(unique(member[member>0]))
  if(nrow(edges)&&length(comms)) {
    i<-match(edges$from,nodes$id);j<-match(edges$to,nodes$id)
    kis<-as.matrix(Matrix::sparseMatrix(i=c(i,j),j=match(c(member[j],member[i]),comms),x=1,dims=c(n,length(comms))))
    ki<-rowSums(kis);active<-which(member>0&ki>0)
    out$within_degree[active]<-as.integer(kis[cbind(active,match(member[active],comms))])
    for(g in comms) {
      ii<-active[member[active]==g];w<-out$within_degree[ii];sdv<-sqrt(mean((w-mean(w))^2))
      out$z[ii]<-if(sdv>0)(w-mean(w))/sdv else 0
    }
    P<-1-rowSums((kis[active,,drop=FALSE]/ki[active])^2);out$participation[active]<-P
    hub<-out$z[active]>=z_hub-eps
    out$role_code[active]<-ifelse(hub,ifelse(P<=.30+eps,"R5",ifelse(P<=.75+eps,"R6","R7")),ifelse(P<=.05+eps,"R1",ifelse(P<=.62+eps,"R2",ifelse(P<=.80+eps,"R3","R4"))))
    out$linked[active]<-vapply(active,function(v){others<-setdiff(which(kis[v,]>0),match(member[v],comms));if(!length(others))return("");others<-others[order(-kis[v,others],comms[others])];paste0(comms[others]," (",kis[v,others],")",collapse=", ")},"")
  }
  out$role<-unname(ifelse(is.na(out$role_code),"Sin relaciones significativas",labels[out$role_code]))
  out$role_group<-unname(ifelse(is.na(out$role_code),"Aislada",groups[out$role_code]))
  out
}
# Lectura en lenguaje llano, generada de forma determinista a partir de los resultados calculados.
wiki_network_reading <- function(f) {
  fmt<-function(x)format(x,big.mark=".",decimal.mark=",",scientific=FALSE,trim=TRUE)
  quote_words<-function(x){x<-paste0("\u00ab",x,"\u00bb");if(length(x)<2)x else paste0(paste(x[-length(x)],collapse=", ")," y ",x[length(x)])}
  nodes<-f$nodes;st<-f$stats;pr<-f$params;active<-nodes[nodes$community>0,,drop=FALSE];K<-length(unique(active$community))
  alpha<-pr$alpha;k<-pr$top_k
  crit<-if(identical(pr$criterion,"tfidf"))"con mayor TF-IDF (suma)" else "que aparecen en m\u00e1s fichas"
  cap<-if(!is.null(st$excluded_ceiling)&&st$excluded_ceiling>0)paste0(" Se han excluido ",st$excluded_ceiling," palabras presentes en m\u00e1s del ",format(100*pr$max_share,decimal.mark=",")," % de las fichas (",paste(quote_words(head(f$selection$excluded_labels,6)),collapse=""),if(st$excluded_ceiling>6)", entre otras" else "",").") else ""
  gen<-f$selection$general_labels;gen_txt<-if(length(gen))paste0(" Atenci\u00f3n: ",quote_words(head(gen,6)),if(length(gen)>6)" y otras" else ""," aparece",if(length(gen)>1)"n" else ""," en m\u00e1s del 30 % de las fichas; si forma",if(length(gen)>1)"n" else ""," parte de la ecuaci\u00f3n de b\u00fasqueda o del lenguaje general del corpus, tender\u00e1",if(length(gen)>1)"n" else ""," a conectarse con casi todo. El techo de fichas permite excluirla",if(length(gen)>1)"s" else "",".") else ""
  p1<-paste0("Se analizan las ",nrow(nodes)," palabras ",crit,if(!is.null(st$concepts_total)&&st$concepts_total>nrow(nodes))paste0(" (de las ",fmt(st$concepts_total)," del \u00edndice)") else "",".",cap,gen_txt," ",
    "De los ",fmt(st$pairs)," pares posibles, ",fmt(st$significant)," aparecen juntos en las mismas fichas m\u00e1s de lo esperable por azar",if(!is.na(alpha))paste0(" (prueba hipergeom\u00e9trica con control de falsos descubrimientos al ",format(100*alpha,decimal.mark=",")," %)") else " (sin prueba de significaci\u00f3n)",
    if(!is.na(k))paste0("; para que el dibujo sea legible, cada palabra conserva sus ",k," relaciones m\u00e1s fuertes") else "",
    ". El resultado son ",fmt(st$kept)," relaciones entre ",nrow(active)," palabras",if(nrow(nodes)>nrow(active))paste0("; las otras ",nrow(nodes)-nrow(active)," no tienen ninguna relaci\u00f3n que cumpla estos criterios (comunidad 0).") else ".")
  if(!K)return(c(p1,"No hay comunidades que describir con estos criterios. Prueba a ampliar el n\u00famero de palabras, a relajar el nivel de significaci\u00f3n o a reducir el m\u00ednimo de fichas."))
  top_words<-function(g,m)head(active$label[active$community==g][order(-active$fichas[active$community==g],active$label[active$community==g])],m)
  sizes<-table(active$community);show<-seq_len(min(K,5L))
  q<-f$modularity
  q_text<-if(is.na(q))"" else if(q>=.3)paste0(" La modularidad es Q = ",format(round(q,2),decimal.mark=",")," (Newman y Girvan, 2004, se\u00f1alan que en redes con estructura comunitaria marcada Q suele situarse entre 0,3 y 0,7).") else paste0(" La modularidad es baja (Q = ",format(round(q,2),decimal.mark=","),"; en redes con estructura comunitaria marcada suele estar entre 0,3 y 0,7, seg\u00fan Newman y Girvan, 2004): los grupos est\u00e1n poco diferenciados y conviene leerlos con cautela.")
  p2<-paste0("Las palabras se agrupan en ",K," comunidades, es decir, conjuntos de palabras que se relacionan m\u00e1s entre s\u00ed que con el resto. ",
    paste(vapply(show,function(g)paste0("La comunidad ",g," (",sizes[as.character(g)]," palabras) gira en torno a ",quote_words(top_words(g,4)),"."),""),collapse=" "),if(K>length(show))paste0(" Hay ",K-length(show)," comunidades m\u00e1s, de menor tama\u00f1o.") else "",q_text)
  hubs<-active[active$role_group %in% c("Eje","Eje y puente"),,drop=FALSE];hubs<-hubs[order(-hubs$z,-hubs$degree,hubs$label),,drop=FALSE]
  bridges<-active[active$role_group %in% c("Puente","Eje y puente")&active$degree>=3L,,drop=FALSE];bridges<-bridges[order(-bridges$participation,-bridges$degree,bridges$label),,drop=FALSE]
  hub_text<-if(nrow(hubs))paste0("Ejes (palabras con muchas m\u00e1s relaciones dentro de su comunidad que el resto de ella): ",paste(vapply(seq_len(min(6L,nrow(hubs))),function(r)paste0("\u00ab",hubs$label[r],"\u00bb (comunidad ",hubs$community[r],", ",hubs$degree[r]," relaciones)"),""),collapse="; "),".") else "Ninguna palabra destaca como eje (z \u2265 2,5): las comunidades no est\u00e1n dominadas por una palabra central."
  bridge_text<-if(nrow(bridges))paste0(" Puentes (palabras que reparten sus relaciones entre varias comunidades y por eso conectan temas distintos): ",paste(vapply(seq_len(min(6L,nrow(bridges))),function(r)paste0("\u00ab",bridges$label[r],"\u00bb (comunidad ",bridges$community[r],", enlaza con las comunidades ",paste(head(strsplit(gsub(" \\([0-9]+\\)","",bridges$linked[r]),", ",fixed=TRUE)[[1]],4L),collapse=", "),")"),""),collapse="; "),".") else " No hay palabras con un papel claro de puente."
  p3<-paste0(hub_text,bridge_text," El resto, ",sum(active$role_group=="Apoyo")," palabras, son de apoyo: se relacionan sobre todo con su propia comunidad y la precisan.")
  p4<-"C\u00f3mo interpretarlo: una relaci\u00f3n indica que dos palabras tienden a aparecer en las mismas fichas; no demuestra que est\u00e9n vinculadas por causa o por significado, ni que una cite a otra. Las comunidades y los roles son descripciones exploratorias que dependen del n\u00famero de palabras, del nivel de significaci\u00f3n y de cu\u00e1ntas relaciones se conservan por palabra: cambia estos valores y comprueba si la lectura se mantiene antes de darle importancia."
  c(p1,p2,p3,p4)
}
# Seleccion declarada y determinista de las palabras que entran en la red. Criterio por defecto: frecuencia documental (DF,
# fichas con mencion; empates por apariciones y etiqueta, orden C). Alternativa: TF-IDF = suma sobre las fichas de la palabra de
# log(1 + frecuencia) multiplicada por ln(N / DF) (Sp??rck Jones, 1972). Techo opcional: se excluyen las palabras presentes en
# mas de max_share de las fichas (p. ej. terminos de la ecuacion de busqueda); se devuelven para poder declararlas.
wiki_concept_selection <- function(index,max_concepts=NULL,criterion="df",max_share=NULL) {
  total<-nrow(index$concepts);N<-nrow(index$documents);df<-as.numeric(index$concepts$documents)
  if(!criterion %in% c("df","tfidf"))abort_user("El criterio de selecci\u00f3n de palabras debe ser fichas con la palabra (df) o TF-IDF (tfidf).")
  if(!is.null(max_share))check_number(max_share,"El techo de fichas",.01,1,integer=FALSE)
  over<-if(!is.null(max_share)&&max_share<1)df>max_share*N else rep(FALSE,total)
  if(all(over))abort_user("El techo de fichas excluye todas las palabras. El\u00e9valo o desact\u00edvalo (100 %).")
  score<-if(criterion=="tfidf"){w<-methods::as(index$counts,"CsparseMatrix");w@x<-log1p(w@x);as.numeric(Matrix::colSums(w))*log(N/pmax(df,1))} else df
  ord<-order(-score,-df,-index$concepts$occurrences,index$concepts$label,method="radix");ord<-ord[!over[ord]]
  keep<-if(is.null(max_concepts))ord else ord[seq_len(min(max_concepts,length(ord)))]
  excluded<-which(over);excluded<-excluded[order(-df[excluded],index$concepts$label[excluded],method="radix")]
  list(keep=sort(keep),criterion=criterion,max_share=if(is.null(max_share))NA_real_ else max_share,excluded_labels=index$concepts$label[excluded],documents=N)
}
wiki_concept_network <- function(index,min_shared=1L,min_similarity=0,resolution=1,seed=2026L,max_concepts=NULL,alpha=NULL,top_k=NULL,criterion="df",max_share=NULL) {
  total<-nrow(index$concepts)
  if(!total)abort_user("El \u00edndice no contiene conceptos. Revisa el vocabulario o el diccionario.")
  if(!is.null(max_concepts))check_number(max_concepts,"Los conceptos incluidos",1,2000)
  selection<-wiki_concept_selection(index,max_concepts,criterion,max_share)
  if(length(selection$keep)<total) {
    keep<-selection$keep;index$concepts<-index$concepts[keep,,drop=FALSE];index$counts<-index$counts[,keep,drop=FALSE]
  }
  n<-nrow(index$concepts)
  if(!n)abort_user("El \u00edndice no contiene conceptos. Revisa el vocabulario o el diccionario.")
  if(n>2000L)abort_user("La red de conceptos admite hasta 2.000 conceptos. Reduce expl\u00edcitamente el vocabulario o usa un diccionario; no se dibuja una red parcial.")
  # Reutiliza el calculo probado de presencia y Jaccard, transponiendo las unidades.
  transposed<-list(documents=data.frame(key=index$concepts$key,doc_id=index$concepts$key,title=index$concepts$label,doi=""),concepts=data.frame(label=index$documents$doc_id),counts=methods::as(Matrix::t(index$counts),"dgCMatrix"))
  f<-wiki_document_network(transposed,min_shared,min_similarity,resolution,seed,shared_label="fichas con ambos conceptos",alpha=alpha,top_k=top_k)
  f$nodes$label<-index$concepts$label;f$nodes$type<-"Concepto";f$nodes$fichas<-as.integer(index$concepts$documents)
  f$nodes$description<-paste(index$concepts$documents,"fichas con menci\u00f3n /",index$concepts$occurrences,"apariciones")
  f$edges$type<-rep("Coaparici\u00f3n",nrow(f$edges))
  f$summary<-do.call(rbind,lapply(sort(unique(f$nodes$community)),function(g){ii<-which(f$nodes$community==g);top<-head(ii[order(-f$nodes$degree[ii],-index$concepts$documents[ii],index$concepts$label[ii])],8L);data.frame(community=g,concepts=length(ii),labels=paste(index$concepts$label[top],collapse=", "))}))
  f$note<-paste(n,"conceptos /",nrow(f$edges),"coapariciones /",length(unique(f$nodes$community[f$nodes$community>0])),"comunidades. Grupo 0: sin conexiones de coaparici\u00f3n con estos umbrales. Louvain ponderado por Jaccard de fichas con menci\u00f3n; notas manuales excluidas. Los grupos son exploratorios.")
  f$params$max_concepts<-if(!is.null(max_concepts)&&max_concepts<total)as.integer(max_concepts) else NA_integer_
  f$params$criterion<-criterion;f$params$max_share<-selection$max_share
  f$stats$concepts_total<-total;f$stats$documents<-selection$documents;f$stats$excluded_ceiling<-length(selection$excluded_labels)
  general<-f$nodes$label[f$nodes$fichas>.30*selection$documents];general<-general[order(-f$nodes$fichas[match(general,f$nodes$label)],general)]
  f$selection<-list(criterion=criterion,max_share=selection$max_share,excluded_labels=selection$excluded_labels,general_labels=general)
  if(n<total)f$note<-paste(f$note,paste0("Se incluyen los ",n," conceptos ",if(criterion=="tfidf")"con mayor TF-IDF (suma de log(1 + frecuencia) x ln(N / fichas) sobre sus fichas; empates por fichas, apariciones y etiqueta)" else "que aparecen en m\u00e1s fichas (empates por apariciones y etiqueta)"," de ",total,if(length(selection$excluded_labels))paste0(", tras excluir ",length(selection$excluded_labels)," presentes en m\u00e1s del ",format(100*selection$max_share,decimal.mark=",")," % de las fichas") else "",". Cada peso Jaccard es el de la red completa; las comunidades se calculan solo con estos conceptos."))
  roles<-wiki_network_roles(f$edges,f$nodes)
  f$nodes<-cbind(f$nodes,roles[c("within_degree","z","participation","role_code","role","role_group","linked")])
  f$roles<-data.frame(id=f$nodes$id,label=f$nodes$label,community=f$nodes$community,fichas=f$nodes$fichas,degree=f$nodes$degree,within_degree=roles$within_degree,z=roles$z,participation=roles$participation,role_group=roles$role_group,role=roles$role,linked=roles$linked,stringsAsFactors=FALSE)
  f$reading<-wiki_network_reading(f)
  f
}
# Referencias validadas contra Crossref (DOI, autores, ano, revista, volumen y paginas) el 15-10-2026.
wiki_network_references <- function(keys=NULL) {
  refs<-c(
    benjamini="Benjamini, Y., y Hochberg, Y. (1995). Controlling the false discovery rate: A practical and powerful approach to multiple testing. Journal of the Royal Statistical Society: Series B (Methodological), 57(1), 289-300. https://doi.org/10.1111/j.2517-6161.1995.tb02031.x",
    blondel="Blondel, V. D., Guillaume, J.-L., Lambiotte, R., y Lefebvre, E. (2008). Fast unfolding of communities in large networks. Journal of Statistical Mechanics: Theory and Experiment, 2008(10), P10008. https://doi.org/10.1088/1742-5468/2008/10/P10008",
    callon="Callon, M., Courtial, J.-P., Turner, W. A., y Bauin, S. (1983). From translations to problematic networks: An introduction to co-word analysis. Social Science Information, 22(2), 191-235. https://doi.org/10.1177/053901883022002003",
    guimera="Guimer\u00e0, R., y Amaral, L. A. N. (2005). Functional cartography of complex metabolic networks. Nature, 433(7028), 895-900. https://doi.org/10.1038/nature03288",
    jaccard="Jaccard, P. (1912). The distribution of the flora in the alpine zone. New Phytologist, 11(2), 37-50. https://doi.org/10.1111/j.1469-8137.1912.tb05611.x",
    luhn="Luhn, H. P. (1958). The automatic creation of literature abstracts. IBM Journal of Research and Development, 2(2), 159-165. https://doi.org/10.1147/rd.22.0159",
    neal="Neal, Z. (2014). The backbone of bipartite projections: Inferring relationships from co-authorship, co-sponsorship, co-attendance and other co-behaviors. Social Networks, 39, 84-97. https://doi.org/10.1016/j.socnet.2014.06.001",
    newman="Newman, M. E. J., y Girvan, M. (2004). Finding and evaluating community structure in networks. Physical Review E, 69(2), 026113. https://doi.org/10.1103/PhysRevE.69.026113",
    sparck="Sp\u00e4rck Jones, K. (1972). A statistical interpretation of term specificity and its application in retrieval. Journal of Documentation, 28(1), 11-21. https://doi.org/10.1108/eb026526",
    traag="Traag, V. A., Waltman, L., y van Eck, N. J. (2019). From Louvain to Leiden: Guaranteeing well-connected communities. Scientific Reports, 9, 5233. https://doi.org/10.1038/s41598-019-41695-z",
    tumminello="Tumminello, M., Miccich\u00e8, S., Lillo, F., Piilo, J., y Mantegna, R. N. (2011). Statistically validated networks in bipartite complex systems. PLoS ONE, 6(3), e17994. https://doi.org/10.1371/journal.pone.0017994")
  unname(if(is.null(keys))refs else refs[keys])
}
# Ejemplo con los datos propios del usuario: la relacion significativa mas intensa y la mas sorprendente (mayor lift).
wiki_network_example <- function(f) {
  fmt<-function(x,d=0)format(round(x,d),big.mark=".",decimal.mark=",",nsmall=d,scientific=FALSE,trim=TRUE)
  fmtp<-function(p)if(is.na(p))"no calculada" else if(p<.001)"menor que 0,001" else format(round(p,3),decimal.mark=",")
  e<-f$edges;e<-e[e$type=="Coaparici\u00f3n"&!is.na(e$lift),,drop=FALSE];N<-f$stats$documents
  if(!nrow(e)||is.null(N))return(character())
  nd<-f$nodes;one<-function(r,lead){a<-nd$label[match(r$from,nd$id)];b<-nd$label[match(r$to,nd$id)];fa<-nd$fichas[match(r$from,nd$id)];fb<-nd$fichas[match(r$to,nd$id)];exp<-fa*fb/N
    paste0(lead," \u00ab",a,"\u00bb aparece en ",fmt(fa)," de las ",fmt(N)," fichas (",fmt(100*fa/N,1)," %) y \u00ab",b,"\u00bb en ",fmt(fb)," (",fmt(100*fb/N,1)," %). Si ambas palabras se repartieran al azar entre las fichas, cabr\u00eda esperar ",fmt(exp,1)," fichas con las dos; en realidad hay ",fmt(r$shared),", es decir, ",fmt(r$lift,1)," veces m\u00e1s de lo esperado. Su Jaccard es ",fmt(r$weight,2)," (",fmt(r$shared)," fichas con ambas entre ",fmt(fa+fb-r$shared)," fichas con al menos una) y la probabilidad de observar tanta coincidencia por azar, ya ajustada por la multiplicidad de pares, es ",fmtp(r$p_adj),".")}
  strongest<-e[order(-e$weight,-e$shared,e$from,e$to,method="radix")[1],,drop=FALSE];surprising<-e[order(-e$lift,-e$shared,e$from,e$to,method="radix")[1],,drop=FALSE]
  out<-one(strongest,"Relaci\u00f3n m\u00e1s intensa de esta red:")
  if(!identical(c(strongest$from,strongest$to),c(surprising$from,surprising$to)))out<-c(out,one(surprising,"Relaci\u00f3n m\u00e1s sorprendente (mayor exceso sobre el azar):"))
  out
}
# Redaccion sugerida para el apartado de metodos, con los parametros realmente usados. Determinista; sin modelo de lenguaje.
wiki_network_methods <- function(f) {
  fmt<-function(x)format(x,big.mark=".",decimal.mark=",",scientific=FALSE,trim=TRUE);pc<-function(x)format(100*x,decimal.mark=",")
  pr<-f$params;st<-f$stats;nd<-f$nodes;active<-nd[nd$community>0,,drop=FALSE];K<-length(unique(active$community));N<-st$documents
  ver<-tryCatch(paste0(if(requireNamespace("bibliolab",quietly=TRUE))paste0("bibliolab ",utils::packageVersion("bibliolab"),"; ") else "","R ",getRversion(),"; igraph ",utils::packageVersion("igraph")),error=function(e)"R")
  sel<-if(identical(pr$criterion,"tfidf"))paste0("las ",nrow(nd)," palabras con mayor TF-IDF (suma, sobre las fichas en que aparece cada palabra, de log(1 + frecuencia) multiplicada por el logaritmo neperiano del cociente entre el n\u00famero de fichas y el de fichas con la palabra; Sp\u00e4rck Jones, 1972)") else paste0("las ",nrow(nd)," palabras con mayor frecuencia documental, es decir, el n\u00famero de fichas en que aparece cada palabra con independencia de cu\u00e1ntas veces se repita (empates resueltos por el total de apariciones y el orden alfab\u00e9tico)")
  ceil<-if(!is.null(st$excluded_ceiling)&&st$excluded_ceiling>0)paste0(" Se excluyeron previamente ",st$excluded_ceiling," palabras presentes en m\u00e1s del ",pc(pr$max_share)," % de las fichas (",paste(head(f$selection$excluded_labels,10),collapse=", "),if(st$excluded_ceiling>10)", entre otras" else "",").") else if(!is.na(pr$max_share))" No se excluy\u00f3 ninguna palabra por exceso de presencia." else " No se aplic\u00f3 techo de presencia."
  m1<-paste0("Datos y vocabulario. El an\u00e1lisis se realiz\u00f3 sobre ",fmt(N)," fichas (un documento por ficha). Para la red de palabras se seleccionaron ",sel,".",ceil," La unidad de an\u00e1lisis es la presencia o ausencia de cada palabra en cada ficha.")
  has_alpha<-!is.na(pr$alpha);has_k<-!is.na(pr$top_k)
  m2<-paste0("Relaciones. Dos palabras se consideraron relacionadas si aparecen juntas en al menos ",fmt(pr$min_shared)," ",if(pr$min_shared==1)"ficha" else "fichas",if(pr$min_similarity>0)paste0(" y su coeficiente de Jaccard (Jaccard, 1912), definido como el n\u00famero de fichas con ambas palabras dividido entre el n\u00famero de fichas con al menos una de ellas, alcanza ",format(pr$min_similarity,decimal.mark=",")) else "; la intensidad de la relaci\u00f3n se midi\u00f3 con el coeficiente de Jaccard (Jaccard, 1912), definido como el n\u00famero de fichas con ambas palabras dividido entre el n\u00famero de fichas con al menos una de ellas",". ",
    if(has_alpha)paste0("Se contrast\u00f3 cada uno de los ",fmt(st$pairs)," pares posibles con una prueba hipergeom\u00e9trica unilateral, cuya hip\u00f3tesis nula es una coaparici\u00f3n aleatoria condicionada al n\u00famero de fichas de cada palabra (Tumminello et al., 2011), y se corrigi\u00f3 la multiplicidad con el procedimiento de Benjamini y Hochberg (1995) fijando la tasa de falsos descubrimientos en ",pc(pr$alpha)," %. Resultaron significativos ",fmt(st$significant)," pares",if(has_k)paste0(". Para facilitar la lectura, cada palabra conserv\u00f3 sus ",pr$top_k," relaciones significativas m\u00e1s intensas seg\u00fan Jaccard (una relaci\u00f3n se dibuja si figura entre las ",pr$top_k," m\u00e1s intensas de alguna de sus dos palabras); esta reducci\u00f3n es descriptiva y no inferencial") else "",". La red final contiene ",fmt(st$kept)," relaciones entre ",nrow(active)," palabras.") else paste0("No se aplic\u00f3 prueba de significaci\u00f3n; la red contiene ",fmt(st$kept)," relaciones entre ",nrow(active)," palabras."))
  grp<-table(factor(active$role_group,levels=c("Eje","Eje y puente","Puente","Apoyo")))
  q<-if(is.na(f$modularity))"" else paste0(", con una modularidad Q = ",format(round(f$modularity,2),decimal.mark=",")," (Newman y Girvan, 2004)")
  m3<-paste0("Comunidades y roles. Las comunidades se identificaron con el algoritmo de Louvain (Blondel et al., 2008) sobre la red ponderada por Jaccard, con resoluci\u00f3n ",format(pr$resolution,decimal.mark=",")," y semilla ",pr$seed," para asegurar la reproducibilidad; se obtuvieron ",K," comunidades",q,". El papel de cada palabra se clasific\u00f3 seg\u00fan la tipolog\u00eda de Guimer\u00e0 y Amaral (2005), que combina el z-score de su grado dentro de su comunidad (eje si z \u2265 2,5) y su coeficiente de participaci\u00f3n P, que mide c\u00f3mo reparte sus relaciones entre comunidades. Resultaron ",grp[["Eje"]]," ejes, ",grp[["Eje y puente"]]," ejes y puente, ",grp[["Puente"]]," puentes y ",grp[["Apoyo"]]," palabras de apoyo. C\u00e1lculos realizados con ",ver,".")
  m4<-"Limitaciones. La coaparici\u00f3n no implica relaci\u00f3n causal ni sem\u00e1ntica. La prueba hipergeom\u00e9trica condiciona a las frecuencias documentales de las palabras, pero no modela la heterogeneidad en la longitud de las fichas, que modelos nulos m\u00e1s flexibles s\u00ed contemplan (Neal, 2014). El procedimiento de Benjamini y Hochberg (1995) supone independencia o ciertas formas de dependencia positiva entre contrastes. Louvain es un algoritmo heur\u00edstico que puede devolver comunidades poco conectadas (Traag et al., 2019). Las comunidades y los roles dependen del vocabulario seleccionado, por lo que se comprob\u00f3, o se recomienda comprobar, su estabilidad variando el n\u00famero de palabras, el criterio de selecci\u00f3n, el n\u00famero de relaciones por palabra y la resoluci\u00f3n."
  c(m1,m2,m3,m4)
}
wiki_relation_documents <- function(index,from,to) {
  j<-match(c(from,to),index$concepts$key)
  if(anyNA(j))abort_user("Selecciona una conexi\u00f3n entre dos conceptos vigentes.")
  a<-as.numeric(index$counts[,j[1]]);b<-as.numeric(index$counts[,j[2]]);ii<-which(a>0&b>0);d<-index$documents[ii,,drop=FALSE]
  data.frame(doc_id=d$doc_id,titulo=d$title,doi=d$doi,menciones_origen=a[ii],menciones_destino=b[ii],stringsAsFactors=FALSE)
}
wiki_concept_graph <- function(index,node,scope="global",community="all",min_shared=1L,min_similarity=0,resolution=1,seed=2026L,remove_isolates=FALSE,notes=wiki_empty_notes(),include_manual=TRUE,manual_links=NULL,network=NULL) {
  f<-network %||% wiki_concept_network(index,min_shared,min_similarity,resolution,seed)
  nodes<-f$nodes;edges<-f$edges
  edges$evidence<-rep("",nrow(edges))
  manual<-if(include_manual){if(!is.null(manual_links))manual_links else if(nrow(notes))wiki_note_links(notes,index) else NULL} else NULL
  if(!is.null(manual)&&nrow(manual)) {
    manual<-unique(manual[manual$resolved&manual$from %in% nodes$id&manual$to %in% nodes$id,c("from","to"),drop=FALSE])
    if(nrow(manual))edges<-rbind(edges,data.frame(from=manual$from,to=manual$to,weight=1,shared=NA_real_,type="Nota expl\u00edcita",p_adj=NA_real_,lift=NA_real_,evidence="Enlace escrito por el investigador; no interviene en Louvain."))
  }
  if(scope=="community"&&community!="all")nodes<-nodes[as.character(nodes$community)==as.character(community),,drop=FALSE]
  if(scope=="local") {
    if(node %in% index$concepts$key)keys<-unique(c(node,edges$to[edges$from==node],edges$from[edges$to==node]))
    else {i<-match(node,index$documents$key);if(is.na(i))abort_user("Selecciona una ficha o concepto vigente.");keys<-index$concepts$key[which(as.numeric(index$counts[i,])>0)]}
    nodes<-nodes[nodes$id %in% keys,,drop=FALSE]
  }
  edges<-edges[edges$from %in% nodes$id&edges$to %in% nodes$id,,drop=FALSE]
  if(remove_isolates)nodes<-nodes[nodes$id %in% unique(c(edges$from,edges$to)),,drop=FALSE]
  if(!nrow(nodes))abort_user("No hay conceptos en esta vista. Revisa los umbrales, la p\u00e1gina activa o la opci\u00f3n de ocultar aislados.")
  drawn<-sum(edges$type=="Coaparici\u00f3n")
  if(nrow(nodes)>500L||drawn>5000L)abort_user(paste0("Esta vista tiene ",nrow(nodes)," conceptos y ",drawn," coapariciones; para conservar una lectura legible el dibujo admite hasta 500 y 5.000. Reduce los conceptos incluidos (los N m\u00e1s frecuentes), conserva menos relaciones por palabra, eleva el m\u00ednimo de fichas o el Jaccard, o elige una comunidad o el entorno local. La tabla de comunidades conserva toda la red calculada; no se dibuja una vista recortada."))
  nodes$central<-if(scope=="local")nodes$id==node else rep(FALSE,nrow(nodes))
  # Contextos completos solo al solicitar un enlace: no se duplican textos en cada arista.
  edges<-edges[order(edges$type,edges$from,edges$to),,drop=FALSE];rownames(edges)<-NULL;rownames(nodes)<-NULL
  list(nodes=nodes,edges=edges,kind="concepts",communities=f$summary,memberships=f$nodes[c("id","community","degree")],network_params=f$params,
    audit=data.frame(criterio=c("Alcance","Selecci\u00f3n de palabras","Conceptos de la red / dibujo","Coapariciones / enlaces expl\u00edcitos dibujados","Regla de coaparici\u00f3n","Peso autom\u00e1tico","Asociaci\u00f3n frente al azar","Roles de las palabras","Comunidades","Modularidad","Qu\u00e9 puede concluirse"),valor=c(switch(scope,global="Todos los conceptos del \u00edndice",local="Entorno del concepto / conceptos presentes en la ficha activa",community=paste("Subgrafo inducido / comunidad",community)),paste0(if(identical(f$params$criterion,"tfidf"))"TF-IDF (suma de log(1 + frecuencia) x ln(N / fichas))" else "Fichas con la palabra (frecuencia documental)",if(!is.na(f$params$max_concepts))paste0("; las ",f$params$max_concepts," primeras") else "; todas",if(!is.na(f$params$max_share))paste0("; techo: se excluyen ",length(f$selection$excluded_labels)," palabras presentes en m\u00e1s del ",format(100*f$params$max_share,decimal.mark=",")," % de las fichas") else "; sin techo de presencia"),paste(nrow(f$nodes),"/",nrow(nodes)),paste(sum(edges$type=="Coaparici\u00f3n"),sum(edges$type=="Nota expl\u00edcita"),sep=" / "),paste("M\u00ednimo",f$params$min_shared,"fichas con ambos conceptos / Jaccard m\u00ednimo",f$params$min_similarity),"Jaccard = fichas con ambos / fichas con al menos uno. Repetir una palabra no aumenta este peso.",
      if(is.na(f$params$alpha))"Sin prueba de significaci\u00f3n: se dibujan todas las coapariciones que cumplen el m\u00ednimo y el Jaccard." else paste0("Prueba hipergeom\u00e9trica unilateral por pares (marginales fijos: fichas de cada concepto) con control de la tasa de falsos descubrimientos de Benjamini-Hochberg al ",format(100*f$params$alpha,decimal.mark=",")," % sobre los ",format(f$stats$pairs,big.mark=".",decimal.mark=",",scientific=FALSE)," pares posibles",if(is.na(f$params$top_k))"." else paste0(". Cada palabra conserva sus ",f$params$top_k," relaciones significativas m\u00e1s fuertes por Jaccard; es una simplificaci\u00f3n para la legibilidad.")),
      "Guimer\u00e0 y Amaral (2005): eje si el grado dentro de su comunidad supera en 2,5 desviaciones t\u00edpicas la media de esa comunidad; puente seg\u00fan el coeficiente de participaci\u00f3n P (m\u00e1s de 0,62 sin ser eje; m\u00e1s de 0,30 siendo eje). Descriptivo y dependiente de las comunidades.",
      paste("Louvain / resoluci\u00f3n",resolution,"/ semilla",seed,"/ grupo 0 sin coapariciones. Pertenencia de la red completa; las notas no intervienen."),format(f$modularity,digits=4),"Una coaparici\u00f3n permite localizar lecturas conjuntas; no demuestra cita, acuerdo, sinonimia ni causalidad. Un backlink expl\u00edcito es la relaci\u00f3n inversa de un enlace escrito en una nota.")),note=f$note,roles=f$roles,reading=f$reading,stats=f$stats,selection=f$selection)
}
