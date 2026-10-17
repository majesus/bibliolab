estimate_language_one <- function(txt,min_letters=40L,dominance=.90) {
    letters<-nchar(gsub("[^\\p{L}]","",txt,perl=TRUE))
    out<-data.frame(codigo_estimado="",idioma_estimado="Sin estimaci\u00f3n",fiable=FALSE,proporcion_clasificada=NA_real_,codigo_automatico="",estado_estimacion=if(!nzchar(trimws(txt))) "Sin texto" else "Texto demasiado breve",letras=letters,stringsAsFactors=FALSE)
    if(letters<min_letters) return(out)
    detected<-tryCatch(cld2::detect_language_mixed(txt,plain_text=TRUE),error=function(e) NULL)
    if(is.null(detected) || !nrow(detected$classification)) {out$estado_estimacion<-"No se pudo estimar";return(out)}
    a<-detected$classification[order(-detected$classification$proportion),,drop=FALSE]
    out$codigo_estimado<-a$code[1];out$idioma_estimado<-a$language[1]
    # El paquete 1.2.5 devuelve 'reliabale'; aceptar tambien la grafia corregida.
    out$fiable<-isTRUE(detected$reliable %||% detected$reliabale)
    out$proporcion_clasificada<-a$proportion[1]
    supported<-out$codigo_estimado %in% names(language_models())
    out$estado_estimacion<-if(!out$fiable || out$codigo_estimado %in% c("un","und","")) "Estimaci\u00f3n incierta" else if(!supported) "Idioma sin modelo disponible" else if(!is.finite(out$proporcion_clasificada) || out$proporcion_clasificada<dominance) "Posible mezcla de idiomas" else "Asignaci\u00f3n autom\u00e1tica disponible"
    if(out$estado_estimacion=="Asignaci\u00f3n autom\u00e1tica disponible") out$codigo_automatico<-out$codigo_estimado
    display<-c(language_labels(),gl="Gallego",ca="Catal\u00e1n",eu="Euskera",nl="Neerland\u00e9s",ru="Ruso",ar="\u00c1rabe",zh="Chino",ja="Japon\u00e9s")
    if(out$codigo_estimado %in% names(display)) out$idioma_estimado<-unname(display[out$codigo_estimado])
    out
}

# UDPipe es una dependencia R/C++; no se usa Python ni servicios externos de anotacion.
language_models <- function() c(es = "spanish-gsd", en = "english-ewt", fr = "french-gsd",
  de = "german-gsd", it = "italian-isdt", pt = "portuguese-bosque")
language_labels <- function() c(es = "Espa\u00f1ol", en = "Ingl\u00e9s", fr = "Franc\u00e9s", de = "Alem\u00e1n", it = "Italiano", pt = "Portugu\u00e9s")
#' Carpeta de modelos UDPipe
#'
#' Usa la opcion `bibliolab.model_dir` si esta definida; en otro caso, la
#' carpeta de datos de usuario de R (`tools::R_user_dir("bibliolab", "data")`).
#' El paquete nunca descarga modelos sin una accion explicita del usuario.
#'
#' @return Ruta (puede no existir todavia).
#' @examples
#' model_directory()
#' @export
model_directory <- function() getOption("bibliolab.model_dir", file.path(tools::R_user_dir("bibliolab", "data"), "models"))
model_file <- function(language, directory = model_directory()) {
  if (!language %in% names(language_models())) abort_user("Idioma sin modelo configurado: usa es, en, fr, de, it o pt.")
  if (!dir.exists(directory)) return(NULL)
  files <- list.files(directory, pattern = "\\.udpipe$", full.names = TRUE)
  files <- files[startsWith(basename(files), paste0(language_models()[[language]], "-"))]
  if (!length(files)) NULL else sort(files)[1]
}
.model_validation_cache <- new.env(parent = emptyenv())
# Un modelo es utilizable solo si UDPipe puede cargarlo. El resultado se recuerda por ruta, tamano y fecha.
model_usable <- function(path) {
  if (!is.character(path) || length(path) != 1L || !file.exists(path)) return(FALSE)
  size <- file.size(path)
  if (is.na(size) || size <= 0) return(FALSE)
  key <- paste(normalizePath(path, winslash = "/"), size, as.numeric(file.mtime(path)))
  hit <- .model_validation_cache[[key]]
  if (!is.null(hit)) return(hit)
  # udpipe_load_model() no falla con un archivo danado: devuelve un objeto cuyo puntero es nulo.
  # Por eso se exige un puntero valido y una anotacion minima que produzca filas.
  ok <- tryCatch({
    model <- suppressWarnings(udpipe::udpipe_load_model(path))
    valid <- inherits(model, "udpipe_model") && !identical(model$model, methods::new("externalptr"))
    valid && nrow(as.data.frame(suppressWarnings(udpipe::udpipe_annotate(model, x = "Hola mundo.", doc_id = "d")))) > 0L
  }, error = function(e) FALSE)
  .model_validation_cache[[key]] <- ok
  ok
}
#' Descarga y verifica un modelo UDPipe
#'
#' Solo debe invocarse por decision del usuario (requiere conexion). El modelo se
#' descarga a una carpeta temporal, se comprueba que corresponde al idioma pedido y
#' que UDPipe puede cargarlo, y solo entonces se publica en [model_directory()]. Un
#' modelo ya presente se reutiliza unicamente si tambien se puede cargar: si esta
#' danado (por ejemplo, una descarga interrumpida), se sustituye por una descarga
#' nueva en lugar de devolverse como valido.
#'
#' @param language Codigo `es`, `en`, `fr`, `de`, `it` o `pt`.
#' @param directory Carpeta de destino.
#' @param force Si `TRUE`, descarga de nuevo aunque el modelo local sea utilizable.
#' @return Ruta del archivo del modelo.
#' @export
download_language_model <- function(language, directory = model_directory(), force = FALSE) {
  if (!requireNamespace("udpipe", quietly = TRUE)) abort_user("Falta el paquete udpipe. Inst\u00e1lalo con install.packages(\"udpipe\").")
  if (!is.character(language) || length(language) != 1L || !language %in% names(language_models())) abort_user("Selecciona uno de los seis idiomas disponibles.")
  existing <- model_file(language, directory)
  if (!is.null(existing) && !isTRUE(force) && model_usable(existing)) return(existing)
  old <- getOption("timeout"); options(timeout = max(300, old)); on.exit(options(timeout = old), add = TRUE)
  staging <- tempfile("bibliolab-modelo-"); dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  info <- tryCatch(udpipe::udpipe_download_model(language = unname(language_models()[language]), model_dir = staging,
    udpipe_model_repo = "jwijffels/udpipe.models.ud.2.5"), error = function(e) NULL)
  if (is.null(info) || !nrow(info) || isTRUE(info$download_failed[1]) || !file.exists(info$file_model[1]))
    abort_user("No se ha podido descargar el modelo. Comprueba la conexi\u00f3n y vuelve a intentarlo; el corpus y los modelos locales no se han modificado.")
  downloaded <- info$file_model[1]
  if (!startsWith(basename(downloaded), paste0(language_models()[[language]], "-")))
    abort_user("El archivo descargado no corresponde al idioma solicitado. No se ha instalado.")
  if (!model_usable(downloaded)) abort_user("El archivo descargado no se puede cargar como modelo UDPipe. No se ha instalado; vuelve a intentarlo.")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  target <- file.path(directory, basename(downloaded))
  if (!file.copy(downloaded, target, overwrite = TRUE)) abort_user("No se puede escribir el modelo en la carpeta de modelos.")
  if (!model_usable(target)) { unlink(target); abort_user("La copia del modelo no se puede cargar. No se ha instalado.") }
  # Retirar solo los restos danados de ese mismo idioma; nunca otros archivos de la carpeta.
  stale <- list.files(directory, pattern = "\\.udpipe$", full.names = TRUE)
  stale <- stale[startsWith(basename(stale), paste0(language_models()[[language]], "-")) & normalizePath(stale, winslash = "/") != normalizePath(target, winslash = "/")]
  for (f in stale) if (!model_usable(f)) unlink(f)
  normalizePath(target, winslash = "/")
}
normalize_language <- function(x) {
  key <- normalize_key(x)
  dictionary <- c(es = "es", spanish = "es", "espa\u00f1ol" = "es", espanol = "es", en = "en", english = "en", "ingl\u00e9s" = "en", ingles = "en",
    fr = "fr", french = "fr", "fran\u00e7ais" = "fr", frances = "fr", "franc\u00e9s" = "fr", de = "de", german = "de", deutsch = "de", aleman = "de", "alem\u00e1n" = "de",
    it = "it", italian = "it", italiano = "it", pt = "pt", portuguese = "pt", "portugu\u00eas" = "pt", portugues = "pt", "portugu\u00e9s" = "pt")
  unname(dictionary[key])
}
annotate_corpus_units <- function(units, documents, cfg, stops, pool=NULL, progress=NULL) {
  if (!requireNamespace("udpipe", quietly = TRUE)) abort_user("La lematizaci\u00f3n necesita el paquete udpipe. Inst\u00e1lalo con install.packages(\"udpipe\").")
  if (cfg$lemma_language == "column") {
    languages <- normalize_language(documents$language[match(units$doc_id, documents$doc_id)])
    bad<-is.na(languages) & nzchar(trimws(units$original))
    if(any(bad)) {
      ix<-head(which(bad),5);raw<-documents$language[match(units$doc_id[ix],documents$doc_id)]
      details<-paste(paste0(units$doc_id[ix]," (",ifelse(nzchar(raw),raw,"sin idioma"),")"),collapse=", ")
      abort_user(paste0("Elegiste Varios idiomas, pero todav\u00eda no se puede asignar modelo a: ",details,". En 02 / Preparaci\u00f3n abre Revisar idiomas / solo pendientes: CLD2 completa los casos claros y muestra por qu\u00e9 otros necesitan revisi\u00f3n. Asignar o revisar manualmente permite corregir esas filas. Se admiten nombres y c\u00f3digos de las seis lenguas disponibles. Una lengua sin modelo no se sustituye por otra."))
    }
  } else {
    if (!cfg$lemma_language %in% names(language_models())) abort_user("Selecciona el idioma del modelo de lematizaci\u00f3n.")
    languages <- rep(cfg$lemma_language, nrow(units))
  }
  if (cfg$pos_filter && (!length(cfg$pos_keep) || any(!cfg$pos_keep %in% c("NOUN", "PROPN", "ADJ", "VERB", "ADV"))))
    abort_user("Selecciona al menos una categor\u00eda gramatical admitida.")
  files <- setNames(lapply(unique(languages[!is.na(languages)]), model_file), unique(languages[!is.na(languages)]))
  damaged <- names(files)[vapply(files, function(f) !is.null(f) && !model_usable(f), logical(1))]
  if (length(damaged)) abort_user(paste0("El modelo local de ", paste(language_labels()[damaged], collapse = ", "), " est\u00e1 da\u00f1ado y UDPipe no puede cargarlo. Vuelve a descargarlo desde Preparar modelos necesarios, o ejecuta download_language_model('", damaged[1], "', force = TRUE). Carpeta consultada: ", model_directory(), "."))
  missing <- names(files)[vapply(files, is.null, logical(1))]
  if (length(missing)) abort_user(paste0("El idioma est\u00e1 seleccionado, pero falta descargar el modelo de ", paste(language_labels()[missing], collapse = ", "), ". No has preparado mal el archivo: seleccionar una lengua no instala su analizador. En 02 / Normalizaci\u00f3n ling\u00fc\u00edstica abre Preparar modelos necesarios y pulsa Descargar todos los modelos necesarios. Cuando aparezca Modelo local disponible, cierra el di\u00e1logo y pulsa Preparar corpus. Si solo necesitas palabras sin lemas ni categor\u00edas, desmarca esas dos opciones. Carpeta consultada: ", model_directory(), "."))
  # Limite explicito antes del paso de anotacion mas costoso.
  if (sum(nchar(units$original)) > 5e6) abort_user("La anotaci\u00f3n ling\u00fc\u00edstica est\u00e1 limitada a cinco millones de caracteres. Aplica una muestra.")
  jobs<-list();models<-list()
  for(lang in names(files)) {
    idx<-which(languages==lang & nzchar(trimws(units$original)))
    models[[lang]]<-list(file=basename(files[[lang]]),md5=unname(tools::md5sum(files[[lang]])),package=as.character(utils::packageVersion("udpipe")),parser="none",tagger="default")
    for(batch in split(idx,ceiling(seq_along(idx)/100L))) jobs[[length(jobs)+1L]]<-list(file=files[[lang]],language=lang,text=units$original[batch],unit_id=units$unit_id[batch])
  }
  # Mantener afinidad de idioma reduce cargas duplicadas del mismo modelo.
  # Una lengua extensa se reparte en bloques contiguos; una pequena va junta.
  grouped<-list();capacity<-processing_execution(cfg$execution)$workers
  for(lang in names(files)) {
    batches<-jobs[vapply(jobs,function(x) x$language==lang,TRUE)]
    cost<-sum(vapply(batches,function(x) sum(nchar(x$text)),0))
    parts<-if(length(batches)>=8L || cost>=3e5) min(capacity,length(batches)) else 1L
    if(length(batches)) for(ix in split(seq_along(batches),ceiling(seq_along(batches)/ceiling(length(batches)/parts)))) grouped[[length(grouped)+1L]]<-list(batches=batches[ix])
  }
  on.exit(rm(list=ls(.processing_model_cache),envir=.processing_model_cache),add=TRUE)
  annotated<-processing_map(grouped,"annotate",list(cfg=cfg),cfg$execution,sum(nchar(units$original)),pool,progress)
  processing_audit<-attr(annotated,"processing")
  rows<-unlist(annotated,recursive=FALSE)
  rows<-rows[vapply(rows,nrow,1L)>0L]
  annotation <- if (length(rows)) do.call(rbind, rows) else data.frame()
  if (nrow(annotation) > BIBLIO_LIMITS$tokens) abort_user("La anotaci\u00f3n supera un mill\u00f3n de tokens. Aplica una muestra.")
  ids<-split(seq_len(nrow(units)),ceiling(seq_len(nrow(units))/50L))
  jobs<-lapply(ids,function(ix) list(unit_ids=units$unit_id[ix],languages=languages[ix],annotation=if(nrow(annotation)) annotation[annotation$doc_id %in% units$unit_id[ix],,drop=FALSE] else data.frame()))
  normalized<-processing_map(jobs,"normalize",list(cfg=cfg,stops=stops),cfg$execution,sum(nchar(units$original)),pool,progress)
  processing_audit<-rbind(processing_audit,attr(normalized,"processing"))
  parts<-unlist(normalized,recursive=FALSE)
  tokens<-lapply(parts,`[[`,"tokens");pairs<-lapply(parts,`[[`,"pairs");sequences<-lapply(parts,`[[`,"sequences")
  lemmatized<-vapply(parts,`[[`,"","lemmatized")
  if (nrow(annotation)) annotation <- annotation[c("doc_id", "paragraph_id", "sentence_id", "token_id", "token", "lemma", "upos", "language")]
  list(tokens = tokens, pairs = pairs, sequences = sequences, lemmatized = lemmatized, annotation = annotation, models = models, processing=processing_audit)
}

estimate_text_languages <- function(text, min_letters=40L, dominance=.90, execution=NULL, progress=NULL) {
  if(!requireNamespace("cld2",quietly=TRUE)) abort_user("La estimaci\u00f3n de idiomas necesita el paquete cld2. Inst\u00e1lalo con install.packages(\"cld2\").")
  check_number(min_letters,"Letras m\u00ednimas para estimar idioma",1,1000)
  check_number(dominance,"Proporci\u00f3n m\u00ednima del idioma dominante",.5,1,FALSE)
  text<-enc2utf8(clean_value(text))
  text<-gsub("https?://\\S+|www\\.\\S+|[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]+"," ",text,perl=TRUE)
  # CLD2 mixed analiza un vector como un unico texto: cada llamada recibe
  # exactamente un documento, nunca el corpus concatenado. Cachear duplicados.
  unique_text<-unique(text)
  results<-processing_map(as.list(unique_text),"language",list(min_letters=min_letters,dominance=dominance),execution,sum(nchar(unique_text)),progress=progress)
  template<-data.frame(codigo_estimado=character(),idioma_estimado=character(),fiable=logical(),proporcion_clasificada=numeric(),codigo_automatico=character(),estado_estimacion=character(),letras=integer())
  d<-if(length(results)) do.call(rbind,results)[match(text,unique_text),,drop=FALSE] else template
  rownames(d)<-NULL
  attr(d,"processing")<-attr(results,"processing")
  attr(d,"detector")<-list(engine="cld2",version=as.character(utils::packageVersion("cld2")),min_letters=min_letters,dominance=dominance,policy=paste0("Solo fiable, lengua compatible y al menos ",100*dominance,"% del texto clasificado; porcentaje no es probabilidad de acierto. An\u00e1lisis local por documento."))
  d
}

route_document_languages <- function(d,mapping,manual=character(),estimates=NULL) {
  declared<-mapped(d,mapping,"language");codes<-normalize_language(declared)
  values<-declared;overrides<-character();origin<-ifelse(!is.na(codes),"CSV","Pendiente")
  if(!is.null(estimates)) {
    if(nrow(estimates)!=nrow(d)) abort_user("Las estimaciones no corresponden al archivo actual. Vuelve a revisar idiomas.")
    take<-is.na(codes)&nzchar(estimates$codigo_automatico)
    keys<-as.character(which(take));overrides[keys]<-estimates$codigo_automatico[take]
    values[take]<-estimates$codigo_automatico[take];origin[take]<-"CLD2 autom\u00e1tico"
  }
  values<-apply_language_overrides(values,manual)
  if(length(manual)) {overrides[names(manual)]<-manual;origin[as.integer(names(manual))]<-"Correcci\u00f3n manual"}
  overrides<-overrides[order(as.integer(names(overrides)))]
  final<-normalize_language(values);has_text<-nzchar(trimws(mapped(d,mapping,"text")))
  origin[!has_text]<-"Sin texto"
  audit<-data.frame(fila=seq_len(nrow(d)),idioma_csv=declared,codigo_aplicado=ifelse(is.na(final),"",final),origen_idioma=origin,requiere_revision=has_text&is.na(final),stringsAsFactors=FALSE)
  if(!is.null(estimates)) audit<-cbind(audit,estimates[setdiff(names(estimates),"codigo_automatico")])
  audit$discrepancia<-if(is.null(estimates)) rep(FALSE,nrow(d)) else has_text & !is.na(final) & estimates$fiable & nzchar(estimates$codigo_estimado) & !estimates$codigo_estimado %in% c("un","und") & final!=estimates$codigo_estimado
  audit$porcentaje_texto_clasificado<-if(is.null(estimates)) rep(NA_real_,nrow(d)) else 100*estimates$proporcion_clasificada
  list(overrides=overrides,audit=audit,detector=if(is.null(estimates)) NULL else attr(estimates,"detector"))
}

language_diagnostics <- function(d,mapping,overrides=character()) {
  raw<-apply_language_overrides(mapped(d,mapping,"language"),overrides)
  codes<-normalize_language(raw)
  data.frame(fila=seq_len(nrow(d)),id=mapped(d,mapping,"id"),titulo=mapped(d,mapping,"title"),
    idioma_declarado=raw,idioma_reconocido=ifelse(is.na(codes),"Sin identificar",unname(language_labels()[codes])),codigo=ifelse(is.na(codes),"",codes),
    texto_ejemplo=substr(mapped(d,mapping,"text"),1,160),stringsAsFactors=FALSE)
}
