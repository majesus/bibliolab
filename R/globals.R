# Nombres que R CMD check no puede resolver estaticamente:
#  * variables de estetica de ggplot2 (evaluacion no estandar);
#  * reactivos y funciones definidos por los modulos de sesion de inst/app/server,
#    que se cargan con source(local = TRUE) dentro de app_server().
utils::globalVariables(c(
  ".data", "ano", "aporte_acumulado_pct", "authors_graph", "ca_variance_graph",
  "citations_graph", "comparison_current", "consecutivo", "cos2_plano", "density_current",
  "density_export_current", "density_graph", "density_membership_graph",
  "density_similarity_graph", "density_stacked_graph", "density_terms_graph", "direccion",
  "documento", "documentos", "dsens_current", "eje_1", "eje_2", "eje_label", "estado", "estimacion",
  "etiqueta", "grupo", "grupo_A", "grupo_B", "grupo_label", "inferior", "jsd_bits",
  "jsd_cumulative_graph", "jsd_graph", "jsd_matrix_graph", "jsd_time_graph", "keywords_graph",
  "kselect_current", "label", "language_estimates", "language_route", "lda_heatmap_graph",
  "lda_display_documents", "lda_time_graph", "lectura", "make_network_graph", "network_current", "network_graph",
  "pair", "pca_axes", "pca_current", "pca_documents_graph", "pca_terms_graph", "pca_variance_graph",
  "posicion", "proporcion", "proporcion_media", "segmento", "shift_pct", "subgraph_current",
  "superior", "tema", "tema_label", "termino", "token_bars_graph", "token_display_metric", "token_graph", "token_view",
  "total", "type", "valor", "wiki_export_current", "x", "xend", "y", "yend",
  "regularities_current", "observado", "referencia", "porcentaje_acumulado", "rango", "zona",
  "thematic_current", "centralidad", "densidad", "cuadrante", "texto", "hjust", "vjust", "selection_settings"
))
