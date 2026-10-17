## Entorno de prueba

* Linux (R 4.3.3), instalacion con `R CMD INSTALL` y comprobacion con
  `R CMD check --as-cran` del tarball construido con `R CMD build`.
* Comprobacion adicional con `_R_CHECK_DEPENDS_ONLY_=true` (solo dependencias duras).
* La integracion continua de GitHub prueba Linux (release, oldrel-1, R-devel y R 4.1.0,
  la version minima declarada en DESCRIPTION), macOS y Windows, ademas de una
  ejecucion solo con dependencias duras. Los resultados de R-devel y de R 4.1.0 se
  consultan en esa integracion; no se ejecutaron localmente.

## Resultado de R CMD check

`R CMD check --as-cran --no-manual` (R 4.3.3, Linux, sin acceso a Internet): 0 errores.
Los avisos que aparecen proceden unicamente de la ausencia de red en el entorno de prueba:

* WARNING "unable to access index for repository" en "checking for unstated
  dependencies in 'tests'": la comprobacion no pudo consultar CRAN ni Bioconductor.
* NOTE "unable to verify current time" en "checking for future file timestamps".
* NOTE de "CRAN incoming feasibility": datos del mantenedor.

Con `_R_CHECK_DEPENDS_ONLY_=true` (solo Depends/Imports): 0 errores, 0 avisos; los ejemplos,
las pruebas y la vineta se ejecutan sin ningun paquete de `Suggests`. La nota de
"no visible global variable" que se observaba antes (`pca_axes`, `token_display_metric`)
ya no aparece. El manual en PDF no se compilo en este entorno (`--no-manual`).

## Notas para los revisores

* Primera entrega: la nota "New submission" es esperable.
* La aplicacion Shiny (`run_app()`) no se ejecuta en pruebas ni ejemplos; sus modulos de
  sesion se comprueban con `shiny::testServer()` (omitido en CRAN).
* Los modelos de lematizacion UDPipe no se incluyen ni se descargan durante las pruebas
  ni los ejemplos; el paquete solo los descarga por orden expresa del usuario
  (`download_language_model()`), nunca al arrancar.
* `run_app()` no instala paquetes salvo con `install_missing = TRUE`, en sesion interactiva
  y con confirmacion del usuario.
* Los paquetes de `Suggests` se usan siempre de forma condicional
  (`requireNamespace()`), tambien en ejemplos y vineta.
