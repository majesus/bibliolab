# Lectura enlazada determinista. Menciones lexicas y enlaces de notas son relaciones distintas.
WIKI_LIMITS <- list(concepts=100L,variants=300L,matches=250000L,chars=1e7,note_chars=20000L,note_total=4e6)
wiki_require_matrix <- function() {
  if(!requireNamespace("Matrix",quietly=TRUE))abort_user("La lectura del \u00edndice necesita el paquete Matrix.")
  invisible(TRUE)
}
wiki_escape_regex <- function(x) {
  vapply(strsplit(x,"",fixed=TRUE),function(chars) paste0(ifelse(chars %in% c("\\",".","^","$","|","?","*","+","(",")","[","]","{","}"),paste0("\\",chars),chars),collapse=""),"")
}
wiki_key <- function(x) tolower(gsub("[\\h]+"," ",trimws(normalize_unicode(x)),perl=TRUE))
wiki_pattern <- function(forms) {
  forms<-forms[order(-nchar(forms),forms)]
  escaped<-wiki_escape_regex(forms)
  escaped<-gsub(" +","\\\\h+",escaped,perl=TRUE)
  paste0("(?<![\\p{L}\\p{M}\\p{N}_])(?:",paste(escaped,collapse="|"),")(?![\\p{L}\\p{M}\\p{N}_])")
}
wiki_token_pattern <- function(token) paste0("(?<!\\S)(?:",wiki_escape_regex(token),")(?!\\S)")
wiki_dictionary <- function(text) {
  lines<-trimws(strsplit(normalize_unicode(text),"\n",fixed=TRUE)[[1]]);lines<-lines[nzchar(lines)]
  if(!length(lines)) abort_user("Escribe al menos un concepto, uno por l\u00ednea. Puedes a\u00f1adir variantes separadas por |.")
  if(any(grepl("(^[|]|[|]$|[|][\\h]*[|])",lines,perl=TRUE)))abort_user("Cada concepto y variante debe tener texto; no dejes un campo vac\u00edo junto a |.")
  if(length(lines)>WIKI_LIMITS$concepts) abort_user("El diccionario admite como m\u00e1ximo 100 conceptos por \u00edndice.")
  forms<-lapply(lines,function(x) unique(wiki_key(strsplit(x,"|",fixed=TRUE)[[1]])))
  if(any(lengths(forms)==0)||any(!nzchar(unlist(forms)))) abort_user("Cada concepto y variante debe tener texto; no dejes un campo vac\u00edo junto a |.")
  if(any(nchar(unlist(forms))>128)||any(grepl("[[:cntrl:]\\[\\]]|\ufffc",unlist(forms),perl=TRUE))) abort_user("Usa conceptos de hasta 128 caracteres, sin corchetes ni caracteres de control.")
  if(sum(lengths(forms))>WIKI_LIMITS$variants) abort_user("El diccionario admite como m\u00e1ximo 300 formas, incluidas sus variantes.")
  if(anyDuplicated(unlist(forms))) abort_user("Una misma forma aparece en dos conceptos. As\u00edgnala a uno solo para evitar una equivalencia ambigua.")
  labels<-vapply(forms,`[`,"",1);order<-order(labels);forms<-forms[order];labels<-labels[order]
  d<-data.frame(key=paste0("concept:",labels),label=labels,variants=vapply(forms,paste,"",collapse=" | "),pattern=vapply(forms,wiki_pattern,""),stringsAsFactors=FALSE)
  d
}
wiki_mask_links <- function(text) {
  p<-gregexpr("(?:https?://|www\\.)[^\\s]+|[\\p{L}\\p{N}._%+-]+@[\\p{L}\\p{N}.-]+\\.[\\p{L}]{2,}",text,perl=TRUE,ignore.case=TRUE)[[1]]
  if(p[1]<0) return(text)
  n<-attr(p,"match.length")
  # Barrera, no espacios: excluir una URL no crea una frase a traves de ella.
  for(i in rev(seq_along(p))) substr(text,p[i],p[i]+n[i]-1)<-strrep("\ufffc",n[i])
  text
}
wiki_hits <- function(text,pattern) {
  x<-gregexpr(pattern,text,perl=TRUE,ignore.case=TRUE)[[1]]
  if(x[1]<0) return(data.frame(start=integer(),end=integer()))
  data.frame(start=as.integer(x),end=as.integer(x+attr(x,"match.length")-1))
}
wiki_fingerprint <- function(data) {
  # Identidad por columnas y valores; no depende de nombre de archivo, lector o fecha.
  values<-lapply(data,function(x)enc2utf8(as.character(x)))
  f<-tempfile("wiki_source_");on.exit(unlink(f),add=TRUE);saveRDS(values,f,version=2);unname(tools::md5sum(f))
}
build_wiki_index <- function(prepared,corpus,mode="corpus",dictionary="",source_key="",progress=NULL,text_source="prepared") {
  wiki_require_matrix()
  if(!mode %in% c("corpus","dictionary")) abort_user("Selecciona vocabulario preparado o diccionario sobre originales.")
  docs<-prepared$documents
  if(!nrow(docs)||anyDuplicated(docs$doc_id)) abort_user("La lectura enlazada necesita documentos preparados con ID \u00fanicos.")
  matches<-data.frame(doc=integer(),concept=integer(),start=integer(),end=integer())
  if(!text_source %in% c("original","prepared"))abort_user("Selecciona texto original o preparado para el cuaderno.")
  if(mode=="corpus" && text_source=="prepared") {
    if(is.null(corpus$counts)||!ncol(corpus$counts)) abort_user("No hay vocabulario retenido. Revisa la preparaci\u00f3n o usa un diccionario sobre los originales.")
    m<-document_counts(corpus,prepared)
    co<-sort(colnames(m));concepts<-data.frame(key=paste0("term:",co),label=co,variants=co,pattern=vapply(co,wiki_token_pattern,""),stringsAsFactors=FALSE)
    trip<-Matrix::summary(methods::as(m[,co,drop=FALSE],"dgCMatrix"))
    counts<-Matrix::sparseMatrix(i=match(rownames(m)[trip$i],docs$doc_id),j=trip$j,x=trip$x,dims=c(nrow(docs),length(co)),dimnames=list(docs$doc_id,concepts$key))
    units<-split(corpus$units$cleaned,corpus$units$doc_id)
    texts<-vapply(docs$doc_id,function(id) paste(units[[id]],collapse=" "),"")
    source<-paste0("Texto preparado / ",if(isTRUE(prepared$config$lemmatize))"lemas de UDPipe" else "formas l\u00e9xicas tras limpieza","; enlaces solo a vocabulario retenido",if(isTRUE(prepared$config$split_sentences))"; frases reunidas por documento" else "")
  } else {
    concepts<-if(mode=="dictionary")wiki_dictionary(dictionary) else {
      co<-sort(corpus$vocabulary);if(!length(co))abort_user("No hay t\u00e9rminos retenidos. Prepara vocabulario o escribe un diccionario.")
      data.frame(key=paste0("term:",co),label=co,variants=co,pattern=vapply(co,function(t)wiki_pattern(t),""),stringsAsFactors=FALSE)
    };texts<-clean_value(docs$text)
    if(sum(nchar(texts))>WIKI_LIMITS$chars) abort_user("El diccionario se aplica a un m\u00e1ximo de diez millones de caracteres. Usa una muestra; los modelos anteriores se conservan.")
    masked<-vapply(texts,wiki_mask_links,"");blocks<-list();total<-0L
    for(j in seq_len(nrow(concepts))) {
      hits<-gregexpr(concepts$pattern[j],masked,perl=TRUE,ignore.case=TRUE)
      lens<-vapply(hits,function(h) if(h[1]<0)0L else length(h),1L)
      total<-total+sum(lens)
      if(total>WIKI_LIMITS$matches) abort_user("El diccionario supera 250.000 menciones. Reduce conceptos o usa una muestra; no se acepta un \u00edndice parcial.")
      if(any(lens>0)) blocks[[length(blocks)+1L]]<-do.call(rbind,lapply(which(lens>0),function(i){h<-hits[[i]];data.frame(doc=i,concept=j,start=as.integer(h),end=as.integer(h+attr(h,"match.length")-1))}))
      if(!is.null(progress)) progress(j/nrow(concepts))
    }
    if(length(blocks)) matches<-do.call(rbind,blocks)
    counts<-Matrix::sparseMatrix(i=matches$doc,j=matches$concept,x=rep(1,nrow(matches)),dims=c(nrow(docs),nrow(concepts)),dimnames=list(docs$doc_id,concepts$key))
    source<-paste("Texto original de",prepared$mapping$text %||% "la columna elegida","/ coincidencias literales de",if(mode=="dictionary")"conceptos y variantes declaradas" else "t\u00e9rminos retenidos","; sin URLs ni correos. Un lema puede no tener esa forma literal en el original.")
  }
  concepts$documents<-as.integer(Matrix::colSums(counts>0));concepts$occurrences<-as.integer(Matrix::colSums(counts))
  concepts$filename<-sprintf("Conceptos/T%05d",seq_len(nrow(concepts)))
  documents<-data.frame(key=paste0("doc:",docs$doc_id),doc_id=docs$doc_id,title=clean_value(docs$title),original_id=clean_value(docs$original_id),year=docs$year,text=texts,original=clean_value(docs$text),filename=paste0("Documentos/",docs$doc_id),stringsAsFactors=FALSE)
  documents$source_row<-docs$source_row
  for(field in c("doi","authors","source","language"))documents[[field]]<-if(field %in% names(docs))clean_value(docs[[field]]) else rep("",nrow(docs))
  list(version=1L,mode=mode,source=source,source_key=source_key,source_name=prepared$source_name %||% "",concepts=concepts,documents=documents,counts=counts,matches=matches,
    params=list(mode=mode,dictionary=if(mode=="dictionary")dictionary else "",source_key=source_key,text_source=text_source,text_field=prepared$mapping$text),preparation=list(config=prepared$config,mapping=prepared$mapping,models=corpus$models,app_version=BIBLIO_VERSION),built_at=format(Sys.time(),"%Y-%m-%d %H:%M:%S %Z"))
}
wiki_spans <- function(index,doc_id) {
  wiki_require_matrix()
  i<-match(doc_id,index$documents$doc_id);if(is.na(i))abort_user("El documento no pertenece al \u00edndice vigente.")
  if(index$mode=="dictionary") return(index$matches[index$matches$doc==i,c("concept","start","end"),drop=FALSE])
  js<-which(as.numeric(index$counts[i,])>0)
  if(!length(js))return(data.frame(concept=integer(),start=integer(),end=integer()))
  parts<-lapply(js,function(j){h<-wiki_hits(index$documents$text[i],index$concepts$pattern[j]);data.frame(concept=rep(j,nrow(h)),h)})
  do.call(rbind,parts)
}
wiki_nonoverlap <- function(spans,limit=400L) {
  if(!nrow(spans))return(spans)
  order<-order(-(spans$end-spans$start+1),spans$start,spans$concept);chosen<-integer()
  for(i in order) if(!length(chosen)||all(spans$end[i]<spans$start[chosen]|spans$start[i]>spans$end[chosen])) {chosen<-c(chosen,i);if(length(chosen)>=limit)break}
  spans[chosen[order(spans$start[chosen])],,drop=FALSE]
}
wiki_button <- function(key,label) paste0('<button type="button" class="wiki-link" data-wiki-node="',htmltools::htmlEscape(key,attribute=TRUE),'">',htmltools::htmlEscape(label),'</button>')
wiki_text_html <- function(index,doc_id,limit=400L) {
  i<-match(doc_id,index$documents$doc_id);text<-index$documents$text[i];s<-wiki_nonoverlap(wiki_spans(index,doc_id),limit)
  if(!nrow(s))return(as.character(htmltools::htmlEscape(text)))
  out<-character();pos<-1L
  for(k in seq_len(nrow(s))) {
    if(s$start[k]>pos)out<-c(out,as.character(htmltools::htmlEscape(substr(text,pos,s$start[k]-1))))
    out<-c(out,wiki_button(index$concepts$key[s$concept[k]],substr(text,s$start[k],s$end[k])));pos<-s$end[k]+1L
  }
  paste0(c(out,as.character(htmltools::htmlEscape(substr(text,pos,nchar(text))))),collapse="")
}
wiki_backlinks <- function(index,key,limit=NULL) {
  wiki_require_matrix()
  j<-match(key,index$concepts$key);if(is.na(j))abort_user("El concepto no pertenece al \u00edndice vigente.")
  n<-as.numeric(index$counts[,j]);i<-which(n>0);i<-i[order(-n[i],index$documents$doc_id[i])]
  if(!is.null(limit))i<-head(i,limit)
  data.frame(doc_id=index$documents$doc_id[i],titulo=index$documents$title[i],ano=index$documents$year[i],menciones=as.integer(n[i]),stringsAsFactors=FALSE)
}
wiki_kwic <- function(index,key,doc_ids=NULL,context=70L,limit=200L) {
  check_number(context,"El contexto",20,200);check_number(limit,"Las concordancias",1,5000)
  j<-match(key,index$concepts$key);if(is.na(j))abort_user("El concepto no pertenece al \u00edndice vigente.")
  ids<-wiki_backlinks(index,key)$doc_id;if(!is.null(doc_ids))ids<-ids[ids %in% doc_ids]
  result<-list();used<-0L
  for(id in ids) {
    i<-match(id,index$documents$doc_id);txt<-index$documents$text[i]
    h<-if(index$mode=="dictionary")index$matches[index$matches$doc==i&index$matches$concept==j,c("start","end"),drop=FALSE] else wiki_hits(txt,index$concepts$pattern[j])
    if(!nrow(h))next
    h<-head(h,limit-used)
    result[[length(result)+1L]]<-data.frame(doc_id=id,inicio=h$start,fin=h$end,antes=vapply(h$start,function(p)substr(txt,max(1,p-context),p-1),""),coincidencia=substring(txt,h$start,h$end),despues=vapply(h$end,function(p)substr(txt,p+1,min(nchar(txt),p+context)),""),stringsAsFactors=FALSE)
    used<-used+nrow(h);if(used>=limit)break
  }
  if(!length(result))return(data.frame(doc_id=character(),inicio=integer(),fin=integer(),antes=character(),coincidencia=character(),despues=character()))
  do.call(rbind,result)
}
wiki_registry <- function(index) rbind(data.frame(key=index$documents$key,label=index$documents$doc_id,filename=index$documents$filename),index$concepts[c("key","label","filename")])
wiki_empty_notes <- function() data.frame(scope=character(),node=character(),text=character(),updated_at=character(),stringsAsFactors=FALSE)
wiki_resolve_many <- function(targets,index) {
  r<-wiki_registry(index);wanted<-wiki_key(targets);labels<-wiki_key(r$label)
  direct<-match(wanted,wiki_key(r$key));bylabel<-match(wanted,labels)
  ambiguous<-duplicated(labels)|duplicated(labels,fromLast=TRUE)
  result<-rep(NA_character_,length(wanted));known<-!is.na(direct);result[known]<-r$key[direct[known]]
  allowed<-!known&!is.na(bylabel);allowed[allowed]<-!ambiguous[bylabel[allowed]];result[allowed]<-r$key[bylabel[allowed]]
  result
}
wiki_resolve <- function(target,index) wiki_resolve_many(target,index)[1]
wiki_note_links <- function(notes,index) {
  notes<-notes[notes$scope==index$source_key&notes$node %in% wiki_registry(index)$key,,drop=FALSE];out<-list()
  for(i in seq_len(nrow(notes))) {
    hits<-gregexpr("\\[\\[[^\\[\\]\\r\\n]+\\]\\]",notes$text[i],perl=TRUE)[[1]];if(hits[1]<0)next
    raw<-regmatches(notes$text[i],list(hits))[[1]]
    targets<-trimws(sub("[|].*$","",substr(raw,3,nchar(raw)-2)))
    out[[length(out)+1L]]<-data.frame(from=notes$node[i],target=targets,stringsAsFactors=FALSE)
  }
  if(!length(out))return(data.frame(from=character(),target=character(),to=character(),resolved=logical()))
  d<-unique(do.call(rbind,out));d$to<-wiki_resolve_many(d$target,index);d$resolved<-!is.na(d$to);d
}
wiki_note_html <- function(text,index) {
  hits<-gregexpr("\\[\\[[^\\[\\]\\r\\n]+\\]\\]",text,perl=TRUE)[[1]]
  if(hits[1]<0)return(as.character(htmltools::htmlEscape(text)))
  ends<-hits+attr(hits,"match.length")-1;out<-character();pos<-1L
  parts_all<-lapply(seq_along(hits),function(i)strsplit(substr(text,hits[i]+2,ends[i]-2),"|",fixed=TRUE)[[1]])
  destinations<-wiki_resolve_many(vapply(parts_all,function(p)trimws(p[1]),""),index)
  for(i in seq_along(hits)) {
    parts<-parts_all[[i]];to<-destinations[i];label<-if(length(parts)>1)parts[2] else parts[1]
    if(hits[i]>pos)out<-c(out,as.character(htmltools::htmlEscape(substr(text,pos,hits[i]-1))))
    out<-c(out,if(is.na(to)||i>400L)as.character(htmltools::htmlEscape(substr(text,hits[i],ends[i]))) else wiki_button(to,label));pos<-ends[i]+1L
  }
  paste0(c(out,as.character(htmltools::htmlEscape(substr(text,pos,nchar(text))))),collapse="")
}
wiki_local_graph <- function(index,node,max_terms=12L,max_docs=20L,min_shared=2L,notes=wiki_empty_notes(),include_manual=TRUE,manual_links=NULL,view="bipartite",scope="local",community="all",min_similarity=.1,resolution=1,seed=2026L,remove_isolates=FALSE,network=NULL) {
  if(!scope %in% c("local","global","community"))abort_user("Alcance del grafo no admitido.")
  if(identical(view,"concepts"))return(wiki_concept_graph(index,node,scope,community,min_shared,min_similarity,resolution,seed,remove_isolates,notes,include_manual,manual_links,network))
  if(scope!="local")return(wiki_overview_graph(index,node,scope,community,min_shared,min_similarity,resolution,seed,remove_isolates,network))
  if(identical(view,"documents"))return(wiki_document_graph(index,node,max_terms,max_docs,min_shared,notes,include_manual,manual_links))
  if(!identical(view,"bipartite"))abort_user("Vista del grafo de lectura no admitida.")
  wiki_require_matrix()
  check_number(max_terms,"Los conceptos del grafo",1,30);check_number(max_docs,"Los documentos vecinos",1,60);check_number(min_shared,"Los conceptos compartidos",1,10000)
  i<-match(node,index$documents$key);j<-match(node,index$concepts$key)
  if(is.na(i)&&is.na(j))abort_user("Selecciona un documento o concepto vigente.")
  if(!is.na(i)) {
    ts<-which(as.numeric(index$counts[i,])>0);ts<-head(ts[order(index$concepts$documents[ts],index$concepts$label[ts])],max_terms)
    shared<-if(length(ts))as.numeric(Matrix::rowSums(index$counts[,ts,drop=FALSE]>0)) else rep(0,nrow(index$documents))
    eligible<-setdiff(which(shared>=min_shared),i);eligible<-eligible[order(-shared[eligible],index$documents$doc_id[eligible])]
    ds<-c(i,head(eligible,max_docs));available<-length(eligible)
  } else {ts<-j;v<-as.numeric(index$counts[,j]);eligible<-which(v>0);eligible<-eligible[order(-v[eligible],index$documents$doc_id[eligible])];ds<-head(eligible,max_docs);available<-length(eligible)}
  selected_count<-length(ts)
  keys<-c(index$documents$key[ds],index$concepts$key[ts]);auto_keys<-keys;manual<-if(is.null(manual_links))wiki_note_links(notes,index) else manual_links;manual<-manual[manual$resolved,,drop=FALSE]
  if(include_manual&&nrow(manual)) {near<-manual[manual$from==node|manual$to==node,,drop=FALSE];keys<-unique(c(keys,head(sort(unique(c(near$from,near$to))),30)))}
  registry<-wiki_registry(index);keys<-unique(keys);di<-match(keys,index$documents$key);ci<-match(keys,index$concepts$key)
  doc_labels<-ifelse(nzchar(index$documents$title),index$documents$title,paste("Documento",index$documents$doc_id))
  labels<-ifelse(!is.na(di),doc_labels[pmax(1,di)],index$concepts$label[pmax(1,ci)])
  labels[!is.na(di) & nchar(labels)>20]<-paste0(substr(labels[!is.na(di) & nchar(labels)>20],1,20),"\u2026")
  nodes<-data.frame(id=keys,label=labels,type=ifelse(!is.na(di),"Documento","Concepto"),central=keys==node,stringsAsFactors=FALSE)
  nodes$description<-ifelse(!is.na(di),paste(doc_labels[pmax(1,di)],index$documents$year[pmax(1,di)],index$documents$source[pmax(1,di)],sep=" \u00b7 "),paste(index$concepts$documents[pmax(1,ci)],"documentos /",index$concepts$occurrences[pmax(1,ci)],"apariciones"))
  ds<-which(index$documents$key %in% keys);ts<-which(index$concepts$key %in% keys)
  m<-index$counts[ds,ts,drop=FALSE];trip<-Matrix::summary(methods::as(m,"dgCMatrix"))
  edges<-data.frame(from=index$documents$key[ds[trip$i]],to=index$concepts$key[ts[trip$j]],weight=trip$x,type=rep("Menci\u00f3n",nrow(trip)),stringsAsFactors=FALSE)
  if(include_manual&&nrow(manual)) {kept<-manual[manual$from %in% keys&manual$to %in% keys,,drop=FALSE];if(nrow(kept))edges<-rbind(edges,data.frame(from=kept$from,to=kept$to,weight=1,type="Nota expl\u00edcita"))}
  edges<-unique(edges);edges<-edges[order(edges$type,edges$from,edges$to,edges$weight),,drop=FALSE];rownames(edges)<-NULL
  list(nodes=nodes,edges=edges,audit=data.frame(criterio=c("Relaci\u00f3n autom\u00e1tica","Conceptos autom\u00e1ticos elegidos","Vecinos que cumplen la regla","P\u00e1ginas a\u00f1adidas por notas","Documentos mostrados / ambas capas","Enlaces de menciones / notas","M\u00ednimo compartido solicitado"),valor=c("Documento\u2013concepto; nunca documento\u2013documento por intuici\u00f3n",if(!is.na(i))paste(selected_count,"/ m\u00e1ximo",max_terms,"; menor presencia, desempate alfab\u00e9tico") else "Concepto activo",paste(available,"antes del l\u00edmite"),sum(!keys %in% auto_keys),length(ds),paste(sum(edges$type=="Menci\u00f3n"),sum(edges$type=="Nota expl\u00edcita"),sep=" / "),if(!is.na(i)&&min_shared>selected_count)paste(min_shared,": supera los",selected_count,"conceptos elegidos. Ning\u00fan vecino puede cumplirlo; reduce este m\u00ednimo.") else as.character(min_shared))))
}
wiki_index_table <- function(index) {
  wiki_require_matrix()
  s<-Matrix::summary(methods::as(index$counts,"dgCMatrix"))
  data.frame(doc_id=index$documents$doc_id[s$i],concepto=index$concepts$label[s$j],node=index$concepts$key[s$j],menciones=as.integer(s$x),stringsAsFactors=FALSE)
}
wiki_save_note <- function(notes,scope,node,text,known) {
  if(!is.character(text)||length(text)!=1||is.na(text)||!node %in% known)abort_user("La nota no corresponde a una p\u00e1gina conocida.")
  if(nchar(text)>WIKI_LIMITS$note_chars)abort_user("La nota supera 20.000 caracteres. Divide el contenido antes de guardarlo.")
  keep<-!(notes$scope==scope&notes$node==node);next_notes<-notes[keep,,drop=FALSE]
  if(nzchar(text)) next_notes<-rbind(next_notes,data.frame(scope=scope,node=node,text=normalize_unicode(text),updated_at=format(Sys.time(),"%Y-%m-%d %H:%M:%S %Z")))
  if(sum(nchar(next_notes$text))>WIKI_LIMITS$note_total)abort_user("Las notas de esta sesi\u00f3n superan cuatro millones de caracteres. Descarga su copia antes de ampliar el cuaderno.")
  if(nrow(next_notes)>5000)abort_user("Esta sesi\u00f3n admite 5.000 notas. Conserva su copia y contin\u00faa en otra sesi\u00f3n.")
  next_notes
}
wiki_read_notes <- function(path) {
  if(is.na(file.info(path)$size)||file.info(path)$size>20*1024^2)abort_user("La copia de notas no se puede leer o supera 20 MB.")
  obj<-tryCatch(jsonlite::read_json(path,simplifyVector=TRUE),error=function(e)abort_user("La copia no es un JSON v\u00e1lido de notas."))
  if(!is.list(obj)||!is.numeric(obj$schema)||length(obj$schema)!=1||!is.finite(obj$schema)||obj$schema!=1)abort_user("Formato de notas no compatible. Usa una copia JSON descargada por este cuaderno.")
  d<-obj$notes;if(is.null(d)||!length(d))return(wiki_empty_notes())
  if(!is.data.frame(d)||!all(c("scope","node","text","updated_at") %in% names(d)))abort_user("La copia no contiene las columnas necesarias.")
  d<-d[c("scope","node","text","updated_at")]
  if(nrow(d)>5000||any(nchar(d$node)>256)||any(nchar(d$updated_at)>80))abort_user("La copia supera 5.000 notas o contiene identificadores inv\u00e1lidos.")
  if(any(!vapply(d,is.character,TRUE))||anyNA(d)||anyDuplicated(paste(d$scope,d$node))||any(!grepl("^[a-f0-9]{32}$",d$scope))||any(!grepl("^(doc:|term:|concept:).+",d$node))||any(nchar(d$text)>WIKI_LIMITS$note_chars)||sum(nchar(d$text))>WIKI_LIMITS$note_total)abort_user("La copia tiene notas duplicadas, campos inv\u00e1lidos o supera los l\u00edmites. No se ha restaurado parcialmente.")
  d
}
wiki_md_escape <- function(x) {
  x<-gsub("<","&lt;",gsub(">","&gt;",gsub("&","&amp;",x,fixed=TRUE),fixed=TRUE),fixed=TRUE)
  gsub("([\\\\`*_{}\\[\\]#])","\\\\\\1",x,perl=TRUE)
}
wiki_md_alias <- function(x) wiki_md_escape(gsub("[|\\[\\]]"," ",x,perl=TRUE))
wiki_md_note <- function(text,index) {
  hits<-gregexpr("\\[\\[[^\\[\\]\\r\\n]+\\]\\]",text,perl=TRUE)[[1]];if(hits[1]<0)return(wiki_md_escape(text))
  ends<-hits+attr(hits,"match.length")-1;out<-character();pos<-1L;r<-wiki_registry(index)
  parts_all<-lapply(seq_along(hits),function(i)strsplit(substr(text,hits[i]+2,ends[i]-2),"|",fixed=TRUE)[[1]])
  destinations<-wiki_resolve_many(vapply(parts_all,function(p)trimws(p[1]),""),index)
  for(i in seq_along(hits)) {parts<-parts_all[[i]];to<-destinations[i];label<-if(length(parts)>1)parts[2] else parts[1];if(hits[i]>pos)out<-c(out,wiki_md_escape(substr(text,pos,hits[i]-1)));out<-c(out,if(is.na(to))wiki_md_escape(substr(text,hits[i],ends[i])) else paste0("[[",r$filename[match(to,r$key)],"|",wiki_md_alias(label),"]]"));pos<-ends[i]+1L}
  paste0(c(out,wiki_md_escape(substr(text,pos,nchar(text)))),collapse="")
}
wiki_graph_figure <- function(g) {
  n<-g$nodes;e<-g$edges
  ig<-igraph::graph_from_data_frame(e[c("from","to")],directed=FALSE,vertices=n[c("id","label","type","central")])
  xy<-with_seed(2026,if(nrow(n)==1)matrix(c(0,0),1) else if(nrow(e))igraph::layout_with_fr(ig,weights=NA,niter=500) else igraph::layout_in_circle(ig))
  n$x<-xy[,1];n$y<-xy[,2];n$color<-if("community" %in% names(n))ifelse(n$community==0,"#999999",swiss_colours(max(1,max(n$community)))[pmax(1,n$community)]) else ifelse(n$central,"#c7281e",ifelse(n$type=="Concepto","#245579","#777777"))
  edges<-e;edges$x<-n$x[match(e$from,n$id)];edges$y<-n$y[match(e$from,n$id)];edges$xend<-n$x[match(e$to,n$id)];edges$yend<-n$y[match(e$to,n$id)]
  mentions<-edges[edges$type!="Nota expl\u00edcita",,drop=FALSE];manual<-edges[edges$type=="Nota expl\u00edcita"&edges$from!=edges$to,,drop=FALSE];self<-edges[edges$type=="Nota expl\u00edcita"&edges$from==edges$to,,drop=FALSE]
  degree<-as.numeric(igraph::degree(ig));labels<-n[head(order(!n$central,-degree,n$id),50),,drop=FALSE]
  plot<-ggplot2::ggplot(n,ggplot2::aes(x,y))+
    ggplot2::geom_segment(data=mentions,ggplot2::aes(xend=xend,yend=yend),colour="#b8b8b8",linewidth=.5,inherit.aes=TRUE)+
    ggplot2::geom_curve(data=manual,ggplot2::aes(xend=xend,yend=yend),colour="#222222",linetype="dashed",curvature=.15,linewidth=.5,arrow=grid::arrow(length=grid::unit(2.5,"mm"),type="closed"))+
    ggplot2::geom_point(data=self,shape=1,size=9,colour="#222222",stroke=.6)+
    ggplot2::geom_point(ggplot2::aes(shape=type),fill=n$color,colour=n$color,size=3.5)+ggplot2::scale_shape_manual(values=c(Documento=21,Concepto=23),name="P\u00e1gina")+
    label_layer(labels,ggplot2::aes(label=label),size=3.2,seed=2026,repel=list(max.overlaps=Inf))+ggplot2::coord_equal()+
    ggplot2::labs(title="Cuaderno / grafo de lectura",subtitle=paste(nrow(n),"p\u00e1ginas /",nrow(e),"relaciones \u00b7 disposici\u00f3n est\u00e1tica; hasta 50 etiquetas"),caption=if(identical(g$kind,"concepts"))"Gris continuo: coaparici\u00f3n en fichas. Discontinua con flecha: enlace expl\u00edcito en una nota. Colores: comunidades Louvain sobre Jaccard de fichas; gris sin comunidad autom\u00e1tica. Las notas no intervienen en la agrupaci\u00f3n." else if("community" %in% names(n))"Colores: comunidades Louvain del grafo Jaccard; gris: aislados. La comunidad conserva la pertenencia de la red completa. No representa citas ni temas validados." else "Gris: menci\u00f3n documental o conceptos compartidos, seg\u00fan la vista registrada. Discontinua con flecha: enlace escrito en una nota. Rojo: p\u00e1gina activa. No representa citas ni equivalencia sem\u00e1ntica.",x=NULL,y=NULL)+swiss_theme()+
    ggplot2::theme(axis.text=ggplot2::element_blank(),axis.ticks=ggplot2::element_blank(),panel.grid.major=ggplot2::element_blank(),panel.grid.minor=ggplot2::element_blank(),legend.position="bottom")
  plot
}
export_wiki_vault <- function(directory,index,notes=wiki_empty_notes(),graph=NULL,view=NULL) {
  dir.create(directory,recursive=TRUE,showWarnings=FALSE);dir.create(file.path(directory,"Documentos"),showWarnings=FALSE);dir.create(file.path(directory,"Conceptos"),showWarnings=FALSE)
  r<-wiki_registry(index);notes<-notes[notes$scope==index$source_key,,drop=FALSE];links<-wiki_note_links(notes,index)
  note<-function(key){i<-match(key,notes$node);if(is.na(i))"Sin nota del investigador." else wiki_md_note(notes$text[i],index)}
  put<-function(filename,lines)writeLines(enc2utf8(lines),file.path(directory,paste0(filename,".md")),useBytes=TRUE)
  for(i in seq_len(nrow(index$documents))) {
    d<-index$documents[i,];s<-wiki_nonoverlap(wiki_spans(index,d$doc_id),limit=1000000L);text<-d$text;out<-character();pos<-1L
    for(k in seq_len(nrow(s))) {if(s$start[k]>pos)out<-c(out,wiki_md_escape(substr(text,pos,s$start[k]-1)));c<-index$concepts[s$concept[k],];out<-c(out,paste0("[[",c$filename,"|",wiki_md_alias(substr(text,s$start[k],s$end[k])),"]]"));pos<-s$end[k]+1L}
    linked<-paste0(c(out,wiki_md_escape(substr(text,pos,nchar(text)))),collapse="")
    js<-which(as.numeric(index$counts[i,])>0)
    navigation<-paste0("- [[",index$concepts$filename[js],"|",wiki_md_alias(index$concepts$label[js]),"]] \u2014 ",as.numeric(index$counts[i,js,drop=FALSE])," menciones")
    put(d$filename,c("---",paste0("id: ",jsonlite::toJSON(d$doc_id,auto_unbox=TRUE)),paste0("title: ",jsonlite::toJSON(d$title,auto_unbox=TRUE)),paste0("original_id: ",jsonlite::toJSON(d$original_id,auto_unbox=TRUE)),paste0("doi: ",jsonlite::toJSON(d$doi,auto_unbox=TRUE)),paste0("year: ",jsonlite::toJSON(d$year,auto_unbox=TRUE,na="null")),"---",paste("#",d$doc_id,wiki_md_escape(d$title)),"",paste("Autores:",wiki_md_escape(d$authors)),paste("Fuente:",wiki_md_escape(d$source)),paste("DOI:",wiki_md_escape(d$doi)),paste("Fecha de publicaci\u00f3n / campo del archivo:",wiki_md_escape(d$publication_date %||% "")),paste("Early Access:",wiki_md_escape(d$early_access_date %||% "")),paste("Idioma declarado o aplicado:",wiki_md_escape(d$language)),"","## Texto enlazado",index$source,"",linked,"","## Conceptos presentes",if(length(js))navigation else "No contiene conceptos de este \u00edndice.","","## Nota del investigador",note(d$key),"","## Texto original / para contrastar",wiki_md_escape(d$original)))
  }
  for(j in seq_len(nrow(index$concepts))) {
    c<-index$concepts[j,];b<-wiki_backlinks(index,c$key)
    put(c$filename,c("---",paste0("aliases: ",jsonlite::toJSON(c$label,auto_unbox=FALSE)),"---",paste("#",wiki_md_escape(c$label)),"",paste("Variantes declaradas:",wiki_md_escape(c$variants)),paste("Documentos:",c$documents,"/ menciones:",c$occurrences),"","## Documentos que lo mencionan",if(nrow(b))paste0("- [[Documentos/",b$doc_id,"|",b$doc_id,"]] \u2014 ",b$menciones," menciones; ",wiki_md_escape(b$titulo)) else "Ning\u00fan documento coincide con este concepto.","","## Nota del investigador",note(c$key)))
  }
  put("LEEME",c("# Cuaderno de lectura enlazada","","Abre esta carpeta como b\u00f3veda en Obsidian o consulta sus archivos Markdown. No requiere plugins ni servicios de IA.","",paste("Fuente:",wiki_md_escape(index$source_name)),paste("Lectura:",index$source),"","Las menciones autom\u00e1ticas no demuestran citas ni equivalencia sem\u00e1ntica. Las variantes del diccionario son decisiones del investigador. Los enlaces escritos en notas se exportan como enlaces internos si su destino existe; los desconocidos se conservan como texto literal.","","Los nombres de archivo son ID seguros; manifest.json permite rastrear p\u00e1ginas. Conceptos que se solapan conservan sus conteos; en texto prevalece la menci\u00f3n m\u00e1s larga. La lista de conceptos de cada documento conserva todas las relaciones, incluidas las que no se subrayan en ese solapamiento.","","Las notas pertenecen al investigador. Revisa datos y derechos antes de compartir esta carpeta."))
  safe_csv(wiki_index_table(index),file.path(directory,"indice_documento_concepto.csv"));safe_csv(links,file.path(directory,"enlaces_notas.csv"))
  if(!is.null(graph)) {
    if(identical(graph$kind,"concepts"))jsonlite::write_json(list(kind="concepts",relation="coappearance or explicit note link",nodes=graph$nodes,links=graph$edges,params=graph$network_params),file.path(directory,"grafo_conceptos.json"),pretty=TRUE,auto_unbox=TRUE,na="null");safe_csv(graph$nodes,file.path(directory,"grafo_local_nodos.csv"));safe_csv(graph$edges,file.path(directory,"grafo_local_enlaces.csv"));safe_csv(graph$audit,file.path(directory,"grafo_local_auditoria.csv"))
    if(!is.null(graph$communities)){safe_csv(graph$communities,file.path(directory,if(identical(graph$kind,"concepts"))"comunidades_conceptos.csv" else "comunidades_documentales.csv"));safe_csv(graph$memberships,file.path(directory,"pertenencia_comunidades.csv"))};fig<-wiki_graph_figure(graph);ggplot2::ggsave(file.path(directory,"grafo_local.png"),fig,width=11,height=8,dpi=180,bg="white");ggplot2::ggsave(file.path(directory,"grafo_local.pdf"),fig,width=11,height=8,device=if(capabilities("cairo"))grDevices::cairo_pdf else grDevices::pdf,bg="white")
  }
  jsonlite::write_json(list(schema=1,source_key=index$source_key,source=index$source,params=index$params,preparation=index$preparation,view=view,pages=r),file.path(directory,"manifest.json"),pretty=TRUE,auto_unbox=TRUE,na="null")
  jsonlite::write_json(list(schema=1,notes=notes),file.path(directory,"notas.json"),pretty=TRUE,auto_unbox=TRUE,na="null")
  saveRDS(list(index=index,notes=notes,graph=graph,view=view),file.path(directory,"cuaderno.rds"))
  invisible(directory)
}
