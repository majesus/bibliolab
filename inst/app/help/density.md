---
titulo: UMAP + HDBSCAN / Comprender el análisis
objetivo: Explorar grupos de documentos y su vocabulario con un flujo inspirado en BERTopic, íntegro en R, y comprobar cuánto dependen los grupos de los parámetros y de la semilla.
fuentes:
  - BERTopic / algoritmo | https://maartengr.github.io/BERTopic/algorithm/algorithm.html
  - uwot / UMAP | https://jlmelville.github.io/uwot/reference/umap.html
  - dbscan / HDBSCAN | https://search.r-project.org/CRAN/refmans/dbscan/html/hdbscan.html
---

## 1. Finalidad y funcionamiento

**Finalidad.** Buscar grupos de documentos y comprobar qué vocabulario los describe. No se fija de antemano cuántos grupos habrá.

**Datos de partida.** Cada documento se convierte en una lista de números que resume su vocabulario: eso es su representación numérica. TF-IDF y BM25 son dos reglas para asignar peso a las palabras. LSA resume esos valores en un número menor de coordenadas, llamadas dimensiones. Como alternativa puedes importar vectores externos, es decir, listas de números producidas por otro modelo, con su procedencia documentada.

**Cómo se encadenan los pasos.** UMAP calcula nuevas coordenadas procurando conservar qué documentos son vecinos según la representación elegida. HDBSCAN busca concentraciones de documentos en ese espacio: densidad significa aquí cuántos documentos hay próximos entre sí, no frecuencia de palabras. Puede dejar documentos sin asignar, que aparecen como grupo 0. c-TF-IDF asigna después pesos a las palabras de cada grupo para orientar su descripción; no decide el nombre ni confirma un tema.

**Qué muestra el mapa.** HDBSCAN agrupa inicialmente en cinco dimensiones. La figura de dos ejes se calcula aparte para facilitar la lectura: es una proyección y puede ocultar diferencias. Las posiciones y distancias del dibujo no bastan para interpretar los grupos.

**Cómo decidir.** Cambia una opción cada vez, guarda un resultado de referencia y lee documentos de cada grupo y del grupo 0. La semilla fija el inicio aleatorio de un cálculo; repetirla no demuestra estabilidad ante otras semillas.

**Scopus y Web of Science.** Se utilizan los documentos y campos preparados en 02. Comprueba qué textos y metadatos tienen datos: la misma regla de análisis no hace equivalentes dos búsquedas o exportaciones diferentes.

## 2. Ejemplo de lectura

Las cifras proceden de ejecutar el cálculo de la aplicación (`class_tfidf`) sobre un ejemplo ilustrativo de seis documentos y cuatro términos, repartidos en dos grupos de tres.

| Grupo | Término | c-TF-IDF | Apariciones en el grupo |
|---|---|---|---|
| 1 | hospital | 0,636 | 12 |
| 1 | salud | 0,318 | 6 |
| 2 | energía | 0,438 | 12 |
| 2 | edificio | 0,384 | 9 |

### Interpretación

c-TF-IDF reúne las apariciones de palabras de todos los documentos de un grupo y trata ese grupo como un texto conjunto, llamado «documento de clase». Divide los conteos entre el total de palabras de la clase y multiplica por `ln(1 + A / f_t)`, donde A es la media de palabras por clase y f_t las apariciones totales del término entre todas las clases. Así, «hospital» (12 apariciones en el grupo 1 y solo 1 en el 2) obtiene un peso alto en el grupo 1, mientras que «salud», presente en ambos, pesa menos. Los documentos sin asignar no entran en el vocabulario que describe los grupos. Los términos de c-TF-IDF describen la composición del grupo, no demuestran que el grupo sea un tema.

## 3. Parámetros y cómo decidir

### Decidir los parámetros sin cambiar toda la solución a la vez

Cada control tiene una nota breve y un botón **Cómo decidir**. El modal distingue qué modifica el ajuste, qué cambia solo la lectura y qué corresponde al análisis temporal adicional.

- **Representación:** comienza con la ruta léxica si no dispones de vectores externos documentados. TF-IDF y BM25 ponderan las palabras de modo distinto; compara contenido y longitud de los documentos que cambian de grupo.
- **Vecinos UMAP:** el inicio es 10. Contrasta 15 o 20 con la misma semilla y minPts; observa composición de grupos y documentos sin asignar, no solo separación visual.
- **minPts:** empieza con 5 y compara 10. En dbscan de R modifica tanto el tamaño mínimo de grupo como la estimación de densidad. No equivale a dos controles independientes de otras implementaciones.
- **LSA:** el máximo inicial es 30 dimensiones. Contrasta otro máximo si hay dimensiones útiles suficientes; son coordenadas de la representación, no temas.
- **Dimensiones para agrupar:** HDBSCAN recibe inicialmente 5. El mapa visible usa 2 calculadas por separado; que dos puntos parezcan próximos no asegura que sean vecinos en el espacio de agrupación.
- **min_dist:** 0 en el espacio de agrupación; contrasta 0,1 manteniendo el resto. La vista 2D utiliza 0,15 por separado. No es un radio de búsqueda de HDBSCAN.
- **Épocas y semilla:** 300 y 2026 son los valores iniciales. Más épocas dan más tiempo de optimización; otra semilla comprueba sensibilidad a la inicialización. Ninguna de las dos decisiones valida el contenido de los grupos.

Antes de aceptar una partición, lee documentos de cada grupo, casos poco característicos y documentos sin asignar. Utiliza la evaluación de estabilidad y sensibilidad para comprobar cuánto se mantienen las asignaciones.

### Primer recorrido

1. **Elige la representación.** *TF-IDF + LSA* funciona íntegramente en R y no usa BERT ni une idiomas por significado. En *Vectores precomputados* importas un CSV con `doc_id` u `original_id` y las dimensiones numéricas, y debes registrar el modelo y la versión que los creó; la aplicación alinea los identificadores y valida que cubran todos los documentos.
2. **Elige la ponderación.** TF-IDF o BM25 (ver *Elegir ponderación*). Con BM25 aparecen k1 (repeticiones) y b (longitud). El máximo de dimensiones LSA (30 por defecto) está en *Opciones avanzadas de LSA y UMAP*: en el primer recorrido puedes dejarlo como está.
3. **Fija los parámetros de UMAP.** *Vecinos* (10 por defecto) controla el alcance local: menos vecinos prestan más atención al entorno inmediato y más vecinos amplían el entorno; debe ser menor que el número de documentos. Las demás opciones están en *Opciones avanzadas de LSA y UMAP*, con el botón *Restablecer valores iniciales*: *dimensiones para agrupar* (5) son las que recibe HDBSCAN; *min_dist* (0) controla la compactación de los puntos en UMAP y no es un radio de búsqueda de HDBSCAN; *épocas* (300) fijan las iteraciones de optimización. Cámbialas de una en una, solo para comprobar la sensibilidad.
4. **Fija minPts de HDBSCAN** (5 por defecto). Un valor mayor exige grupos más grandes, modifica la estimación de densidad y puede dejar más documentos sin asignar.
5. **Fija la semilla** (2026) y calcula. Se necesitan al menos 10 documentos con vocabulario y no se admiten más de 3.000.
6. **Lee los resultados.** Usa la primera ejecución como hipótesis de trabajo: lee los textos de cada grupo con *Leer documentos representativos*, los casos de grado de pertenencia bajo y los documentos sin asignar.
7. **Estudia la sensibilidad.** Cambia un parámetro cada vez (vecinos 10 frente a 20; dimensiones 5 frente a 10; min_dist 0 frente a 0,1; minPts 5 frente a 10; semilla 2026 frente a 2027) y usa *Evaluar estabilidad y sensibilidad* para repetir el flujo con otras semillas y otros vecinos y minPts, midiendo cuánto cambian las asignaciones.
8. **Evolución temporal.** Describe cuánto pesan los grupos fijos en cada año con documentos con año válido; puedes comparar proporciones o una curva penalizada cuando haya cobertura suficiente. La tabla de palabras por año muestra vocabulario observado dentro del grupo, sin reentrenar ningún modelo dinámico.

## 4. Salidas, comprobaciones y límites

**El grado de pertenencia al grupo no es una probabilidad temática.** Es un valor de estabilidad individual dentro de la estructura de densidad estimada por HDBSCAN. La atipicidad indica cuánto se aparta un documento de esa estructura; un valor alto señala un caso que conviene revisar, no un error documental. Orientan la lectura, pero no son probabilidades calibradas de un tema.

**La semilla da repetibilidad, no estabilidad.** La semilla controla las operaciones aleatorias de UMAP y de la aproximación de LSA con matrices grandes. HDBSCAN recibe las coordenadas resultantes y es determinista sobre una matriz fija. Cambiar la semilla puede cambiar los grupos; repetir con la misma semilla no demuestra que los grupos sean reproducibles con otra.

**El ARI mide acuerdo entre agrupaciones.** El **índice de Rand ajustado (ARI)** compara dos agrupaciones del mismo conjunto de documentos: vale 1 con acuerdo total y 0 con el acuerdo esperable por azar. La **persistencia** compara sus documentos con los de cada grupo de otra semilla mediante Jaccard: documentos compartidos divididos entre documentos distintos de ambos grupos. Se conserva la mejor coincidencia; 1 significa los mismos documentos y 0 ninguno compartido. Confía sobre todo en los grupos que persisten entre semillas y parámetros vecinos. Un ARI bajo indica que la partición depende de la ejecución; no indica que los documentos no tengan estructura.

**Cero grupos es un resultado válido.** Si HDBSCAN no encuentra regiones densas con esos parámetros, todos los documentos quedan sin asignar. Compara con otros valores de minPts antes de concluir nada.

**Qué comprobar.** Que la proporción sin asignar es razonable para tu corpus, que los textos de cada grupo se parecen entre sí más que a los de otros grupos y que los grupos que vas a describir persisten con otra semilla.

## 5. Cómo documentar la decisión

Informa la representación, los vecinos, las dimensiones, min_dist, minPts, la semilla y la proporción sin asignar. Una redacción modelo, que debes completar con tus cifras: «Se agruparon los documentos mediante UMAP ([vecinos] vecinos, [dimensiones] dimensiones, min_dist = [valor]) y HDBSCAN (minPts = [valor]) sobre una representación [TF-IDF/BM25 con LSA de [d] dimensiones]. El [x] % de los documentos quedó sin asignar. La estabilidad se evaluó con [n] semillas (ARI entre [mín.] y [máx.]); los grupos se interpretaron tras leer [m] documentos representativos por grupo».

No presentes los grupos como taxonomías validadas, y no describas la ruta léxica como un análisis con BERT si no importaste vectores de ese origen.

+++ Nota técnica: representación y algoritmos
Ruta léxica (`lsa_vectors()`): TF por unidad, IDF suavizado `ln((N + 1) / (df + 1)) + 1` (o pesos BM25), normalización L2 de cada fila, descomposición en valores singulares (`svd` si la menor dimensión es 60 o menos, `irlba::irlba` en otro caso) y proyección `U·D`, que se vuelve a normalizar. `uwot::umap()` usa distancia coseno e inicialización aleatoria, con 2 a 10 dimensiones para agrupar; `dbscan::hdbscan()` se ejecuta en ese espacio con `minPts`. El mapa bidimensional es una proyección independiente con `min_dist = 0,15`; el agrupamiento no se recalcula sobre los dos ejes dibujados. En dbscan, minPts controla el tamaño mínimo y la suavización de la estimación de densidad, y no replica los dos parámetros de otras implementaciones. c-TF-IDF (`class_tfidf()`): conteos agregados por grupo, divididos entre las palabras de la clase y multiplicados por `ln(1 + A / f_t)`. El mapa de similitud compara los vectores c-TF-IDF de los grupos con el coseno. Límites: mínimo 10 documentos con vocabulario y máximo 3.000; `minPts` y los vecinos deben ser menores que el número de documentos. Referencias: ARI, Hubert y Arabie (1985); persistencia por Jaccard, Hennig (2007).
+++
