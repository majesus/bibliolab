#' bibliolab: analisis bibliometrico y de textos, guiado y reproducible
#'
#' Aplicacion Shiny guiada y funciones para describir un corpus bibliografico,
#' explorar su texto con modelos (LDA, correspondencias, ACP, UMAP + HDBSCAN,
#' JSD, redes) y exportar una entrega reproducible. Punto de entrada: [run_app()].
#'
#' @keywords internal
#' @import shiny
#' @importFrom data.table .N
#' @importFrom Matrix sparseMatrix
#' @importFrom stats setNames median sd aggregate
#' @importFrom utils head tail modifyList capture.output sessionInfo
"_PACKAGE"
