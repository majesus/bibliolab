---
titulo: Lectura enlazada / del término al documento y a tu interpretación
objetivo: Entender qué relaciona la red de conceptos, qué filtros aplica antes de calcular comunidades y roles, y cómo conservar tu interpretación sin confundir coaparición con vínculo.
fuentes:
  - Benjamini y Hochberg / control de la tasa de falsos descubrimientos | https://doi.org/10.1111/j.2517-6161.1995.tb02031.x
  - Tumminello et al. / redes estadísticamente validadas | https://doi.org/10.1371/journal.pone.0017994
  - Guimerà y Amaral / roles en comunidades | https://doi.org/10.1038/nature03288
  - Blondel et al. / algoritmo de Louvain | https://doi.org/10.1088/1742-5468/2008/10/P10008
  - Obsidian / enlaces y backlinks | https://help.obsidian.md/plugins/backlinks
---

## 1. Conceptos fundamentales: de la palabra al documento

**Lo que quieres saber.** Qué palabras tienden a aparecer en las mismas fichas, qué papel cumple cada una en el conjunto y dónde puedes volver a leer el texto que respalda cada relación.

**Lo que se calcula realmente.** Cada documento es una **ficha** (una página del cuaderno) con el campo de texto que elegiste. Cada palabra o **concepto** tiene su propia ficha, que lista como **backlinks** todas las fichas que lo mencionan. La red de conceptos no dibuja las fichas, sino las palabras: dos conceptos se conectan por **coaparición** cuando figuran juntos en las mismas fichas.

El peso de la conexión es el **coeficiente de Jaccard**: las fichas con ambas palabras divididas entre las fichas con al menos una. Repetir una palabra dentro de una ficha no aumenta ese peso. Una coaparición se considera **significativa** cuando una prueba hipergeométrica indica que es mayor que la esperable por azar si cada palabra se repartiera independientemente entre las fichas, manteniendo fija su frecuencia documental, y se corrige por comparaciones múltiples (Benjamini–Hochberg, FDR). Después, el algoritmo de Louvain agrupa las palabras en **comunidades** y la tipología de Guimerà y Amaral asigna un **rol** a cada una (eje, puente, apoyo).

> **La analogía cotidiana:**
>
> Es como el índice de materias de un libro, donde cada término remite a las páginas en que aparece: dos términos con muchas páginas en común están relacionados en el texto, pero el índice no dice por qué ni si los autores los vinculan.
>
> **Dónde deja de servir la analogía:** un índice es un listado fijo. Aquí la red depende de las palabras que elijas, del nivel de significación y de cuántas relaciones conserves, y cada una de esas decisiones cambia las comunidades y los roles.

## 2. Ejemplo práctico: siete conceptos en veinte fichas

Los resultados se han obtenido ejecutando el cálculo de la aplicación sobre un corpus ilustrativo de veinte fichas y siete conceptos. «Salud», «hospital» y «paciente» aparecen sobre todo en las fichas 1 a 8; «energía», «edificio» y «eficiencia», en las fichas 9 a 16; «datos» figura en las veinte, y hay dos coapariciones ocasionales entre ambos grupos.

| Relación | Fichas con ambas | Jaccard | p ajustada | Con FDR al 5 % |
|---|---|---|---|---|
| salud – hospital | 8 | 0,80 | 0,006 | Se conserva |
| energía – eficiencia | 8 | 0,89 | 0,002 | Se conserva |
| energía – edificio | 6 | 0,60 | 0,043 | Se conserva |
| salud – datos | 9 | 0,45 | 1,000 | Se descarta |
| salud – energía | 1 | 0,06 | 1,000 | Se descarta |

Sin filtro de significación, la red conserva 14 pares con coaparición observada, entre ellos los seis pares de «datos» con cada una de las otras palabras. Con FDR al 5 %, quedan 6 relaciones y «datos» queda sin relaciones. «Datos» aparece en todas las fichas, así que coincide con cualquier palabra tanto como cabe esperar por frecuencia; su coaparición con «salud» no es mayor que la esperable por azar, aunque su Jaccard (0,45) parezca alto.

### Interpretación

El Jaccard describe cuánto coinciden dos palabras; la prueba responde si esa coincidencia supera lo esperable dadas sus frecuencias. Una palabra presente en casi todas las fichas se asocia con todo y aporta poca información, y por eso la aplicación avisa de las palabras presentes en más del 30 % de las fichas y permite fijar un techo de fichas para excluirlas. Con FDR al 5 %, los dos grupos forman dos comunidades (modularidad 0,50) y los seis conceptos quedan como «Apoyo exclusivo de su comunidad» (participación 0): no hay ningún puente, porque ninguna palabra reparte sus relaciones entre comunidades.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige de dónde salen los conceptos.** *Vocabulario preparado* usa los términos retenidos en Preparación; si lematizaste, «estudiante» y «estudiantes» pueden aparecer bajo «estudiante», y conviene contrastar con el original. *Diccionario del investigador* busca en los originales los conceptos que escribes (uno por línea, variantes separadas por `|`, por ejemplo «salud mental | mental health»); la aplicación no traduce ni añade sinónimos, y solo reúne las variantes que tú declaras. Pulsa *Crear índice de lectura*.
2. **Elige la red y calcúlala.** En *Conceptos*, define cómo se eligen las palabras (por número de fichas, DF, o por TF-IDF en suma), el techo de fichas, el número de palabras (100 por defecto), el filtro de significación (casilla activada por defecto; nivel de FDR de 0,001 a 0,5, 0,05 por defecto; desmarcar la casilla desactiva el filtro), las relaciones más fuertes por palabra (3 por defecto; 0 conserva todas), el mínimo de fichas con ambos conceptos, el Jaccard mínimo y la resolución de Louvain. Pulsa *Calcular red y comunidades*: solo este paso recalcula la red, y si cambias un valor sin recalcular, el grafo se sustituye por un aviso.
3. **Lee la definición y el resumen** antes del dibujo: cuántas palabras entran, cuántos pares se contrastan, cuántos resultan significativos y cuántas relaciones se conservan.
4. **Busca y resalta** una palabra o una comunidad en el dibujo; estos controles y los ajustes del dibujo no recalculan.
5. **Abre la ficha de un concepto** para ver las fichas que lo mencionan y las concordancias (la expresión con sus palabras anteriores y posteriores); pulsa una línea del grafo para ver las fichas que respaldan esa relación.
6. **Escribe tu interpretación en notas** con enlaces `[[concepto]]` o `[[ID]]`: aparecen como líneas discontinuas con flecha y como backlinks en la página de destino. Si el destino no se reconoce, queda señalado como pendiente.
7. **Descarga antes de cerrar.** Las notas viven en la memoria de la sesión; descarga la copia JSON para restaurarlas y la carpeta Markdown para abrirla como bóveda en Obsidian. Una entrada distinta no hereda notas solo por compartir un ID: se compara la huella de columnas y valores.

## 4. Cómo leer la red sin errores de interpretación

**Una coaparición no es una cita ni un vínculo semántico.** Indica que dos palabras tienden a aparecer en las mismas fichas; no demuestra causalidad, sinonimia, acuerdo entre autores ni que se citen.

**Limitar las relaciones por palabra es un filtro del análisis.** Se aplica antes de calcular las comunidades, de modo que modifica el grafo analizado y, con él, las comunidades, la modularidad y los roles. En el ejemplo, pasar de 3 a 1 relación por palabra reduce las relaciones de 6 a 4 (las comunidades se mantienen, pero con más conceptos pueden cambiar). Al cambiar solo este valor y recalcular, la aplicación muestra junto a la lectura cuántos enlaces, comunidades y qué modularidad había antes y hay ahora. Repite el análisis con otros valores y presenta solo lo que se mantiene.

**Un valor alto de modularidad no demuestra que una solución sea mejor.** Compara resoluciones (por ejemplo 0,5 y 1,5) y lee las fichas.

**Sin filtro de significación no hay atribución de significación.** Con la casilla del filtro desmarcada la red solo contiene pares con coaparición observada, y todo texto debe describirlos así.

**Con TF-IDF en suma o en media, el orden es el mismo.** Para los mismos pesos sobre las mismas fichas, la media es la suma dividida por un número constante de fichas, y el orden no cambia. Las diferencias entre variantes proceden de cómo se pondera cada aparición (aquí, `ln(1 + frecuencia)` multiplicado por `ln(N / DF)`) o de promediar solo entre fichas con peso positivo; la frecuencia documental (DF) es una elección adecuada para estudiar presencia conjunta.

**Los roles dependen de las relaciones conservadas.** Con pocas relaciones, el coeficiente de participación es poco fiable; el listado de roles muestra las relaciones de cada palabra para valorarlo.

**La prueba condiciona a la frecuencia documental.** No modela que unas fichas sean más largas que otras, y la corrección de Benjamini–Hochberg supone independencia o ciertas formas de dependencia positiva entre contrastes. Las comunidades de Louvain son exploratorias, no temas validados.

**Qué comprobar.** Que las palabras generales no dominan, que la conclusión se mantiene al variar N, el nivel de significación, las relaciones por palabra y la resolución, y que las fichas respaldan la lectura.

## 5. Pautas para documentar y redactar tu decisión

Describe la fuente del vocabulario, las variantes, los filtros y el nivel de significación: «Se construyó una red de coaparición de [N] palabras (las de mayor frecuencia documental, [con / sin] techo de [x] % de fichas), ponderada por Jaccard. Se conservaron las coapariciones con p ajustada ≤ [α] (Benjamini–Hochberg) y, para cada palabra, sus [k] relaciones más fuertes. Louvain (resolución [r], semilla [s]) identificó [c] comunidades (modularidad [Q])».

Es una redacción modelo que debes completar con tus valores. Si el filtro de significación está desactivado, escribe «pares con coaparición observada» y no «coapariciones significativas». Un grafo vistoso no es una validación semántica: sostén la lectura con concordancias y con los textos originales.

+++ Nota técnica: cálculo
La frecuencia documental (DF) de un concepto es el número de fichas con al menos una mención. El peso es `J = c / (DF_A + DF_B − c)`, con c las fichas con ambos conceptos. El valor p de cada par es la cola superior de la distribución hipergeométrica, `P(X ≥ c)` con `N` fichas, `DF_A` éxitos y `DF_B` extracciones, ajustado por Benjamini–Hochberg sobre la familia completa de `n(n − 1)/2` pares (los pares sin coaparición tienen p = 1). El mínimo de fichas compartidas y el Jaccard mínimo son filtros descriptivos posteriores que no alteran esa familia. La reducción por palabra conserva, entre las candidatas, las `k` relaciones de mayor Jaccard de cada nodo (unión de ambos extremos; empates por orden). Louvain se ejecuta sobre el grafo filtrado, ponderado por Jaccard, con la semilla y la resolución elegidas. Los roles usan `z` (grado dentro de la comunidad estandarizado con la desviación típica poblacional de su comunidad) y `P = 1 − Σ (kᵢ/k)²`: eje si `z ≥ 2,5`; entre los no ejes, apoyo si `P ≤ 0,62` y puente si `P > 0,62`; entre los ejes, eje si `P ≤ 0,30`, y eje y puente si `P > 0,30`. El TF-IDF en suma es `Σ ln(1 + frecuencia) · ln(N / DF)` sobre las fichas de cada palabra.
+++
