spline_state<-reactiveValues(fit=NULL,assignments=NULL,params=NULL,settings=NULL,error=NULL)
spline_settings<-reactive(list(group=as.integer(input$density_spline_group %||% -1),k=input$density_spline_k %||% 5L))
spline_current<-reactive({f<-density_current();if(is.null(f)||is.null(spline_state$fit)||!identical(f$assignments,spline_state$assignments)||!identical(f$params,spline_state$params)||!identical(spline_settings(),spline_state$settings)) return(NULL);spline_state$fit})
output$temporal_controls<-renderUI(model_parameter_guidance({
  f<-density_current();if(is.null(f)||!identical(input$density_time_view,"spline")) return(NULL)
  groups<-f$summary$grupo[f$summary$grupo>0]
  if(!length(groups)) return(hint("No hay grupos asignados para ajustar. La evolución de sin asignar sigue disponible en puntos y barras."))
  tagList(tags$div(class="row control-row",column(5,selectInput("density_spline_group","Grupo cuya proporción quieres estudiar",setNames(groups,paste("Grupo",groups)))),column(4,numericInput("density_spline_k","Complejidad máxima / funciones base",5,3,8)),column(3,actionButton("run_density_spline","Ajustar spline",class="btn-primary run-analysis"))),
    hint("La penalización evita seguir cada oscilación de los puntos. Empieza con 5 funciones base y contrasta otra complejidad. Se exigen al menos 10 años observados y cinco documentos del modelo por año. Si faltan años, la curva se interrumpe en los huecos. Estos límites no garantizan validez estadística."))
}))
observeEvent(input$run_density_spline,{
  spline_state$fit<-NULL;spline_state$error<-NULL
  task("Ajustando la proporción anual con una spline penalizada…",{
    f<-density_current();if(is.null(f)) abort_user("Calcula primero UMAP/HDBSCAN con los parámetros actuales.")
    s<-spline_settings()
    fit<-tryCatch(density_spline(f,s$group,s$k),error=function(e){spline_state$error<-conditionMessage(e);stop(e)})
    spline_state$fit<-fit;spline_state$assignments<-f$assignments;spline_state$params<-f$params;spline_state$settings<-s
  })
})
output$temporal_reading<-renderUI({f<-density_current();if(is.null(f)) return(NULL)
  view<-input$density_time_view %||% "stacked"
  tagList(if(view=="spline" && !is.null(spline_current())) tags$p(class="chart-caption",spline_current()$note),tags$p(class="chart-caption",switch(view,
    stacked="Cada barra representa un año y su altura es el número de documentos del modelo con ese año. Los colores separan grupos fijos; gris conserva los documentos sin asignar. Más documentos de un grupo pueden reflejar que ese año se recuperaron más publicaciones en total.",
    proportions="Para cada año dividimos documentos del grupo entre todos los documentos del modelo con año válido, incluidos sin asignar. Los puntos permiten comparar su peso relativo; las líneas solo conectan años consecutivos observados. Un cambio describe este corpus y clasificación, no todo el campo.",
    spline="Los puntos son proporciones observadas y la curva resume una tendencia suave de un grupo frente al resto. Ajustar no cambia grupos ni palabras. La banda es puntual y condicional a los supuestos; consulta diagnósticos y contraste de cobertura antes de interpretarla.")),
    tags$p("Aquí hay años de publicación: puedes estudiar evolución anual. La estacionalidad es un patrón que se repite dentro de ciclos regulares, como meses o trimestres. Los años agregados no permiten identificar estaciones ni ciclos mensuales. Esta pantalla no ejecuta una prueba de estacionalidad."))
})
density_time_graph<-reactive({f<-density_current();validate(need(!is.null(f),"Calcula los grupos vigentes antes de estudiar años."));view<-input$density_time_view %||% "stacked"
  if(view=="stacked") return(density_stacked_graph())
  if(view=="spline") validate(need(!is.null(spline_current()),spline_state$error %||% "Selecciona un grupo y pulsa Ajustar spline; si no hay cobertura suficiente, utiliza proporciones observadas."))
  density_temporal_figure(f,view,spline_current())
})
output$density_time_table<-table_render(function(){f<-density_current();validate(need(!is.null(f),"Calcula UMAP/HDBSCAN."));d<-density_yearly(f);d$porcentaje_anual<-100*d$proporcion;d[c("ano","grupo","documentos","total","porcentaje_anual")]})
output$spline_diagnostics<-table_render(function(){f<-spline_current();validate(need(!is.null(f),"Los diagnósticos aparecen después de un ajuste válido."));f$diagnostics})
output$temporal_word_controls<-renderUI(model_parameter_guidance({f<-density_current();if(is.null(f)) return(NULL);g<-f$summary$grupo[f$summary$grupo>0]
  if(!length(g)) return(hint("No se detectaron grupos temáticos para describir su vocabulario por año."))
  tagList(selectInput("density_word_group","Grupo de documentos que quieres leer por años",setNames(g,paste("Grupo",g))),
    hint("Se muestran cinco términos con más apariciones de cada año del grupo, resolviendo empates por nombre. La proporción se refiere a tokens retenidos de ese grupo/año. Los grupos permanecen fijos; esta tabla no estima un nuevo tema dinámico."))
}))
year_term_data<-reactive({f<-density_current();validate(need(!is.null(f),"Calcula UMAP/HDBSCAN."));group<-as.integer(input$density_word_group %||% f$summary$grupo[f$summary$grupo>0][1]);if(is.na(group)) return(data.frame());density_year_terms(rv$corpus,rv$prepared,f,group)})
output$density_year_terms<-table_render(function(){d<-year_term_data();if(!nrow(d)) return(d);d<-do.call(rbind,lapply(split(d,d$ano),head,5));d$porcentaje_tokens<-100*d$proporcion_tokens;d[setdiff(names(d),"proporcion_tokens")]})
output$lda_yearly_table<-table_render(function(){f<-lda_current();validate(need(!is.null(f),"Calcula LDA con parámetros vigentes."));d<-lda_yearly(f,current());d$porcentaje_tematico_medio<-100*d$proporcion_media;d[c("ano","tema","documentos","porcentaje_tematico_medio")]})
lda_time_graph<-reactive({f<-lda_current();validate(need(!is.null(f),"Calcula LDA con parámetros vigentes."));validate(need(nrow(lda_yearly(f,current()))>0,"Asigna años para estudiar la prevalencia de temas fijos."));lda_temporal_figure(f,current(),spline=isTRUE(input$lda_time_spline))})
output$lda_time_plot<-renderPlot(lda_time_graph(),res=96)

density_export_current<-reactive({f<-density_current();if(!is.null(f) && !is.null(spline_current())) f$temporal_spline<-spline_current();f})
