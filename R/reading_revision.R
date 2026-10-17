# Fuentes de lectura y proyeccion documental: funciones sin estado de Shiny.
wiki_field_profile <- function(raw,mapping) {
  fields<-names(raw);nm<-gsub("[^a-z0-9]+"," ",ascii_fold(tolower(fields)))
  abstract<-grepl("abstract|resumen|resumo|summary|^ab$|^ak$|^x4$|^y4$|^z4$",nm)
  title<-fields %in% mapping$title | grepl("^title$|^titulo$|^ti$|article title",nm)
  body<-abstract|title
  n<-vapply(raw,function(v)sum(nzchar(trimws(clean_value(v)))),1L)
  lang<-vapply(seq_along(fields),function(i){
    declared<-if(grepl("korean|^ak$",nm[i]))"coreano" else if(grepl("spanish|espan|^x4$",nm[i]))"espa\u00f1ol" else if(grepl("portugu|^y4$",nm[i]))"portugu\u00e9s" else if(grepl("foreign|non english|^z4$",nm[i]))"otra lengua / sin especificar" else "sin especificar"
    sample<-head(clean_value(raw[[i]])[nzchar(trimws(clean_value(raw[[i]])))],20L)
    detected<-if(body[i]&&length(sample)&&requireNamespace("cld2",quietly=TRUE))tryCatch(cld2::detect_language(substr(sample,1,3000),plain_text=TRUE),error=function(e)character()) else character()
    detected<-sort(table(detected[!is.na(detected)&detected!="un"]),decreasing=TRUE)
    labels<-c(es="espa\u00f1ol",en="ingl\u00e9s",fr="franc\u00e9s",de="alem\u00e1n",pt="portugu\u00e9s",it="italiano",ko="coreano",ja="japon\u00e9s",zh="chino",gl="gallego",ca="catal\u00e1n",ru="ruso",ar="\u00e1rabe")
    codes<-names(detected);languages<-ifelse(codes %in% names(labels),unname(labels[codes]),paste("c\u00f3digo",codes))
    paste0("Campo: ",declared,if(length(detected))paste0("; muestra (hasta 20): ",paste(languages,as.integer(detected),sep="=",collapse=", ")) else "")
  },"")
  data.frame(field=fields,kind=ifelse(abstract,"Resumen",ifelse(title,"T\u00edtulo","Otro campo / avanzado")),nonempty=n,total=nrow(raw),coverage=if(nrow(raw))100*n/nrow(raw) else 0,language=lang,recommended=body,stringsAsFactors=FALSE)
}
wiki_attach_metadata <- function(index,raw) {
  nm<-gsub("[^a-z0-9]+"," ",ascii_fold(tolower(names(raw))))
  aliases<-list(publication_date=c("publication date","date of publication","cover date","coverdate","pd","fecha de publicacion"),early_access_date=c("early access date","early access","ea","date of electronic publication"))
  rows<-index$documents$source_row
  for(k in names(aliases)){j<-match(aliases[[k]],nm);j<-j[!is.na(j)];index$documents[[k]]<-if(length(j)&&length(rows))clean_value(raw[[j[1]]][rows]) else rep("",nrow(index$documents))}
  index
}
wiki_metadata_ui <- function(d) {
  row<-function(label,value)if(length(value)&&!is.na(value)&&nzchar(trimws(as.character(value))))tags$p(tags$strong(paste0(label,": ")),value)
  doi<-d$doi %||% "";doi<-sub("^https?://(dx[.])?doi[.]org/","",doi,ignore.case=TRUE)
  tags$div(class="document-metadata",row("Autores",d$authors),row("Revista / fuente",d$source),row("A\u00f1o bibliogr\u00e1fico",d$year),
    row("Fecha de publicaci\u00f3n / campo del archivo",d$publication_date),row("Publicaci\u00f3n anticipada / Early Access",d$early_access_date),
    if(nzchar(doi))tags$p(tags$strong("DOI: "),tags$a(href=paste0("https://doi.org/",utils::URLencode(doi,reserved=FALSE)),target="_blank",rel="noopener",doi)))
}
lda_document_rows <- function(fit,ids=NULL,page=1L,page_size=18L) {
  d<-fit$document_topics
  if(!is.null(ids))return(d[match(intersect(ids,d$doc_id),d$doc_id),,drop=FALSE])
  check_number(page_size,"Documentos por p\u00e1gina",1,100);page<-max(1L,min(as.integer(page),max(1L,ceiling(nrow(d)/page_size))))
  d[seq_len(nrow(d))>(page-1L)*page_size & seq_len(nrow(d))<=page*page_size,,drop=FALSE]
}
lda_document_labels <- function(fit,prepared) {
  d<-prepared$documents[match(fit$document_topics$doc_id,prepared$documents$doc_id),]
  setNames(fit$document_topics$doc_id,paste(d$doc_id,d$title,ifelse(nzchar(d$doi),paste("DOI",d$doi),""),sep=" \u00b7 "))
}
lda_composition_figure <- function(fit,prepared,d) {
  if(!nrow(d))abort_user("Elige al menos un documento para consultar su composici\u00f3n.")
  k<-fit$params$k;dd<-prepared$documents[match(d$doc_id,prepared$documents$doc_id),]
  labels<-paste(d$doc_id,ifelse(nchar(dd$title)>65,paste0(substr(dd$title,1,62),"\u2026"),dd$title),sep=" \u00b7 ")
  long<-data.frame(documento=factor(rep(labels,each=k),levels=rev(labels)),tema=factor(rep(paste("Tema",seq_len(k)),nrow(d)),levels=paste("Tema",seq_len(k))),proporcion=as.numeric(t(as.matrix(d[-1]))))
  ggplot2::ggplot(long,ggplot2::aes(proporcion,documento,fill=tema))+ggplot2::geom_col(width=.7,position=ggplot2::position_stack(reverse=TRUE))+
    ggplot2::scale_fill_manual(values=setNames(swiss_colours(k),paste("Tema",seq_len(k))))+
    ggplot2::scale_x_continuous(labels=function(x)paste0(round(100*x),"%"),limits=c(0,1),expand=c(0,0))+
    ggplot2::labs(x="Composici\u00f3n estimada / cada documento suma 100%",y=NULL,fill=NULL,title="Mezcla tem\u00e1tica de los documentos elegidos",subtitle=paste(nrow(d),"documentos mostrados de",nrow(fit$document_topics),"/ selecci\u00f3n por p\u00e1gina o por ID, t\u00edtulo y DOI"))+swiss_theme()+
    ggplot2::theme(axis.text.y=ggplot2::element_text(size=10),panel.grid.major.y=ggplot2::element_blank())
}
# Diagnostico exacto cuando la red supera el limite. No se recorta la red ni se cambian los
# umbrales: se informa de cuanto la superan y de los umbrales que, elevados de forma explicita,
# dejan la red completa dentro del limite. Un umbral u es admisible si hay a lo sumo `limit` pares
# con valor >= u; basta u > (limit+1)-esimo valor mayor.
wiki_network_limit_message <- function(shared,sim,min_shared,min_similarity,limit,label) {
  fmt<-function(x)format(x,big.mark=".",decimal.mark=",",scientific=FALSE,trim=TRUE)
  w<-sort(sim,decreasing=TRUE)[limit+1L];jaccard<-ceiling(w*100+1e-6)/100
  m<-as.integer(sort(shared,decreasing=TRUE)[limit+1L])+1L
  options<-c(if(jaccard<=1)paste0("Jaccard m\u00ednimo ",format(jaccard,decimal.mark=",")," (",fmt(sum(sim>=jaccard))," relaciones)"),
    if(m<=max(shared))paste0("m\u00ednimo compartido ",m," (",fmt(sum(shared>=m))," relaciones)"))
  paste0("La red supera ",fmt(limit)," relaciones: tiene ",fmt(length(sim))," con m\u00ednimo compartido ",min_shared," (",label,") y Jaccard ",format(min_similarity,decimal.mark=","),". ",
    if(length(options))paste0("Eleva expl\u00edcitamente uno de estos umbrales; cada uno, aplicado por separado, deja la red completa dentro del l\u00edmite: ",paste(options,collapse="; "),". ") else "Ning\u00fan umbral m\u00e1s estricto basta: reduce el vocabulario o usa una muestra. ",
    "No se acepta una red parcial ni se modifican los umbrales autom\u00e1ticamente.")
}
# Conserva, entre las relaciones candidatas, las `k` mas fuertes de cada nodo (union de ambos extremos).
# Los empates se resuelven por el orden de los nodos: el resultado es determinista. Es una
# simplificacion descriptiva para la legibilidad, no una inferencia estadistica.
wiki_strongest_links <- function(i,j,w,k) {
  e<-seq_along(i);long<-data.frame(node=c(i,j),e=c(e,e),w=c(w,w))
  long<-long[order(long$node,-long$w,long$e),,drop=FALSE]
  sort(unique(long$e[stats::ave(long$e,long$node,FUN=seq_along)<=k]))
}
# Una red documental global distinta del entorno local. Se computan todos los pares por bloques.
# Filtros, en este orden y todos explicitos: (1) si se pide `alpha`, asociacion mayor que el azar (test
# hipergeometrico unilateral) con control de la tasa de falsos descubrimientos de Benjamini-Hochberg sobre
# la familia completa de n(n-1)/2 pares: todos los pares con alguna coaparicion se contrastan y el resto
# tiene p = 1; (2) minimo compartido y (3) Jaccard minimo, como filtros descriptivos que no alteran la
# familia ni las p ajustadas; (4) las `top_k` relaciones mas fuertes de cada nodo (si se pide). Los
# limites fallan explicitamente, sin aceptar un resultado parcial.
wiki_document_network <- function(index,min_shared=2L,min_similarity=.1,resolution=1,seed=2026L,shared_label="conceptos compartidos",alpha=NULL,top_k=NULL) {
  check_number(min_shared,"Conceptos compartidos",1,10000);check_number(min_similarity,"Similitud Jaccard m\u00ednima",0,1,integer=FALSE);check_number(resolution,"Resoluci\u00f3n Louvain",.1,5,integer=FALSE)
  if(!is.null(alpha))check_number(alpha,"El nivel de significaci\u00f3n (FDR)",.0001,.5,integer=FALSE)
  if(!is.null(top_k))check_number(top_k,"Las relaciones m\u00e1s fuertes por nodo",1,50)
  n<-nrow(index$documents);if(n>2000L)abort_user("La vista global y las comunidades admiten hasta 2.000 documentos. Usa una muestra expl\u00edcita; el entorno local sigue disponible y no se dibuja una red global parcial.")
  b<-(index$counts>0)*1;degree<-as.numeric(Matrix::rowSums(b));trials<-ncol(b);limit<-100000L;pairs_total<-n*(n-1)/2
  blocks<-list()
  for(start in seq.int(1L,n,by=100L)) {
    rows<-seq.int(start,min(n,start+99L));s<-Matrix::summary(methods::as(Matrix::tcrossprod(b[rows,,drop=FALSE],b),"dgCMatrix"))
    i<-rows[s$i];j<-s$j;keep<-i<j&s$x>=1
    blocks[[length(blocks)+1L]]<-list(i=i[keep],j=j[keep],shared=s$x[keep])
  }
  I<-as.integer(unlist(lapply(blocks,`[[`,"i")));J<-as.integer(unlist(lapply(blocks,`[[`,"j")));SH<-as.numeric(unlist(lapply(blocks,`[[`,"shared")))
  o<-order(I,J);I<-I[o];J<-J[o];SH<-SH[o];SIM<-SH/(degree[I]+degree[J]-SH);padj<-rep(NA_real_,length(I))
  # P(X >= k) con marginales fijos; los pares sin coaparicion tienen p = 1 y no alteran los rangos de BH.
  if(length(I))padj<-stats::p.adjust(stats::phyper(SH-1,degree[I],trials-degree[I],degree[J],lower.tail=FALSE),"BH",n=pairs_total)
  significant<-if(is.null(alpha))rep(TRUE,length(I)) else padj<=alpha
  # El minimo compartido, igual que Jaccard, es un filtro descriptivo posterior: la familia de BH incluye todas las coapariciones positivas.
  reported<-SH>=min_shared
  cand<-which(significant&reported&SIM>=min_similarity);after_filters<-length(cand)
  if(!is.null(top_k)&&length(cand))cand<-cand[wiki_strongest_links(I[cand],J[cand],SIM[cand],top_k)]
  if(length(cand)>limit)abort_user(wiki_network_limit_message(SH[cand],SIM[cand],min_shared,min_similarity,limit,shared_label))
  stats_n<-list(units=n,pairs=pairs_total,tested=length(I),candidates=sum(reported),significant=sum(significant&reported),after_filters=after_filters,kept=length(cand))
  parts<-if(length(cand))list(data.frame(from=index$documents$key[I[cand]],to=index$documents$key[J[cand]],weight=SIM[cand],shared=SH[cand],type="Conceptos compartidos",p_adj=padj[cand],lift=SH[cand]*trials/(degree[I[cand]]*degree[J[cand]]),stringsAsFactors=FALSE)) else list()
  edges<-if(length(parts))do.call(rbind,parts) else data.frame(from=character(),to=character(),weight=numeric(),shared=numeric(),type=character(),p_adj=numeric(),lift=numeric())
  docs<-index$documents;nodes<-data.frame(id=docs$key,label=ifelse(nzchar(docs$title),docs$title,docs$doc_id),type="Documento",central=FALSE,description=paste(docs$doc_id,docs$title,docs$doi,sep=" \u00b7 "),stringsAsFactors=FALSE)
  nodes$label<-ifelse(nchar(nodes$label)>20,paste0(substr(nodes$label,1,20),"\u2026"),nodes$label)
  graph<-igraph::graph_from_data_frame(edges,directed=FALSE,vertices=nodes)
  nodes$degree<-as.integer(igraph::degree(graph));nodes$community<-0L;active<-which(nodes$degree>0);q<-NA_real_
  if(length(active)) {
    sub<-igraph::induced_subgraph(graph,active);cl<-with_seed(seed,igraph::cluster_louvain(sub,weights=igraph::E(sub)$weight,resolution=resolution));member<-as.integer(igraph::membership(cl))
    # Numeros estables por tamano y primer ID; no implican un orden sustantivo.
    groups<-sort(unique(member));first<-vapply(groups,function(g)min(igraph::V(sub)$name[member==g]),"");sizes<-vapply(groups,function(g)sum(member==g),1L)
    ordered<-groups[order(-sizes,first)];nodes$community[match(igraph::V(sub)$name,nodes$id)]<-match(member,ordered)
    q<-igraph::modularity(sub,member,weights=igraph::E(sub)$weight,resolution=resolution)
  }
  summary<-do.call(rbind,lapply(sort(unique(nodes$community)),function(g){ii<-which(nodes$community==g);v<-as.numeric(Matrix::colSums(b[ii,,drop=FALSE]));top<-head(order(-v,index$concepts$label),5);top<-top[v[top]>0];data.frame(community=g,documents=length(ii),concepts=paste(index$concepts$label[top],collapse=", "),stringsAsFactors=FALSE)}))
  list(nodes=nodes,edges=edges,summary=summary,modularity=q,params=list(min_shared=min_shared,min_similarity=min_similarity,resolution=resolution,seed=seed,alpha=if(is.null(alpha))NA_real_ else alpha,top_k=if(is.null(top_k))NA_integer_ else as.integer(top_k)),stats=stats_n,note=paste(n,"documentos /",nrow(edges),"enlaces /",length(unique(nodes$community[nodes$community>0])),"comunidades /",sum(nodes$community==0),"aislados. Louvain sobre Jaccard de conceptos presentes; notas manuales excluidas. Las comunidades son exploratorias, no temas validados."))
}
wiki_overview_graph <- function(index,node,scope="global",community="all",min_shared=2L,min_similarity=.1,resolution=1,seed=2026L,remove_isolates=FALSE,network=NULL) {
  f<-network %||% wiki_document_network(index,min_shared,min_similarity,resolution,seed);nodes<-f$nodes
  if(scope=="community"&&community!="all")nodes<-nodes[as.character(nodes$community)==as.character(community),,drop=FALSE]
  if(remove_isolates)nodes<-nodes[nodes$degree>0,,drop=FALSE]
  if(nrow(nodes)>500L)abort_user(paste(nrow(nodes),"documentos en esta vista. Para conservar una lectura legible, el dibujo admite hasta 500: elige una comunidad o usa el entorno local. La tabla de comunidades conserva toda la red calculada."))
  if(!nrow(nodes))abort_user("No hay documentos en este subgrafo con los filtros elegidos.")
  edges<-f$edges[f$edges$from %in% nodes$id&f$edges$to %in% nodes$id,,drop=FALSE];nodes$central<-nodes$id==node
  edges$evidence<-vapply(seq_len(nrow(edges)),function(k){i<-match(edges$from[k],index$documents$key);j<-match(edges$to[k],index$documents$key);ts<-which(as.numeric(index$counts[i,])>0&as.numeric(index$counts[j,])>0);paste(index$concepts$label[ts],collapse=", ")},"")
  list(nodes=nodes,edges=edges,communities=f$summary,memberships=f$nodes[c("id","community","degree")],network_params=f$params,audit=data.frame(criterio=c("Alcance","Documentos de la red / dibujo","Peso","Regla de enlace","Comunidades","Modularidad","L\u00edmites de interpretaci\u00f3n"),valor=c(if(scope=="community")paste("Subgrafo inducido de la comunidad",community) else "Red documental global",paste(nrow(f$nodes),"/",nrow(nodes)),"Jaccard: conceptos compartidos / conceptos distintos presentes entre ambos documentos",paste("M\u00ednimo compartido",min_shared,"/ Jaccard",min_similarity),paste("Louvain / resoluci\u00f3n",resolution,"/ semilla",seed,"/ aislados = 0"),format(f$modularity,digits=4),"No representa citas ni garantiza validez tem\u00e1tica. No se mezclan notas manuales con la detecci\u00f3n.")),note=f$note)
}
expanded_ordination_ui <- function(f,kind,focus="",quadrant="all") {
  ca<-identical(kind,"ca")
  controls<-if(ca) {
    fluidRow(
      column(8,selectizeInput("expanded_ca_focus","Localizar un t\u00e9rmino",c("Plano general"="",setNames(f$terms$termino,f$terms$termino)),selected=focus)),
      column(4,numericInput("expanded_ca_labels","M\u00e1ximo de etiquetas",min(40,nrow(f$terms)),1,nrow(f$terms))))
  } else {
    tagList(
      fluidRow(
        column(6,selectInput("expanded_pca_view","Plano ampliado",c("Documentos"="documents","Variables / correlaciones"="terms"),selected=kind)),
        column(6,numericInput("expanded_pca_labels","M\u00e1ximo de etiquetas",min(40,nrow(f$terms)),1,min(300,max(nrow(f$terms),nrow(f$documents)))))),
      selectInput("expanded_pca_quadrant","Cuadrante de variables",c("Plano completo"="all","Horizontal + / vertical +"="pp","Horizontal \u2212 / vertical +"="np","Horizontal \u2212 / vertical \u2212"="nn","Horizontal + / vertical \u2212"="pn"),selected=quadrant),
      selectizeInput("expanded_pca_focus","Localizar documento o t\u00e9rmino",c("Vista general"="",setNames(f$documents$doc_id,paste(f$documents$doc_id,f$documents$title)),setNames(f$terms$termino,f$terms$termino)),selected=""))
  }
  tags$div(class="ca-expanded-shell",
    tags$details(class="ca-figure-controls",tags$summary(if(ca)"Buscar t\u00e9rminos / mostrar m\u00e1s etiquetas / interpretaci\u00f3n" else "Cambiar documentos o variables / buscar / mostrar m\u00e1s etiquetas"),
      controls,
      hint("El m\u00e1ximo puede llegar a todos los t\u00e9rminos del modelo. Se colocan las etiquetas que caben en el espacio disponible; los dem\u00e1s puntos conservan su informaci\u00f3n al pasar el cursor. Los ejes y las coordenadas se mantienen. Usa b\u00fasqueda, cuadrante o zoom para casos densos. Cierra estos controles para dedicar el modal al gr\u00e1fico.")),
    plotly::plotlyOutput(if(ca)"ca_expanded" else "pca_expanded",height="100%",width="100%"))
}
