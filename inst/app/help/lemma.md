---
titulo: Lematización / de las formas al lema
objetivo: Reunir las variantes gramaticales de una palabra, con el modelo de idioma adecuado, para evitar la dispersión del vocabulario.
fuentes:
  - UDPipe / anotación en R | https://bnosac.github.io/udpipe/docs/doc2.html
  - CLD2 / estimación local y lenguas mezcladas | https://docs.ropensci.org/cld2/reference/cld2.html
---

## 1. Conceptos fundamentales: idioma, palabras vacías, lemas y categorías

**Para situarte.** El texto que se analiza puede ser el resumen, el título u otra columna elegida en 02. Su idioma puede diferir del idioma del artículo completo. Un modelo de idioma es un archivo que permite al programa analizar palabras de una lengua; no es una traducción del texto.

**Lo que quieres saber.** Si «estudiante», «estudiantes» y «estudiando» se están contando como palabras distintas, y si el análisis lingüístico es el adecuado para el idioma de cada texto.

**Lo que se calcula realmente.** Un **lema** es la forma de diccionario de una palabra. **Lematizar** reúne determinadas flexiones (estudiante y estudiantes) y algunas conjugaciones bajo una misma forma, con lo que se reduce la dispersión del vocabulario. No traduce, no reúne sinónimos y no garantiza acierto en siglas, nombres propios o vocabulario especializado. La aplicación lematiza con **UDPipe**, que tokeniza, asigna a cada palabra una categoría gramatical (sustantivo, adjetivo, verbo…) y obtiene su lema con un modelo específico de cada idioma: español, inglés, francés, alemán, italiano o portugués. El análisis es local, en R; los resúmenes no se envían a ningún servidor.

Las **palabras vacías** (artículos, preposiciones, conjunciones) se eliminan con la lista del idioma elegido, más las que añadas tú. La **lematización** y el **filtro de categorías gramaticales** son decisiones independientes: puedes usar una, ambas o ninguna. Con el filtro de categorías sin lematizar se conservan las formas originales de las palabras que pertenecen a las categorías elegidas.

## 2. Ejemplo práctico: un corpus de resúmenes en dos idiomas

Tienes mil resúmenes, unos en español y otros en inglés, sin columna de idioma. Las cifras que siguen son ilustrativas.

Eliges *Varios idiomas / estimación automática con CLD2*. El detector examina cada resumen en tu ordenador y asigna idioma de forma automática solo si se cumplen tres condiciones: el texto tiene al menos 40 letras, la estimación es fiable según el detector y una lengua compatible concentra al menos el 90 % del texto clasificado. Los casos que no las cumplen quedan pendientes, cada uno con su motivo: texto demasiado breve, estimación incierta, idioma sin modelo disponible (por ejemplo, un resumen en neerlandés, que se detecta bien pero no tiene lematizador en la aplicación) o posible mezcla de idiomas.

Con un modelo español, «los estudiantes estudian» puede dar los lemas *estudiante* y *estudiar*; con un modelo inglés, *studies* puede dar *study*. Si un lema aparece como *estudiante* en 3 resúmenes y *estudiantes* como forma distinta en otros 4, sin solaparse, tras lematizar el lema *estudiante* aparece en 7 documentos. Esa reunión puede hacer que una palabra supere la presencia mínima que antes no alcanzaba.

### Interpretación

El porcentaje de predominio de CLD2 describe la proporción del texto clasificado en esa lengua; no es la probabilidad de que el idioma asignado sea correcto. Un idioma estimado es una decisión documentada, no una verdad confirmada: la columna de idioma de un CSV puede describir el idioma del artículo mientras que el resumen seleccionado está traducido.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Decide si lematizas.** Si solo quieres eliminar palabras vacías, no hace falta ningún modelo: elige la lista de palabras vacías del idioma de tus textos (o *Español + inglés*, o *Sin lista*). Si activas lemas o categorías, el idioma del modelo determina también la lista de palabras vacías. Si el idioma de la lista y el del modelo no coinciden, la aplicación se detiene con un aviso.
2. **Elige el idioma.** Si todos los textos analizados están en el mismo idioma, elígelo, aunque los artículos del archivo estén escritos en varias lenguas. Si los textos analizados tienen varios idiomas, elige *Varios idiomas*.
3. **Prepara los modelos.** *Preparar modelos necesarios* muestra qué lematizadores hacen falta y los descarga una sola vez; la descarga solo ocurre cuando tú la pides y cada ejecución registra la huella MD5 del modelo utilizado.
4. **Resuelve los idiomas pendientes.** Abre *Revisar idiomas / solo pendientes* y resuelve los casos leyendo sus extractos. Consulta también las discrepancias y una muestra de las asignaciones automáticas. Puedes corregir varias filas a la vez. Un nombre o código de idioma reconocido en el CSV se conserva, y una corrección manual tiene prioridad sobre el CSV y sobre CLD2. Si cambias el texto seleccionado, se recalculan las estimaciones y se retiran las correcciones hechas para el texto anterior.
5. **Filtro de categorías (opcional).** Por defecto conserva sustantivos, nombres propios y adjetivos. Puede eliminar verbos o adverbios importantes para tu pregunta; compara con los originales.
6. **Pulsa Preparar corpus** y contrasta una muestra de originales con sus lemas en el visor, que distingue el texto lematizado del limpio.

## 4. Cómo leer la lematización sin errores de interpretación

**Lematizar no es traducir ni unir sinónimos.** Reúne formas de una misma palabra, no conceptos relacionados. «Docente» y «profesor» siguen siendo dos lemas.

**Lematizar no es hacer *stemming*.** El *stemming* recorta formas con reglas y puede devolver una raíz que no es una palabra (*univers* a partir de *universities*). La lematización busca una forma lingüística interpretable. La aplicación no hace *stemming*; si importas texto ya reducido a raíces, contará las raíces presentes y debes documentar esa preparación previa.

**Un documento mezclado no se fuerza.** Si un documento contiene de forma sustancial dos idiomas, la aplicación no le impone un modelo único: revísalo y documenta cómo lo tratas.

**Lo que puede salir mal.** Una sigla o un término técnico mal analizado puede justificar conservar las formas originales. La anotación está limitada a cinco millones de caracteres y a un millón de palabras tras la limpieza; si los superas, aplica una muestra.

**Qué comprobar.** Que los idiomas pendientes son cero o están justificados, que una muestra de lemas es razonable en tu campo y que los términos clave de tu pregunta no se han fusionado ni dividido de forma indebida.

## 5. Pautas para documentar y redactar tu decisión

En el método puedes escribir, completando los corchetes: «Los textos se lematizaron por documento con UDPipe (modelos [modelos y versiones]); el idioma de cada documento procedía de [nombre o código de idioma del archivo / estimación local con CLD2 revisada mediante (procedimiento) / corrección manual]. Se conservaron las categorías [categorías]».

Es una redacción modelo que debes ajustar a lo que hiciste. No escribas que el corpus se tradujo ni que sus lenguas se fusionaron: los lemas siguen perteneciendo a idiomas diferentes. La entrega conserva las estimaciones de idioma, su origen, las correcciones y los idiomas efectivamente aplicados, de modo que puedes repetir el proceso sin volver a estimar.

+++ Nota técnica: reglas de asignación y de filtrado
`estimate_language_one()` exige `min_letters = 40`, un resultado de `cld2::detect_language_mixed()` marcado como fiable, un código con modelo disponible y una proporción dominante de al menos `dominance = 0.90`. Un nombre o código de idioma del CSV reconocido por `normalize_language()` se conserva; la estimación solo completa los casos sin nombre o código de idioma reconocido, y las correcciones manuales prevalecen sobre ambas. Los modelos son `spanish-gsd`, `english-ewt`, `french-gsd`, `german-gsd`, `italian-isdt` y `portuguese-bosque`. En `normalize_annotation_one()`, la forma analizada es el lema si `lemmatize` está activo y la forma escrita original si no; se descartan puntuación y símbolos, números aislados si procede, y las palabras cuya forma original o cuyo lema esté en la lista de palabras vacías; la longitud mínima y máxima se aplican a la forma analizada. El filtro gramatical utiliza estos códigos: `NOUN` (sustantivo), `PROPN` (nombre propio), `ADJ` (adjetivo), `VERB` (verbo) y `ADV` (adverbio).
+++
