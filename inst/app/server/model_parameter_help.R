# Solo abre orientacion editorial. No observa cambios de parametros ni ajusta modelos.
for (parameter_id in names(model_parameter_catalog())) local({
  id <- parameter_id
  observeEvent(input[[paste0("help_parameter_", id)]], {
    card <- model_parameter_catalog()[[id]]
    showModal(modalDialog(title = card$title, size = "l", easyClose = TRUE,
      model_parameter_modal(id), footer = modalButton("Volver al análisis")))
  }, ignoreInit = TRUE)
})
