# Leyes de Lotka, Bradford y Zipf (descriptivas; ver R/leyes.R).
laws_current<-reactive({current();req(rv$bib,rv$corpus);bibliometric_laws(rv$bib,rv$corpus)})
law_lotka_graph<-reactive(lotka_graph(laws_current()$lotka))
law_bradford_graph<-reactive(bradford_graph(laws_current()$bradford))
law_zipf_graph<-reactive(zipf_graph(laws_current()$zipf))
output$law_lotka_plot<-renderPlot(law_lotka_graph(),res=110)
output$law_bradford_plot<-renderPlot(law_bradford_graph(),res=110)
output$law_zipf_plot<-renderPlot(law_zipf_graph(),res=110)
for(key in c("lotka","bradford","zipf"))local({k<-key
  output[[paste0("law_",k,"_reading")]]<-renderUI({f<-laws_current()[[k]];tags$div(class="chart-caption",tags$p(f$lectura),if(nzchar(f$criterio))tags$p(tags$em("Criterio de ajuste: "),f$criterio))})
})
