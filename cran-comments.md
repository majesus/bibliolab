## Entorno de prueba (version 5.0.3)

* Linux (R 4.3.3), tarball construido con `R CMD build` y comprobado con
  `R CMD check --as-cran --no-manual` (modo CRAN, `NOT_CRAN=false`).
* Segunda comprobacion con `_R_CHECK_DEPENDS_ONLY_=true` y `NOT_CRAN=true` (solo dependencias
  duras; ejecuta todas las pruebas, ejemplos y la vineta).
* Suite completa fuera de CRAN con todas las dependencias opcionales (locale UTF-8) y, en el
  locale C, los archivos de pruebas de la auditoria, de la entrega, de integridad y de preparacion.
* La integracion continua de GitHub prueba Linux (release, oldrel-1 y R-devel), macOS y Windows,
  una ejecucion solo con dependencias duras y R 4.1.0 (la version minima declarada) tambien con
  solo dependencias duras: `dbscan`, un paquete opcional, exige R >= 4.3.0 y impedia resolver las
  dependencias de ese trabajo. Los resultados de R-devel, R 4.1.0, macOS y Windows se consultan
  en esa integracion; no se ejecutaron localmente.

## Resultado de R CMD check

`R CMD check --as-cran --no-manual` (R 4.3.3, Linux, sin acceso a Internet): 0 errores,
0 avisos y 2 notas, ambas atribuibles a la falta de red del entorno de prueba:

* NOTE "CRAN incoming feasibility": no se pudo consultar el indice de CRAN (estado 403) y
  aparecen los datos del mantenedor.
* NOTE "unable to verify current time" en "checking for future file timestamps".

Con `_R_CHECK_DEPENDS_ONLY_=true` y `NOT_CRAN=true`: `Status: OK` (0 errores, 0 avisos,
0 notas). El manual en PDF no se compilo en este entorno (`--no-manual`).

## Notas para los revisores

* Primera entrega: la nota "New submission" es esperable.
* La aplicacion Shiny (`run_app()`) no se ejecuta en pruebas ni ejemplos; sus modulos de
  sesion se comprueban con `shiny::testServer()` (omitido en CRAN).
* Los modelos de lematizacion UDPipe no se incluyen ni se descargan durante las pruebas
  ni los ejemplos; el paquete solo los descarga por orden expresa del usuario
  (`download_language_model()`), nunca al arrancar. Son materiales externos con su propia
  licencia (CC BY-NC-SA 4.0, repositorio udpipe.models.ud.2.5), distinta de la MIT del codigo;
  la funcion y la aplicacion lo advierten antes de descargar y cada modelo usado queda
  registrado con archivo, MD5, origen y licencia.
* `run_app()` no instala paquetes salvo con `install_missing = TRUE`, en sesion interactiva
  y con confirmacion del usuario.
* Los paquetes de `Suggests` se usan siempre de forma condicional
  (`requireNamespace()`), tambien en ejemplos y vineta. `ggrepel` es opcional: sin el, las
  etiquetas de los graficos usan `ggplot2::geom_text(check_overlap = TRUE)`.
* La version minima de R del nucleo es 4.1.0; la capacidad UMAP + HDBSCAN requiere R >= 4.3.0
  por `dbscan` (consta en README y en `biblio_check_dependencies()`).
