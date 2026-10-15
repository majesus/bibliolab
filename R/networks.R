# Redes no dirigidas, sin bucles: todas las medidas describen el grafo filtrado.
network_shortest_path <- function(fit,from,to) {
  if(!all(c(from,to) %in% fit$nodes$name))abort_user("El origen y el destino deben estar incluidos en la red vigente.")
  graph<-igraph::graph_from_data_frame(fit$edges[c("from","to")],directed=FALSE,vertices=fit$nodes$name)
  distance<-as.numeric(igraph::distances(graph,v=from,to=to,weights=NA))
  if(!is.finite(distance))return(list(connected=FALSE,distance=Inf,nodes=character(),edges=data.frame(from=character(),to=character()),steps=data.frame(Paso=integer(),Nodo=character())))
  path<-as.character(igraph::as_ids(igraph::shortest_paths(graph,from=from,to=to,weights=NA)$vpath[[1]]))
  edges<-if(length(path)>1L)data.frame(from=head(path,-1),to=tail(path,-1)) else data.frame(from=character(),to=character())
  list(connected=TRUE,distance=distance,nodes=path,edges=edges,steps=data.frame(Paso=seq_along(path)-1L,Nodo=path))
}
network_defaults <- function() list(type = "authors", weighting = "full", min_presence = 1L,
  max_nodes = 60L, min_shared = 1L, seed = 2026L, community_method = "louvain", resolution = 1, keyplayers_k = 3L, max_edges = 0L,
  remove_isolates = FALSE, include_nodes = character())

author_sets <- function(prepared) {
  raw <- lapply(metadata_split(prepared$documents$authors, metadata_separator(prepared,"authors")),
    function(x) trimws(x[nzchar(trimws(x))]))
  # Variantes de escritura (mayusculas, acentos, puntos de las iniciales) se unifican; homonimos no.
  if (isTRUE(prepared$config$normalize_labels %||% TRUE)) {
    vm <- variant_map(unlist(raw, use.names = FALSE), "author")
    raw <- lapply(raw, function(z) if (length(z)) unname(vm$map[z]) else z)
  }
  lapply(raw, function(z) sort(unique(z)))
}

collaboration_summary <- function(prepared) {
  k <- lengths(author_sets(prepared)); known <- k > 0; multi <- k > 1
  data.frame(indicador = c("Documentos con autores", "Documentos sin autores", "% multiautor entre documentos con autores", "Autores medios por documento con autores", "\u00cdndice de colaboraci\u00f3n: autores medios en documentos multiautor"),
    valor = c(sum(known), sum(!known), if (any(known)) 100 * mean(multi[known]) else NA,
      if (any(known)) mean(k[known]) else NA, if (any(multi)) mean(k[multi]) else NA))
}

#' Redes bibliometricas y lexicas
#'
#' Construye una red no dirigida de coautoria, copresencia de palabras,
#' afinidad lexica de revistas, cocitacion de referencias o acoplamiento
#' bibliografico, y calcula indicadores del grafo filtrado: densidad,
#' componentes, centralidades, comunidades (Louvain o Walktrap) y su
#' estabilidad entre semillas.
#'
#' @param corpus,prepared Resultados de [prepare_corpus()] y [prepare_documents()].
#' @param params Lista parcial: `type`, `weighting` (`"full"`, `"fractional"`,
#'   `"cosine"`, `"association"`), `min_presence`, `max_nodes`, `min_shared`,
#'   `seed`, `community_method`, `resolution`, `max_edges`, `keyplayers_k`,
#'   `remove_isolates` (retira aislados tras filtrar conexiones) e
#'   `include_nodes` (nombres prioritarios que superan el umbral; conserva el
#'   maximo de nodos).
#' @return Lista con `nodes`, `edges`, `summary`, `audit`, `selection`
#'   (cada entidad y su motivo de inclusion/exclusion), `keyplayers`, `note` y `params`.
#' @references
#' Blondel, V. et al. (2008). Fast unfolding of communities in large networks. J. Stat. Mech.
#' van Eck, N. J., Waltman, L. (2009). How to normalize cooccurrence data? JASIST.
#' @examples
#' d <- read_biblio_csv(system.file("extdata", "practica.csv", package = "bibliolab"), ";")
#' p <- prepare_documents(d, guess_columns(d)); cp <- prepare_corpus(p)
#' net <- run_network(cp, p, list(type = "words", max_nodes = 15))
#' net$summary
#' @export
run_network <- function(corpus, prepared, params = list()) {
  if (!requireNamespace("igraph", quietly = TRUE)) abort_user("Falta el paquete igraph. Inst\u00e1lalo con install.packages(\"igraph\") para calcular redes.")
  p <- utils::modifyList(network_defaults(), params)
  if (!p$type %in% c("authors", "words", "sources", "references", "coupling") || !p$weighting %in% c("full", "fractional", "cosine", "association")) abort_user("Tipo de red o ponderaci\u00f3n no admitidos.")
  check_number(p$min_presence, "La presencia m\u00ednima", 1, 10000)
  check_number(p$max_nodes, "El m\u00e1ximo de nodos", 2, 150)
  check_number(p$min_shared, "La coincidencia m\u00ednima", 1, 10000)
  check_number(p$max_edges, "El m\u00e1ximo de conexiones", 0, 12000)
  check_number(p$seed, "La semilla de la red", 1, .Machine$integer.max)
  if(!p$community_method %in% c("louvain","walktrap")) abort_user("Metodo de comunidades no admitido.")
  check_number(p$resolution,"Resolucion Louvain",.1,3,FALSE)
  check_number(p$keyplayers_k,"Numero de candidatos",1,10)
  docs <- prepared$documents
  if (p$type == "authors") {
    sets <- author_sets(prepared); entities <- sort(unique(unlist(sets)))
    if (!length(entities)) abort_user("No hay autores. Asigna su columna y comprueba el delimitador en Preparaci\u00f3n.")
    b <- Matrix::sparseMatrix(i = rep(seq_along(sets), lengths(sets)), j = match(unlist(sets), entities), x = 1,
      dims = c(nrow(docs), length(entities)), dimnames = list(docs$doc_id, entities))
    note <- paste("Coautor\u00eda: una conexi\u00f3n indica autores presentes en el mismo documento.",if(isTRUE(prepared$config$normalize_labels)) "Las variantes de escritura se unifican seg\u00fan el registro de normalizaci\u00f3n; no se resuelven hom\u00f3nimos." else "Los nombres se distinguen literalmente, sin unificar variantes.","Revisa las identidades antes de interpretar posiciones.")
  } else if (p$type %in% c("references","coupling")) {
    sets <- reference_sets(prepared); entities <- sort(unique(unlist(sets)))
    if(!length(entities)) abort_user("Esta red necesita referencias citadas. Asigna Referencias / CR en Preparacion y vuelve a preparar.")
    b <- Matrix::sparseMatrix(i=rep(seq_along(sets),lengths(sets)),j=match(unlist(sets),entities),x=1,dims=c(nrow(docs),length(entities)),dimnames=list(docs$doc_id,entities))
    note <- "Cocitacion: dos referencias aparecen en la bibliografia de un mismo documento. Identificacion por cadena normalizada exacta; revisar variantes de una misma referencia."
    if(p$type=="coupling") {
      b <- Matrix::t(b[lengths(sets)>0,,drop=FALSE]); p$weighting <- "cosine"
      note <- "Acoplamiento bibliografico: dos documentos del corpus comparten referencias citadas. Peso coseno de perfiles binarios. Cada nodo es una publicacion; con mas documentos que el limite se eligen los de mayor acoplamiento total (referencias compartidas con otros documentos) y solo entran documentos que comparten al menos una referencia. Las faltas en las bibliografias afectan la red. Identificacion exacta, sin fusion aproximada."
    }
  } else {
    m <- document_counts(corpus, prepared); b <- (m > 0) * 1
    note <- "Copresencia de palabras: cada t\u00e9rmino cuenta una vez por documento, aunque se repita o haya varias frases. Se utiliza el vocabulario retenido."
    if (p$type == "sources") {
      src <- clean_value(docs$source[match(rownames(b), docs$doc_id)]); good <- nzchar(src)
      if(isTRUE(prepared$config$normalize_labels)){vm<-variant_map(docs$source,"source");src[good]<-unname(vm$map[src[good]])}
      sources <- sort(unique(src[good])); if (!length(sources)) abort_user("No hay revistas en documentos con vocabulario. Asigna Revista / fuente.")
      a <- Matrix::sparseMatrix(i = match(src[good], sources), j = seq_len(sum(good)), x = 1,
        dims = c(length(sources), sum(good)))
      profiles <- (a %*% b[good, , drop = FALSE]) > 0
      b <- Matrix::t(profiles * 1); colnames(b) <- sources
      note <- "Afinidad l\u00e9xica de revistas: una conexi\u00f3n indica t\u00e9rminos retenidos compartidos entre sus art\u00edculos. Cada t\u00e9rmino cuenta una vez por revista. No es cocitaci\u00f3n ni acoplamiento bibliogr\u00e1fico por referencias."
      p$weighting <- "cosine"
    }
  }
  presence <- Matrix::colSums(b)
  # En revistas, seleccionar por documentos con texto; la similitud usa terminos distintos.
  # Acoplamiento: se eligen los documentos con mayor fuerza de acoplamiento total (referencias compartidas con otros),
  # no los primeros por ID. fuerza_j = suma_r b_rj * (n_r - 1), con n_r documentos que citan r.
  coupling_strength <- if (p$type == "coupling") as.numeric(Matrix::t(b) %*% (Matrix::rowSums(b) - 1)) else NULL
  selection_presence <- if (p$type == "coupling") coupling_strength else if (p$type == "sources") as.numeric(table(factor(src[good], levels = colnames(b)))) else presence
  names(selection_presence) <- colnames(b)
  eligible <- which(if (p$type == "coupling") selection_presence > 0 else selection_presence >= p$min_presence)
  selected <- head(eligible[order(-selection_presence[eligible], colnames(b)[eligible])], p$max_nodes)
  if(!is.logical(p$remove_isolates) || length(p$remove_isolates)!=1L || is.na(p$remove_isolates)) abort_user("Eliminar aislados debe ser verdadero o falso.")
  if(!is.character(p$include_nodes) || anyNA(p$include_nodes)) abort_user("Las entidades prioritarias deben ser nombres de nodos.")
  priority<-match(unique(p$include_nodes),colnames(b))
  if(anyNA(priority) || any(!priority %in% eligible)) abort_user("Alguna entidad prioritaria no est\u00e1 en este corpus o no supera el umbral. Revisa la presencia m\u00ednima antes de incluirla.")
  if(length(priority)>p$max_nodes) abort_user("El m\u00e1ximo de nodos debe permitir incluir todas las entidades prioritarias.")
  selected<-head(unique(c(priority,selected,eligible[order(-selection_presence[eligible],colnames(b)[eligible])])),p$max_nodes)
  if (!length(selected)) abort_user("Ning\u00fan nodo supera la presencia m\u00ednima. Reduce ese umbral.")
  all_presence <- presence; all_k <- Matrix::rowSums(b)
  b <- b[, selected, drop = FALSE]; raw <- as.matrix(Matrix::crossprod(b))
  weight <- raw
  if (p$weighting == "fractional") {
    # Cada documento aporta 1 entre TODAS sus parejas, antes del limite de nodos.
    factors <- ifelse(all_k > 1, 2 / pmax(all_k * (all_k - 1), 1), 0)
    weight <- as.matrix(Matrix::crossprod(b, Matrix::Diagonal(x = factors) %*% b))
  }
  if (p$weighting == "cosine") weight <- raw / outer(sqrt(all_presence[selected]), sqrt(all_presence[selected]))
  # Fuerza de asociacion (van Eck y Waltman, 2009): coincidencias frente a las esperadas por azar.
  if (p$weighting == "association") weight <- raw / outer(all_presence[selected], all_presence[selected])
  pairs <- which(upper.tri(raw) & raw >= p$min_shared, arr.ind = TRUE)
  edges <- data.frame(from = colnames(b)[pairs[, 1]], to = colnames(b)[pairs[, 2]],
    coincidencias = raw[pairs], weight = weight[pairs], stringsAsFactors = FALSE)
  before_cap <- nrow(edges)
  if (p$max_edges > 0 && nrow(edges) > p$max_edges) edges <- head(edges[order(-edges$weight,-edges$coincidencias,edges$from,edges$to),,drop=FALSE],p$max_edges)
  nodes <- data.frame(name = colnames(b), documentos = if (p$type == "coupling") rep(1, length(selected)) else as.numeric(selection_presence[selected]), stringsAsFactors = FALSE)
  if (p$type == "coupling") nodes$acoplamiento_total <- as.numeric(coupling_strength[selected])
  isolated<-!nodes$name %in% unique(c(edges$from,edges$to))
  removed<-if(isTRUE(p$remove_isolates)) sum(isolated) else 0L
  if(isTRUE(p$remove_isolates)) nodes<-nodes[!isolated,,drop=FALSE]
  ranked<-order(-selection_presence,names(selection_presence))
  selection<-data.frame(name=names(selection_presence),documentos=if(p$type=="coupling")rep(1,length(presence)) else as.numeric(selection_presence),
    criterio_seleccion=as.numeric(selection_presence),posicion=match(seq_along(presence),ranked),supera_umbral=seq_along(presence) %in% eligible,
    prioridad=seq_along(presence) %in% priority,en_red=names(selection_presence) %in% nodes$name,stringsAsFactors=FALSE)
  selection$motivo<-ifelse(selection$en_red,"Incluido",ifelse(!selection$supera_umbral,"No supera el umbral de selecci\u00f3n",ifelse(!seq_along(presence) %in% selected,"Fuera del m\u00e1ximo de nodos / orden por presencia y desempate alfab\u00e9tico","Aislado retirado tras filtrar conexiones")))
  selection<-selection[order(selection$posicion),,drop=FALSE]
  metrics <- network_metrics(nodes,edges,p)
  nodes<-metrics$nodes;summary<-metrics$summary;players<-metrics$keyplayers
  n<-nrow(nodes);e<-nrow(edges)
  audit <- data.frame(etapa = c("Entidades observadas", "Superan presencia m\u00ednima", "Nodos seleccionados", "Conexiones tras umbral"),
    cantidad = c(length(presence), length(eligible), n, e))
  audit <- rbind(audit,data.frame(etapa=c("Aislados retirados","Entidades prioritarias","Conexiones antes del l\u00edmite por peso","Conexiones omitidas por l\u00edmite gr\u00e1fico y anal\u00edtico"),cantidad=c(removed,length(priority),before_cap,before_cap-e)))
  list(nodes = nodes, edges = edges, summary = summary, audit = audit, selection=selection, params = p, keyplayers = players, note = paste(note,
    "Densidad, centralidades y comunidades describen SOLO estos nodos y conexiones. Intermediaci\u00f3n y centralidad arm\u00f3nica usan saltos sin pesos; fuerza y comunidades usan el peso elegido. Roles topologicos exploratorios; no calidad o liderazgo demostrado.",if(isTRUE(p$remove_isolates)) paste(removed,"aislados retirados despu\u00e9s de filtrar conexiones; m\u00e9tricas recalculadas.") else "Aislados conservados.","Posiciones: disposici\u00f3n visual, no distancia sem\u00e1ntica.",
    if(p$max_edges>0) paste("Se conservan hasta",p$max_edges,"conexiones de mayor peso; se omitieron",before_cap-e,". El filtro cambia m\u00e9tricas y comunidades: contrasta otros l\u00edmites. No selecciona relaciones estad\u00edsticamente significativas.") else "Sin l\u00edmite adicional de conexiones por peso."),
    collaboration = if (p$type == "authors") collaboration_summary(prepared) else NULL)
}

# Heuristica de cobertura de vecindarios cerrados; no asegura optimo global.
keyplayers_coverage <- function(graph, k=3L) {
  n<-igraph::vcount(graph);if(!n) return(data.frame())
  names<-igraph::V(graph)$name; neighborhoods<-igraph::ego(graph,order=1,mindist=0)
  chosen<-integer(); covered<-integer(); out<-list()
  for(step in seq_len(min(k,n))) {
    candidates<-setdiff(seq_len(n),chosen)
    gains<-vapply(candidates,function(i) length(setdiff(as.integer(neighborhoods[[i]]),covered)),1L)
    i<-candidates[order(-gains,names[candidates])[1]]
    gain<-length(setdiff(as.integer(neighborhoods[[i]]),covered))
    chosen<-c(chosen,i);covered<-union(covered,as.integer(neighborhoods[[i]]))
    out[[step]]<-data.frame(orden=step,nodo=names[i],nuevos_cubiertos=gain,cubiertos_acumulados=length(covered),porcentaje_cubierto=100*length(covered)/n)
  }
  do.call(rbind,out)
}
network_conclusions <- function(fit) {
  d<-fit$nodes;v<-function(k) fit$summary$valor[fit$summary$indicador==k][1]
  strongest<-if(nrow(d)) paste(head(d$name[order(-d$fuerza,d$name)],3),collapse="; ") else "Sin nodos"
  bridges<-d$name[d$articulacion]; bridges<-if(length(bridges)) paste(head(bridges,5),collapse="; ") else "No se detectan articulaciones"
  data.frame(lectura=c("Cobertura del grafo","Conectividad","Conexiones mas intensas","Puentes estructurales","Comunidades","Candidatos por cobertura"),
    resultado=c(paste(nrow(d),"nodos /",nrow(fit$edges),"conexiones"),paste(v("Componentes"),"componentes /",v("Nodos aislados"),"aislados"),strongest,bridges,
      if(nrow(fit$edges)) paste(fit$params$community_method,"/ modularidad",round(v("Modularidad"),3)) else "No hay conexiones para buscar comunidades",
      if(nrow(fit$keyplayers)) paste(fit$keyplayers$nodo,collapse="; ") else "Sin candidatos"),
    interpretacion=c("Describe la seleccion tras filtros; no toda la literatura.","Varias componentes indican partes desconectadas. Revisar umbrales y cobertura.","Mayor fuerza segun el peso elegido; no implica mayor calidad o influencia.","Al retirar una articulacion aumenta el numero de componentes; no demuestra liderazgo.","Particion exploratoria de conexiones; contrastar otro metodo y leer los documentos.","Heuristica codiciosa de alcance a un salto, incluido el propio nodo. No es una solucion optima ni un ranking universal."))
}

network_metrics <- function(nodes,edges,p) {
  g <- igraph::graph_from_data_frame(edges, directed = FALSE, vertices = nodes)
  n <- igraph::vcount(g); e <- igraph::ecount(g)
  components <- igraph::components(g)
  nodes$grado <- as.numeric(igraph::degree(g)); nodes$fuerza <- as.numeric(igraph::strength(g))
  # Indicadores topologicos sin pesos: evitan confundir frecuencia con distancia.
  nodes$intermediacion <- if (n > 2) as.numeric(igraph::betweenness(g, directed = FALSE, weights = NA, normalized = TRUE)) else rep(0, n)
  nodes$centralidad_armonica <- if (n > 1) as.numeric(igraph::harmonic_centrality(g, weights = NA, normalized = TRUE)) else rep(0,n)
  nodes$agrupamiento_local <- as.numeric(igraph::transitivity(g, type = "local", isolates = "zero"))
  nodes$componente <- components$membership
  communities <- if (e) with_seed(p$seed, if(p$community_method=="walktrap") igraph::cluster_walktrap(g, weights=edges$weight) else igraph::cluster_louvain(g, weights = edges$weight, resolution=p$resolution)) else NULL
  nodes$comunidad <- if (e) as.integer(igraph::membership(communities)) else rep(0L, n)
  modularity <- if (e) igraph::modularity(communities) else NA_real_
  stability <- if (e && p$community_method == "louvain") community_stability(g, edges$weight, "louvain", p$resolution, B = 20L, seed = p$seed) else list(ari = NA_real_)
  layout <- if (n == 1) matrix(c(0, 0), 1) else if (!e) igraph::layout_in_circle(g) else with_seed(p$seed, igraph::layout_with_fr(g, weights = edges$weight, niter = 600))
  nodes$x <- layout[, 1]; nodes$y <- layout[, 2]
  nodes$nucleo_k <- as.numeric(igraph::coreness(g))
  nodes$articulacion <- nodes$name %in% igraph::as_ids(igraph::articulation_points(g))
  nodes$participacion <- vapply(seq_len(n), function(i) {
    ix <- as.integer(igraph::neighbors(g,i)); if(!length(ix)) return(0)
    q <- table(nodes$comunidad[ix])/length(ix); 1-sum(q^2)
  }, 0)
  nodes$rol_observado <- ifelse(nodes$grado==0,"Aislado",ifelse(nodes$articulacion,"Articulacion / candidato a puente",ifelse(nodes$participacion>0,"Conecta comunidades","Conexion interna")))
  players <- keyplayers_coverage(g, min(p$keyplayers_k,n))
  summary <- data.frame(indicador = c("Nodos", "Conexiones", "Densidad", "Componentes", "Nodos aislados", "Grado medio", "Transitividad global", paste("Comunidades",p$community_method), "Modularidad", "Estabilidad de comunidades (ARI medio, 20 semillas)"),
    valor = c(n, e, if (n > 1) 2 * e / (n * (n - 1)) else NA, components$no, sum(nodes$grado == 0), if(n) mean(nodes$grado) else NA,
      if (sum(nodes$grado * (nodes$grado - 1)) > 0) igraph::transitivity(g, type = "global") else NA,
      if (e) length(unique(nodes$comunidad)) else NA, modularity, stability$ari))
  list(nodes=nodes,summary=summary,keyplayers=players)
}

#' Subgrafo inducido de una red
#'
#' @param parent Resultado de [run_network()].
#' @param method `"ego"`, `"community"`, `"component"` o `"manual"`.
#' @param focus Nodo de referencia (no necesario en `"manual"`).
#' @param order Distancia del vecindario (0-3) para `"ego"`.
#' @param selection Nodos elegidos para `"manual"`.
#' @return Lista como la de [run_network()], con indicadores recalculados.
#' @export
extract_subgraph <- function(parent, method="ego", focus="", order=1L, selection=character()) {
  g<-igraph::graph_from_data_frame(parent$edges,directed=FALSE,vertices=parent$nodes)
  if(method=="ego") {
    if(!focus %in% parent$nodes$name) abort_user("Selecciona un nodo que pertenezca a la red vigente.")
    check_number(order,"Distancia del vecindario",0,3)
    chosen<-igraph::as_ids(igraph::ego(g,order=order,nodes=focus,mindist=0)[[1]])
  } else if(method %in% c("community","component")) {
    if(!focus %in% parent$nodes$name) abort_user("Selecciona un nodo para identificar su comunidad o componente.")
    field<-if(method=="community") "comunidad" else "componente"
    value<-parent$nodes[[field]][match(focus,parent$nodes$name)]
    if(method=="community" && value==0) abort_user("Este nodo no tiene comunidad asignada. Usa vecindario, componente o selecci\u00f3n manual.")
    chosen<-parent$nodes$name[parent$nodes[[field]]==value]
  } else if(method=="manual") chosen<-unique(selection)
  else abort_user("M\u00e9todo de extracci\u00f3n no admitido.")
  if(!length(chosen) || any(!chosen %in% parent$nodes$name)) abort_user("Selecciona al menos un nodo de la red vigente.")
  nodes<-parent$nodes[parent$nodes$name %in% chosen,c("name","documentos"),drop=FALSE]
  nodes$comunidad_origen<-parent$nodes$comunidad[match(nodes$name,parent$nodes$name)]
  nodes$grado_origen<-parent$nodes$grado[match(nodes$name,parent$nodes$name)]
  edges<-parent$edges[parent$edges$from %in% chosen & parent$edges$to %in% chosen,,drop=FALSE]
  p<-parent$params;metrics<-network_metrics(nodes,edges,p)
  list(nodes=metrics$nodes,edges=edges,summary=metrics$summary,keyplayers=metrics$keyplayers,params=p,
    extraction=list(method=method,focus=focus,order=order,nodes=nodes$name,parent_params=parent$params,parent_nodes=nrow(parent$nodes),parent_edges=nrow(parent$edges)),
    audit=data.frame(etapa=c("Nodos en red de origen","Nodos del subgrafo","Conexiones internas"),cantidad=c(nrow(parent$nodes),nrow(nodes),nrow(edges))),
    note="Subgrafo inducido: conserva todas las conexiones de la red de origen entre los nodos elegidos y sus pesos originales. Presencia documental sigue referida al corpus original. Grado, densidad, centralidades, componentes y comunidades se recalculan en el subgrafo; comunidad_origen y grado_origen permiten comparar. Las posiciones son visuales.",collaboration=NULL)
}

export_subgraph <- function(directory,parent,subgraph,module_dir=NULL) {
  dir.create(directory,recursive=TRUE,showWarnings=FALSE)
  safe_csv(subgraph$nodes,file.path(directory,"subgrafo_nodos.csv"))
  safe_csv(subgraph$edges,file.path(directory,"subgrafo_conexiones.csv"))
  safe_csv(subgraph$summary,file.path(directory,"subgrafo_indicadores.csv"))
  safe_csv(subgraph$keyplayers,file.path(directory,"subgrafo_candidatos.csv"))
  saveRDS(parent,file.path(directory,"red_origen.rds"))
  saveRDS(subgraph$extraction,file.path(directory,"seleccion.rds"))
  jsonlite::write_json(list(version=BIBLIO_VERSION,seleccion=subgraph$extraction,definicion=subgraph$note),file.path(directory,"parametros_subgrafo.json"),pretty=TRUE,auto_unbox=TRUE,digits=NA)
  writeLines(c("# Ejecuta desde la carpeta descomprimida.",script_preamble(),
    "padre<-readRDS('red_origen.rds');s<-readRDS('seleccion.rds')",
    "subgrafo<-extract_subgraph(padre,s$method,s$focus,s$order,s$nodes)",
    "stopifnot(identical(subgrafo$nodes$name,s$nodes))","saveRDS(subgrafo,'subgrafo_reproducido.rds')"),file.path(directory,"reproducir_subgrafo.R"))
  writeLines(c(subgraph$note,"Los pesos y documentos proceden de la red de origen. Las m\u00e9tricas y comunidades se recalculan en los nodos seleccionados.",
    "Los RDS preservan etiquetas exactas; los CSV neutralizan f\u00f3rmulas para Excel. No se incluyen textos originales del corpus, aunque pueden aparecer nombres, referencias y t\u00edtulos.",
    "Necesitas R y el paquete bibliolab instalado; el script no instala paquetes ni modifica datos."),file.path(directory,"LEEME.txt"),useBytes=TRUE)
}
