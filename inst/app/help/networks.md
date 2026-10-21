---
titulo: Redes / relaciones e indicadores
objetivo: Definir qué representa cada conexión, cómo se pesa y qué miden los indicadores, antes de interpretar el dibujo.
fuentes:
  - igraph / centralidad armónica | https://r.igraph.org/reference/harmonic_centrality.html
  - igraph / comunidades | https://igraph.org/r/html/latest/cluster_louvain.html
---

## 1. Conceptos fundamentales: una red es una definición, no un dibujo

**Para situarte.** Un nodo es un elemento dibujado como punto, por ejemplo un autor. Una conexión es una línea entre dos nodos y responde a la relación elegida, como firmar el mismo artículo. Su peso es el valor numérico asignado a esa relación. Grafo y red se refieren aquí al mismo conjunto de nodos y conexiones.

**Lo que quieres saber.** Quién o qué está conectado con quién, y qué posición ocupa cada elemento.

**Lo que se calcula realmente.** Una **red** representa entidades como **nodos** y una relación definida como **conexiones**. Los autores se conectan por coautoría (firman un mismo documento); las palabras, por copresencia (aparecen en un mismo documento); las referencias, por cocitación (un mismo documento las cita a ambas); los documentos, por acoplamiento bibliográfico (comparten referencias); y las revistas, en esta aplicación, por afinidad léxica (comparten términos retenidos entre sus artículos). Son preguntas distintas, aunque todas se dibujen como puntos y líneas.

La **disposición** solo ayuda a ver conexiones: arrastrar un nodo no cambia la relación medida, sus pesos ni los indicadores. Las **comunidades** se calculan a partir de las conexiones y sus pesos, no por cercanía visual. Los indicadores dependen de los nodos y las conexiones que has conservado.

## 2. Ejemplo práctico: coautoría con conteo completo y fraccionado

Los resultados de este apartado se han obtenido ejecutando el cálculo de la aplicación sobre cinco documentos ilustrativos, firmados por: Ana, Luis y Eva; Ana y Luis; Ana y Eva; Marta y Pablo; Eva y Marta.

Con el **conteo completo**, cada documento añade 1 a cada pareja de autores que lo firman. Ana–Luis y Ana–Eva obtienen un peso 2; Luis–Eva, Eva–Marta y Marta–Pablo, un peso 1. Con el **conteo fraccionado**, cada documento reparte una unidad entre todas sus parejas: el documento de tres autores genera tres parejas y cada una recibe un tercio. Entonces Ana–Luis y Ana–Eva pesan 1 + 1/3 = 1,333, Luis–Eva pesa 0,333, y las otras dos parejas siguen pesando 1. Si después limitas el dibujo a Ana y Luis, el peso sigue siendo el mismo: el límite del gráfico no cambia la aportación original.

| Autor | Grado (vecinos) | Fuerza (conteo completo) | Intermediación | ¿Articulación? |
|---|---|---|---|---|
| Ana | 2 | 4 | 0,00 | No |
| Eva | 3 | 4 | 0,67 | Sí |
| Luis | 2 | 3 | 0,00 | No |
| Marta | 2 | 2 | 0,50 | Sí |
| Pablo | 1 | 1 | 0,00 | No |

### Interpretación

Ana y Eva tienen la misma fuerza (4), pero Eva tiene un vecino más (grado 3) y conecta los dos equipos: si se retira, la red se divide en dos partes. Esa es una **articulación**. Describe una posición en esta red; no demuestra liderazgo ni prestigio. Con la partición de Louvain, la red tiene dos comunidades (Ana, Eva y Luis; Marta y Pablo), con una modularidad de 0,19.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige la entidad y la relación.** *Entidades y relación* define los nodos y la regla de conexión. Las redes de referencias y de documentos necesitan la columna de referencias citadas.
2. **Elige el peso de las conexiones.** *Completo* cuenta coincidencias; *Fraccionado* hace que cada documento aporte 1 repartido entre sus parejas; *Coseno* normaliza por la presencia de cada nodo; *Fuerza de asociación* divide las coincidencias por el producto de las presencias documentales de los dos nodos: una misma coincidencia recibe distinto peso según lo extendidos que estén. Ese peso no es una probabilidad ni una prueba de asociación. Las redes de revistas y de acoplamiento usan siempre el coseno.
3. **Fija los filtros.** *Presencia mínima*, *máximo de nodos* (se eligen los más presentes), *coincidencias mínimas por conexión* y *máximo de conexiones de mayor peso* (0 = todas) reducen el grafo a algo legible. Estos filtros cambian la red sobre la que se calculan los indicadores y las comunidades; no simplifican solo el dibujo ni son pruebas estadísticas; para palabras, la primera vista empieza con 30 nodos, 120 conexiones, presencia y coincidencia mínimas de 3 y fuerza de asociación.
4. **Elige el método de comunidades** (Louvain, con su resolución, o Walktrap) y la semilla de la disposición y de las comunidades. Pulsa *Calcular red*.
5. **Lee primero la definición de la conexión** que muestra la aplicación, después el resumen de indicadores y por último el dibujo.
6. **Comprueba las conclusiones** del dibujo en la tabla de conexiones y en la auditoría (cuántos nodos y conexiones se descartaron en cada filtro).
7. **Para estudiar una zona**, extrae un subgrafo (ver su guía); sus indicadores se recalculan y no son los de la red completa.

## 4. Cómo leer los indicadores sin errores de interpretación

| Indicador | Qué mide | Precaución |
|---|---|---|
| Grado / fuerza | Número de vecinos / suma de pesos | Conectividad e intensidad son cosas distintas |
| Densidad | Conexiones observadas entre las posibles | Depende del número de nodos conservados |
| Componentes | Partes separadas: dentro de cada una se puede ir de un nodo a otro siguiendo conexiones; un aislado forma una por sí solo | Varias componentes pueden deberse a los umbrales |
| Intermediación | Fracción normalizada de caminos mínimos que pasan por el nodo | Se calcula en saltos, sin pesos |
| Centralidad armónica | Media de los inversos de las distancias en saltos | Los nodos inalcanzables aportan cero |
| Agrupamiento / transitividad | Mide si dos vecinos de un nodo también están conectados entre sí, formando un triángulo | El local vale cero si faltan vecinos; el global puede no ser evaluable |
| Louvain / modularidad | Louvain propone comunidades; la modularidad compara sus conexiones internas con un reparto de referencia de la red | No demuestra grupos sociales reales |

**La disposición no es un indicador.** Si dos nodos parecen cercanos al arrastrarlos, solo ha cambiado el dibujo.

**Los filtros modifican los indicadores.** Limitar el número de conexiones cambia métricas y comunidades: contrasta otros límites.

**La semilla da repetibilidad, no calidad.** Fijar la semilla hace que Louvain y la disposición se repitan; no corrige problemas de conectividad ni mejora las comunidades. La estabilidad de la partición se mide aparte: con Louvain, el resumen incluye el acuerdo medio entre 20 ejecuciones con semillas distintas, medido mediante ARI: 1 indica la misma agrupación y 0 el acuerdo esperado por azar, teniendo en cuenta los tamaños de los grupos.

**Una centralidad alta describe una posición en esta red.** Atribuir liderazgo o prestigio exige evidencia adicional.

**Qué comprobar.** Que los nombres no están duplicados por variantes de escritura, que la definición de la conexión coincide con tu pregunta y que ninguna conclusión depende de un umbral que no has contrastado.

## 5. Pautas para documentar y redactar tu decisión

Describe los nodos, la relación, el conteo y los filtros: «Se construyó una red de [entidades] conectadas por [regla], con pesos [definición], [n] nodos (los de mayor presencia, con presencia mínima [valor]) y [m] conexiones. Se detectaron [c] comunidades con [Louvain/Walktrap] (modularidad [valor])». Informa la cobertura y los umbrales.

Es una redacción modelo que debes completar con tus cifras. Una centralidad alta describe una posición en esta red; no la presentes como liderazgo sin otra evidencia.

+++ Nota técnica: definiciones
Densidad = 2e / (n(n − 1)). Intermediación y centralidad armónica se calculan sin pesos (`weights = NA`) y normalizadas. El agrupamiento local usa `transitivity(type = "local", isolates = "zero")`. La fuerza es `igraph::strength()` con el peso elegido. Pesos: completo = coincidencias; fraccionado = cada documento aporta `2 / (k(k − 1))` a cada pareja de sus k elementos, antes de aplicar el límite de nodos; coseno = coincidencias / √(presencia_i · presencia_j); fuerza de asociación = coincidencias / (presencia_i · presencia_j) (van Eck y Waltman, 2009). Las comunidades se calculan con `cluster_louvain()` (con resolución) o `cluster_walktrap()`, ponderadas por el peso elegido. La estabilidad solo se evalúa con Louvain: es la media del índice de Rand ajustado entre todos los pares de 20 ejecuciones con semillas derivadas de la elegida.
+++
