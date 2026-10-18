# Procesos R locales PSOCK; compatible con Windows. Sin forks ni planes globales.
.processing_model_cache <- new.env(parent=emptyenv())
processing_worker_limit <- function() {
  cores<-suppressWarnings(parallel::detectCores(logical=FALSE))
  if(length(cores)!=1 || is.na(cores) || cores<2) return(1L)
  as.integer(min(4L,cores-1L))
}
processing_execution <- function(execution=NULL) {
  if(is.null(execution)) return(list(enabled=FALSE,workers=1L))
  workers<-execution$workers %||% 2L
  check_number(workers,"Trabajadores de preprocesamiento",1,4)
  list(enabled=isTRUE(execution$enabled),workers=as.integer(min(workers,processing_worker_limit())))
}
processing_plan <- function(job,n,chars,execution=NULL) {
  e<-processing_execution(execution)
  threshold<-switch(job,language=n>=1000L || chars>=5e5,lexical=n>=3000L || chars>=1e6,annotate=n>=2L && chars>=100000L,normalize=n>=4L && chars>=1e6,FALSE)
  parallel<-e$enabled && e$workers>1L && n>1L && threshold
  list(parallel=parallel,workers=if(parallel) min(e$workers,n) else 1L,
       reason=if(!e$enabled) "Opci\u00f3n paralela desactivada" else if(e$workers==1L) "Un trabajador disponible o solicitado" else if(!threshold || n<2L) "Volumen peque\u00f1o: evitar coste de iniciar procesos" else "Volumen suficiente para repartir lotes")
}
processing_close <- function(pool) {
  if(!is.null(pool$cluster)) {
    ids<-pool$pids %||% integer()
    try(parallel::stopCluster(pool$cluster),silent=TRUE)
    # Solo PIDs obtenidos de este cluster local, nunca procesos ajenos.
    # Tambien libera un trabajador aun ocupado tras error/interrupcion.
    for(pid in ids[ids>0 & ids!=Sys.getpid()]) try(tools::pskill(pid,signal=15L),silent=TRUE)
    pool$cluster<-NULL
  }
}
processing_open <- function(pool,workers) {
  if(!is.null(pool$cluster)) return(invisible(pool$cluster))
  # system.file() apunta a inst/ con pkgload: no identifica la raiz ni prueba que
  # el paquete este instalado. Usar la ubicacion del namespace que ejecuta la app.
  path<-normalizePath(getNamespaceInfo(asNamespace("bibliolab"),"path"),winslash="/",mustWork=TRUE)
  version<-as.character(getNamespaceVersion("bibliolab"))
  source<-!file.exists(file.path(path,"Meta","package.rds"))
  if(source && (!file.exists(file.path(path,"DESCRIPTION")) || !dir.exists(file.path(path,"R"))))
    abort_user("No se encuentran las fuentes de bibliolab para los trabajadores. Vuelve a abrir la aplicaci\u00f3n desde su carpeta completa.")
  log<-tempfile("bibliolab_workers_",fileext=".log")
  pool$log<-log
  pool$cluster<-parallel::makePSOCKcluster(workers,master="127.0.0.1",rscript_args="--vanilla",setup_timeout=15,timeout=600,outfile=log)
  # Registrar los PIDs antes de cargar el paquete permite cerrar los procesos
  # propios aunque falle la inicializacion de uno de los trabajadores.
  pool$pids<-as.integer(unlist(parallel::clusterCall(pool$cluster,Sys.getpid),use.names=FALSE))
  init<-function(libs,path,version,source) {
    .libPaths(libs)
    Sys.setenv(OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",MKL_NUM_THREADS="1")
    if(source) {
      if(!requireNamespace("pkgload",quietly=TRUE)) stop("Falta pkgload en el trabajador para cargar las fuentes locales de bibliolab. Instalalo con install.packages('pkgload') y vuelve a abrir la app.")
      pkgload::load_all(path,attach=FALSE,export_all=FALSE,helpers=FALSE,attach_testthat=FALSE,quiet=TRUE)
    } else loadNamespace("bibliolab",lib.loc=dirname(path))
    loaded_path<-normalizePath(getNamespaceInfo(asNamespace("bibliolab"),"path"),winslash="/",mustWork=TRUE)
    if(!identical(loaded_path,path) || !identical(as.character(getNamespaceVersion("bibliolab")),version))
      stop("El trabajador no ha cargado la misma ubicacion y version de bibliolab que la app. Reinicia la aplicaci\u00f3n.")
    if(requireNamespace("data.table",quietly=TRUE)) data.table::setDTthreads(1L)
    invisible(TRUE)
  }
  environment(init)<-baseenv()
  parallel::clusterCall(pool$cluster,init,.libPaths(),path,version,source)
  pool$package_path<-path
  pool$package_version<-version
  pool$source<-source
  invisible(pool$cluster)
}
processing_dispatch <- function(items,job,args) {
  switch(job,
    language=lapply(items,function(x) estimate_language_one(x,args$min_letters,args$dominance)),
    lexical=lapply(items,function(x) tokenize_document(x,args$cfg,args$stops)),
    annotate=lapply(items,function(x){out<-lapply(x$batches,annotate_language_batch,cfg=args$cfg);if(sum(vapply(out,nrow,1L))>BIBLIO_LIMITS$tokens) abort_user("La anotaci\u00f3n supera un mill\u00f3n de tokens. Aplica una muestra.");out}),
    normalize=lapply(items,function(x) normalize_annotation_chunk(x,args$cfg,args$stops)),
    abort_user("Tarea de preprocesamiento desconocida."))
}
processing_map <- function(items,job,args=list(),execution=NULL,chars=0,pool=NULL,progress=NULL) {
  saved_seed<-rng_state()
  on.exit(rng_restore(saved_seed),add=TRUE)
  started<-proc.time()[[3]];plan<-processing_plan(job,length(items),chars,execution)
  own_pool<-is.null(pool)
  if(own_pool) {pool<-new.env(parent=emptyenv());pool$cluster<-NULL;pool$log<-NULL}
  if(isTRUE(pool$unavailable)) {plan$parallel<-FALSE;plan$workers<-1L;plan$reason<-"Continuaci\u00f3n secuencial tras recuperaci\u00f3n de los trabajadores"}
  if(own_pool) on.exit({processing_close(pool);if(!is.null(pool$log)) unlink(pool$log)},add=TRUE)
  chunk_size<-switch(job,language=250L,lexical=50L,annotate=1L,normalize=1L,50L)
  chunks<-split(seq_along(items),ceiling(seq_along(items)/chunk_size))
  total_units<-total_tokens<-0L
  enforce<-function(result) {
    if(job=="lexical") {
      total_units<<-total_units+sum(vapply(result,function(x) length(x$units),1L))
      total_tokens<<-total_tokens+sum(vapply(result,function(x) sum(vapply(x$units,function(z) length(z$tokens),1L)),0))
      if(total_units>BIBLIO_LIMITS$units || total_tokens>BIBLIO_LIMITS$tokens) abort_user("El corpus supera 20.000 unidades o un mill\u00f3n de palabras. Usa una muestra o res\u00famenes m\u00e1s breves.")
    }
    if(job=="annotate") {
      total_tokens<<-total_tokens+sum(vapply(result,function(x) sum(vapply(x,nrow,1L)),0))
      if(total_tokens>BIBLIO_LIMITS$tokens) abort_user("La anotaci\u00f3n supera un mill\u00f3n de tokens. Aplica una muestra.")
    }
  }
  run<-function(parallel) {
    out<-vector("list",length(items));total_units<<-total_tokens<<-0L
    if(parallel) processing_open(pool,plan$workers)
    worker<-function(items,job,args) get("processing_dispatch",envir=asNamespace("bibliolab"))(items,job,args)
    environment(worker)<-baseenv()
    width<-if(parallel) plan$workers else 1L
    waves<-split(seq_along(chunks),ceiling(seq_along(chunks)/width))
    for(wave in waves) {
      payload<-lapply(chunks[wave],function(ix) items[ix])
      result<-if(parallel) parallel::clusterApply(pool$cluster,payload,worker,job,args) else lapply(payload,processing_dispatch,job=job,args=args)
      for(j in seq_along(result)) {enforce(result[[j]]);out[chunks[[wave[j]]]]<-result[[j]]}
      if(is.function(progress)) progress(job,max(unlist(chunks[wave])),length(items))
    }
    out
  }
  fallback<-NULL
  result<-if(plan$parallel) tryCatch(run(TRUE),error=function(e){
    fallback<<-paste("Se recuper\u00f3 en secuencial:",conditionMessage(e));processing_close(pool);pool$unavailable<-TRUE;run(FALSE)
  }) else run(FALSE)
  attr(result,"processing")<-data.frame(etapa=job,modo=if(!is.null(fallback)) "Secuencial / recuperaci\u00f3n" else if(plan$parallel) "PSOCK local" else "Secuencial",trabajadores=if(plan$parallel && is.null(fallback)) plan$workers else 1L,lotes=length(chunks),elementos=length(items),segundos=unname(proc.time()[[3]]-started),nota=fallback %||% plan$reason,stringsAsFactors=FALSE)
  attr(result,"worker_pids")<-pool$pids %||% integer()
  result
}

tokenize_document <- function(doc,cfg,stops) {
  # `stops` puede ser una lista nombrada por idioma (modo por documento): se elige la de este documento.
  if(is.list(stops)) {lang<-doc$language %||% NA_character_;stops<-if(length(lang)==1L && !is.na(lang) && lang %in% names(stops)) stops[[lang]] else character()}
  chunks<-if(cfg$split_sentences) strsplit(doc$text,"(?<=[.!?])\\s+|[\\r\\n]+",perl=TRUE)[[1]] else doc$text
  if(!length(chunks)) chunks<-""
  units<-pairs<-sequences<-vector("list",length(chunks));total<-0L
  for(j in seq_along(chunks)) {
    parts<-tokenize_one(chunks[j],cfg,stops);tokens<-unlist(parts,use.names=FALSE);tokens<-tokens[nzchar(tokens)]
    total<-total+length(tokens)
    if(j>BIBLIO_LIMITS$units || total>BIBLIO_LIMITS$tokens) abort_user("El corpus supera 20.000 unidades o un mill\u00f3n de palabras. Usa una muestra o res\u00famenes m\u00e1s breves.")
    uid<-if(cfg$split_sentences) paste0(doc$doc_id,"_S",sprintf("%04d",j)) else doc$doc_id
    units[[j]]<-list(unit_id=uid,doc_id=doc$doc_id,sentence=j,original=chunks[j],cleaned=paste(tokens,collapse=" "),tokens=tokens)
    pp<-unlist(lapply(parts,function(w){if(length(w)<2) return(character());valid<-nzchar(head(w,-1))&nzchar(tail(w,-1));paste(head(w,-1)[valid],tail(w,-1)[valid])}),use.names=FALSE)
    pairs[j]<-list(unique(as.character(pp)));sequences[j]<-list(parts)
  }
  list(units=units,pairs=pairs,sequences=sequences)
}

annotate_language_batch <- function(job,cfg) {
  if(!identical(.processing_model_cache$file,job$file)) {
    rm(list=ls(.processing_model_cache),envir=.processing_model_cache);gc(FALSE)
    .processing_model_cache$model<-udpipe::udpipe_load_model(job$file)
    .processing_model_cache$file<-job$file
  }
  text<-job$text
  if(cfg$remove_links) text<-gsub("https?://\\S+|www\\.\\S+|[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]+",".",text,perl=TRUE)
  a<-as.data.frame(udpipe::udpipe_annotate(.processing_model_cache$model,x=enc2utf8(text),doc_id=job$unit_id,parser="none"))
  if(nrow(a)) a<-a[grepl("^[0-9]+$",a$token_id),,drop=FALSE]
  if(nrow(a)) a$language<-job$language
  a
}
normalize_annotation_chunk <- function(job,cfg,stops) {
  annotation<-job$annotation
  index<-if(nrow(annotation)) split(seq_len(nrow(annotation)),annotation$doc_id) else list()
  lapply(seq_along(job$unit_ids),function(i){
    a<-if(nrow(annotation)) annotation[index[[job$unit_ids[i]]] %||% integer(),,drop=FALSE] else data.frame()
    normalize_annotation_one(a,job$languages[i],cfg,stops)
  })
}
normalize_annotation_one <- function(a,language,cfg,stops) {
  if(!nrow(a)) return(list(tokens=character(),pairs=character(),sequences=NULL,lemmatized=""))
  surface<-tolower(clean_value(a$token));lemma<-tolower(clean_value(a$lemma))
  fallback<-!nzchar(lemma)|lemma=="_";lemma[fallback]<-surface[fallback]
  lexical<-!a$upos %in% c("PUNCT","SYM") & grepl("^[\\p{L}\\p{N}]+(?:['\u2019][\\p{L}\\p{N}]+)?$",surface,perl=TRUE)
  if(cfg$remove_numbers) lexical<-lexical & !grepl("^\\p{N}+$",surface,perl=TRUE)
  if(cfg$remove_codes) lexical<-lexical & !(grepl("\\p{L}",surface,perl=TRUE)&grepl("\\p{N}",surface,perl=TRUE))
  lemmatized<-paste(lemma[lexical],collapse=" ")
  selected<-if(cfg$lemmatize) lemma else surface
  local_stops<-stops
  if(cfg$remove_stop && cfg$lemma_language=="column" && cfg$language!="none") {
    custom<-trimws(tolower(strsplit(cfg$custom_stop %||% "",",",fixed=TRUE)[[1]]))
    local_stops<-unique(c(custom[nzchar(custom)],stopwords::stopwords(language,source="snowball")))
  }
  keep<-lexical & nchar(selected)>=cfg$min_chars & nchar(selected)<=cfg$max_chars & !surface %in% local_stops & !selected %in% local_stops
  if(cfg$pos_filter) keep<-keep & a$upos %in% cfg$pos_keep
  selected[!keep]<-""
  groups<-split(seq_len(nrow(a)),paste(a$paragraph_id,a$sentence_id,sep=":"))
  sequences<-lapply(groups,function(ix) selected[ix])
  pairs<-unlist(lapply(groups,function(ix){w<-selected[ix];if(length(w)<2) return(character());valid<-nzchar(head(w,-1))&nzchar(tail(w,-1));paste(head(w,-1)[valid],tail(w,-1)[valid])}),use.names=FALSE)
  list(tokens=selected[nzchar(selected)],pairs=unique(as.character(pairs)),sequences=sequences,lemmatized=lemmatized)
}
