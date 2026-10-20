---
titulo: UMAP → HDBSCAN → c-TF-IDF
objetivo: Explorar grupos de documentos y su vocabulario con un flujo inspirado en BERTopic, íntegro en R, y comprobar cuánto dependen los grupos de los parámetros y de la semilla.
fuentes:
  - BERTopic / algoritmo | https://maartengr.github.io/BERTopic/algorithm/algorithm.html
  - uwot / UMAP | https://jlmelville.github.io/uwot/reference/umap.html
  - dbscan / HDBSCAN | https://search.r-project.org/CRAN/refmans/dbscan/html/hdbscan.html
---

## 1. Conceptos fundamentales: de los textos a los grupos

**Lo que quieres saber.** Si tus documentos forman grupos de contenido parecido y qué vocabulario describe cada grupo.

**Lo que se calcula realmente.** El procedimiento tiene cuatro etapas encadenadas. Primero se necesita una **representación numérica** de cada documento: la ruta léxica pondera los términos (TF-IDF o BM25) y resume ese vocabulario en pocas dimensiones mediante **LSA** (análisis semántico latente, una descomposición en valores singulares); la ruta alternativa importa vectores externos con procedencia documentada. Segundo, **UMAP** reduce esa representación a unas pocas dimensiones intentando conservar los vecindarios. Tercero, **HDBSCAN** busca en esas coordenadas regiones densas de documentos y deja sin asignar los que no pertenecen a ninguna. Cuarto, **c-TF-IDF** describe cada grupo con las palabras que lo distinguen de los demás.

Un grupo reúne documentos por el procedimiento y los parámetros elegidos, no por una categoría verdadera ya conocida. El **grupo 0** conserva los documentos sin asignar; no es un error ni un tema adicional. El mapa de dos ejes se calcula aparte para poder verlo: HDBSCAN trabaja en el espacio de agrupación (por defecto, cinco dimensiones), aunque en pantalla solo haya dos.

> **La analogía cotidiana:**
>
> Es como ordenar a los invitados de una fiesta según quién conversa con quién: se forman corrillos densos, hay gente que circula entre ellos y hay personas que están solas. El mapa es una foto aérea; los corrillos son lo que se ve, no lo que se ha decidido de antemano.
>
> **Dónde deja de servir la analogía:** en la fiesta, la gente se agrupa por una relación real. Aquí las distancias entre documentos dependen del vocabulario y de los parámetros de la reducción, y UMAP puede deformar las distancias globales: la cercanía en el mapa es una pista de lectura, no una medida de semejanza temática.

## 2. Ejemplo práctico: qué hace c-TF-IDF con dos grupos

Las cifras proceden de ejecutar el cálculo de la aplicación (`class_tfidf`) sobre un ejemplo ilustrativo de seis documentos y cuatro términos, repartidos en dos grupos de tres.

| Grupo | Término | c-TF-IDF | Apariciones en el grupo |
|---|---|---|---|
| 1 | hospital | 0,636 | 12 |
| 1 | salud | 0,318 | 6 |
| 2 | energía | 0,438 | 12 |
| 2 | edificio | 0,384 | 9 |

### Interpretación

c-TF-IDF une los documentos de cada grupo en un solo «documento de clase», divide los conteos entre el total de palabras de la clase y multiplica por `ln(1 + A / f_t)`, donde A es la media de palabras por clase y f_t las apariciones totales del término entre todas las clases. Así, «hospital» (12 apariciones en el grupo 1 y solo 1 en el 2) obtiene un peso alto en el grupo 1, mientras que «salud», presente en ambos, pesa menos. Los documentos sin asignar no entran en el vocabulario que describe los grupos. Los términos de c-TF-IDF describen la composición del grupo, no demuestran que el grupo sea un tema.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige la representación.** *TF-IDF + LSA* funciona íntegramente en R y no usa BERT ni une idiomas por significado. En *Vectores precomputados* importas un CSV con `doc_id` u `original_id` y las dimensiones numéricas, y debes registrar el modelo y la versión que los creó; la aplicación alinea los identificadores y valida que cubran todos los documentos.
2. **Elige la ponderación.** TF-IDF o BM25 (ver *Elegir ponderación*). Con BM25 aparecen k1 (repeticiones) y b (longitud). El máximo de dimensiones LSA (30 por defecto) está en *Opciones avanzadas de LSA y UMAP*: en el primer recorrido puedes dejarlo como está.
3. **Fija los parámetros de UMAP.** *Vecinos* (10 por defecto) controla el alcance local: menos vecinos prestan más atención al entorno inmediato y más vecinos amplían el entorno; debe ser menor que el número de documentos. Las demás opciones están en *Opciones avanzadas de LSA y UMAP*, con el botón *Restablecer valores iniciales*: *dimensiones para agrupar* (5) son las que recibe HDBSCAN; *min_dist* (0) controla la compactación de los puntos en UMAP y no es un radio de búsqueda de HDBSCAN; *épocas* (300) fijan las iteraciones de optimización. Cámbialas de una en una, solo para comprobar la sensibilidad.
4. **Fija minPts de HDBSCAN** (5 por defecto). Un valor mayor exige grupos más grandes, modifica la estimación de densidad y puede dejar más documentos sin asignar.
5. **Fija la semilla** (2026) y calcula. Se necesitan al menos 10 documentos con vocabulario y no se admiten más de 3.000.
6. **Lee los resultados.** Usa la primera ejecución como hipótesis de trabajo: lee los textos de cada grupo con *Leer documentos representativos*, los casos de grado de pertenencia bajo y los documentos sin asignar.
7. **Estudia la sensibilidad.** Cambia un parámetro cada vez (vecinos 10 frente a 20; dimensiones 5 frente a 10; min_dist 0 frente a 0,1; minPts 5 frente a 10; semilla 2026 frente a 2027) y usa *Evaluar estabilidad y sensibilidad* para repetir el flujo con otras semillas y otros vecinos y minPts, midiendo cuánto cambian las asignaciones.
8. **Evolución temporal.** Describe cuánto pesan los grupos fijos en cada año con documentos con año válido; puedes comparar proporciones o una curva penalizada cuando haya cobertura suficiente. La tabla de palabras por año muestra vocabulario observado dentro del grupo, sin reentrenar ningún modelo dinámico.

## 4. Cómo leer el resultado sin errores de interpretación

**El grado de pertenencia al grupo no es una probabilidad temática.** Es el grado en que un documento pertenece a su grupo en la estimación de densidad de HDBSCAN; la atipicidad es una puntuación de valores atípicos. Orientan la lectura, pero no son probabilidades calibradas de un tema.

**La semilla da repetibilidad, no estabilidad.** La semilla controla las operaciones aleatorias de UMAP y de la aproximación de LSA con matrices grandes. HDBSCAN recibe las coordenadas resultantes y es determinista sobre una matriz fija. Cambiar la semilla puede cambiar los grupos; repetir con la misma semilla no demuestra que los grupos sean reproducibles con otra.

**El ARI mide acuerdo entre agrupaciones.** El **índice de Rand ajustado (ARI)** compara dos agrupaciones del mismo conjunto de documentos: vale 1 con acuerdo total y 0 con el acuerdo esperable por azar. La **persistencia** de un grupo es el mayor índice de Jaccard con un grupo de otra semilla. Confía sobre todo en los grupos que persisten entre semillas y parámetros vecinos. Un ARI bajo indica que la partición depende de la ejecución; no indica que los documentos no tengan estructura.

**Cero grupos es un resultado válido.** Si HDBSCAN no encuentra regiones densas con esos parámetros, todos los documentos quedan sin asignar. Compara con otros valores de minPts antes de concluir nada.

**Qué comprobar.** Que la proporción sin asignar es razonable para tu corpus, que los textos de cada grupo se parecen entre sí más que a los de otros grupos y que los grupos que vas a describir persisten con otra semilla.

## 5. Pautas para documentar y redactar tu decisión

Informa la representación, los vecinos, las dimensiones, min_dist, minPts, la semilla y la proporción sin asignar. Una redacción modelo, que debes completar con tus cifras: «Se agruparon los documentos mediante UMAP ([vecinos] vecinos, [dimensiones] dimensiones, min_dist = [valor]) y HDBSCAN (minPts = [valor]) sobre una representación [TF-IDF/BM25 con LSA de [d] dimensiones]. El [x] % de los documentos quedó sin asignar. La estabilidad se evaluó con [n] semillas (ARI entre [mín.] y [máx.]); los grupos se interpretaron tras leer [m] documentos representativos por grupo».

No presentes los grupos como taxonomías validadas, y no describas la ruta léxica como un análisis con BERT si no importaste vectores de ese origen.

+++ Nota técnica: representación y algoritmos
Ruta léxica (`lsa_vectors()`): TF por unidad, IDF suavizado `ln((N + 1) / (df + 1)) + 1` (o pesos BM25), normalización L2 de cada fila, descomposición en valores singulares (`svd` si la menor dimensión es 60 o menos, `irlba::irlba` en otro caso) y proyección `U·D`, que se vuelve a normalizar. `uwot::umap()` usa distancia coseno e inicialización aleatoria, con 2 a 10 dimensiones para agrupar; `dbscan::hdbscan()` se ejecuta en ese espacio con `minPts`. El mapa bidimensional es una proyección independiente con `min_dist = 0,15`; el agrupamiento no se recalcula sobre los dos ejes dibujados. En dbscan, minPts controla el tamaño mínimo y la suavización de la estimación de densidad, y no replica los dos parámetros de otras implementaciones. c-TF-IDF (`class_tfidf()`): conteos agregados por grupo, divididos entre las palabras de la clase y multiplicados por `ln(1 + A / f_t)`. El mapa de similitud compara los vectores c-TF-IDF de los grupos con el coseno. Límites: mínimo 10 documentos con vocabulario y máximo 3.000; `minPts` y los vecinos deben ser menores que el número de documentos. Referencias: ARI, Hubert y Arabie (1985); persistencia por Jaccard, Hennig (2007).
+++
