# Lecturas breves basadas en la ejecución vigente, no inferencias automáticas.
caption <- function(text) tags$p(class="chart-caption",text)
output$metadata_separator_reading<-renderUI({req(rv$raw)
  labels<-c(";"="punto y coma", "|"="barra vertical", ","="coma",none="un elemento por celda")
  tagList(lapply(c("authors","keywords"),function(field){x<-mapped(rv$raw,settings()$mapping,field);selected<-input[[paste0(field,"_sep")]] %||% "auto";sep<-metadata_rule(x,selected)
    hint(paste(if(field=="authors")"Autores:" else "Palabras clave:",sum(nzchar(x)),"filas con contenido; regla:",labels[[sep]],".",if(selected=="auto")metadata_detect(x)$note else "Regla elegida por ti. Comprueba cómo queda en la tabla."))}),hint("El separador es el signo que divide varios elementos dentro de una celda, distinto del separador de columnas del CSV. No necesitas abrir el archivo: estos ejemplos muestran el valor original y el reparto que usará la app. Si una celda dice Sánchez-Franco, M. J.; García, A., se reconocen dos autores y se conservan las comas de sus nombres."))
})
output$metadata_separator_preview<-table_render(function(){req(rv$raw);d<-lapply(c("authors","keywords"),function(field){x<-metadata_preview(rv$raw,settings()$mapping,field,input[[paste0(field,"_sep")]] %||% "auto");cbind(Campo=rep(if(field=="authors")"Autores" else "Palabras clave",nrow(x)),x)});do.call(rbind,d)})
output$model_dimensions<-renderUI({p<-current();m<-rv$corpus$counts;if(is.null(m))return(hint("No hay vocabulario para LDA. Reduce presencia mínima o revisa palabras vacías en 02."));hint(paste("LDA recibirá",nrow(m),"unidades ×",ncol(m),"términos /",sum(m),"tokens. Usa conteos, no pesos TF-IDF. La selección del vocabulario sí puede haber usado TF-IDF o BM25."))})
output$startup_environment<-renderUI({d<-biblio_check_dependencies();hint(paste("Sesión",BIBLIO_VERSION,"/ R",getRversion(),"/",sum(d$instalado),"de",nrow(d),"paquetes opcionales de análisis cargables.",if(all(d$instalado))"Todas las técnicas están disponibles. Los modelos de idioma se descargan cuando eliges usarlos en 02." else paste0("Pendientes: ",paste0(d$paquete[!d$instalado]," (",d$habilita[!d$instalado],")",collapse="; "),". Instálalos con install.packages(); el resto de la aplicación funciona sin ellos.")))})
output$keywords_availability<-renderUI({p<-current();caption(keyword_availability(p))})
output$keywords_fields<-table_render(function(){d<-keyword_field_audit(rv$raw,current());names(d)<-c("Campo","Origen / comprobar definición","Documentos con datos en el archivo","Documentos con datos tras preparar","Campo asignado");d})
output$keywords_result<-renderUI({p<-current();if(!nrow(rv$bib$keywords))return(tagList(hint("No hay palabras clave declaradas que se puedan representar. La tabla anterior distingue un campo vacío en el archivo de un campo con datos perdido al filtrar. Si hay otra columna con contenido, comprueba su origen y asígnala en Preparación; Author Keywords y Keywords Plus tienen orígenes diferentes. Si todas están vacías, vuelve a exportar los metadatos incluyendo palabras clave."),actionButton("prepare_from_keywords","Revisar correspondencia de campos en 02",class="btn-next")))
  tagList(rank_controls("keywords"),tags$div(class="rank-scroll",plotOutput("keywords_plot",height="auto")),uiOutput("keywords_caption"),result_tools("keywords"))})
observeEvent(input$prepare_from_keywords,updateTabsetPanel(session,"steps",selected="prepare"))
for(key in c("sources","authors","keywords")) local({k<-key
  output[[paste0(k,"_caption")]]<-renderUI({p<-current();d<-rv$bib[[k]];if(!nrow(d))return(NULL)
    metric<-if(k=="authors")input$authors_order %||% "documentos" else "documentos"
    view<-rank_slice(d,input[[paste0(k,"_n")]] %||% 25,input[[paste0(k,"_page")]] %||% 1,metric)
    lead<-d[order(-d[[metric]],d$elemento,na.last=TRUE),,drop=FALSE][1,]
    caption(paste("Página",view$page,"de",view$pages,"/",nrow(view$data),"filas mostradas /",view$total,"seleccionadas de",nrow(d),"disponibles.",
      "El primer registro según este orden es",if(k=="sources")display_label(lead$elemento,"source") else lead$elemento,"con",if(is.finite(lead[[metric]]))lead[[metric]] else "dato ausente",switch(metric,documentos="documentos.",h_corpus="de índice h del corpus.",citas_suma="citas válidas."),
      if(k=="authors")"Un artículo multiautor cuenta una vez para cada firmante. Índice h: h publicaciones de esta muestra con al menos h citas cada una. No representa la carrera completa ni compara calidad." else if(k=="sources")"La selección describe las fuentes de esta búsqueda. Una fuente frecuente no demuestra mayor calidad ni representatividad del campo." else "Son palabras declaradas en los metadatos, independientes de las palabras extraídas del resumen."))
  })
})
output$annual_caption<-renderUI({current();d<-rv$bib$annual;if(!nrow(d))return(NULL);i<-which.max(d$documentos);caption(paste("El mayor número de registros aparece en",d$ano[i],":",d$documentos[i],"documentos. El gráfico describe la búsqueda importada. Comprueba cobertura y fecha de extracción antes de interpretar aumentos como crecimiento del campo."))})
output$pca_quadrant_reading<-renderUI({f<-pca_current();if(is.null(f))return(NULL);d<-ordination_quadrant(pca_plane(f,"terms",pca_axes()),input$pca_quadrant %||% "all");caption(paste(nrow(d),"variables en la selección. Las etiquetas priorizan contribución y separación espacial; todos los puntos conservan información al pasar el cursor. Para leer más palabras, selecciona un cuadrante o abre Ampliar variables. El signo de cada eje es convencional. Interpreta relaciones y cos², no el signo como valoración positiva o negativa."))})
output$guide_tokens<-renderUI({current();d<-token_view_base();if(!nrow(d))return(NULL)
  metric<-input$token_rank_metric %||% "frecuencia";choices<-term_metric_choices();metric<-if(metric %in% unname(choices)&&metric %in% names(d))metric else "frecuencia"
  label<-names(choices)[match(metric,choices)];top<-head(d$termino[order(-d[[metric]],-d$documentos,d$termino,na.last=TRUE)],3);zeros<-sum(d[[metric]]==0,na.rm=TRUE)
  caution<-if(metric=="documentos")"Que una palabra aparezca en muchos documentos no la hace relevante: puede ser lenguaje genérico o formar parte de tu ecuación de búsqueda; comprueba esa posibilidad." else if(metric=="frecuencia")"Una frecuencia alta puede proceder de pocos textos: compara también la presencia en documentos." else "Un peso alto puede proceder de pocos textos y no demuestra relevancia para la pregunta; compara su presencia y abre sus documentos."
  caption(paste0("Con el indicador «",label,"», encabezan la lista ",paste(top,collapse=", "),". ",if(zeros>0)paste0(zeros," de ",nrow(d)," términos valen cero en este indicador; se ordenan entre sí por presencia y después por nombre. ") else "",caution," La tabla muestra media, desviación típica, mediana y MAD."))})
output$vocab_order_note<-renderUI({t<-rv$corpus$terms;if(is.null(t)||!nrow(t)||is.null(rv$prepared))return(hint("Cambiar el orden solo importa cuando hay más términos que cumplen tus umbrales que el máximo de términos."))
  limit<-sum(t$motivo_exclusion=="Límite de vocabulario");eligible<-sum(t$incluido)+limit;maxn<-suppressWarnings(as.integer(input$max_terms %||% 1000L))
  hint(if(limit==0)paste0("En la última preparación, los ",eligible," términos que superaron los umbrales cabían en el máximo; cambiar el orden no modifica el vocabulario incluido. El orden solo decide cuando hay más términos elegibles que el máximo.") else paste0("En la última preparación, ",eligible," términos superaron los umbrales y el máximo dejó fuera ",limit,": el orden elegido decide cuáles de ellos entran."))})
for(key in c("citations","bigrams","lda","ca","density","pca"))local({k<-key
  output[[paste0("guide_",k)]]<-renderUI({if(is.null(rv$prepared)||stale())return(NULL)
    if(k=="lda"){f<-lda_current();if(is.null(f))return(NULL);return(caption(lda_result_reading(f)))}
    if(k=="ca"){f<-ca_current();if(is.null(f))return(NULL);return(caption(ordination_reading(f,"Correspondencias")))}
    if(k=="pca"){f<-pca_current();if(is.null(f))return(NULL);return(caption(ordination_reading(f,"ACP",pca_axes())))}
    if(k=="density"){f<-density_current();if(is.null(f))return(NULL);return(caption(paste(sum(f$summary$grupo>0),"grupos y",sum(f$assignments$grupo==0),"documentos sin asignar.",figure_explanation("density"),"Evalúa estabilidad antes de describir temas.")))}
    if(k=="bigrams"){d<-gram_data();if(!nrow(d))return(NULL);return(caption(paste("El primer resultado según el indicador elegido es",d$expresion[1],". La adyacencia muestra una expresión literal, no una relación causal. Contrasta sus contextos y la dispersión de pesos en la tabla.")))}
    if(k=="citations")return(caption("El índice h es el último rango con al menos ese número de citas. Citas ausentes se excluyen; con cobertura parcial, el valor es un límite inferior del h que tendría este corpus con todas sus citas. Edad, disciplina y fuente condicionan la comparación."))
    NULL
  })
})
