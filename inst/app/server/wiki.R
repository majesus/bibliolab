# Módulo optativo de lectura. No modifica matrices, filtros ni resultados de modelos.
rv$wiki_index<-NULL;rv$wiki_signature<-NULL;rv$wiki_focus<-NULL;rv$wiki_concept<-NULL;rv$wiki_doc_id<-NULL
rv$wiki_notes<-wiki_empty_notes();rv$wiki_known<-list();rv$wiki_saved<-"Las notas se conservan en esta sesión. Descarga una copia JSON o Markdown antes de cerrar."
rv$wiki_graph_links<-data.frame(from=character(),target=character(),to=character(),resolved=logical())
rv$wiki_concept_network<-NULL;rv$wiki_concept_signature<-NULL;rv$wiki_concept_error<-NULL
wiki_concept_settings<-reactive(list(index=rv$wiki_signature,max_concepts=suppressWarnings(as.integer(input$wiki_concept_top %||% 100L)),criterion=input$wiki_concept_criterion %||% "df",ceiling=suppressWarnings(as.numeric(input$wiki_concept_ceiling %||% 100)),alpha=suppressWarnings(as.numeric(input$wiki_concept_alpha %||% .05)),top_k=suppressWarnings(as.integer(input$wiki_concept_k %||% 3L)),min_shared=as.integer(input$wiki_concept_min_docs %||% 1L),min_similarity=input$wiki_concept_similarity %||% 0,resolution=input$wiki_concept_resolution %||% 1))
wiki_concept_network_current<-reactive({if(is.null(wiki_current())||!identical(rv$wiki_concept_signature,wiki_concept_settings()))return(NULL);rv$wiki_concept_network})
wiki_update_groups<-function(f){groups<-if(is.null(f))integer() else f$summary$community;updateSelectInput(session,"wiki_community",choices=c("Todas"="all",setNames(as.character(groups),ifelse(groups==0,"0 / sin conexiones automáticas",paste("Comunidad",groups)))),selected="all")
  highlight<-c("Ninguna"="none");sm<-if(is.null(f))NULL else f$summary
  if(!is.null(sm)&&all(c("community","concepts","labels") %in% names(sm))){sm<-sm[sm$community>0,,drop=FALSE];if(nrow(sm))highlight<-c(highlight,setNames(as.character(sm$community),paste0("Comunidad ",sm$community," · ",sm$concepts," palabras · ",vapply(strsplit(sm$labels,", ",fixed=TRUE),function(v)paste(utils::head(v,3L),collapse=", "),""))))}
  updateSelectInput(session,"wiki_highlight_community",choices=highlight,selected="none")}
wiki_calculate_concepts<-function(x){s<-wiki_concept_settings();f<-wiki_concept_network(x,s$min_shared,s$min_similarity,s$resolution,max_concepts=if(is.na(s$max_concepts)||s$max_concepts<1L)NULL else s$max_concepts,criterion=s$criterion,max_share=if(is.na(s$ceiling)||s$ceiling>=100)NULL else s$ceiling/100,alpha=if(is.na(s$alpha)||s$alpha>=1)NULL else s$alpha,top_k=if(is.na(s$top_k)||s$top_k<1L)NULL else s$top_k);rv$wiki_concept_network<-f;rv$wiki_concept_signature<-s;rv$wiki_concept_error<-NULL;wiki_update_groups(f);invisible(f)}
wiki_fields<-reactive({req(rv$prepared);wiki_field_profile(rv$raw,rv$prepared$mapping)})
output$wiki_text_field_control<-renderUI({if(is.null(rv$prepared))return(hint("Prepara un corpus en 02 para elegir las páginas del cuaderno."));d<-wiki_fields();advanced<-isTRUE(input$wiki_advanced_fields)
  eligible<-d[d$nonempty>0 & (d$recommended|advanced),,drop=FALSE]
  if(!nrow(eligible))return(hint("No hay resúmenes ni títulos con texto. Las opciones avanzadas permiten elegir otro campo de forma explícita."))
  field<-isolate(input$wiki_text_field %||% rv$prepared$mapping$text);if(!field %in% eligible$field)field<-eligible$field[1]
  selectInput("wiki_text_field","Texto de cada página / columna del archivo",setNames(eligible$field,paste0(eligible$field," / ",eligible$nonempty," de ",eligible$total," con texto")),selected=field)})
output$wiki_field_reading<-renderUI({d<-wiki_fields();i<-match(input$wiki_text_field,d$field);if(is.na(i))return(NULL)
  tagList(hint(paste(d$kind[i],"/",d$language[i],"/ cobertura",sprintf("%.1f %%",d$coverage[i]),". El idioma estimado corresponde a una muestra, no certifica toda la columna.")),
    if(!d$recommended[i])tags$p(class="integrity-note","Has elegido un campo avanzado. Autores, DOI y fechas se ofrecen como metadatos; tratarlos como texto puede producir coincidencias de nombres o números que no representan conceptos temáticos."))})
output$wiki_field_coverage<-table_render(function(){d<-wiki_fields();d<-d[d$recommended,,drop=FALSE];data.frame(Campo=d$field,Tipo=d$kind,Documentos_con_texto=d$nonempty,Total=d$total,Cobertura_porcentaje=round(d$coverage,1),Idioma=d$language,Disponible=d$nonempty>0,check.names=FALSE)})
wiki_source_key<-reactive({req(rv$raw);wiki_fingerprint(rv$raw)})
wiki_settings<-reactive(list(signature=rv$signature,source_key=wiki_source_key(),mode=input$wiki_mode %||% "corpus",text_field=input$wiki_text_field %||% rv$prepared$mapping$text,text_source=input$wiki_text_source %||% "original",dictionary=if(identical(input$wiki_mode,"dictionary"))input$wiki_dictionary %||% "" else ""))
wiki_current<-reactive({if(is.null(rv$prepared)||stale()||is.null(rv$wiki_index)||!identical(rv$wiki_signature,wiki_settings()))return(NULL);rv$wiki_index})
wiki_notes_current<-reactive({x<-wiki_current();if(is.null(x))return(wiki_empty_notes());rv$wiki_notes[rv$wiki_notes$scope==x$source_key,,drop=FALSE]})
wiki_export_current<-reactive({x<-wiki_current();if(is.null(x))return(NULL);list(index=x,notes=wiki_notes_current(),graph=wiki_graph_data(),view=list(node=wiki_active(),params=wiki_graph_settings(),seed=2026L,motion=isTRUE(input$wiki_motion %||% TRUE)))})
observeEvent(input$wiki_build,task("Construyendo el índice de lectura…",{
  p<-current();s<-wiki_settings();field<-s$text_field
  if(!field %in% names(rv$raw))abort_user("Elige una columna de texto para el cuaderno.")
  if(s$text_source=="prepared"&&field!=p$mapping$text)abort_user("Texto preparado solo corresponde a la columna usada en 02. Elige Original para leer otro campo, o prepara de nuevo con ese campo.")
  p$documents$text<-clean_value(rv$raw[[field]][p$documents$source_row]);p$mapping$text<-field
  # Construcción transaccional: una petición fallida no altera los modelos ni las notas.
  x<-build_wiki_index(p,rv$corpus,s$mode,s$dictionary,s$source_key,function(v)incProgress(0,detail=paste0(round(100*v),"% del índice")),text_source=s$text_source)
  x<-wiki_attach_metadata(x,rv$raw)
  rv$wiki_index<-x;rv$wiki_signature<-s;rv$wiki_focus<-if(nrow(x$concepts))x$concepts$key[1] else x$documents$key[1];rv$wiki_concept<-if(nrow(x$concepts))x$concepts$key[1] else NULL;rv$wiki_doc_id<-x$documents$doc_id[1]
  rv$wiki_concept_network<-NULL;rv$wiki_concept_signature<-NULL
  tryCatch(wiki_calculate_concepts(x),error=function(e){rv$wiki_concept_error<-conditionMessage(e);showNotification(rv$wiki_concept_error,type="warning",duration=15)})
  known<-rv$wiki_known;known[[x$source_key]]<-unique(c(known[[x$source_key]],wiki_registry(x)$key));rv$wiki_known<-known
  updateSelectizeInput(session,"wiki_document",choices=setNames(x$documents$doc_id,paste(x$documents$doc_id,x$documents$title,x$documents$doi,sep=" · ")),selected=x$documents$doc_id[1],server=TRUE)
  updateSelectizeInput(session,"wiki_term",choices=setNames(x$concepts$key,paste0(x$concepts$label," / ",x$concepts$documents," documentos")),selected=x$concepts$key[1],server=TRUE)
  showNotification("Índice listo. Pulsa un término para ver sus documentos y contextos; las notas son tuyas, sin IA.",type="message",duration=7)
}))
output$wiki_state<-renderUI({x<-wiki_current()
  if(is.null(x))return(empty_help(if(is.null(rv$prepared)||stale())"Prepara un corpus vigente para construir la lectura enlazada. Puedes consultar su guía sin calcularla." else "Elige la fuente de conceptos y pulsa Crear índice. Si cambias preparación o diccionario, vuelve a construirlo; tus notas permanecen en esta sesión."))
  missing_notes<-sum(rv$wiki_notes$scope==x$source_key&!rv$wiki_notes$node %in% wiki_registry(x)$key)
  tags$div(class="wiki-state",tags$strong(paste(nrow(x$documents),"documentos /",nrow(x$concepts),"conceptos /",length(x$counts@x),"relaciones de mención")),tags$p(x$source),tags$p("Una coincidencia léxica no prueba una cita, equivalencia semántica o relación causal. El grafo permite navegar y contrastar contextos."),
    if(missing_notes)hint(paste(missing_notes,"notas de esta entrada corresponden a páginas fuera del índice actual. Se conservan en la copia JSON; recuperar su documento o concepto permite volver a leerlas.")))
})
output$wiki_ready<-renderText(if(is.null(wiki_current()))"no" else "yes");outputOptions(output,"wiki_ready",suspendWhenHidden=FALSE)
wiki_navigate<-function(node,modal=TRUE) {
  x<-wiki_current();if(is.null(x)||!node %in% wiki_registry(x)$key)return()
  rv$wiki_focus<-node
  if(node %in% x$documents$key){rv$wiki_doc_id<-x$documents$doc_id[match(node,x$documents$key)];updateSelectizeInput(session,"wiki_document",selected=rv$wiki_doc_id)}
  else {rv$wiki_concept<-node;updateSelectizeInput(session,"wiki_term",selected=node)}
  if(!modal)return(invisible(node))
  if(node %in% x$concepts$key) showModal(modalDialog(title=paste("Menciones de",x$concepts$label[match(node,x$concepts$key)]),size="l",easyClose=TRUE,
    tags$p("Selecciona un documento para leerlo en este mismo diálogo. La tabla cuenta todas las menciones; las concordancias muestran hasta 200 contextos."),DT::DTOutput("wiki_modal_backlinks"),tags$h3("Concordancias / expresión en contexto"),DT::DTOutput("wiki_modal_kwic"),footer=modalButton("Volver a la lectura")))
  else {i<-match(node,x$documents$key);d<-x$documents[i,];showModal(modalDialog(title=if(nzchar(d$title))d$title else d$doc_id,size="l",easyClose=TRUE,
    wiki_metadata_ui(d),tags$p(class="hint",x$source),tags$article(class="wiki-text",HTML(wiki_text_html(x,d$doc_id))),
    tags$details(tags$summary("Texto original / sin transformaciones"),tags$p(class="wiki-text",d$original)),footer=modalButton("Volver al cuaderno")))}
}
observeEvent(input$wiki_navigate,{if(identical(input$wiki_navigate$source,"graph"))updateSelectizeInput(session,"wiki_find",selected="");node<-input$wiki_navigate$node;if(is.character(node)&&length(node)==1)wiki_navigate(node,modal=!identical(input$wiki_navigate$source,"graph"))})
observeEvent(input$wiki_document,{x<-wiki_current();if(!is.null(x)&&input$wiki_document %in% x$documents$doc_id&&!identical(input$wiki_document,rv$wiki_doc_id)){rv$wiki_doc_id<-input$wiki_document;rv$wiki_focus<-paste0("doc:",input$wiki_document)}})
observeEvent(input$wiki_open_term,{x<-wiki_current();req(x);wiki_navigate(input$wiki_term)})
wiki_doc_id<-reactive({x<-wiki_current();req(x);focus<-rv$wiki_focus %||% x$documents$key[1]
  if(focus %in% x$documents$key)sub("^doc:","",focus) else if((rv$wiki_doc_id %||% "") %in% x$documents$doc_id)rv$wiki_doc_id else x$documents$doc_id[1]})
wiki_active<-reactive({x<-wiki_current();req(x);node<-rv$wiki_focus %||% x$documents$key[1];if(!node %in% wiki_registry(x)$key)node<-x$documents$key[1];node})
output$wiki_reading<-renderUI({x<-wiki_current();if(is.null(x))return(NULL);node<-wiki_active()
  if(node %in% x$concepts$key){j<-match(node,x$concepts$key);c<-x$concepts[j,];return(tags$article(class="wiki-reading",tags$p(class="eyebrow","Ficha de concepto"),tags$h3(c$label),tags$p(paste(c$documents,"fichas con mención /",c$occurrences,"apariciones")),tags$p("Estas fichas enlazan este concepto desde su texto. Son sus backlinks documentales. Selecciona una fila para leer el texto completo y seguir otras palabras enlazadas."),DT::DTOutput("wiki_card_backlinks"),tags$details(tags$summary("Variantes y criterio de lectura"),tags$p(c$variants),tags$p(x$source)),hint("Los enlaces salientes y backlinks escritos en tus notas se consultan en Notas y backlinks explícitos. La presencia de una palabra no valida una interpretación semántica.")))}
  id<-wiki_doc_id();i<-match(id,x$documents$doc_id);d<-x$documents[i,];spans<-wiki_spans(x,id)
  tags$article(class="wiki-reading",tags$p(class="eyebrow",paste(id,"·",if(is.na(d$year))"Sin año" else d$year)),tags$h3(if(nzchar(d$title))d$title else "Documento sin título"),wiki_metadata_ui(d),tags$p(class="chart-caption",x$source),
    tags$div(class="wiki-text",if(nzchar(d$text))HTML(wiki_text_html(x,id)) else empty_help("Este documento no aporta texto a esta versión. Sus metadatos y notas siguen disponibles.")),
    hint(paste(nrow(spans),"coincidencias localizadas. En el texto se enlazan hasta 400 menciones no superpuestas; las frases más largas tienen prioridad. Las tablas conservan todos los conteos.")),
    if(x$mode=="corpus")tags$details(class="visible-disclosure",tags$summary("Contrastar con el texto original"),tags$p(class="wiki-text",d$original)),
    tags$details(tags$summary("Conceptos de este documento / relación completa"),DT::DTOutput("wiki_document_terms")))
})
output$wiki_document_terms<-table_render(function(){x<-wiki_current();req(x);i<-match(wiki_doc_id(),x$documents$doc_id);n<-as.numeric(x$counts[i,]);js<-which(n>0);data.frame(Concepto=x$concepts$label[js],"Apariciones en este documento"=n[js],"Documentos que lo mencionan"=x$concepts$documents[js],check.names=FALSE)})
output$wiki_backlink_title<-renderUI({x<-wiki_current();if(is.null(x))return(NULL);j<-match(rv$wiki_concept,x$concepts$key)
  if(!length(j)||is.na(j))return(hint("Pulsa una palabra enlazada o busca un concepto y ábrelo. Aquí aparecerán los documentos que lo mencionan y sus contextos."))
  tags$div(tags$h3(paste0("Menciones de [[",x$concepts$label[j],"]]")),tags$p(paste(x$concepts$documents[j],"documentos /",x$concepts$occurrences[j],"apariciones. La tabla de documentos cuenta todas las coincidencias, no solo las que se subrayan en el texto.")))
})
wiki_backlink_data<-reactive({x<-wiki_current();req(x,rv$wiki_concept);wiki_backlinks(x,rv$wiki_concept)})
output$wiki_backlinks<-table_render(wiki_backlink_data,selection="single")
output$wiki_card_backlinks<-table_render(wiki_backlink_data,selection="single")
observeEvent(input$wiki_card_backlinks_rows_selected,{d<-wiki_backlink_data();i<-input$wiki_card_backlinks_rows_selected;if(length(i)==1&&i %in% seq_len(nrow(d)))wiki_navigate(paste0("doc:",d$doc_id[i]),modal=FALSE)})
output$wiki_modal_backlinks<-table_render(wiki_backlink_data,selection="single")
output$wiki_modal_kwic<-table_render(function(){x<-wiki_current();req(x,rv$wiki_concept);wiki_kwic(x,rv$wiki_concept,context=as.integer(input$wiki_context %||% 70L),limit=200L)},selection="single")
observeEvent(input$wiki_modal_backlinks_rows_selected,{d<-wiki_backlink_data();i<-input$wiki_modal_backlinks_rows_selected;if(length(i)==1&&i %in% seq_len(nrow(d)))wiki_navigate(paste0("doc:",d$doc_id[i]))})
observeEvent(input$wiki_modal_kwic_rows_selected,{x<-wiki_current();req(x,rv$wiki_concept);d<-wiki_kwic(x,rv$wiki_concept,context=as.integer(input$wiki_context %||% 70L),limit=200L);i<-input$wiki_modal_kwic_rows_selected;if(length(i)==1&&i %in% seq_len(nrow(d)))wiki_navigate(paste0("doc:",d$doc_id[i]))})
observeEvent(input$wiki_backlinks_rows_selected,{d<-wiki_backlink_data();i<-input$wiki_backlinks_rows_selected;if(length(i)==1&&i %in% seq_len(nrow(d)))wiki_navigate(paste0("doc:",d$doc_id[i]))})
output$wiki_kwic<-table_render(function(){x<-wiki_current();req(x,rv$wiki_concept);wiki_kwic(x,rv$wiki_concept,context=as.integer(input$wiki_context %||% 70L),limit=200L)},selection="single")
observeEvent(input$wiki_kwic_rows_selected,{x<-wiki_current();req(x,rv$wiki_concept);d<-wiki_kwic(x,rv$wiki_concept,context=as.integer(input$wiki_context %||% 70L),limit=200L);i<-input$wiki_kwic_rows_selected;if(length(i)==1&&i %in% seq_len(nrow(d)))wiki_navigate(paste0("doc:",d$doc_id[i]))})
observeEvent(input$wiki_note_save,{
  a<-input$wiki_note_save
  if(!is.list(a)||!is.character(a$scope)||length(a$scope)!=1||!is.character(a$node)||length(a$node)!=1)return()
  saved<-tryCatch({notes<-wiki_save_note(rv$wiki_notes,a$scope,a$node,a$text,rv$wiki_known[[a$scope]] %||% character());rv$wiki_notes<-notes;rv$wiki_saved<-if(nzchar(a$text))paste("Nota guardada para",a$node,"en esta sesión ·",format(Sys.time(),"%H:%M:%S"),"· descarga una copia antes de cerrar.") else "Esta página no tiene texto de nota. Las notas de otras páginas siguen conservadas en la sesión.";TRUE},error=function(e){rv$wiki_saved<-paste("No se ha guardado:",conditionMessage(e));showNotification(rv$wiki_saved,type="error",duration=12);FALSE})
  session$sendCustomMessage("wikiNoteSaved",list(ok=saved,scope=a$scope,node=a$node,text=a$text))
})
output$wiki_note_editor<-renderUI({x<-wiki_current();if(is.null(x))return(NULL);node<-wiki_active();r<-wiki_registry(x);label<-r$label[match(node,r$key)];notes<-isolate(rv$wiki_notes);i<-which(notes$scope==x$source_key&notes$node==node);body<-if(length(i))notes$text[i[1]] else ""
  tags$div(tags$h3(paste0("Tu nota / [[",label,"]]")),tags$p("Escribe una interpretación, duda o evidencia. Para enlazar otra página usa [[D00001]] o [[concepto]]. Si un nombre es ambiguo, utiliza su clave completa: doc:D00001, term:salud o concept:salud."),
    tags$label(`for`="wiki_note","Nota del investigador / hasta 20.000 caracteres"),tags$textarea(id="wiki_note",class="form-control wiki-note",`data-wiki-node`=node,`data-wiki-scope`=x$source_key,rows=6,body),
    tags$button(type="button",class="btn btn-primary wiki-note-save","Guardar ahora"))
})
output$wiki_note_status<-renderText(rv$wiki_saved)
output$wiki_note_preview<-renderUI({x<-wiki_current();if(is.null(x))return(NULL);node<-wiki_active();notes<-wiki_notes_current();i<-match(node,notes$node)
  if(is.na(i))return(hint("Todavía no has anotado esta página. Las notas se guardan en memoria de la sesión; no se escriben automáticamente en disco."))
  tags$section(tags$h4("Lectura de tu nota / enlaces navegables"),tags$div(class="wiki-text",HTML(wiki_note_html(notes$text[i],x))),hint("La lectura muestra hasta 400 enlaces interactivos. La nota completa y todos sus enlaces se conservan en las copias y exportaciones."))
})
wiki_note_relations<-reactive({x<-wiki_current();req(x);wiki_note_links(wiki_notes_current(),x)})
observe({x<-wiki_current();if(is.null(x))return();links<-wiki_note_relations();links<-unique(links[links$resolved,,drop=FALSE]);links$target<-rep("",nrow(links));links<-unique(links);links<-links[order(links$from,links$to),,drop=FALSE];rownames(links)<-NULL;if(!identical(links,isolate(rv$wiki_graph_links)))rv$wiki_graph_links<-links})
wiki_note_links_data<-reactive({x<-wiki_current();req(x);d<-wiki_note_relations();d[d$from==wiki_active()|(!is.na(d$to)&d$to==wiki_active()),,drop=FALSE]})
output$wiki_note_links<-table_render(function(){x<-wiki_current();req(x);d<-wiki_note_links_data();r<-wiki_registry(x)
  data.frame("Página que enlaza"=r$label[match(d$from,r$key)],"Nombre escrito"=d$target,"Página de destino"=ifelse(d$resolved,r$label[match(d$to,r$key)],"Sin resolver"),"Relación con esta página"=ifelse(d$from==wiki_active(),"Enlace saliente","Backlink entrante"),"Destino reconocido"=d$resolved,check.names=FALSE)},selection="single")
observeEvent(input$wiki_note_links_rows_selected,{d<-wiki_note_links_data();i<-input$wiki_note_links_rows_selected;if(length(i)==1&&i %in% seq_len(nrow(d))){target<-if(d$from[i]==wiki_active())d$to[i] else d$from[i];if(is.na(target))showNotification("El destino no está resuelto. Revisa el nombre escrito.",type="message") else wiki_navigate(target)}})
output$wiki_note_link_reading<-renderUI({x<-wiki_current();if(is.null(x))return(NULL);d<-wiki_note_relations();missing<-d[!d$resolved,,drop=FALSE]
  tagList(hint("Los enlaces escritos por ti son dirigidos: desde la nota donde aparecen hacia su destino. Un backlink es la misma relación leída desde el destino; no inventamos un segundo enlace."),if(nrow(missing))tags$p(class="quality-notes",paste(nrow(missing),"enlaces de notas no resueltos. Revisa el nombre o recupera el concepto en este índice; las notas no se borran.")))
})
rv$wiki_network<-NULL;rv$wiki_network_signature<-NULL
wiki_cluster_settings<-reactive(list(index=rv$wiki_signature,min_shared=as.integer(input$wiki_graph_shared %||% 2L),min_similarity=input$wiki_similarity %||% .1,resolution=input$wiki_resolution %||% 1))
wiki_network_current<-reactive({if(is.null(wiki_current())||!identical(rv$wiki_network_signature,wiki_cluster_settings()))return(NULL);rv$wiki_network})
observeEvent(input$wiki_cluster,task("Calculando red y comunidades…",{x<-wiki_current();req(x)
  if(identical(input$wiki_graph_view %||% "concepts","concepts"))wiki_calculate_concepts(x)
  else {s<-wiki_cluster_settings();f<-wiki_document_network(x,s$min_shared,s$min_similarity,s$resolution);rv$wiki_network<-f;rv$wiki_network_signature<-s;wiki_update_groups(f)}
}))
wiki_selected_network<-reactive(if(identical(input$wiki_graph_view %||% "concepts","concepts"))wiki_concept_network_current() else wiki_network_current())
observeEvent(input$wiki_graph_view,{view<-input$wiki_graph_view;wiki_update_groups(wiki_selected_network());updateSelectInput(session,"wiki_graph_scope",choices=if(view=="bipartite")c("Entorno local / documento y sus menciones"="local") else c("Red completa / todos los nodos calculados"="global","Entorno local de la ficha activa"="local","Solo una comunidad"="community"),selected=if(view=="concepts")"global" else "local")},ignoreInit=TRUE)
output$wiki_cluster_state<-renderUI({f<-wiki_selected_network();hint(if(is.null(f))paste("La red no está calculada con los valores actuales: pulsa «Calcular red y comunidades».",if(identical(input$wiki_graph_view %||% "concepts","concepts"))rv$wiki_concept_error %||% "" else "") else paste(f$note,"Modularidad:",format(f$modularity,digits=4)))})
output$wiki_communities<-table_render(function(){f<-wiki_selected_network();validate(need(!is.null(f),"Calcula la red para consultar sus comunidades."));d<-f$summary;names(d)<-if(identical(input$wiki_graph_view %||% "concepts","concepts"))c("Comunidad / 0 sin coapariciones","Conceptos","Conceptos conectados / nombres orientativos") else c("Comunidad / 0 = aislados","Documentos","Conceptos frecuentes / nombres orientativos");d})
output$wiki_roles<-table_render(function(){f<-wiki_selected_network();validate(need(!is.null(f)&&!is.null(f$roles),"Calcula la red de conceptos para consultar los roles."));d<-f$roles[f$roles$community>0,,drop=FALSE];d<-d[order(d$community,-d$z,d$label),,drop=FALSE]
  data.frame(Palabra=d$label,Comunidad=d$community,Fichas=d$fichas,Relaciones=d$degree,`Relaciones en su comunidad`=d$within_degree,z=round(d$z,2),`Participación P`=round(d$participation,2),Rol=d$role,`Comunidades con las que enlaza (relaciones)`=d$linked,check.names=FALSE)})
output$wiki_network_example<-renderUI({f<-wiki_selected_network();ex<-if(is.null(f)||is.null(f$stats$documents))character() else wiki_network_example(f);if(!length(ex))return(hint("Calcula la red de conceptos para ver un ejemplo con tus datos."));tagList(lapply(ex,tags$p))})
output$wiki_network_methods<-renderUI({f<-wiki_selected_network();if(is.null(f)||is.null(f$stats$documents))return(hint("Calcula la red de conceptos para generar el texto de métodos con tus parámetros."));keys<-c("benjamini","blondel","guimera","jaccard","neal","newman","traag","tumminello",if(identical(f$params$criterion,"tfidf"))"sparck");keys<-keys[order(keys)];tagList(lapply(wiki_network_methods(f),tags$p),tags$p(tags$strong("Referencias citadas en este texto")),tags$ul(lapply(wiki_network_references(keys),tags$li)))})
output$wiki_network_reading<-renderUI({f<-wiki_selected_network();if(is.null(f)||is.null(f$reading))return(hint("Calcula la red de conceptos para ver su lectura."));tagList(lapply(f$reading,tags$p),tags$p(class="hint","Color = comunidad. Tamaño = fichas con la palabra. Forma: cuadrado = eje de su comunidad; triángulo = puente entre comunidades; estrella = eje y puente; círculo = apoyo. Todas las palabras llevan su nombre; ejes, puentes y las 15 con más fichas, en letra mayor."))})
wiki_graph_settings<-reactive({view<-input$wiki_graph_view %||% "concepts";concepts<-identical(view,"concepts");s<-if(concepts)wiki_concept_settings() else wiki_cluster_settings();list(max_terms=as.integer(input$wiki_graph_terms %||% 12L),max_docs=as.integer(input$wiki_graph_docs %||% 20L),min_shared=s$min_shared,include_manual=isTRUE(input$wiki_graph_manual %||% TRUE),view=view,scope=if(view=="bipartite")"local" else input$wiki_graph_scope %||% if(concepts)"global" else "local",community=input$wiki_community %||% "all",min_similarity=s$min_similarity,resolution=s$resolution,seed=2026L,remove_isolates=isTRUE(input$wiki_remove_isolates))})
wiki_graph_data<-reactive({x<-wiki_current();req(x);s<-wiki_graph_settings();f<-wiki_selected_network();if(s$scope!="local"||s$view=="concepts")validate(need(!is.null(f),paste("Calcula una red vigente antes de abrir esta vista.",if(s$view=="concepts")rv$wiki_concept_error %||% "" else "")));node<-if(s$view=="concepts"&&s$scope!="local")isolate(wiki_active()) else wiki_active();do.call(wiki_local_graph,c(list(index=x,node=node,manual_links=rv$wiki_graph_links,network=f),s))})
# Buscador y resaltado: no recalculan la red. El buscador ofrece los nodos que están dibujados; el resaltado de comunidad se resuelve en el navegador.
observe({x<-wiki_current();g<-tryCatch(wiki_graph_data(),error=function(e)NULL)
  if(is.null(x)||is.null(g)||!nrow(g$nodes)){updateSelectizeInput(session,"wiki_find",choices=character(),selected="",server=TRUE);return()}
  r<-wiki_registry(x);lab<-r$label[match(g$nodes$id,r$key)];lab<-ifelse(is.na(lab)|!nzchar(lab),g$nodes$label,lab)
  o<-order(tolower(lab));updateSelectizeInput(session,"wiki_find",choices=setNames(g$nodes$id[o],lab[o]),selected="",server=TRUE)
  updateSelectInput(session,"wiki_highlight_community",selected="none")})
observeEvent(input$wiki_find,{id<-input$wiki_find;x<-wiki_current();if(is.null(x)||!is.character(id)||length(id)!=1L||!nzchar(id)||!id %in% wiki_registry(x)$key)return()
  s<-wiki_graph_settings();wiki_navigate(id,modal=FALSE)
  # Con alcance local (o vistas de documentos) abrir la ficha recentra el dibujo; en la red de conceptos se resalta sobre el dibujo existente.
  if(identical(s$view,"concepts")&&!identical(s$scope,"local"))session$sendCustomMessage("wikiFocusNode",list(id=id))},ignoreInit=TRUE)
observeEvent(input$wiki_clear_highlight,{updateSelectizeInput(session,"wiki_find",selected="");updateSelectInput(session,"wiki_highlight_community",selected="none");session$sendCustomMessage("wikiClearHighlight",list())})
observeEvent(input$wiki_hl_reset,updateSelectizeInput(session,"wiki_find",selected=""),ignoreInit=TRUE)
wiki_draw<-new.env(parent=emptyenv());wiki_draw$revision<-0L;wiki_draw$graph<-NULL
output$wiki_graph<-visNetwork::renderVisNetwork({g<-wiki_graph_data();n<-g$nodes;ed<-g$edges
  wiki_draw$revision<-wiki_draw$revision+1L;wiki_draw$graph<-g;wiki_draw$settings<-isolate(wiki_graph_settings());wiki_draw$signature<-isolate(rv$wiki_signature);ed$id<-as.character(seq_len(nrow(ed)))
  n$color<-if("community" %in% names(n))ifelse(n$community==0,"#999999",swiss_colours(max(1,max(n$community)))[pmax(1,n$community)]) else ifelse(n$central,"#c7281e",ifelse(n$type=="Concepto","#245579","#777777"));n$shape<-ifelse(n$type=="Concepto","diamond","dot");n$size<-ifelse(n$central,21,13);n$title<-paste0(escape_html(n$description),if("community" %in% names(n))paste0("<br>Comunidad ",n$community) else "")
  if("role_group" %in% names(n)) {
    # El rol se codifica por la forma (legible sin color) y por un contorno oscuro; el color sigue siendo la comunidad.
    fill<-n$color;kind<-n$role_group;role_shape<-c(Eje="square",Puente="triangle","Eje y puente"="star",Apoyo="dot",Aislada="dot")
    n$shape<-unname(role_shape[kind]);n$color<-NULL;border<-ifelse(kind %in% c("Eje","Puente","Eje y puente"),"#111111",fill)
    n$color.background<-fill;n$color.border<-border;n$color.highlight.background<-fill;n$color.highlight.border<-border
    n$borderWidth<-ifelse(kind %in% c("Eje","Puente","Eje y puente"),3,1)
    n$size<-8+22*sqrt(n$fichas/max(1,max(n$fichas)))+ifelse(kind=="Eje y puente",4,0)+ifelse(n$central,4,0)
    n$title<-paste0("<b>",escape_html(n$label),"</b><br>",n$title,"<br>Rol: ",escape_html(n$role),ifelse(is.na(n$z),"",paste0(" (z = ",round(n$z,2),"; P = ",round(n$participation,2),")")))
    prominent<-kind %in% c("Eje","Puente","Eje y puente")|rank(-n$fichas,ties.method="first")<=15|n$central
    n$fullLabel<-n$label
    # Por defecto se rotulan todas las palabras; destacadas (roles y las 15 con más fichas) en letra mayor. Sin la casilla solo se rotulan las destacadas.
    if(!isTRUE(input$wiki_label_all %||% TRUE))n$label<-ifelse(prominent,n$label,"")
    n$font.size<-ifelse(prominent,24,20)
  }
  n$label<-vapply(n$label,function(label)paste(strwrap(label,width=24),collapse="\n"),"")
  if("fullLabel" %in% names(n))n$fullLabel<-vapply(n$fullLabel,function(label)paste(strwrap(label,width=24),collapse="\n"),"")
  ed$color<-ifelse(ed$type!="Nota explícita","#b8b8b8","#222222");ed$dashes<-ed$type=="Nota explícita";ed$arrows<-ifelse(ed$type=="Nota explícita","to","")
  ed$title<-if("shared" %in% names(ed))ifelse(ed$type=="Nota explícita","Enlace escrito en una nota; pulsa para leerla.",paste0("Jaccard: ",round(ed$weight,4)," / ",ed$shared,if(identical(g$kind,"concepts"))" fichas con ambos conceptos. Pulsa para consultar la evidencia." else " conceptos compartidos",if("evidence" %in% names(ed))paste0("<br>",escape_html(ed$evidence)) else "")) else paste0(ed$type," / ",ed$weight,ifelse(ed$type=="Conceptos compartidos"," conceptos"," menciones o enlace declarado"),if("evidence" %in% names(ed))paste0("<br>",escape_html(ed$evidence)) else "");ed$width<-ifelse(ed$type!="Nota explícita",pmin(3,.6+log1p(ed$weight)),1.5)
  if(all(c("p_adj","lift") %in% names(ed)))ed$title<-paste0(sub("(<br>)+$","",ed$title),ifelse(is.na(ed$p_adj),"",paste0("<br>Aparecen juntas ",round(ed$lift,1)," veces más de lo esperable por azar (p ajustada ",trimws(format(ed$p_adj,digits=2)),")")))
  ed$smooth.enabled<-ed$type=="Nota explícita";ed$smooth.type<-rep("curvedCW",nrow(ed));ed$smooth.roundness<-rep(.16,nrow(ed))
  w<-visNetwork::visNetwork(n,ed,height="760px",width="100%")
  w<-visNetwork::visNodes(w,font=list(face="Arial",size=20,strokeWidth=4,strokeColor="#ffffff"),shadow=FALSE);w<-visNetwork::visEdges(w,smooth=FALSE)
  w<-visNetwork::visLayout(w,randomSeed=2026);w<-visNetwork::visInteraction(w,dragNodes=TRUE,dragView=TRUE,zoomView=TRUE,hover=TRUE,navigationButtons=TRUE)
  # Resaltado propio (sustituye a highlightNearest): la lógica vive en window.wikiHL (app.js), compartida con el buscador y el resaltado de comunidades. Pulsar un punto conserva en color y con su nombre ese punto y sus vecinas; pulsar un hueco restaura el dibujo.
  w<-visNetwork::visEvents(w,click=paste0("function(p){var H=window.wikiHL;if(p.nodes.length){if(H)H.node(this,p.nodes[0]);Shiny.setInputValue('wiki_navigate',{node:p.nodes[0],source:'graph',nonce:Date.now()},{priority:'event'});}else if(p.edges.length){Shiny.setInputValue('wiki_edge',{id:p.edges[0],revision:",wiki_draw$revision,",nonce:Date.now()},{priority:'event'});}else if(H){H.reset(this,true);}}"))
  visNetwork::visPhysics(w,enabled=isTRUE(isolate(input$wiki_motion %||% TRUE)),solver="barnesHut",barnesHut=list(gravitationalConstant=-3000,centralGravity=.05,springLength=190,springConstant=.025,damping=.7,avoidOverlap=.6),stabilization=list(enabled=TRUE,iterations=200),maxVelocity=6,minVelocity=.5)
})
rv$wiki_edge_relation<-NULL
observeEvent(input$wiki_edge,{
  a<-input$wiki_edge;if(is.null(wiki_current())||!is.list(a)||!identical(as.integer(a$revision),wiki_draw$revision)||!identical(wiki_draw$signature,rv$wiki_signature)||!identical(wiki_draw$settings,wiki_graph_settings()))return()
  k<-suppressWarnings(as.integer(a$id));g<-wiki_draw$graph;if(length(k)!=1||is.na(k)||!k %in% seq_len(nrow(g$edges)))return();e<-g$edges[k,]
  if(e$type=="Nota explícita"){wiki_navigate(e$from,modal=FALSE);n<-wiki_notes_current();i<-match(e$from,n$node);showModal(modalDialog(title="Enlace explícito / nota de origen",tags$p("La flecha va desde esta nota hacia la página enlazada. Su backlink es la misma relación leída desde el destino."),if(!is.na(i))tags$div(class="wiki-text",HTML(wiki_note_html(n$text[i],wiki_current()))),easyClose=TRUE,footer=modalButton("Volver al grafo")));return()}
  if(!identical(g$kind,"concepts"))return()
  rv$wiki_edge_relation<-list(from=e$from,to=e$to,signature=rv$wiki_signature);labs<-wiki_current()$concepts$label[match(c(e$from,e$to),wiki_current()$concepts$key)]
  showModal(modalDialog(title=paste(labs,collapse=" + "),size="l",easyClose=TRUE,tags$p(paste(e$shared,"fichas mencionan ambos conceptos. Jaccard =",format(e$weight,digits=4),". La tabla incluye todas las fichas de esta conexión. Selecciona una fila para ver el texto; sus palabras permiten continuar la lectura.")),DT::DTOutput("wiki_edge_documents"),uiOutput("wiki_edge_context"),footer=modalButton("Volver al grafo")))
})
wiki_edge_documents<-reactive({x<-wiki_current();r<-rv$wiki_edge_relation;req(x,r);req(identical(r$signature,rv$wiki_signature));wiki_relation_documents(x,r$from,r$to)})
output$wiki_edge_documents<-table_render(wiki_edge_documents,selection="single")
output$wiki_edge_context<-renderUI({x<-wiki_current();d<-wiki_edge_documents();req(nrow(d));i<-input$wiki_edge_documents_rows_selected;if(length(i)!=1||!i %in% seq_len(nrow(d)))i<-1L;id<-d$doc_id[i];row<-x$documents[match(id,x$documents$doc_id),];tagList(tags$h3(paste(id,row$title)),wiki_metadata_ui(row),tags$div(class="wiki-text",HTML(wiki_text_html(x,id))),actionButton("wiki_edge_open_document","Abrir esta ficha en el cuaderno",class="btn-quiet"))})
observeEvent(input$wiki_edge_open_document,{d<-wiki_edge_documents();i<-input$wiki_edge_documents_rows_selected;if(length(i)!=1||!i %in% seq_len(nrow(d)))i<-1L;req(nrow(d));wiki_navigate(paste0("doc:",d$doc_id[i]),modal=FALSE);removeModal()})
observeEvent(input$wiki_motion,{if(!is.null(wiki_current()))visNetwork::visPhysics(visNetwork::visNetworkProxy("wiki_graph",session=session),enabled=isTRUE(input$wiki_motion))},ignoreInit=TRUE)
output$wiki_graph_audit<-table_render(function(){d<-wiki_graph_data()$audit;names(d)<-c("Aspecto del grafo","Lectura");d})
output$download_wiki<-downloadHandler(filename="cuaderno_bibliometria_obsidian.zip",contentType="application/zip",content=function(file){s<-wiki_export_current();req(s);d<-tempfile("wiki_vault_");dir.create(d);on.exit(unlink(d,recursive=TRUE),add=TRUE);export_wiki_vault(d,s$index,s$notes,s$graph,s$view);zip::zipr(file,files=list.files(d,full.names=TRUE),include_directories=TRUE)})
output$download_wiki_notes<-downloadHandler(filename="notas_cuaderno_bibliometria.json",contentType="application/json",content=function(file)jsonlite::write_json(list(schema=1,notes=rv$wiki_notes),file,pretty=TRUE,auto_unbox=TRUE,na="null"))
observeEvent(input$wiki_notes_file,task("Restaurando copia de notas…",{
  imported<-wiki_read_notes(input$wiki_notes_file$datapath);existing<-rv$wiki_notes
  # Las notas locales prevalecen: importar nunca sobrescribe un borrador existente.
  take<-!paste(imported$scope,imported$node) %in% paste(existing$scope,existing$node)
  merged<-rbind(existing,imported[take,,drop=FALSE]);if(nrow(merged)>5000||sum(nchar(merged$text))>WIKI_LIMITS$note_total)abort_user("La suma de notas supera el límite de 5.000 páginas o cuatro millones de caracteres de la sesión. No se ha restaurado parcialmente.")
  rv$wiki_notes<-merged;rv$wiki_saved<-paste(sum(take),"notas restauradas; las notas locales existentes se han conservado. Solo se vinculan a entradas con la misma huella de columnas y valores.")
}))
observeEvent(input$help_wiki,{
  showModal(modalDialog(title="Lectura enlazada / del término al documento y a tu interpretación",size="l",easyClose=TRUE,
    tags$div(class="lesson",tags$p(class="modal-lead","Cada documento es una página con el campo de texto que elegiste. Las palabras de cada ficha son enlaces hacia las fichas de concepto, y cada ficha de concepto lista, como backlinks, todas las fichas que la mencionan. El grafo inicial no dibuja las fichas sino las palabras: muestra las 100 que aparecen en más fichas, y una línea gris conecta dos de ellas que aparecen juntas en las mismas fichas más de lo esperable por azar. Pulsar una palabra resalta, con su nombre, a sus vecinas y abre su ficha de concepto junto al grafo; pulsar una línea abre una ventana con las fichas que respaldan esa relación; pulsar un espacio vacío quita el resaltado. El buscador del paso 2 acerca la vista a una palabra y la resalta con sus vecinas; el selector «Resaltar una comunidad» deja en color las palabras de esa comunidad y atenúa las demás. Una línea discontinua con flecha conserva un enlace escrito en una nota. Para ver las fichas como puntos, cambia «Qué nodos quieres ver» a Documentos o a Documentos y conceptos. Tus notas añaden otra capa: interpretaciones y enlaces que has decidido escribir."),
      tags$section(class="lesson-section",tags$h3("Elegir qué conexión quieres estudiar"),tags$p("Con Vocabulario preparado, la aplicación usa la matriz de términos retenidos. Si lematizaste, estudiante y estudiantes pueden aparecer bajo estudiante; el texto enlazado es el preparado y debes contrastarlo con el original. Con Diccionario sobre originales, escribes conceptos y variantes por línea: salud mental | mental health. La segunda forma se reúne con la primera porque tú lo has declarado; la app no traduce, infiere sinónimos ni aprende equivalencias.")),
      tags$section(class="lesson-example",tags$h3("Un ejemplo de lectura que puedes comprobar"),tags$p("Un artículo menciona salud mental tres veces y otro una. El concepto tendrá dos documentos y cuatro apariciones. Al abrirlo, verás los dos ID; las concordancias mostrarán la expresión con sus palabras anteriores y posteriores. Selecciona una fila para leer ese documento. Encontrar la expresión en ambos no demuestra que los autores se citen, que estén de acuerdo ni que estudien exactamente lo mismo.")),
      tags$section(class="lesson-section",tags$h3("Conceptos, comunidades y vistas adicionales"),tags$p("La vista inicial Conceptos muestra, por defecto, las 100 palabras que aparecen en más fichas y solo las coapariciones estadísticamente significativas, conservando para cada palabra sus 3 más intensas; todos esos límites son visibles y modificables, y el apartado «Qué hace exactamente esta red» los explica con ejemplos. Jaccard compara conjuntos de fichas con mención; repetir la palabra no aumenta el peso. Las comunidades Louvain son exploratorias y excluyen tus notas. Cambiar los umbrales exige recalcular. El entorno local de un concepto conserva sus vecinos dentro de la red calculada; el de una ficha conserva los conceptos de su texto. Para dibujar solo una comunidad, elige «Solo una comunidad» en «Ajustes del dibujo»; para destacarla sin quitar el resto, usa «Resaltar una comunidad». Ninguna de estas opciones, ni la ficha activa, recalcula la red: solo el botón «Calcular red y comunidades» lo hace, y el grafo se sustituye por un aviso si cambias un valor del cálculo y no recalculas. En la vista adicional Documentos, los círculos son páginas y cada conexión gris declara qué conceptos comparten. En Documentos y conceptos aparecen también rombos, y cada línea gris representa una mención concreta. Puedes alternar ambas vistas para pasar de la lectura de páginas a la evidencia de sus conexiones. Para una página documental se eligen hasta los conceptos indicados, priorizando los menos extendidos; se muestran vecinos que comparten al menos el número elegido de esos conceptos. Todas las conexiones entre los nodos elegidos se conservan. La tabla declara los límites del dibujo; reducirlos no elimina relaciones del índice."),tags$p("Los enlaces escritos en notas son otra relación: se dibujan con línea discontinua y flecha desde la nota hacia su destino. Puedes mover nodos y pulsarlos para navegar. Un backlink es un enlace entrante: en una ficha de concepto, las menciones desde los abstracts; en una nota, el enlace explícito que otra nota dirige hacia ella. Una coaparición entre conceptos es una proyección de menciones compartidas, no un backlink escrito. Cambiar su posición no cambia menciones ni demuestra comunidades. Este grafo de lectura no sustituye las redes bibliométricas y sus métricas.")),
      tags$section(class="lesson-example",tags$h3("Escribir enlaces y conservar tu trabajo"),tags$p("Puedes anotar: «Comparar la definición con [[D00002]] y revisar [[salud mental]]». En la página de destino aparecerá la nota que lo enlaza: ese es el backlink. Si el destino no se reconoce, el enlace queda señalado como pendiente, sin inventar una página ni borrar tu texto. Las notas son del investigador y no forman parte de los resúmenes originales."),tags$p("El texto se guarda en la memoria de esta sesión y se envía antes de navegar mediante los enlaces del cuaderno. Descarga una copia JSON para restaurar notas y una carpeta Markdown para abrirla como bóveda en Obsidian. No hay guardado automático en disco: antes de cerrar, descarga. Una entrada distinta no hereda notas solo por tener el mismo ID; se compara la huella de columnas y valores.")),
      tags$section(class="lesson-section",tags$h3("Cómo justificarlo en un trabajo"),tags$p("Describe la fuente del vocabulario, variantes, reglas de coincidencia y filtros. En el diccionario se respetan palabras completas y espacios horizontales; no se buscan frases a través de saltos de línea ni se cuentan URLs o correos. Los conceptos solapados conservan sus conteos, pero el texto subraya primero la expresión más larga. Usa concordancias y originales para sostener una lectura: un grafo vistoso no es una validación semántica.")),
      tags$p(tags$a(href="https://help.obsidian.md/plugins/backlinks",target="_blank",rel="noopener","Obsidian / enlaces y backlinks"))),footer=modalButton("Volver al cuaderno")))
})
observeEvent(input$code_wiki,{
  paths<-c(app_file("server","wiki.R"))
  functions<-c("wiki_field_profile","build_wiki_index","wiki_attach_metadata","wiki_local_graph","wiki_document_graph","wiki_document_network","wiki_overview_graph","wiki_concept_network","wiki_concept_graph","wiki_relation_documents","wiki_kwic","wiki_note_links","export_wiki_vault")
  showModal(modalDialog(title="Código R / índice, concordancias y enlaces",size="l",easyClose=TRUE,
    tags$p("Este es el código real del cuaderno. La matriz guarda apariciones; las notas y sus enlaces se mantienen en una capa independiente. El ZIP de entrega incluye estos módulos y el script adicional de reproducción si has construido un índice vigente."),
    tags$pre(class="code-view",paste(c(paste("# Parámetros del índice",r_literal(if(is.null(wiki_current()))NULL else wiki_current()$params)),paste("# Parámetros de la vista",r_literal(wiki_graph_settings())),vapply(functions,function(nm)paste(nm,"<-",paste(deparse(get(nm,asNamespace("bibliolab")),width.cutoff=120),collapse="\n")),""),vapply(paths,function(f)paste(c(paste("# ARCHIVO",basename(f)),readLines(f,encoding="UTF-8")),collapse="\n"),"")),collapse="\n\n")),footer=modalButton("Cerrar código")))
})
