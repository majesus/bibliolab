model_comparison_table <- function(lda=NULL,density=NULL,pca=NULL,ca=NULL,prepared=NULL,pca_axes=c(1L,2L)) {
  row <- function(method,fit,representation,result,caution) data.frame(metodo=method,estado=if(is.null(fit)) "Sin calcular / no vigente" else "Vigente",representacion=representation,
    resultado=if(is.null(fit)) "Calcula el m\u00e9todo para comparar sus resultados" else result,interpretacion=caution)
  out<-rbind(row("LDA",lda,"Conteos / mezcla por unidad",if(!is.null(lda)) paste(lda$params$k,"temas /",lda$units,"unidades /",lda$terms,"t\u00e9rminos"),"Cada documento puede mezclar temas. k es elegido; leer palabras y textos."),
    row("UMAP + HDBSCAN",density,if(is.null(density)) "LSA lexical o vectores importados" else density$representation$type,
      if(!is.null(density)) paste(sum(density$summary$grupo>0),"grupos /",sum(density$assignments$grupo==0),"sin asignar de",nrow(density$assignments)),"Agrupaci\u00f3n por densidad; comparar par\u00e1metros y semillas. El mapa 2D es otra proyecci\u00f3n."),
    row("ACP",pca,"TF-IDF centrado / estandarizaci\u00f3n opcional",if(!is.null(pca)) sprintf("%d documentos / plano %d / %d: %.1f%% de varianza",nrow(pca$documents),pca_axes[1],pca_axes[2],sum(pca$dimensions$porcentaje[pca_axes])),"Varianza y cos\u00b2 del plano; no produce cl\u00fasteres por s\u00ed solo."),
    row("Correspondencias",ca,"Conteos / perfiles chi-cuadrado",if(!is.null(ca)) sprintf("%d unidades / plano %.1f%% de inercia",nrow(ca$units),sum(ca$dimensions$porcentaje[1:2])),"Inercia y cos\u00b2; no comparar su porcentaje como si fuera varianza ACP."))
  ca_documents<-if(is.null(ca))NA_integer_ else length(unique(sub("[_.].*$","",ca$units$unit_id)))
  out$documentos_modelo<-c(if(is.null(lda))NA else nrow(lda$document_topics),if(is.null(density))NA else nrow(density$assignments),if(is.null(pca))NA else nrow(pca$documents),ca_documents)
  out$unidades_modelo<-c(if(is.null(lda))NA else lda$units,if(is.null(density))NA else nrow(density$assignments),if(is.null(pca))NA else nrow(pca$documents),if(is.null(ca))NA else nrow(ca$units))
  out$terminos_modelo<-c(if(is.null(lda))NA else lda$terms,if(is.null(density))NA else density$params$vocabulary_terms %||% NA,if(is.null(pca))NA else nrow(pca$terms),if(is.null(ca))NA else nrow(ca$terms))
  out$cobertura_documentos_pct<-if(is.null(prepared))NA_real_ else 100*out$documentos_modelo/nrow(prepared$documents)
  out$hallazgos<-"Pendiente de calcular"
  out$diagnosticos_observados<-"Pendiente de calcular"
  if(!is.null(lda)){
    out$hallazgos[1]<-paste(vapply(seq_len(nrow(lda$prevalence)),function(i){t<-lda$prevalence$tema[i];sprintf("T%d: %.1f %% (%s)",t,100*lda$prevalence$proporcion_media[i],paste(head(lda$top$termino[lda$top$tema==t],3),collapse=", "))},""),collapse="; ")
    v<-lda$diagnostics$overview$valor;out$diagnosticos_observados[1]<-sprintf("NPMI %.3f; UMass %.3f; diversidad %.1f %% de palabras principales distintas. Diagn\u00f3sticos internos; estabilidad requiere repeticiones.",v[1],v[2],100*v[3])
  }
  if(!is.null(density)){
    d<-density$summary;out$hallazgos[2]<-paste(vapply(seq_len(nrow(d)),function(i)sprintf("%s: %d documentos / %.1f %% (%s)",d$etiqueta[i],d$documentos[i],d$porcentaje[i],d$palabras[i]),""),collapse="; ")
    a<-density$assignments;out$diagnosticos_observados[2]<-paste0(sprintf("Sin asignar: %.1f %%",100*mean(a$grupo==0)),if(any(a$grupo>0))sprintf("; grado medio de pertenencia de los asignados %.3f",mean(a$membresia[a$grupo>0])) else "; no se detectan grupos", ". El grado de pertenencia al grupo no es probabilidad tem\u00e1tica; estabilidad requiere repeticiones.")
  }
  for(i in 3:4){f<-if(i==3)pca else ca;if(is.null(f))next;d<-if(i==3)pca_plane(f,"terms",pca_axes) else f$terms;axes<-if(i==3)pca_axes else c(1,2)
    out$hallazgos[i]<-paste("T\u00e9rminos con mayores aportaciones a la construcci\u00f3n de los ejes del plano:",paste(head(d$termino[order(-(d$contribucion_eje_1+d$contribucion_eje_2))],5),collapse=", "))
    out$diagnosticos_observados[i]<-sprintf("Plano %d / %d: %.1f %% de %s; mediana cos\u00b2 de t\u00e9rminos %.3f. %d de %d ejes evaluados superan la referencia que deja por debajo el 95 %% de los resultados de las permutaciones. Esa comparaci\u00f3n no valida temas.",axes[1],axes[2],sum(f$dimensions$porcentaje[axes]),if(i==3)"varianza" else "inercia",stats::median(d$cos2_plano),sum(f$dimensions$supera_azar %in% TRUE),sum(!is.na(f$dimensions$supera_azar)))
  }
  out[c("metodo","estado","documentos_modelo","cobertura_documentos_pct","unidades_modelo","terminos_modelo","resultado","hallazgos","diagnosticos_observados","representacion","interpretacion")]
}

