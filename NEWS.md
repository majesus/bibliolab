# bibliolab 5.0.2

Revision a partir de la auditoria del commit b876e55. Cada punto cita su hallazgo (H01-H23).

## Integridad de datos

* Deduplicacion con evidencia (H02): un DOI identico es decisivo; sin DOI, titulo o texto
  normalizado solo bastan si no hay DOI ni anio contradictorios y, con titulos de menos de
  cuatro palabras (por ejemplo, "Editorial"), si coinciden ademas el anio y los autores o el
  texto. `prepare_documents()` devuelve `duplicates` (con criterio y registro conservado) y
  `ambiguous` (coincidencias no eliminadas) e `input_md5`.
* Las claves de etiqueta (`label_key()`) conservan escrituras no latinas y combinan
  diacriticos de forma Unicode (H03): "李 a" y "王 a" ya no colapsan.
* `bm25_weights()` valida los valores almacenados de la matriz dispersa sin densificarla (H08).
* La red documental aplica Benjamini-Hochberg sobre todos los pares con alguna coaparicion y
  despues el minimo compartido como filtro descriptivo; la p ajustada ya no depende de ese
  umbral (H09).
* Palabras vacias por documento (`language = "by_document"`) con una lista por idioma; aborta si
  un documento con texto no tiene idioma reconocido (H17).

## Diagnosticos metodologicos

* `lda_select_k()` reserva documentos completos para la perplejidad y calcula la coherencia
  por documento (H04); restaura el generador aleatorio global (H15).
* Semillas derivadas por rotacion dentro del rango entero (`derive_seed()`), tambien con
  `.Machine$integer.max` (H21).
* Estados `ejecutada` / `no_aplicable` / `fallida` con causa para la estabilidad de comunidades,
  la incertidumbre de la JSD (por comparacion y por periodo) y la sensibilidad de UMAP/HDBSCAN (H18).
* `jsd_rows()` y `jsd_uncertainty()` rechazan entradas improcedentes; una fila sin masa devuelve
  `NA` y no cero.
* La sensibilidad del vocabulario simula con los mismos filtros y el mismo maximo de terminos,
  de modo que la fila `actual` coincide con el vocabulario efectivo (H22).

## Entrega y reproducibilidad

* `export_bundle()` publica de forma transaccional: escribe en una carpeta contigua y la renombra
  al terminar; rechaza una carpeta de destino con archivos y no deja restos tras un fallo (H07).
* Entrega parcial declarada (H06): sin `raw`, sin los vectores de entrada de `run_density()`
  (`input_vectors`) o sin el agrupamiento de una comparacion no se escribe un guion que no podria
  ejecutarse; `parametros.json`, `LEEME.txt` y un aviso lo registran.
* `manifiesto_archivos.csv` (tamano y MD5) y las nuevas funciones `write_bundle_manifest()` y
  `verify_bundle()` (H07).
* El guion de reproduccion comprueba huella de entrada, numero de documentos y dimensiones y
  suma del corpus, y toma los modelos de idioma del corpus (H14).
* La seleccion de k y la sensibilidad de densidad se guardan en `parametros.json` y
  `evidencia_ia.json` con independencia del modelo final, con sus repeticiones, el reparto
  reservado y `reproducir_diagnosticos.R` (H20).
* La huella del corpus (`corpus_fingerprint()`) invalida los diagnosticos de la aplicacion cuando
  cambia el corpus aunque las dimensiones coincidan (H01).

## Dependencias y modelos de idioma

* `run_app()` ya no instala nada por defecto: `install_missing = TRUE` exige sesion interactiva y
  confirmacion; los paquetes opcionales ausentes solo deshabilitan su capacidad (H12, H13).
  `biblio_check_dependencies()` incluye la columna `funciones`. Se elimina `mclust` de `Suggests`
  porque no se usaba.
* `download_language_model()` descarga a una carpeta temporal, valida el idioma y la carga del
  modelo y solo entonces lo publica; un modelo danado ya no se da por valido (H16).
  `udpipe::udpipe_load_model()` no falla con un archivo danado (devuelve un puntero nulo), de modo
  que la validacion exige un puntero valido y una anotacion minima.

## Documentacion y compatibilidad

* Se exportan y documentan `density_defaults()`, `read_document_vectors()`, `network_defaults()`
  y `comparison_defaults()`; `default_config()` describe cada opcion, su rango y su efecto (H19).
* Se anaden `pca_axes` y `token_display_metric` a `utils::globalVariables()` y la integracion
  continua prueba R-devel y la version minima declarada, R 4.1.0 (H23). Se anade `cran-comments.md`.
* Nuevas pruebas de regresion con oraculos independientes para H01-H09, H12-H18 y H20-H22.

# bibliolab 5.0.1

* Correccion de empaquetado: se restauran `inst/app/www/style.css` (hoja de estilos
  que enlaza `build_ui()`; sin ella la interfaz se abria sin su aspecto) y
  `R/wiki_graph_reading.R` (define `wiki_document_graph()`, necesaria para la vista
  documental de la lectura enlazada). Se recuperan las importaciones declaradas de
  `Matrix`, `stats` y `utils` en `NAMESPACE`.
* `run_app()` abre el navegador predeterminado del sistema sin depender de
  `options(browser)` y avisa si faltan `style.css` o `app.js`. Se anade el acceso
  `ABRIR_BIBLIOLAB.cmd` / `lanzar_bibliolab.R`, que carga el codigo de esta carpeta
  con `pkgload` sin instalar el paquete.

* Skills de redacción y revisión (v4): contrato de evidencia alineado con 5.0.x (informe metodológico, referencia nula de la JSD, selección de k, sensibilidad de UMAP/HDBSCAN), scripts de inventario y verificación de cifras contra los CSV, plantilla de registro de afirmaciones y de dictamen, y aviso de integridad académica (`inst/skills/INTEGRIDAD_ACADEMICA.md`).

* Lectura: campos recomendados con cobertura e idioma de muestra, selección
  avanzada explícita y fichas con autores, DOI y fechas. Red documental Jaccard,
  comunidades Louvain y subgrafos seleccionables con parámetros reproducibles.
* Redes de lectura: si superan 100.000 relaciones, el aviso indica el recuento
  exacto y el Jaccard o el mínimo compartido que dejan la red completa dentro
  del límite. No se recorta la red ni se cambian los umbrales automáticamente.
* Red de conceptos legible: por defecto, los 100 conceptos más frecuentes (0 = todos);
  solo relaciones significativas (test hipergeométrico unilateral de coaparición con
  marginales fijos, corrección Benjamini-Hochberg sobre todos los pares, FDR 0,05)
  y, por palabra, las 3 relaciones más intensas por Jaccard (0 = todas; reducción
  descriptiva, no inferencial). Roles de Guimerà y Amaral (2005): z intracomunitario
  y coeficiente de participación, con formas distintas por rol (eje, puente, eje y
  puente, apoyo), etiquetas selectivas, tabla de roles y lectura en lenguaje llano.
  Se conservan los pesos Jaccard de la red completa y el dibujo se limita a 500 nodos y
  5.000 coapariciones, con aviso en lugar de recorte. Los aislados se ocultan por defecto.
* Selección de palabras: por defecto, las de mayor frecuencia documental (fichas con la palabra,
  no apariciones). Criterio alternativo TF-IDF (suma de log(1 + frecuencia) x ln(N / DF)) y techo
  opcional de presencia (sin techo por defecto): las palabras excluidas se declaran y la lectura avisa
  de las que superan el 30 % de las fichas. Explicación paso a paso con ejemplos, ejemplo con datos
  propios y redacción sugerida del apartado de métodos con los parámetros usados y referencias
  verificadas en Crossref (Jaccard 1912; Luhn 1958; Spärck Jones 1972; Callon et al. 1983;
  Benjamini y Hochberg 1995; Newman y Girvan 2004; Guimerà y Amaral 2005; Blondel et al. 2008;
  Tumminello et al. 2011; Neal 2014; Traag et al. 2019).
* Panel del grafo reordenado en pasos: 1 calcular (único paso que recalcula, con el estado junto al botón),
  2 buscar y resaltar, ajustes del dibujo, ficha activa, grafo, y 3 interpretación. Buscador de palabras
  en el grafo, resaltado de una comunidad sin recalcular y quitar resaltado; todas las palabras llevan su
  nombre, con letra algo mayor. Los selectores de ficha declaran que no cambian la red.
* LDA: consulta por título, DOI o ID, paginación y selección en el modal; calidad
  montada por bloques y figura de composición elegida reproducible en la descarga.
* ACP y correspondencias: ampliaciones interactivas que aprovechan el modal,
  más etiquetas distribuidas sin alterar coordenadas y controles plegables.
  Fuentes y autores recuperan barras rojas.

* Arranque con instalación explícita, comprobación posterior y bibliotecas R
  alineadas. La API run_app prepara Imports y todos los análisis. Diez escenarios
  de lanzadores incluyen R 4.6.1 simulado sin paquetes y fallos de instalación.
* Módulos de sesión congelados con el namespace: se impide mezclar pantallas nuevas
  con funciones antiguas. Validaciones explícitas de selecciones sin filas.
* Ejemplo separado de la importación, acciones y navegación con colores distintos,
  keywords visibles (incluido Keywords author), separadores por campo y ejemplos
  observados, BM25 explicado con valores calculados y ejes X a 90 grados.
* Rutas mínimas, aislados inmediatos, key players localizables, JSD con palabras
  reales, n-gramas con ceros visibles y lecturas de utilidad y límites.
* ACP con todos los componentes útiles y cualquier par, interpretaciones de LDA,
  ACP y correspondencias, y comparación de resultados con palabras y proporciones.
* Cuaderno de páginas con texto original elegido, grafo de documentos y evidencia
  de cada enlace. Las exportaciones reproducen texto, grafo y plano ACP seleccionado.
* Auditoría: docs/REVISION_CLARIDAD_V5_20261015.md.

# bibliolab 5.0.0

* Revisión de uso: estadísticas TF-IDF alternativas y rankings por estado;
  diagnóstico de keywords; selección trazable de todas las entidades y prioridades
  explícitas; key players visibles y retirada auditada de aislados.
* Arrastre con posiciones conservadas y física, proyecciones de concentración,
  títulos de backlinks de 20 caracteres, lecturas de calidad LDA, spline
  descriptiva y modal CA adaptable.
* Arranque local con preparación previa de todas las dependencias de análisis;
  binarios en Windows, detección de fallos y comprobación independiente.
* Exportaciones conservan opciones y admiten prioridades vacías o múltiples.
  Detalle: docs/REVISION_USO_V5_20261014.md.

* Trabajadores PSOCK compatibles con el arranque desde fuentes locales mediante
  pkgload: cargan la misma ubicación y versión que la aplicación. La recuperación
  secuencial se conserva para fallos excepcionales; no es la vía prevista para
  los lanzadores V5. Los procesos propios se identifican antes de inicializarlos.
* Selección TF-IDF por media, mediana, cuartiles o percentil configurable, con
  ceros explícitos y estadísticos SD/MAD; orden reproducible con desempates.
* h de autores dentro del corpus y cobertura de citas; rankings editables,
  páginas de hasta 50 barras, cifras visibles y tipografía compacta.
* JSD entre autores con exclusión de publicaciones compartidas; categorías de
  citas por cuartiles o umbral. Fuentes normalizadas al comparar y hacer redes.
* Red de palabras con preset legible y límite de conexiones por peso antes de
  calcular métricas; auditoría de selección y acceso visible a subgrafos.
* Visor predictivo sin diferencias por tildes/mayúsculas; enlaces y documentos
  en modales. Mínimos imposibles de conceptos compartidos dan cero vecinos.
* LDA disperso hasta 20.000 unidades, 2.500 términos y un millón de tokens;
  correspondencias/ACP limitados por celdas densas en lugar de 1.500 filas.
* Spline con años observados separados: no se predicen huecos de cobertura.
* Decisiones, ceros, límites y denominadores visibles; errores esperados en
  español; estado permanente del corpus y diagnóstico de keywords ausentes.
* Pruebas nuevas de métodos/servidor, comprobación empírica local e informe de
  auditoría con trazabilidad de las observaciones. No se promete aceptación editorial.

# bibliolab 4.0.0

Primera versión empaquetada (derivada de «Bibliometría v3.8»). Cambios respecto a V3.8:

## Cambios que pueden alterar resultados

* **LDA:** el prior de mezcla por documento pasa de `50/k` (valor por defecto de
  `topicmodels`) a `1/k`. Con `50/k`, las proporciones por documento de textos cortos
  quedaban dominadas por el prior (en los datos de práctica, proporción media del tema
  dominante 0,36 frente a 0,93 con `1/k`). El valor se puede cambiar y queda registrado.
* **Palabras clave, autores y fuentes:** se unifican variantes que solo difieren en
  mayúsculas, acentos o puntuación (`normalize_labels`, activo por defecto). La tabla de
  variantes unificadas se exporta.
* **Deduplicación:** el título se compara sin acentos, mayúsculas ni puntuación; el
  registro de duplicados indica el criterio.
* **Detección de columnas:** en exportaciones etiquetadas de WoS, `ID` (Keywords Plus)
  ya no se propone como identificador del documento (se usa `UT`).
* **Avisos de copyright:** se retiran del texto analizado (no del original) los avisos
  finales tipo «(c) 2023 Elsevier. All rights reserved» (`remove_boilerplate`).
* **Acoplamiento bibliográfico:** con más documentos que el límite, se eligen los de
  mayor acoplamiento total y solo entran documentos que comparten alguna referencia
  (antes, los primeros por identificador).

## Novedades metodológicas

* `lda_select_k()`: comparación de soluciones LDA (coherencia, diversidad, estabilidad,
  perplejidad reservada) con valor de compromiso y aviso de conflicto entre criterios.
* `run_lda()`: `alpha`, `delta`, `burnin`, `thin` explícitos; diagnósticos de calidad,
  coherencia por tema y traza de log-verosimilitud.
* `density_sensitivity()`: estabilidad entre semillas y sensibilidad a vecinos/minPts
  (ARI) y persistencia por grupo.
* `jsd_uncertainty()`: referencia nula por permutación, exceso, valor p e intervalo
  bootstrap; la trayectoria anual incluye la JSD esperada por azar.
* `run_ca()` / `run_pca()`: línea base de permutación por eje.
* Redes: ponderación `association` (van Eck y Waltman, 2009) y estabilidad de comunidades.
* `vocabulary_diagnostics()`: sensibilidad de la presencia mínima y candidatos a
  palabras vacías propias del corpus.
* `reproducibility_record()` y `methods_report()`: registro de versiones, semillas y
  huella del archivo; informe metodológico con validaciones ejecutadas y pendientes.

## Cambios de arquitectura

* Estructura de paquete R (CRAN): `run_app()`, funciones documentadas, pruebas con
  `testthat`, viñeta.
* Se eliminan el instalador, la biblioteca privada y los lanzadores `.cmd`; los modelos
  UDPipe ya no están dentro de la carpeta de la aplicación y solo se descargan por
  petición explícita a `tools::R_user_dir("bibliolab", "data")`.
* La entrega reproducible apunta al paquete instalado en lugar de copiar los módulos R.
