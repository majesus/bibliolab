---
titulo: 02 / Decisiones de preparación
objetivo: Construir un corpus reproducible, con exclusiones justificadas y verificables.
fuentes:
  - Stanford / ponderación TF-IDF | https://nlp.stanford.edu/IR-book/html/htmledition/tf-idf-weighting-1.html
  - UDPipe / anotación en R | https://bnosac.github.io/udpipe/docs/doc2.html
---

## 1. Conceptos fundamentales: ¿qué significa preparar el corpus?

**Para situarte.** El corpus es el conjunto de documentos que estudias. Los metadatos son sus datos bibliográficos: título, año, autores, revista y otros campos. Un término es una palabra tal como queda después de la limpieza. La unidad de texto es el documento completo o la frase que se utilizará en los cálculos.

**Lo que quieres saber.** Qué documentos y qué palabras van a intervenir en los cálculos, y qué has dejado fuera por el camino.

**Lo que se calcula realmente.** Preparar registra documentos y palabras conservados y excluidos: construye, en un orden fijo, la versión del corpus sobre la que se calcularán los modelos. Primero se aplican los filtros de registros: valor exacto, periodo y los filtros documentales adicionales que hayas elegido. Después se realiza la **deduplicación**, que retira repeticiones seguras de una misma obra y, si lo pides, una **muestra aleatoria**. A continuación se segmenta y normaliza el texto, se anotan lemas o categorías gramaticales si los has elegido, y se aplican los criterios de vocabulario. El texto original se conserva siempre para contrastar cada transformación.

Reducir ruido significa retirar elementos que no ayudan a la pregunta, como un correo electrónico en un resumen o una frase de copyright repetida en cada ficha. Conservar información significa evitar que esos filtros borren diferencias que sí importan. No existe un filtro universal que separe automáticamente lo útil de lo inútil; por eso cada transformación queda registrada y puede revisarse.

## 2. Ejemplo práctico: de 100 registros a 42 documentos

Las cifras son ilustrativas. Un archivo contiene 100 registros importados. El filtro por periodo deja 90. La deduplicación elimina 5 repeticiones de la misma obra y quedan 85. Con una muestra del 50 %, la aplicación conserva `floor(85 × 50 / 100) = 42` documentos (se redondea hacia abajo).

La **presencia** de una palabra se mide sobre esos 42 documentos, incluso si alguno no aporta ninguna palabra tras la limpieza. Si un término aparece en 8 documentos, su presencia es 8/42 = 19,05 %. En cambio, la rareza (IDF) usa solo las unidades que conservan palabras: si 40 de los 42 documentos las conservan y el término aparece en 8 de ellos, IDF = ln(40/8) ≈ 1,61.

### Interpretación

Un documento sin palabras útiles sigue formando parte del corpus (cuenta en la bibliometría y en el denominador de la presencia), pero los modelos de texto no pueden representarlo. Por eso el vocabulario de los modelos puede ser menor que el vocabulario encontrado inicialmente, y por eso conviene leer por separado la auditoría de documentos y la de términos.

## 3. Flujo de trabajo en la aplicación: paso a paso

### Filtrar el corpus: qué se gana y qué se pierde

El panel anterior a Delimitar y documentar muestra una **previsualización documental** con las decisiones vigentes. El gráfico está encima de los selectores. Cada cambio actualiza registros retenidos y excluidos, porcentaje respecto al archivo importado, cobertura conjunta de DOI y resumen y distribución anual. Se aplica a los indicadores y modelos al pulsar **Preparar corpus**. Cambiar opciones después deja pendiente una nueva preparación.

La tabla indica el **orden real de aplicación**: filtro por valor exacto, periodo, filtros documentales elegidos, duplicados seguros y muestra. Cada registro excluido se atribuye al primer paso que lo elimina. El orden puede cambiar esa atribución. Las medianas de años y citas usan solo datos válidos; los ausentes no son ceros. Los registros sin año se cuentan aparte de las barras. Las diferencias entre lo retenido y excluido son descriptivas y no demuestran por sí solas sesgo estadístico.

Los tipos documentales se reconocen en Document Type de Scopus o DT de WoS y pueden indicar varios tipos en una misma celda, por ejemplo Article y Review. Se conserva un registro si coincide con cualquiera de los tipos permitidos; sin marcar tipos se conservan todos. **Early Access es un estado que puede coexistir con Article o Review** y se filtra por separado. Que el registro no indique acceso anticipado no certifica publicación definitiva.

Comprueba los campos auxiliares en el desplegable del panel. La exigencia de resumen utiliza Abstract o AB, incluso si el texto elegido para analizar es el título. Exigir texto no vacío no garantiza conservar vocabulario después de la limpieza. La presencia de un DOI tampoco comprueba que resuelva correctamente. No se filtran países a partir de direcciones libres: hace falta una columna explícita de país. Los desgloses de tipos, idiomas y países pueden no ser exclusivos.

Scopus y WoS tienen encabezados y coberturas diferentes. UT identifica registros de WoS; ID suele ser Keywords Plus y no se usa como identificador. EID identifica registros de Scopus. Las citas corresponden al campo asignado y no se homogeneizan entre las bases. Es necesario exportar los campos que se quieran utilizar y revisar la correspondencia.

La descarga de selección contiene tablas, decisiones y los registros retenidos y excluidos por fila original. Incluye además la entrada original completa en RDS para reproducir el cálculo; revísala antes de compartirla. El ZIP general conserva las decisiones realmente aplicadas, no las opciones pendientes de la vista previa.

1. **Correspondencia de campos.** Asigna el texto, el título y los metadatos. La columna de texto decide qué se analiza: resumen, título o una traducción ya importada. La propuesta automática es solo una sugerencia.
2. **Delimitar y documentar.** Escribe la pregunta de investigación y, en *Procedencia de la búsqueda*, la base de datos, la ecuación, la fecha de extracción y los criterios de inclusión: la entrega los conserva. Después decide los filtros de registros. Por defecto se excluyen duplicados, no se limita por año, no se filtra por valor, la muestra es del 100 % y la semilla es 2026.
3. **Duplicados.** Un registro solo se elimina cuando la coincidencia es segura: mismo DOI, o mismo título normalizado (sin acentos, mayúsculas ni puntuación) o, si falta el título, mismo texto, siempre que ningún DOI, año ni autores se contradigan (dos registros que declaran autores sin ninguno en común no se fusionan, aunque el título sea idéntico). Un título genérico (menos de cuatro palabras) exige además mismo año y mismos autores o texto. Se conserva la primera fila del archivo de cada grupo y, si le faltan campos que aporta el duplicado (año, DOI, resumen, autores, palabras clave o referencias), se completan y se anotan en `campos_completados`; las citas no se combinan. Las coincidencias dudosas no se eliminan: se conservan y quedan registradas en la entrega (`duplicados_ambiguos`) para que las revises.
4. **Muestra.** Si eliges menos del 100 %, la semilla fija qué documentos entran: la misma semilla sobre el mismo corpus devuelve la misma muestra. Con muestra, los indicadores describen esa muestra y no el corpus completo.
5. **Separar nombres y unificar su escritura.** Indica cómo se separan los autores y las palabras clave en una celda. Los autores no se separan por comas, porque la coma suele dividir apellido e iniciales. *Unificar variantes de escritura* agrupa autores, palabras clave y fuentes que solo difieren en mayúsculas, acentos o puntuación. *Retirar avisos finales de copyright* los quita solo del texto analizado.
6. **Normalización lingüística y selección del vocabulario.** Se explican en sus guías propias (*Guía / idioma, palabras vacías y lemas*, *Entender los filtros y TF-IDF* y *TF-IDF o BM25*). Empieza con los valores iniciales y cambia una decisión cada vez.
7. **Preparar corpus.** Pulsa el botón. Cualquier cambio posterior de columnas, filtros o idiomas invalida los resultados hasta repetir este paso.
8. **Control de calidad.** Abre la auditoría de documentos y cobertura, la tabla de términos retenidos y excluidos y el diagnóstico de vocabulario. El visor muestra una versión textual por vez (original, lematizada o limpia).

## 4. Cómo leer la preparación sin errores de interpretación

**Una exclusión no es un juicio de calidad.** Si una palabra crucial desaparece, localiza en la tabla de términos el motivo de exclusión (presencia mínima, presencia máxima, frecuencia mínima, TF-IDF mínimo, entropía máxima o recorte por el máximo de términos) y contrasta una ejecución con esa regla modificada.

**La deduplicación no es una verificación bibliográfica.** Detecta registros que parecen la misma obra con la evidencia disponible en el archivo. Dos versiones de una obra con años distintos, o dos artículos con un título genérico, se conservan y se registran como ambiguos.

**La muestra cambia la pregunta.** Con una muestra del 50 %, un término que aparece en 8 documentos podría aparecer en 4 o en 12 de otra muestra. Si usas muestra, indícalo en el método y no la mezcles con resultados del corpus completo.

**Qué comprobar.** Que cada etapa de la auditoría (importación, filtro por valor, filtro temporal, deduplicación, muestra final) tiene el número de documentos que esperabas, cuántos documentos quedan sin palabras y por qué, y qué parte de las apariciones iniciales queda representada por el vocabulario retenido. Una exclusión alta debe investigarse, no corregirse para alcanzar un porcentaje prefijado.

## 5. Pautas para documentar y redactar tu decisión

En el método puedes escribir, completando los corchetes con las cifras reales de tu auditoría: «De [n] registros importados se conservaron [m] tras [criterios de filtro y deduplicación]; la normalización utilizó [reglas], y [e] documentos no aportaron vocabulario a los modelos».

Es una redacción modelo que debes revisar antes de copiarla. Guarda la entrega antes de cambiar decisiones para poder comparar ejecuciones: el archivo de entrega recoge la configuración, las huellas de los archivos y el script de reproducción.

+++ Nota técnica: orden de las operaciones y denominadores
`prepare_documents()` aplica, en este orden, filtro por valor, filtro temporal, filtros documentales adicionales elegidos, `duplicate_audit()` y muestra (`sample.int` con `with_seed`, `n = max(1, floor(N × pct / 100))`, índices ordenados). `prepare_corpus()` tokeniza, anota si procede y construye la matriz dispersa de unidades × términos. La frecuencia es la suma de apariciones; la presencia es `documentos / nrow(docs)` sobre todos los documentos del corpus, incluso con frases como unidad; el IDF es `ln(unidades con palabras / unidades con el término)`; la entropía normalizada divide por `ln(nrow(docs))`. El texto original no se modifica: `strip_boilerplate()` actúa solo sobre la copia analizada.
+++
