---
titulo: Frecuencia, presencia y especificidad de los términos
objetivo: Comparar tres formas de medir una palabra (cuánto se repite, en cuántos textos aparece y qué textos distingue) y leer lo que cada una responde.
fuentes:
  - Stanford / ponderación TF-IDF | https://nlp.stanford.edu/IR-book/html/htmledition/tf-idf-weighting-1.html
  - R / cuantiles de tipo 7 | https://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html
---

## 1. Conceptos fundamentales: tres preguntas distintas sobre la misma palabra

**Para situarte.** Término significa palabra después de la limpieza. Presencia cuenta documentos distintos con esa palabra; frecuencia cuenta sus apariciones, incluidas las repeticiones. Una unidad es un documento completo o una frase, según 02: algunos pesos se calculan por unidad y la presencia sigue contándose por documento.

**Lo que quieres saber.** Qué palabras son importantes en tu corpus. La aplicación no puede responder a esa pregunta tal como está formulada, porque esta pantalla no dispone de una medida única de importancia científica. Lo que sí mide son tres cosas diferentes, y cada una responde a una pregunta distinta.

La **frecuencia** responde a «¿cuánto se repite?»: cuenta apariciones. Diez repeticiones en un solo resumen suman diez, aunque exista un único documento. La **presencia** responde a «¿en cuántos textos aparece?»: cuenta documentos distintos, de modo que esas diez repeticiones en el mismo resumen cuentan como presencia en un documento. La **especificidad** responde a «¿qué textos distingue?»: el **TF-IDF** pondera el uso relativo de la palabra en cada texto (TF) por su rareza entre los textos (IDF), de modo que una palabra que comparten todos los textos pesa cero.

## 2. Ejemplo práctico: cuatro palabras, cuatro perfiles

Las cifras proceden de ejecutar la aplicación sobre un corpus ilustrativo de cuatro resúmenes de diez palabras cada uno, sin eliminar palabras vacías.

La tabla de términos que obtiene la aplicación es la siguiente.

| Término | Frecuencia | Presencia (documentos) | Presencia (%) | TF-IDF medio | Entropía normalizada |
|---|---|---|---|---|---|
| datos | 21 | 4 | 100 | 0,000 | 0,969 |
| metodo | 12 | 4 | 100 | 0,000 | 1,000 |
| hospital | 4 | 1 | 25 | 0,139 | 0,000 |
| salud | 3 | 2 | 50 | 0,052 | 0,459 |

### Interpretación

«Datos» es la palabra más repetida y aparece en todos los textos, pero no distingue ninguno: su TF-IDF medio es cero. «Hospital» solo se repite cuatro veces, pero las concentra en un único documento, y obtiene el mayor TF-IDF medio entre estas cuatro palabras: 0,139. Eso describe su peso en esta ponderación; no comprueba un tema. «Salud» ocupa un lugar intermedio. Un valor cero no significa que una palabra sea inútil: «datos» puede ser un concepto indispensable para describir el campo; significa únicamente que no ayuda a diferenciar estos cuatro textos entre sí.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige qué términos mostrar primero.** *Qué términos mostrar primero* ordena por frecuencia, por presencia o por un resumen del TF-IDF (media, mediana, percentil 75 o 90, versiones restringidas a las unidades con peso positivo, o el estadístico elegido en Preparación).
2. **Elige el vocabulario que quieres consultar.** *Evaluado* incluye los términos retenidos y los excluidos por tus reglas; *Solo retenido* y *Solo excluido* los separan. La nota situada sobre las barras indica cuántos términos se evaluaron, cuántos se retuvieron y cuántos se excluyeron.
3. **Lee las barras.** Las tres barras de una fila corresponden al mismo término y tienen escalas distintas. La tercera usa el estadístico TF-IDF que elegiste; si ordenas por frecuencia o por presencia, muestra la media global.
4. **Explora el mapa.** Cada punto es un término. El eje horizontal es la presencia en documentos (%) y el eje vertical es el TF-IDF medio por unidad. Los puntos rojos están retenidos y los grises, excluidos. Con *Localizar un término* se marca el término elegido con un contorno.
5. **Consulta la tabla.** Contiene las cifras exactas (frecuencia, presencia, TF-IDF medio, desviación típica, mediana, MAD, cuartiles, percentil 90, BM25 medio y entropía) y si el término está retenido. Usa *Ver tabla* cuando necesites una cifra para el informe.

## 4. Cómo leer los indicadores sin errores de interpretación

**Cómo leer los resúmenes numéricos.** La media suma los pesos y divide por el número de unidades; la mediana es el valor central ordenado (o la media de los dos centrales). El percentil 75 es el valor de referencia por debajo del que queda aproximadamente el 75 % de los pesos ordenados. La desviación típica y la MAD describen dispersión: la MAD toma la mediana de las distancias absolutas respecto a la mediana. No miden calidad ni significado.

**El TF-IDF no mide importancia científica.** Mide uso relativo y rareza entre las unidades de este corpus. Un término compartido por todos distingue poco; eso no implica que carezca de importancia para tu pregunta.

**La media no es una convención obligatoria.** Es una forma de resumir pesos. La mediana y los percentiles globales incluyen los ceros y pueden empatar en cero en vocabularios dispersos (un término con peso 0 en más de la mitad de las unidades tiene mediana 0). Los resúmenes con peso positivo describen solo las unidades donde el peso es mayor que cero. Compara siempre la presencia.

**Las cifras dependen de cómo preparaste el corpus.** El IDF usa solo las unidades que conservan palabras tras la limpieza; si cambias a frases como unidad, el TF y el IDF se calculan por frase, mientras que la presencia sigue contándose por documento. La entropía normalizada mide cómo se reparten las apariciones entre documentos: 0 es concentración en uno y cerca de 1 es reparto uniforme; un valor alto no implica que una palabra sea inútil.

**Qué comprobar.** Que el término que te interesa no está excluido por una regla que no pretendías aplicar, que su presencia es suficiente para que su TF-IDF medio no dependa de uno o dos documentos, y que la lectura coincide con lo que ves al leer los resúmenes.

## 5. Pautas para documentar y redactar tu decisión

Puedes escribir, completando los corchetes con las cifras de tu corpus: «El término [término] aparece [f] veces en [d] de los [N] documentos ([p] %) y su TF-IDF medio es [t]; estas cifras describen el corpus preparado y no establecen por sí solas la relevancia del término».

Es una redacción modelo que debes revisar antes de copiarla. Indica también las reglas de vocabulario que estaban activas, porque cambian qué términos se evalúan y los valores del TF-IDF.

+++ Nota técnica: definiciones
Para cada unidad, TF es la proporción del término entre las palabras de esa unidad, e IDF es `ln(N / df)`, donde N es el número de unidades con palabras y df el número de esas unidades que contienen el término. El TF-IDF medio del término es el promedio de su peso en todas las unidades con palabras, ceros incluidos. La presencia en porcentaje es `100 × documentos / nrow(docs)`. La entropía normalizada es `−Σ p_d ln p_d / ln(nrow(docs))`, donde `p_d` es la proporción de las apariciones del término que cae en el documento d. La desviación MAD se calcula sin el factor 1,4826, y los percentiles son de tipo 7 de R.
+++
