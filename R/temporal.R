# Evolucion de categorias fijas; no modelo dinamico de palabras ni estacionalidad.
density_yearly <- function(fit) {
  d<-fit$assignments;d<-d[!is.na(d$year),,drop=FALSE]
  if(!nrow(d)) return(data.frame(ano=integer(),grupo=integer(),documentos=integer(),total=integer(),proporcion=numeric(),segmento=integer()))
  if(any(!is.finite(d$year)|d$year!=floor(d$year))) abort_user("La evoluci\u00f3n necesita a\u00f1os de publicaci\u00f3n v\u00e1lidos.")
  years<-sort(unique(d$year));groups<-sort(unique(fit$assignments$grupo))
  out<-expand.grid(ano=years,grupo=groups);counts<-table(d$year,d$grupo)
  out$documentos<-vapply(seq_len(nrow(out)),function(i) sum(d$year==out$ano[i]&d$grupo==out$grupo[i]),1L)
  totals<-table(d$year);out$total<-as.integer(totals[as.character(out$ano)])
  out$proporcion<-out$documentos/out$total
  out$segmento<-cumsum(c(1L,diff(years)>1))[match(out$ano,years)]
  out[order(out$grupo,out$ano),]
}

density_spline <- function(fit,group,k=5L) {
  check_number(k,"Complejidad m\u00e1xima de la spline",3,8)
  d<-density_yearly(fit);d<-d[d$grupo==group,,drop=FALSE]
  if(!nrow(d)) abort_user("Selecciona un grupo de la ejecuci\u00f3n vigente.")
  if(nrow(d)<10) abort_user(paste("La spline necesita al menos 10 a\u00f1os observados; aqu\u00ed hay",nrow(d),". Este es un l\u00edmite de esta herramienta para evitar curvas con pocos puntos, no una garant\u00eda estad\u00edstica. Usa proporciones observadas."))
  gaps <- any(diff(d$ano)!=1)
  if(any(d$total<5)) abort_user("Alg\u00fan a\u00f1o tiene menos de cinco documentos del modelo con a\u00f1o v\u00e1lido. Usa proporciones observadas y revisa la cobertura antes de ajustar una curva.")
  if(sum(d$documentos)==0 || sum(d$documentos)==sum(d$total)) abort_user("El grupo est\u00e1 ausente o re\u00fane todos los documentos en todos los a\u00f1os. No hace falta una spline para una proporci\u00f3n constante de cero o uno.")
  if(!requireNamespace("mgcv",quietly=TRUE)) abort_user("La spline necesita el paquete mgcv (recomendado, incluido con R).")
  k<-min(as.integer(k),nrow(d)-2L);s<-mgcv::s
  formula<-stats::as.formula(paste0("cbind(documentos,total-documentos) ~ s(ano,bs='cr',k=",k,")"),env=environment())
  warnings<-character()
  model<-tryCatch(withCallingHandlers(mgcv::gam(formula,data=d,family=stats::quasibinomial(),method="REML"),
    warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart("muffleWarning")}),error=function(e) abort_user(paste("No se pudo ajustar la spline:",conditionMessage(e),". Conserva los puntos observados.")))
  if(!isTRUE(model$converged) || length(warnings)) abort_user(paste("La spline no ofrece un ajuste limpio. Se conservan los puntos observados.",paste(warnings,collapse="; ")))
  # Se ajustan anos observados; el dibujo se interrumpe en huecos de cobertura.
  grid<-do.call(rbind,lapply(split(d$ano,d$segmento),function(ys) data.frame(ano=seq(min(ys),max(ys),length.out=if(length(ys)>1) max(2L,12L*length(ys)) else 1L),segmento=d$segmento[match(ys[1],d$ano)])))
  pr<-stats::predict(model,newdata=grid,type="link",se.fit=TRUE)
  if(any(!is.finite(pr$fit)|!is.finite(pr$se.fit))) abort_user("La spline no produjo estimaciones finitas. Usa los puntos observados.")
  grid$grupo<-group;grid$estimacion<-stats::plogis(pr$fit);grid$inferior<-stats::plogis(pr$fit-1.96*pr$se.fit);grid$superior<-stats::plogis(pr$fit+1.96*pr$se.fit)
  residuals<-stats::residuals(model,type="deviance");adj<-which(diff(d$ano)==1);acf1<-if(length(adj)>2 && stats::sd(residuals[adj])>0 && stats::sd(residuals[adj+1])>0) stats::cor(residuals[adj],residuals[adj+1]) else NA_real_
  list(observed=d,predictions=grid,params=list(group=group,k=k,basis="cr",family="quasibinomial / logit",method="REML",gaps=gaps,interval="link +/- 1.96 SE / aproximaci\u00f3n puntual condicional"),
    diagnostics=data.frame(indicador=c("A\u00f1os observados","Documentos con a\u00f1o en el modelo","Grados de libertad efectivos del suavizado","Dispersi\u00f3n estimada","Autocorrelaci\u00f3n residual a un a\u00f1o"),valor=c(nrow(d),sum(d$total),sum(model$edf)-1,summary(model)$scale,acf1)),
    note=paste("Spline c\u00fabica penalizada de proporci\u00f3n grupo frente al resto, con enlace logit y dispersi\u00f3n estimada por REML. Clasificaci\u00f3n HDBSCAN fija. Banda aproximada puntual condicional al ajuste y sus supuestos; no incluye incertidumbre al elegir corpus, clasificar temas o estimar dependencia temporal. No es prueba de significaci\u00f3n, pron\u00f3stico ni estacionalidad; revisar residuos y sensibilidad.",if(gaps) "Hay huecos de cobertura: el ajuste utiliza los a\u00f1os observados y el dibujo se interrumpe. No se estiman ni rellenan los a\u00f1os ausentes. Contrasta un intervalo de cobertura continuo." else "Cobertura anual continua en el intervalo observado."))
}

lda_yearly <- function(fit,prepared) {
  d<-fit$document_topics;years<-prepared$documents$year[match(d$doc_id,prepared$documents$doc_id)]
  valid<-!is.na(years);groups<-seq_len(fit$params$k);out<-list()
  for(y in sort(unique(years[valid]))) {
    ix<-which(valid & years==y)
    out[[as.character(y)]]<-data.frame(ano=y,tema=groups,documentos=length(ix),proporcion_media=colMeans(as.matrix(d[ix,-1,drop=FALSE])))
  }
  if(!length(out)) return(data.frame(ano=integer(),tema=integer(),documentos=integer(),proporcion_media=numeric(),segmento=integer()))
  d<-do.call(rbind,out);ys<-sort(unique(d$ano));d$segmento<-cumsum(c(1L,diff(ys)>1))[match(d$ano,ys)]
  rownames(d)<-NULL;d
}

density_year_terms <- function(corpus,prepared,fit,group) {
  counts<-document_counts(corpus,prepared);a<-fit$assignments
  ix<-which(a$grupo==group & !is.na(a$year));out<-list()
  for(y in sort(unique(a$year[ix]))) {
    ids<-a$doc_id[ix[a$year[ix]==y]];m<-counts[match(ids,rownames(counts)),,drop=FALSE]
    f<-as.numeric(Matrix::colSums(m));df<-as.numeric(Matrix::colSums(m>0));keep<-f>0
    out[[as.character(y)]]<-data.frame(ano=y,grupo=group,termino=colnames(m)[keep],apariciones=f[keep],documentos_con_termino=df[keep],documentos_del_grupo=nrow(m),proporcion_tokens=f[keep]/sum(f))
  }
  if(!length(out)) return(data.frame())
  d<-do.call(rbind,out);rownames(d)<-NULL;d[order(d$ano,-d$proporcion_tokens,d$termino),]
}

# Interpolacion Hermite cubica con tangentes cero en los anos observados.
# Cada tramo es una combinacion convexa: no sobrepasa los extremos, mantiene
# la suma de temas y no atraviesa huecos. Es dibujo, no estimacion temporal.
lda_time_curve <- function(d) {
  if(!nrow(d))return(d)
  pieces<-lapply(split(d,interaction(d$tema,d$segmento,drop=TRUE)),function(z){
    z<-z[order(z$ano),,drop=FALSE];if(nrow(z)<2)return(z)
    do.call(rbind,lapply(seq_len(nrow(z)-1L),function(i){
      t<-seq(0,1,length.out=25L);if(i>1)t<-t[-1L]
      out<-z[rep(i,length(t)),,drop=FALSE]
      out$ano<-z$ano[i]+t*(z$ano[i+1L]-z$ano[i])
      w<-3*t^2-2*t^3
      out$proporcion_media<-(1-w)*z$proporcion_media[i]+w*z$proporcion_media[i+1L]
      out
    }))
  })
  out<-do.call(rbind,pieces);rownames(out)<-NULL;out
}

lda_temporal_figure <- function(fit,prepared,spline=FALSE) {
  d<-lda_yearly(fit,prepared)
  if(!nrow(d)) abort_user("Asigna a\u00f1os para estudiar la prevalencia de temas fijos.")
  d$tema_label<-paste("Tema",d$tema)
  curve<-if(isTRUE(spline))lda_time_curve(d) else d
  ggplot2::ggplot(d,ggplot2::aes(ano,100*proporcion_media,colour=tema_label,group=interaction(tema,segmento)))+ggplot2::geom_line(data=curve,linewidth=.7)+ggplot2::geom_point(size=2.3)+
    ggplot2::scale_colour_manual(values=setNames(swiss_colours(fit$params$k),paste("Tema",seq_len(fit$params$k))))+
    ggplot2::scale_y_continuous(limits=c(0,100))+ggplot2::labs(x="A\u00f1o de publicaci\u00f3n",y="Prevalencia media (%)",colour=NULL,title="Prevalencia anual / temas LDA fijos",subtitle=paste("Media de mezclas de documentos con a\u00f1o / puntos observados\n",if(isTRUE(spline)) "Spline c\u00fabica descriptiva / sin extrapolaci\u00f3n ni relleno de a\u00f1os ausentes" else "Segmentos rectos / a\u00f1os sin datos interrumpen las l\u00edneas"))+year_axis(d$ano)+swiss_theme()+ggplot2::theme(axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5),plot.title.position="panel",plot.margin=ggplot2::margin(20,25,18,18))
}

density_temporal_figure <- function(fit,view="proportions",spline=NULL) {
  d<-density_yearly(fit);if(!nrow(d)) abort_user("Asigna a\u00f1os de publicaci\u00f3n v\u00e1lidos antes de estudiar evoluci\u00f3n.")
  d$grupo_label<-ifelse(d$grupo==0,"Sin asignar",paste("Grupo",d$grupo))
  if(view=="spline") {
    if(is.null(spline)) abort_user("Elige un grupo y pulsa Ajustar spline. Si no hay suficientes a\u00f1os, utiliza proporciones observadas.")
    return(ggplot2::ggplot(spline$predictions,ggplot2::aes(ano,100*estimacion,group=segmento))+ggplot2::geom_ribbon(ggplot2::aes(ymin=100*inferior,ymax=100*superior),fill="#245579",alpha=.15)+
      ggplot2::geom_line(colour="#245579",linewidth=.9)+ggplot2::geom_point(data=spline$observed,ggplot2::aes(ano,100*proporcion,size=total),inherit.aes=FALSE,colour="#c7281e")+
      ggplot2::coord_cartesian(ylim=c(0,100))+ggplot2::labs(x="A\u00f1o de publicaci\u00f3n",y="Documentos del grupo entre los del modelo (%)",size="Documentos ese a\u00f1o",title=paste("Evoluci\u00f3n descriptiva / grupo",spline$params$group),subtitle="Puntos observados y spline penalizada / banda puntual condicional / sin extrapolaci\u00f3n")+year_axis(d$ano)+swiss_theme()+ggplot2::theme(axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5)))
  }
  shown<-head(fit$summary$grupo[order(-fit$summary$documentos)],6);d<-d[d$grupo %in% shown,]
  ggplot2::ggplot(d,ggplot2::aes(ano,100*proporcion,colour=grupo_label,group=interaction(grupo,segmento)))+
    ggplot2::geom_line(linewidth=.7)+ggplot2::geom_point(size=2.3)+ggplot2::scale_colour_manual(values=density_palette(d$grupo_label))+
    ggplot2::coord_cartesian(ylim=c(0,100))+ggplot2::labs(x="A\u00f1o de publicaci\u00f3n",y="Proporci\u00f3n anual entre documentos del modelo (%)",colour=NULL,title="Proporci\u00f3n observada de grupos por a\u00f1o",subtitle="Hasta seis grupos m\u00e1s numerosos / a\u00f1os sin datos interrumpen las l\u00edneas")+year_axis(d$ano)+swiss_theme()+ggplot2::theme(axis.text.x=ggplot2::element_text(angle=90,hjust=1,vjust=.5))
}
