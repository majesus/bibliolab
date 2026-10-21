---
titulo: N-gramas / qué cuenta cada indicador
objetivo: Elegir entre repetición, cobertura, especificidad y concentración al ordenar expresiones, sabiendo qué pregunta responde cada indicador.
fuentes:
---

## 1. Conceptos fundamentales: cuatro formas de contar una misma expresión

**Para situarte.** Un término es una palabra después de la limpieza; un lema es su forma de diccionario, como estudiante para estudiantes. Un n-grama es una secuencia de una, dos o tres palabras consecutivas de ese texto. No se unen palabras que estaban separadas por puntuación o por palabras eliminadas.

**Lo que quieres saber.** Qué expresiones (secuencias de palabras adyacentes) caracterizan tu corpus, y si destacan por repetirse, por estar extendidas o por distinguir unos textos de otros.

**Lo que se calcula realmente.** Un **unigrama** es una unidad léxica; un **bigrama**, dos consecutivas; un **trigrama**, tres. La aplicación cuenta secuencias del texto normalizado, sin cruzar puntuación ni palabras eliminadas. Si has lematizado, las secuencias contienen lemas; si importas raíces ya truncadas (*stems*), contienen esas raíces, y no se recuperan las palabras originales.

Cada expresión recibe cuatro indicadores que responden a preguntas distintas. Las **apariciones totales** cuentan todas las repeticiones. La **presencia documental** cuenta documentos distintos, una vez por documento. El **TF-IDF** pondera cuánto ocupa la expresión en cada documento y cuán rara es entre documentos. La **concentración** resume cómo se reparten las apariciones entre documentos y se calcula como uno menos la entropía normalizada de Shannon: es 1 si todas las apariciones están en un solo documento y baja cuando se reparten.

## 2. Ejemplo práctico: dos expresiones con la misma frecuencia

Los resultados se han obtenido ejecutando el cálculo de la aplicación sobre un corpus ilustrativo de diez documentos. La expresión «atención primaria» aparece diez veces en el primer documento y en ningún otro. La expresión «ciclo vital» aparece una vez en cada uno de los diez documentos.

| Expresión | Apariciones | Presencia (documentos) | % del corpus | Concentración | TF-IDF medio |
|---|---|---|---|---|---|
| atención primaria | 10 | 1 | 10 % | 1,00 | 0,100 |
| ciclo vital | 10 | 10 | 100 % | 0,00 | 0,000 |

### Interpretación

Ambas empatan en apariciones, pero cuentan historias distintas. «Atención primaria» está concentrada en un texto: su TF-IDF medio es positivo porque ocupa mucho de ese documento y es rara en el corpus, aunque casi nadie más la usa. «Ciclo vital» tiene máxima cobertura y concentración nula; como aparece en todos los documentos activos, su IDF (`ln(10/10)`) es cero, y también lo es su TF-IDF. Que sea cero no significa que carezca de importancia: significa que no distingue unos textos de otros.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige la longitud de la expresión** (uno, dos o tres palabras). Comparar longitudes distintas requiere recordar que no hay el mismo número de expresiones posibles de cada longitud.
2. **Empieza ordenando por presencia documental.** Así evitas que la repetición intensa de un único texto domine el ranking. Fija una presencia mínima para descartar expresiones de un solo documento si buscas líneas extendidas.
3. **Consulta las apariciones totales** para distinguir extensión y repetición, y la **concentración** para ver cómo se reparten.
4. **Usa el TF-IDF** (media, mediana o percentil 75) si buscas vocabulario distintivo. Consulta junto a él la presencia, la mediana con peso positivo y la desviación mediana absoluta (MAD) de la tabla: una media puede estar sostenida por un único documento atípico.
5. **Lee los contextos** de las expresiones que vayas a interpretar, en los resúmenes donde aparecen.
6. **Registra la configuración**: longitud, indicador de ordenación, presencia mínima y filtros de Preparación.

## 4. Cómo leer los indicadores sin errores de interpretación

**Un ranking de expresiones no es una prueba de colocación.** La adyacencia describe una secuencia literal; no demuestra asociación estadística entre sus palabras, ni causalidad.

**Cada indicador depende de su denominador.** Para un documento, el TF es el número de apariciones de la expresión dividido por todas las expresiones válidas de esa longitud en el documento; el IDF es `ln(N/df)`, donde N son los documentos *activos* (los que aportan al menos una expresión válida de esa longitud) y df los que contienen la expresión; el TF-IDF medio promedia sobre los documentos activos, ceros incluidos. El porcentaje de presencia y la normalización de la entropía usan, en cambio, todos los documentos del corpus preparado.

**Un TF-IDF medio alto puede deberse a un solo texto.** Compara la media con la mediana, la MAD y la presencia antes de afirmar que una expresión caracteriza al corpus.

**Los n-gramas se calculan después de los filtros de Preparación y antes del límite de vocabulario de los modelos.** Cambiar las palabras vacías, la lematización o las categorías cambia las secuencias.

**Qué comprobar.** Que el indicador elegido responde a tu pregunta, que la expresión no depende de un único documento y que sus contextos la respaldan.

## 5. Pautas para documentar y redactar tu decisión

Especifica la longitud, la normalización, las fronteras y el criterio de ordenación: «Se extrajeron [bigramas] del texto normalizado (sin cruzar puntuación), con presencia mínima de [n] documentos y ordenados por [indicador]. La expresión [x] aparece en [d] de [N] documentos ([f] apariciones)».

Es una redacción modelo que debes completar con tus cifras. Si informas un TF-IDF medio, indica que su denominador utiliza los documentos que aportan expresiones válidas de esa longitud.

+++ Nota técnica: cálculo
`ngram_summary()` recorre cada segmento de texto (los segmentos no se unen entre sí) y construye las ventanas de n palabras consecutivas no vacías. Calcula la frecuencia, el número de documentos y, con la matriz documento–expresión, TF = frecuencia / total de expresiones del documento y TF-IDF = TF × `ln(N_activos / df)`. La entropía es `−Σ pᵢ ln pᵢ` con pᵢ la proporción de apariciones en el documento i, dividida por `ln(N_corpus)`; la concentración es uno menos ese valor. El resumen del TF-IDF incluye media, mediana, MAD (sin el factor 1,4826), desviación típica, percentil 75 y mediana entre documentos con peso positivo.
+++
