---
titulo: 04 / Modelos como herramientas exploratorias
objetivo: Elegir el método según la pregunta y validar cada resultado mediante la lectura de documentos y la sensibilidad a los parámetros.
fuentes:
  - topicmodels / LDA en R | https://cran.r-project.org/package=topicmodels
  - uwot / UMAP en R | https://cran.r-project.org/package=uwot
  - dbscan / HDBSCAN en R | https://cran.r-project.org/package=dbscan
---

## 1. Conceptos fundamentales: un modelo es una representación, no una respuesta

**Lo que puedes estudiar.** Los métodos representan aspectos distintos del vocabulario preparado en 02. Un resultado exploratorio sirve para formular y revisar interpretaciones; no demuestra por sí solo una explicación científica.

- **LDA:** estima patrones de palabras, llamados temas, y la proporción de cada uno en cada documento o frase. k es el número de temas que eliges.
- **UMAP + HDBSCAN:** convierte documentos en coordenadas numéricas, reduce su número y busca grupos en zonas donde los documentos quedan concentrados. Puede dejar documentos sin asignar. La representación puede proceder del vocabulario o de vectores numéricos importados.
- **ACP:** construye ejes que resumen la variación de pesos TF-IDF entre documentos. TF-IDF combina uso relativo de la palabra y presencia entre documentos; no mide su importancia científica.
- **AC:** resume diferencias entre los repartos de apariciones de las palabras por documento o frase. Perfil significa aquí ese reparto, no el significado del texto.
- **Mapa temático:** agrupa términos que aparecen juntos por documento y representa sus conexiones con otros grupos y dentro del propio grupo. No es una clasificación exclusiva de documentos.

**Antes de elegir.** Documento es una publicación; unidad es el documento completo o la frase utilizada en el ajuste. Parámetros son las opciones cuyo valor decides. Sensibilidad significa cuánto cambia el resultado al cambiar una de ellas. La semilla controla el inicio aleatorio; no mide calidad ni garantiza estabilidad.

**Cómo interpretar.** Comprueba cobertura —cuántos documentos aportan los datos necesarios—, lee las palabras y los originales y compara alternativas. Cada indicador debe leerse en su método: varianza, inercia, coherencia de palabras y grado de pertenencia no forman una escala común de calidad.

## 2. Ejemplo práctico: un mismo resumen visto por cuatro métodos

Un resumen sobre hospitales sostenibles puede combinar dos temas en LDA (por ejemplo, un 60 % de un tema de salud y un 40 % de uno de sostenibilidad), pertenecer a un único grupo en HDBSCAN o quedar sin asignar. El ACP o las correspondencias pueden mostrar qué vocabulario lo separa de otros documentos sin asignarle ningún tema. Las cifras son ilustrativas.

### Interpretación

Estas diferencias reflejan preguntas y supuestos distintos; no son un fallo por no coincidir. Que dos métodos coincidan puede apoyar una lectura; que discrepen obliga a estudiar las representaciones, la cobertura y los supuestos de cada uno.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige el método por la pregunta.** La pestaña ofrece rutas según la pregunta: patrones de palabras, mezclas de temas, grupos de documentos, conexiones entre temas o solo descripción; cada ruta indica qué devuelve, qué decisión exige y qué no permite concluir, y abre la pestaña de la técnica correspondiente. La ruta *solo describir* lleva directamente a la entrega, sin ajustar modelos. Para ver cómo un resumen mezcla patrones de vocabulario, consulta LDA. Para explorar agrupaciones de documentos, revisa UMAP con HDBSCAN y los documentos sin asignar. Para resumir diferencias de perfiles, usa el ACP o las correspondencias.
2. **Comprueba las condiciones de partida.** La cabecera de la pestaña indica si el corpus vigente permite el modelo. LDA y las correspondencias usan los conteos del vocabulario y pueden trabajar con documentos o con frases, según lo elegido en 02; UMAP con HDBSCAN y el ACP reciben siempre documentos completos.
3. **Fija los parámetros que sí son decisiones.** LDA necesita el número de temas k. UMAP necesita vecinos, dimensiones y compactación; HDBSCAN, el tamaño mínimo de grupo. Cada ayuda propone un valor inicial y qué probar a continuación.
4. **Lee los documentos.** Las tablas de documentos representativos son el puente entre un número y su significado; ningun nombre de tema debe nacer solo de un gráfico.
5. **Estudia la sensibilidad.** Cambia una decisión cada vez y conserva las ejecuciones. La semilla permite repetir una ejecución, pero no prueba estabilidad científica: para LDA usa la comparación de k con varias semillas y para UMAP con HDBSCAN la evaluación de estabilidad.
6. **Compara en la pestaña Comparación.** Recoge los resultados de los modelos calculados. Los indicadores de coherencia, grado de pertenencia al grupo, varianza e inercia responden a preguntas distintas y no se ordenan como una puntuación común; un valor ausente significa no calculado o no aplicable, no cero.

## 4. Cómo leer los modelos sin errores de interpretación

**Un gráfico atractivo o un porcentaje alto de varianza no demuestra validez temática.** Un eje puede explicar mucha variación por una razón puramente léxica (por ejemplo, la longitud de los textos).

**Las agrupaciones no son taxonomías.** Los grupos de HDBSCAN y los temas de LDA son estructuras estadísticas del vocabulario. Puedes proponer categorías de investigación al interpretar esos resultados, pero necesitas criterios documentados y lectura de los textos; ponerles un nombre no las valida automáticamente.

**La aplicación no decide por ti el nombre de los temas.** No decide que un tema sea «educación» o «salud» ni usa un modelo de lenguaje para nombrarlo; los nombres de los temas requieren el trabajo del investigador, con o sin asistencia de IA, que debe documentarse.

**El flujo léxico no es semántico.** La representación TF-IDF con LSA no usa BERT ni une idiomas por significado: «calidad» y *quality* siguen siendo palabras distintas.

**Qué comprobar.** Que las conclusiones sobreviven a otra semilla y a un valor vecino del parámetro principal, y que los documentos representativos de cada resultado se corresponden con la lectura propuesta.

## 5. Pautas para documentar y redactar tu decisión

En el método puedes escribir: «Se utilizó [método] para [pregunta]; se fijó [parámetro principal = valor] y se contrastó la sensibilidad con [semillas / valores alternativos]. Las interpretaciones se revisaron mediante la lectura de [n] documentos representativos por [tema/grupo/eje]».

Es una redacción modelo que debes ajustar a lo que hiciste. Un método adicional debe aportar evidencia a tu pregunta; no aumenta por sí solo el rigor. Conserva los parámetros y las versiones junto a cada ejecución que presentes.

+++ Nota técnica: qué calcula cada pestaña
LDA: `topicmodels::LDA()` con muestreo de Gibbs sobre los conteos, con k entre 2 y 12. UMAP con HDBSCAN: representación TF-IDF o BM25 seguida de LSA (descomposición en valores singulares, con `irlba` cuando la matriz es grande), `uwot::umap()` y `dbscan::hdbscan()`; la descripción de cada grupo usa c-TF-IDF. ACP: `stats::prcomp()` sobre los pesos TF-IDF (con IDF suavizado propio del ACP) de los términos más frecuentes, siempre centrado. Correspondencias: descomposición en valores singulares de los residuos estandarizados de la tabla de conteos de términos por unidad. Ninguna de estas representaciones usa vectores semánticos preentrenados, salvo que importes un CSV de vectores con procedencia documentada.
+++
