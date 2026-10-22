# bibliolab 5.0.8

Correcciones de la auditoría del 22/10/2026 (BL-01 a BL-08, BL-17, 19, 20, 25, 32, 35, 40 y 44). A diferencia de 5.0.7, esta versión modifica código R y puede cambiar resultados en corpus con duplicados, en la prevalencia LDA por frases y en la entrega reproducible.

- Duplicados: dos obras con igual título largo y año pero autores sin ninguno en
  común dejan de fusionarse y se listan como ambiguas («Autores distintos»); un
  DOI idéntico sigue siendo decisivo. El resultado no depende del orden de las filas.
- Duplicados: la fila conservada completa los campos que le faltan (año, DOI, texto,
  título, autores, fuente, palabras clave, referencias) con los del duplicado,
  sin contradicción, y lo registra en `campos_completados`. Las citas no se combinan.
- LDA: la tabla de calidad usa la misma prevalencia documental que la tabla
  principal, también cuando el texto se divide en frases.
- Palabras vacías: `prepare_corpus()` devuelve `language_check` y avisa, sin cambiar
  la elección, si otra lengua encaja claramente mejor que la lista elegida.
- Referencias: las variantes de una misma referencia con el mismo DOI forman una
  entidad en cocitación y acoplamiento.
- Entrega: incluye el mapa temático vigente (parámetros, semilla, lectura,
  cobertura, tablas, figuras y guion) en el informe, el informe metodológico, la
  evidencia para IA y el manifiesto; si las figuras no pueden escribirse se deja constancia.
- Reproducibilidad: el registro incluye la huella del código instalado y el guion
  la comprueba como aviso antes de calcular. `reproducir_diagnosticos.R` termina con
  error si una reproducción difiere o no ejecuta ninguna comparación, y escribe
  `verificacion_diagnosticos.json`.
- Selección de k: el número de palabras principales se recorta al vocabulario
  (se registra `top_n_pedido`), y la recomendación señala soluciones empatadas y
  estabilidad o vocabulario poco informativos. El botón pasa a «Usar este k en el
  modelo LDA» y avisa de que el modelo final aún no está calculado. La ayuda aclara
  el alcance de la reserva.
- Comparación JSD: advierte de que los grupos procedentes de LDA o UMAP + HDBSCAN
  son endógenos; las ayudas explican la unidad de remuestreo y los límites del nulo
  de las líneas base de ejes.
- Importación: el aviso de celdas de más de 50.000 caracteres nombra la columna, y
  los avisos de tamaño explican qué análisis se pierden al quitar las referencias.
- Interfaz: el estado «resultados vigentes» pasa a «resultados calculados con las
  opciones actuales» y aclara que no certifica validez metodológica.
- Lanzador: no instala `pkgload` sin consentimiento explícito.
- Los hallazgos de mayor alcance se documentan en `dev/HOJA_DE_RUTA_AUDITORIA.md`.

# bibliolab 5.0.7

- Añade a DESCRIPTION referencias verificadas de LDA, UMAP, HDBSCAN y
  divergencia Jensen-Shannon, sin cambiar los cálculos.
- Añade una construcción con R release actual y un check del mismo tarball,
  con manual y ejemplos donttest. Conserva el archivo, su SHA256 y los
  registros como artefacto de CI para las comprobaciones previas al envío.

# bibliolab 5.0.6

- Excluye los metadatos de Git, las carpetas temporales y los registros de depuración del paquete
  fuente para impedir que se distribuyan perfiles de navegador y otros
  artefactos locales ajenos a la aplicación.
- Rechaza encabezados CSV vacíos antes de que el lector les asigne nombres
  artificiales y conserva encabezados válidos como `NA` sin interpretarlos
  como valores ausentes.
- Valida los enteros de `k_range` y `seeds` antes de convertirlos en la
  selección LDA, evitando la truncación silenciosa de valores fraccionarios.
- Añade pruebas de regresión para estas validaciones. Mantiene las fórmulas
  de los análisis y las configuraciones enteras válidas.

# bibliolab 5.0.5

- Revisa la claridad de las 32 guías, las ayudas contextuales y las lecturas
  de resultados: define términos en su contexto y distingue medidas numéricas,
  estabilidad entre ejecuciones e interpretación científica, sin cambiar cálculos.
- Revisa las fichas y guías de los cinco análisis de 04 / Modelos y añade
  orientación contextual a sus decisiones: significado, punto de partida,
  efecto del cambio, comprobaciones y límites, sin modificar los cálculos.
- Distingue ajustes, controles de lectura y análisis temporal; precisa la
  resolución de Louvain y el uso de minPts, alpha y min_dist en esta aplicación.
- Añade una previsualización documental de los filtros en 02, con trazabilidad
  secuencial, resumen del corpus retenido y excluido, y distribución anual.
- Los filtros documentales adicionales se aplican al preparar y se conservan
  en la reproducción, con correspondencia explícita para Scopus y WoS.
- Mantiene los cálculos de los modelos y los criterios previos de duplicados
  y muestreo; los nuevos filtros son opcionales.

# bibliolab 5.0.4

- Incorpora en 04 / Modelos un mapa temático de centralidad y densidad de
  Callon, con copresencia documental, índice de equivalencia y Louvain.
  Permite palabras clave o vocabulario preparado, documenta cortes y límites,
  y exporta figuras, tablas y reproducción sin modificar los motores previos.
- Incorpora en 03 / Indicadores las regularidades descriptivas de Lotka,
  Bradford y Zipf, con cobertura, tablas completas, gráficos y referencias
  clásicas explícitas. No se presentan como contrastes estadísticos de leyes.
- Organiza la interfaz en bloques y subbloques titulados y numerados,
  con bordes finos y fondos suaves. Conserva controles, valores y condiciones.
- Añade las tablas de regularidades al informe y a la entrega reproducible,
  y permite descargarlas desde su propia pestaña.
- Mantiene los motores anteriores de preparación y análisis.

# bibliolab 5.0.3

Revision a partir de la auditoria del commit f6a57da3 (version 5.0.2). Cada punto cita su
hallazgo (R01-R18). Cada correccion lleva una prueba de regresion en
`tests/testthat/test-auditoria-503.R` (salvo R01, en `test-entrega-v2.R`) que falla con el codigo
de 5.0.2.

## Integridad de datos y entrega

* Deduplicacion independiente del orden (R03): la identidad se decide sobre el conjunto completo de
  candidatos (grafo de compatibilidad) y no fila a fila. Un registro sin DOI que podria
  corresponder a varias obras incompatibles no se fusiona con ninguna y se lista en `ambiguous`;
  permutar el archivo no cambia las obras analizadas. El registro conservado es la primera fila;
  si le faltan el anio o el DOI y un duplicado los aporta sin contradiccion, se completan y
  `duplicates$campos_completados` lo registra.
* Normalizacion Unicode (R04): el texto, las palabras vacias personalizadas, el diccionario y las
  notas del cuaderno se normalizan a NFC antes de tokenizar (`normalize_unicode()`). "cafe" +
  U+0301 y "cafe" precompuesto son un unico termino. Una marca combinante sin forma precompuesta
  forma parte de la palabra. Nueva dependencia dura, `utf8` (ya presente de forma transitiva).
* Huellas de contenido (R05): `entrega.huellas` de `parametros.json` guarda la huella canonica de
  `entrada_original.rds`, de los documentos preparados y de la matriz documento-termino
  (independientes de plataforma, locale y orden); `reproducir_analisis.R` las verifica y se detiene
  con un mensaje explicito. `export_bundle()` comprueba antes de publicar que `raw`, `prepared`,
  `corpus` y los modelos son coherentes entre si (no solo sus dimensiones).
* Requisitos por resultado (R06): una sensibilidad de UMAP + HDBSCAN se reproduce con sus propios
  insumos, sin exigir el modelo final de densidad; una comparacion por temas LDA o por grupos
  UMAP se entrega sin el modelo de origen y se declara en `entrega.comprobaciones_omitidas` (los
  grupos proceden de `grupos_jsd.rds`). Una sensibilidad con vectores sin sus vectores hace parcial
  la entrega.
* Alpha como funcion (R07): `lda_select_k()` registra los valores efectivos de alpha para cada k
  (`params$alpha_por_k`, `params$alpha_regla`) y el guion los reproduce con una tabla numerica,
  sin depender del entorno de la funcion original.
* `verify_bundle()` valida el esquema y el contenido del manifiesto (R18): rechaza un manifiesto
  ilegible, sin las columnas `archivo`, `bytes` y `md5`, vacio, con rutas vacias, absolutas, con
  `..`, duplicadas o que apunten al propio manifiesto, o con tamanos y MD5 invalidos. Mantiene los
  estados `correcto`, `modificado`, `ausente` y `no registrado`.
* Publicacion alternativa de la entrega: si no se puede renombrar la carpeta preparada, la copia se
  verifica y no queda una carpeta temporal contigua.

## Diagnosticos

* Semillas de la seleccion de k en la interfaz (R08): se derivan con `derive_seed()`, tambien con
  la semilla maxima.
* `run_lda()` rechaza un `thin` mayor que las iteraciones antes de llamar al motor (R09); el
  ajuste interno de `lda_select_k()` lo comprueba tambien y devuelve un mensaje legible.
* NPMI (R10): un par cuyos dos terminos aparecen en todos los documentos no tiene variacion (0/0) y
  se excluye del promedio en lugar de valer 1. Un tema sin pares informativos devuelve `NA`
  (`topics$pares_npmi`), la lectura lo declara y un k con NPMI no informativa no compite en la
  recomendacion.
* Sensibilidad de UMAP + HDBSCAN (R11): sin grupos en la referencia, `ari_asignados` es `NA` y la
  lectura habla de "misma ausencia de grupos", no de estabilidad excelente.
* Denominadores (R12): `prepare_corpus()` devuelve `tokens_in_model` y `units_in_model`; la
  aplicacion distingue palabras tras la limpieza, palabras en el vocabulario de los modelos y
  unidades de la matriz.
* `vocabulary_diagnostics()` conserva siempre la fila de la presencia minima vigente, tambien con
  vocabulario vacio (R13).

## Dependencias opcionales, licencias y rendimiento

* ggrepel es realmente opcional (R02): las figuras de correspondencias/ACP, el cuaderno y la red
  estatica usan `label_layer()`, que recurre a `ggplot2::geom_text(check_overlap = TRUE)` si falta.
  En la descarga del ZIP, un grafico que falla se omite y se registra en `graficos_omitidos.csv` y
  `LEEME.txt` en lugar de abortar la descarga.
* Modelos UDPipe (R16): se avisa de su licencia (CC BY-NC-SA 4.0) antes de cada descarga y en el
  gestor de modelos; cada modelo usado se registra con archivo, MD5, origen y licencia (parametros,
  informe y tabla de modelos). El README separa la licencia MIT del codigo de la de los
  modelos.
* Version minima de R (R15): el nucleo requiere R 4.1.0 y se comprueba en la integracion continua
  con R 4.1.0 instalando solo las dependencias duras; `dbscan` (HDBSCAN) exige R 4.3.0, hecho que
  consta en el README y en `biblio_check_dependencies()`.
* Rendimiento (R17): `author_citation_metrics()` usa un indice autor -> documentos en una sola
  pasada (3.000 documentos y autores: de unos 17 s a unos 1,5 s en el equipo de prueba) y
  `jsd_uncertainty()` evalua las replicas por lotes con resultados identicos para una misma
  semilla (B = 5000, 10.000 documentos y terminos: pico de unos 830 MB y 31 s).

## Pruebas, API y citacion

* `ejecutar_rscript()` (R01): el helper lanza los guiones en un proceso limpio con
  `withr::with_envvar()` y comprueba el estado de salida; el argumento `env` de `system2()`
  falla en Windows. Se omite si bibliolab no esta instalado.
* `prepare_documents()` rechaza opciones de configuracion desconocidas y opciones logicas que no
  sean `TRUE`/`FALSE` (con sugerencia de la opcion mas parecida).
* `inst/CITATION`: cita de software explicita y coherente con `DESCRIPTION`.

## Limites conocidos (no abordados en esta version)

* R14: la cobertura sigue siendo desigual (cuaderno de lectura, redes, `nlp.R`, `temporal.R`). Se
  anaden regresiones por hallazgo, no una campana de cobertura.
* `reconstruir_graficos.R` no reproduce todos los graficos que la aplicacion anade al ZIP
  (por ejemplo, la red estatica y algunos rankings).
* La cobertura bibliometrica descrita en el informe (RIS/BibTeX, paises e instituciones, citas
  locales, coocurrencia de palabras clave) es alcance futuro, no un defecto de esta version.
* No hay etiquetas de version recuperables en el repositorio; el guion advierte si la version
  instalada difiere de la registrada.

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
