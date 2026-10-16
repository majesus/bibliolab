# Una pagina es un documento y su texto elegido; las relaciones tienen evidencia.
wiki_document_graph <- function(index,node,max_terms=12L,max_docs=20L,min_shared=2L,notes=wiki_empty_notes(),include_manual=TRUE,manual_links=NULL) {
  g<-wiki_local_graph(index,node,max_terms,max_docs,min_shared,notes,include_manual,manual_links,view="bipartite")
  docs<-g$nodes[g$nodes$type=="Documento",,drop=FALSE]
  ds<-match(docs$id,index$documents$key);ts<-match(g$nodes$id[g$nodes$type=="Concepto"],index$concepts$key)
  threshold<-if(node %in% index$concepts$key)1L else min_shared
  b<-index$counts[ds,ts,drop=FALSE]>0
  shared<-as.matrix(Matrix::tcrossprod(b*1));pairs<-which(upper.tri(shared)&shared>=threshold,arr.ind=TRUE)
  edges<-data.frame(from=docs$id[pairs[,1]],to=docs$id[pairs[,2]],weight=if(nrow(pairs))shared[pairs] else numeric(),type=rep("Conceptos compartidos",nrow(pairs)),evidence=character(nrow(pairs)))
  for(i in seq_len(nrow(pairs))){j<-which(as.logical(b[pairs[i,1],])&as.logical(b[pairs[i,2],]));edges$evidence[i]<-paste(index$concepts$label[ts[j]],collapse=", ")}
  manual<-g$edges[g$edges$type=="Nota expl\u00edcita"&g$edges$from %in% docs$id&g$edges$to %in% docs$id,,drop=FALSE]
  if(nrow(manual)){manual$evidence<-"Enlace escrito por el investigador";edges<-rbind(edges,manual)}
  # El grafo local conserva todos los enlaces entre los documentos seleccionados.
  note<-if(!nrow(edges))"No hay enlaces entre los documentos seleccionados. Revisa el m\u00ednimo compartido o escribe un enlace expl\u00edcito en una nota." else paste(nrow(edges),"enlaces entre",nrow(docs),"documentos. Pasa el cursor por una l\u00ednea para ver los conceptos que la justifican.")
  list(nodes=docs,edges=edges,audit=rbind(data.frame(criterio=c("Qu\u00e9 representa una p\u00e1gina","Relaci\u00f3n entre documentos","M\u00ednimo de conceptos compartidos","Lectura del resultado"),valor=c(paste("Documento / texto de",index$params$text_field %||% "la columna preparada"),"Coincidencias literales de conceptos seleccionados; nunca citas o afinidad sem\u00e1ntica inferida",threshold,note)),g$audit),note=note)
}
