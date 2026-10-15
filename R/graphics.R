# Gramatica visual comun; los modelos entregan numeros, estas funciones dibujan.
swiss_number <- function(x) ifelse(is.finite(x) & x>0 & x<1e-4,
  format(x,digits=3,scientific=TRUE,trim=TRUE),formatC(x,format="f",digits=4))
swiss_colours <- function(n = 12L) rep(c("#c7281e", "#245579", "#2d7164", "#9c6d13", "#66518a", "#aa4e65",
  "#333333", "#4b7c95", "#687944", "#b56835", "#817487", "#7b4637"), length.out = n)
swiss_theme <- function(base_size = 12) ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), panel.grid.major = ggplot2::element_line(colour = "#e6e6e6", linewidth = .3),
    plot.title.position = "plot", plot.title = ggplot2::element_text(face = "bold", size = 17, margin = ggplot2::margin(b = 8)),
    plot.subtitle = ggplot2::element_text(size = 11, colour = "#555555", margin = ggplot2::margin(b = 16)),
    axis.title = ggplot2::element_text(size = 12), axis.title.x=ggplot2::element_text(margin=ggplot2::margin(t=18)), axis.title.y=ggplot2::element_text(margin=ggplot2::margin(r=15)), legend.box.margin=ggplot2::margin(t=18), legend.spacing.y=grid::unit(8,"pt"), panel.spacing=grid::unit(22,"pt"), axis.text = ggplot2::element_text(colour = "#333333"),
    axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5),axis.text.y=ggplot2::element_text(angle=0),
    strip.text = ggplot2::element_text(face = "bold", size = 12), legend.position = "bottom", legend.title = ggplot2::element_text(size = 11),
    plot.margin = ggplot2::margin(18, 28, 18, 18), plot.background = ggplot2::element_rect(fill = "white", colour = NA))

swiss_plotly <- function(chart, x_title = "", y_title = "", equal_axes = FALSE, ...) {
  plotly::config(plotly::layout(chart, font = list(family = "Arial, Helvetica, sans-serif", size = 14, color = "#161616"),
    paper_bgcolor = "white", plot_bgcolor = "white", hoverlabel = list(bgcolor = "white", font = list(color = "#161616", size = 13)),
    xaxis = list(tickangle=90,title = list(text = x_title, standoff = 24), automargin = TRUE, gridcolor = "#e6e6e6", zerolinecolor = "#555555"),
    yaxis = list(title = list(text = y_title, standoff = 24), tickangle=0, automargin = TRUE, gridcolor = "#e6e6e6", zerolinecolor = "#555555",
      scaleanchor = if (equal_axes) "x" else NULL, scaleratio = if (equal_axes) 1 else NULL),
    legend = list(orientation="v",y=1,x=1.03), margin=list(l=95,r=130,t=35,b=100), ...), displaylogo = FALSE)
}

ordination_figure <- function(d, dimensions, title, label_field = "termino", circle = FALSE, max_labels = 12L) {
  axes<-attr(d,"axes") %||% c(1L,2L)
  xlab <- sprintf("Eje %d / %.1f%%",axes[1], dimensions$porcentaje[axes[1]]); ylab <- sprintf("Eje %d / %.1f%%",axes[2], dimensions$porcentaje[axes[2]])
  top <- quadrant_labels(d,max_labels)
  g <- ggplot2::ggplot(d, ggplot2::aes(eje_1, eje_2)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = .4, colour = "#777777") + ggplot2::geom_vline(xintercept = 0, linewidth = .4, colour = "#777777")
  if (circle) {
    theta <- seq(0, 2*pi, length.out = 200); ring <- data.frame(x = cos(theta), y = sin(theta))
    g <- g + ggplot2::geom_path(data = ring, ggplot2::aes(x,y), inherit.aes = FALSE, colour = "#bbbbbb", linewidth = .5) +
      ggplot2::geom_segment(data = d[top, ], ggplot2::aes(x = 0, y = 0, xend = eje_1, yend = eje_2), colour = "#777777", linewidth = .45, arrow = grid::arrow(length = grid::unit(2, "mm")))
  }
  size <- if ("masa" %in% names(d)) 3 + 4*sqrt(d$masa/max(d$masa)) else rep(3, nrow(d))
  g + ggplot2::geom_point(ggplot2::aes(colour = cos2_plano), size = size, alpha = .85) +
    ggplot2::scale_colour_gradient(low = "#b7b7b7", high = "#c7281e", limits = c(0,1)) +
    ggrepel::geom_text_repel(data = d[top, ], ggplot2::aes(label = .data[[label_field]]), size = 3.5, colour = "#222222", seed = 2026,
      max.overlaps = Inf, max.time = 2, max.iter = 20000, force = 2, point.padding = .4, min.segment.length = 0, box.padding = .6, segment.colour = "#aaaaaa") +
    ggplot2::coord_equal() + ggplot2::labs(title = title, subtitle = if (circle) "Correlaciones de t\u00e9rminos con componentes / flechas principales" else "Coordenadas calculadas por el modelo / etiquetas de mayor contribuci\u00f3n",
      x = xlab, y = ylab, colour = "Cos\u00b2 del plano") + swiss_theme()
}

ordination_label_positions <- function(d,top,label_field,canvas=c(1000,600),circle=FALSE) {
  xr<-range(c(d$eje_1,if(circle)c(-1,1)),finite=TRUE);yr<-range(c(d$eje_2,if(circle)c(-1,1)),finite=TRUE)
  span<-pmax(c(diff(xr),diff(yr)),1e-8);xr<-xr+c(-.08,.08)*span[1];yr<-yr+c(-.08,.08)*span[2]
  unit<-max(diff(xr)/canvas[1],diff(yr)/canvas[2]);xr<-mean(xr)+c(-.5,.5)*unit*canvas[1];yr<-mean(yr)+c(-.5,.5)*unit*canvas[2]
  # Se reservan cajas en pixeles, sin cambiar las coordenadas de ningun punto.
  px<-(d$eje_1-xr[1])/diff(xr)*canvas[1];py<-(yr[2]-d$eje_2)/diff(yr)*canvas[2]
  boxes<-list();out<-list();offsets<-as.matrix(expand.grid(x=c(0,-1,1),y=c(-1,1,0)));offsets<-offsets[rowSums(abs(offsets))>0,,drop=FALSE]
  for(i in top){label<-as.character(d[[label_field]][i]);w<-min(canvas[1]-.5,7*nchar(label)+10);h<-20
    found<-FALSE
    for(radius in c(20,42,66,90)) {for(k in seq_len(nrow(offsets))){dx<-offsets[k,1]*(w/2+radius);dy<-offsets[k,2]*radius
      box<-c(px[i]+dx-w/2,py[i]+dy-h/2,px[i]+dx+w/2,py[i]+dy+h/2)
      outside<-box[1]<0||box[2]<0||box[3]>canvas[1]||box[4]>canvas[2]
      overlap<-length(boxes)&&any(vapply(boxes,function(b)box[1]<b[3]+4&&box[3]>b[1]-4&&box[2]<b[4]+4&&box[4]>b[2]-4,TRUE))
      if(outside||overlap)next
      boxes[[length(boxes)+1L]]<-box;out[[length(out)+1L]]<-list(i=i,dx=dx,dy=dy,box=box);found<-TRUE;break
    };if(found)break}
  }
  attr(out,"xrange")<-xr;attr(out,"yrange")<-yr;out
}
ordination_widget <- function(d, dimensions, label_field = "termino", focus = "", circle = FALSE, max_labels = 16L,label_canvas=NULL) {
  axes<-attr(d,"axes") %||% c(1L,2L)
  top <- if(is.null(label_canvas))quadrant_labels(d,max_labels) else head(order(-(d$contribucion_eje_1+d$contribucion_eje_2)),as.integer(max_labels))
  if (focus %in% d[[label_field]]) top <- match(focus, d[[label_field]])
  d$label <- ifelse(seq_len(nrow(d)) %in% top, d[[label_field]], "")
  d$hover <- paste0(escape_html(d[[label_field]]), if ("title" %in% names(d)) paste0("<br>", escape_html(substr(d$title,1,150))) else "",
    "<br>Cos\u00b2 del plano: ", round(d$cos2_plano,3), "<br>Contribuci\u00f3n eje ",axes[1],": ", round(d$contribucion_eje_1,2), "%<br>Contribuci\u00f3n eje ",axes[2],": ", round(d$contribucion_eje_2,2), "%")
  chart <- plotly::plot_ly()
  if (circle) {
    t <- seq(0,2*pi,length.out=200)
    chart <- plotly::add_trace(chart, x = cos(t), y = sin(t), type = "scatter", mode = "lines", line = list(color = "#bbbbbb", width = 1), hoverinfo = "skip", showlegend = FALSE)
    for (i in top) chart <- plotly::add_trace(chart, x = c(0,d$eje_1[i]), y = c(0,d$eje_2[i]), type = "scatter", mode = "lines",
      line = list(color = "#aaaaaa", width = 1), hoverinfo = "skip", showlegend = FALSE)
  }
  sizes <- if ("masa" %in% names(d)) 8 + 12*sqrt(d$masa/max(d$masa)) else rep(8,nrow(d))
  chart <- plotly::add_trace(chart, data = d, x = ~eje_1, y = ~eje_2, type = "scatter", mode = if(is.null(label_canvas))"markers+text" else "markers", text = ~label,
    textposition = if(is.null(label_canvas))"top center" else NULL, textfont = if(is.null(label_canvas))list(size = 13) else NULL, hovertext = ~hover, hoverinfo = "text", showlegend = FALSE,cliponaxis=FALSE,
    marker = list(size = sizes, opacity = .85, color = d$cos2_plano, colorscale = list(c(0,"#b7b7b7"),c(1,"#c7281e")), cmin = 0, cmax = 1,
      showscale = TRUE, colorbar = list(title = "Cos\u00b2", thickness = 14)))
  arrows <- if(circle) lapply(top,function(i) list(x=d$eje_1[i],y=d$eje_2[i],ax=0,ay=0,axref="x",ayref="y",xref="x",yref="y",text="",showarrow=TRUE,arrowhead=2,arrowsize=.8,arrowwidth=1,arrowcolor="#888888")) else list()
  if(!is.null(label_canvas)) {
    placed<-ordination_label_positions(d,top,label_field,label_canvas,circle)
    labels<-lapply(placed,function(p)list(x=d$eje_1[p$i],y=d$eje_2[p$i],xref="x",yref="y",ax=p$dx,ay=p$dy,axref="pixel",ayref="pixel",text=escape_html(d[[label_field]][p$i]),showarrow=TRUE,arrowhead=0,arrowwidth=.6,arrowcolor="#999999",font=list(size=12,color="#222222"),bgcolor="rgba(255,255,255,0.85)",borderpad=1,xanchor="center",yanchor="middle"))
    arrows<-c(arrows,labels)
  }
  chart<-swiss_plotly(chart, sprintf("Eje %d / %.1f%%",axes[1],dimensions$porcentaje[axes[1]]), sprintf("Eje %d / %.1f%%",axes[2],dimensions$porcentaje[axes[2]]), equal_axes = TRUE, annotations=arrows)
  plotly::layout(chart,autosize=TRUE,xaxis=list(constrain="range",range=if(!is.null(label_canvas))attr(placed,"xrange") else NULL),yaxis=list(constrain="range",range=if(!is.null(label_canvas))attr(placed,"yrange") else NULL),margin=list(l=85,r=80,t=35,b=80))
}

variance_figure <- function(dimensions, title = "Informaci\u00f3n por eje", measure = "porcentaje") {
  d <- head(dimensions, 12); d$eje_label <- factor(paste("Eje", d$eje), levels = paste("Eje", d$eje))
  ggplot2::ggplot(d, ggplot2::aes(eje_label, .data[[measure]])) + ggplot2::geom_col(fill = "#333333", width = .62) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", .data[[measure]])), vjust = -.5, size = 3.4) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0,.13))) +
    ggplot2::labs(x = NULL, y = "Informaci\u00f3n explicada (%)", title = title, subtitle = "Hasta 12 ejes / valores completos en la tabla y el ZIP") + swiss_theme() +
    ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
}

jsd_figure <- function(fit, top_n = 20L) {
  d <- head(fit$terms[fit$terms$aporte_bits > 0, ], top_n)
  if (!nrow(d)) return(ggplot2::ggplot() + ggplot2::annotate("text", x = 0, y = 0, label = "Las distribuciones A y B son iguales.\nJSD = 0 bits: no hay diferencias l\u00e9xicas que descomponer.", size = 5) + ggplot2::theme_void() + ggplot2::labs(title = "Resultado / distribuciones coincidentes"))
  d$termino <- factor(d$termino, levels = rev(d$termino))
  ggplot2::ggplot(d, ggplot2::aes(shift_pct, termino, fill = direccion)) + ggplot2::geom_vline(xintercept = 0, colour = "#333333", linewidth = .5) +
    ggplot2::geom_col(width = .63) + ggplot2::scale_fill_manual(values = c("Mayor en A" = "#245579", "Mayor en B" = "#c7281e", Igual = "#999999")) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(abs(x),"%")) +
    ggplot2::labs(x = "Mayor en A  /  magnitud = % de la JSD total  /  Mayor en B", y = NULL, fill = NULL,
      title = "Jensen-Shannon divergence shifts", subtitle = sprintf("JSD %s bits / %d t\u00e9rminos explican %.1f%% de la divergencia", swiss_number(fit$jsd), nrow(d), sum(d$aporte_pct))) + swiss_theme()
}

jsd_cumulative_figure <- function(fit) {
  ggplot2::ggplot(fit$terms, ggplot2::aes(posicion, aporte_acumulado_pct)) + ggplot2::geom_line(colour = "#333333", linewidth = .8) +
    ggplot2::geom_hline(yintercept = 80, linetype = "dashed", colour = "#c7281e", linewidth = .5) +
    ggplot2::scale_y_continuous(breaks = c(0,25,50,75,100)) + ggplot2::coord_cartesian(ylim=c(0,100)) + ggplot2::labs(x = "T\u00e9rminos ordenados por contribuci\u00f3n", y = "JSD explicada acumulada (%)",
      title = "Cu\u00e1ntas palabras explican la diferencia", subtitle = "La l\u00ednea del 80% es una referencia visual; no un umbral de significaci\u00f3n") + swiss_theme()
}

jsd_matrix_figure <- function(fit) {
  d <- fit$matrix; labels <- unique(d$grupo_A)
  short <- function(x) if(length(labels)>12) sprintf("%02d",match(x,labels)) else ifelse(nchar(x)>24,paste0(substr(x,1,21),"\u2026"),x)
  g <- ggplot2::ggplot(d,ggplot2::aes(factor(grupo_A,levels=labels),factor(grupo_B,levels=rev(labels)),fill=jsd_bits)) +
    ggplot2::geom_tile(colour="white",linewidth=.4) + ggplot2::scale_fill_gradient(low="#f4f4f2",high="#c7281e",limits=c(0,1)) +
    ggplot2::scale_x_discrete(labels=short) + ggplot2::scale_y_discrete(labels=short) + ggplot2::coord_equal() +
    ggplot2::labs(x=NULL,y=NULL,fill="JSD / bits",title="Diferencias entre categor\u00edas",subtitle=if(length(labels)>12) "C\u00f3digos seg\u00fan orden de la tabla de cobertura / diagonal = 0" else "Mismo vocabulario y normalizaci\u00f3n / diagonal = 0") + swiss_theme() +
    ggplot2::theme(axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5),panel.grid=ggplot2::element_blank())
  if(length(labels)<=8) g <- g + ggplot2::geom_text(ggplot2::aes(label=sprintf("%.3f",jsd_bits),colour=jsd_bits>.5),size=3.5,show.legend=FALSE) + ggplot2::scale_colour_manual(values=c(`TRUE`="white",`FALSE`="#333333"))
  g
}

jsd_time_figure <- function(fit) {
  d <- fit$temporal
  if(!nrow(d)) abort_user("La evoluci\u00f3n JSD necesita una comparaci\u00f3n temporal con al menos dos a\u00f1os observados.")
  d$pair <- paste(d$ano_A,d$ano_B,sep=" / "); d$pair <- factor(d$pair,levels=d$pair)
  ggplot2::ggplot(d,ggplot2::aes(pair,jsd_bits)) + ggplot2::geom_segment(ggplot2::aes(xend=pair,yend=0),colour="#999999",linewidth=.5) +
    ggplot2::geom_point(ggplot2::aes(shape=consecutivo),colour="#c7281e",size=if(nrow(d)>60)1.5 else 3) + ggplot2::scale_x_discrete(breaks=levels(d$pair)[unique(round(seq(1,nrow(d),length.out=min(12,nrow(d)))))] ) +
    ggplot2::scale_shape_manual(values=c(`TRUE`=16,`FALSE`=1),labels=c(`TRUE`="A\u00f1os consecutivos",`FALSE`="Salto entre a\u00f1os observados")) +
    ggplot2::scale_y_continuous(limits=c(0,1)) + ggplot2::labs(x="Comparaciones entre a\u00f1os observados",y="JSD / bits",shape=NULL,title="Diferencias en el vocabulario de a\u00f1os sucesivos",subtitle="No se inventan distribuciones para a\u00f1os sin datos") + swiss_theme() + ggplot2::theme(axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5))
}

graphics_script <- function() paste(c(
  "# Ejecuta primero reproducir_analisis.R. Las figuras se construyen con sus outputs.",
  script_preamble(),
  "r <- readRDS('resultados_reproducidos.rds')", "figuras <- list()",
  "if(!is.null(r$ca)) { figuras$ca_plano <- ordination_figure(r$ca$terms,r$ca$dimensions,'Correspondencias / perfiles l\u00e9xicos'); figuras$ca_inercia <- variance_figure(r$ca$dimensions,'Correspondencias / inercia') }",
  "m <- jsonlite::read_json('parametros.json',simplifyVector=TRUE)", "if(!is.null(r$acp)) { axes <- m$vista_acp$axes %||% c(1L,2L); figuras$acp_documentos <- ordination_figure(pca_plane(r$acp,'documents',axes),r$acp$dimensions,'ACP / documentos',label_field='doc_id'); figuras$acp_variables <- ordination_figure(pca_plane(r$acp,'terms',axes),r$acp$dimensions,'ACP / variables',circle=TRUE); figuras$acp_varianza <- variance_figure(r$acp$dimensions,'ACP / varianza') }",
  "if(!is.null(r$comparacion)) { figuras$jsd_shifts <- jsd_figure(r$comparacion); figuras$jsd_acumulada <- jsd_cumulative_figure(r$comparacion); figuras$jsd_matriz <- jsd_matrix_figure(r$comparacion); if(nrow(r$comparacion$temporal)) figuras$jsd_evolucion <- jsd_time_figure(r$comparacion) }",
  "m <- jsonlite::read_json('parametros.json',simplifyVector=TRUE); v <- m$vista_terminos",
  "if(is.list(v) && all(c('metric','status','n') %in% names(v))) { d <- term_view_data(r$corpus$terms,v$metric,v$status,v$n,compare_states=isTRUE(v$compare_states)); if(nrow(d)) figuras$terminos_comparacion <- term_comparison_figure(d,if(r$preparado$config$split_sentences) 'frase' else 'documento',v$tfidf_metric %||% 'tfidf_medio') }",
  "if(!is.null(r$densidad) && nrow(density_yearly(r$densidad))) figuras$grupos_proporciones_anuales <- density_temporal_figure(r$densidad)",
  "if(!is.null(r$densidad$temporal_spline)) figuras$grupos_spline <- density_temporal_figure(r$densidad,'spline',r$densidad$temporal_spline)",
  "if(!is.null(r$lda) && nrow(lda_yearly(r$lda,r$preparado))) figuras$lda_prevalencia_anual <- lda_temporal_figure(r$lda,r$preparado,spline=isTRUE(m$vista_lda_temporal$spline))",
  "if(!is.null(r$lda) && !is.null(m$vista_lda_documentos)) { d <- lda_document_rows(r$lda,m$vista_lda_documentos$ids %||% character()); if(nrow(d)) figuras$lda_composicion_elegida <- lda_composition_figure(r$lda,r$preparado,d) }",
  "dir.create('graficos_reconstruidos',showWarnings=FALSE)",
  "for(nm in names(figuras)) {",
  "  ggplot2::ggsave(file.path('graficos_reconstruidos',paste0(nm,'.png')),figuras[[nm]],width=11,height=7,dpi=180,bg='white')",
  "  ggplot2::ggsave(file.path('graficos_reconstruidos',paste0(nm,'.pdf')),figuras[[nm]],width=11,height=7,device=if(capabilities('cairo')) grDevices::cairo_pdf else grDevices::pdf,bg='white')",
  "}", ""),collapse="\n")

term_metric_choices <- function() c("M\u00e1s frecuentes"="frecuencia", "M\u00e1s presentes en documentos"="documentos",
  "TF-IDF / media global"="tfidf_medio", "TF-IDF / mediana global"="tfidf_median",
  "TF-IDF / percentil 75 global"="tfidf_q75", "TF-IDF / percentil 90 global"="tfidf_q90",
  "TF-IDF / media con peso positivo"="tfidf_present_mean", "TF-IDF / mediana con peso positivo"="tfidf_present_median",
  "TF-IDF / estad\u00edstico elegido en Preparaci\u00f3n"="tfidf_orden")

source_concentration_widget <- function(d,position=1L) {
  i<-match(position,d$posicion);if(is.na(i))i<-1L
  x<-d$posicion[i];y<-d$porcentaje_acumulado[i]
  hover<-paste0(escape_html(d$elemento),"<br>Fuentes acumuladas: ",d$posicion,"<br>Documentos de esta fuente: ",d$documentos,"<br>Documentos acumulados: ",round(d$porcentaje_acumulado,2)," %")
  chart<-plotly::plot_ly(d,x=~posicion,y=~porcentaje_acumulado,customdata=~posicion,text=hover,hoverinfo="text",type="scatter",mode="lines+markers",source="source_concentration",line=list(color="#245579"),marker=list(color="#245579",size=6),showlegend=FALSE)
  segment<-function(x0,x1,y0,y1,color,dash="dot")list(type="line",xref="x",yref="y",x0=x0,x1=x1,y0=y0,y1=y1,line=list(color=color,width=1.5,dash=dash))
  shapes<-c(lapply(c(50,80),function(p)segment(0,max(d$posicion),p,p,"#999999")),list(segment(x,x,0,y,"#c7281e"),segment(0,x,y,y,"#c7281e")))
  chart<-plotly::add_trace(chart,x=x,y=y,customdata=x,text=sprintf("%d fuentes / %.2f %%",x,y),hoverinfo="text",type="scatter",mode="markers",inherit=FALSE,marker=list(size=12,color="#c7281e"),showlegend=FALSE)
  chart<-plotly::layout(chart,title=list(text="Concentraci\u00f3n observada de las fuentes",font=list(size=17)),font=list(family="Arial",size=13),paper_bgcolor="white",plot_bgcolor="white",shapes=shapes,
    xaxis=list(tickangle=90,title=list(text="N\u00famero acumulado de fuentes / orden por productividad",standoff=22),range=c(0,max(d$posicion)*1.03),automargin=TRUE),
    yaxis=list(tickangle=0,title=list(text="Documentos con fuente acumulados (%)",standoff=22),range=c(0,103),tickvals=sort(unique(c(0,25,50,75,80,100))),automargin=TRUE),
    annotations=list(list(x=x,y=y,text=sprintf("(%d; %.2f %%)",x,y),showarrow=TRUE,ax=30,ay=-35)),margin=list(l=100,r=50,t=65,b=90))
  plotly::config(plotly::event_register(chart,"plotly_click"),displaylogo=FALSE)
}

term_view_data <- function(d,metric="tfidf_medio",status="all",n=12L,compare_states=FALSE) {
  if(!metric %in% unname(term_metric_choices()) || !metric %in% names(d)) abort_user("Orden de t\u00e9rminos no admitido.")
  check_number(n,"N\u00famero de t\u00e9rminos de la figura",5,25)
  if(!status %in% c("all","kept","excluded")) abort_user("Estado de vocabulario no admitido.")
  d<-filter_term_table(d,status=status)
  if(!nrow(d)) return(d)
  d<-d[order(-d[[metric]],d$termino,na.last=TRUE),,drop=FALSE]
  if(isTRUE(compare_states) && status=="all") {
    d<-rbind(head(d[d$incluido,,drop=FALSE],n),head(d[!d$incluido,,drop=FALSE],n))
    attr(d,"compare_states")<-TRUE
    return(d)
  }
  head(d,n)
}
term_comparison_figure <- function(d,unit="documento",tfidf_metric="tfidf_medio") {
  if(!nrow(d)) abort_user("No hay t\u00e9rminos en esta selecci\u00f3n. Cambia el estado del vocabulario o sus filtros.")
  metric_label<-names(term_metric_choices())[match(tfidf_metric,term_metric_choices())]
  labels<-c("Apariciones / repeticiones","Documentos / presencia",paste(metric_label,"/",unit))
  long<-do.call(rbind,lapply(seq_along(labels),function(i) data.frame(termino=factor(d$termino,levels=rev(d$termino)),indicador=factor(labels[i],levels=labels),valor=d[[c("frecuencia","documentos",tfidf_metric)[i]]],estado=factor(ifelse(d$incluido,"Retenido","Excluido"),levels=c("Retenido","Excluido")))))
  long$lectura<-ifelse(long$indicador==labels[3],format(long$valor,digits=3,scientific=FALSE,trim=TRUE),as.character(long$valor))
  wrap<-ggplot2::labeller(indicador=ggplot2::label_wrap_gen(width=25))
  facet<-if(isTRUE(attr(d,"compare_states"))) ggplot2::facet_grid(estado~indicador,scales="free",space="free_y",labeller=wrap) else ggplot2::facet_wrap(~indicador,scales="free_x",nrow=1,labeller=wrap)
  ggplot2::ggplot(long,ggplot2::aes(valor,termino,fill=estado))+ggplot2::geom_col(width=.62)+
    ggplot2::geom_text(ggplot2::aes(label=lectura),hjust=-.1,size=3.2)+facet+
    ggplot2::scale_fill_manual(values=c(Retenido="#c7281e",Excluido="#9c9c9c"))+ggplot2::scale_x_continuous(expand=ggplot2::expansion(mult=c(0,.25)))+
    ggplot2::scale_y_discrete(labels=function(x) vapply(x,function(z) paste(strwrap(z,width=26),collapse="\n"),""))+
    ggplot2::labs(x=NULL,y=NULL,fill="Estado del vocabulario",title="Tres lecturas de los mismos t\u00e9rminos",subtitle="Escalas distintas / la selecci\u00f3n y el orden se indican en la nota de la pantalla")+swiss_theme()+
    ggplot2::theme(strip.text=ggplot2::element_text(size=10),panel.grid.major.y=ggplot2::element_blank())
}
