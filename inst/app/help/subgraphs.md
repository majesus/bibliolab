---
titulo: Subgrafos / estudiar una parte sin perder la red de origen
objetivo: Definir la selección de nodos, entender qué se recalcula al extraerla y evitar atribuir a un nodo los valores de la red completa.
fuentes:
  - igraph / subgrafo inducido | https://r.igraph.org/reference/induced_subgraph.html
---

## 1. Conceptos fundamentales: cambiar el universo de análisis

**Lo que quieres saber.** Qué ocurre en una zona concreta de la red: con quién se conecta un nodo, qué integra una comunidad o qué une una selección.

**Lo que se calcula realmente.** Un **subgrafo inducido** conserva los nodos elegidos y todas las conexiones de la red de origen entre ellos, con sus pesos originales. Puedes elegir un **vecindario** (los nodos a una distancia de 0 a 3 saltos de uno de referencia), una **comunidad**, una **componente** o una **selección manual**. La red completa sigue disponible.

Los indicadores que dependen del conjunto de nodos se **recalculan** dentro del subgrafo: grado, fuerza, densidad, intermediación, centralidad armónica, componentes, comunidades y key players. En cambio, los pesos de las conexiones y la presencia documental de cada nodo siguen referidos al corpus de origen, y la tabla conserva `grado_origen` y `comunidad_origen` para comparar. No se han creado datos nuevos.

> **La analogía cotidiana:**
>
> Es como fijarse solo en una planta de un edificio de oficinas: ves quién habla con quién en esa planta, pero alguien que parece aislado en ella puede ser, en el edificio entero, el que enlaza con otras plantas.
>
> **Dónde deja de servir la analogía:** en un edificio, las demás plantas siguen ahí aunque no las mires. En un subgrafo inducido, las conexiones con los nodos no elegidos desaparecen del cálculo, de modo que las medidas describen únicamente lo que has conservado.

## 2. Ejemplo práctico: Eva dentro y fuera de su vecindario

Los resultados proceden de ejecutar el cálculo de la aplicación sobre la red de coautoría de cinco autores de la guía de redes (conteo completo; Louvain con semilla 2026).

En la red completa, Eva tiene grado 3 (Ana, Luis y Marta) e intermediación 0,67. Si extraes su **vecindario a un salto**, conservas a Eva, Ana, Luis y Marta, y las cuatro conexiones que hay entre ellos (Ana–Eva, Ana–Luis, Eva–Luis y Eva–Marta); Pablo queda fuera. Dentro de ese subgrafo, Marta pasa de grado 2 a grado 1, porque su conexión con Pablo ya no existe en el universo analizado, y la intermediación de Eva sigue siendo 0,67.

Si eliges, en cambio, la **selección manual** de Ana y Pablo, que no están conectados entre sí, obtienes dos nodos sin ninguna conexión: densidad 0, dos componentes, dos aislados y ninguna comunidad que buscar. Es un resultado válido, no un error.

| Selección | Nodos | Conexiones | Densidad | Componentes | Cambio respecto al origen |
|---|---|---|---|---|---|
| Vecindario de Eva (1 salto) | 4 | 4 | 0,67 | 1 | Marta baja de grado 2 a 1 |
| Comunidad de Marta | 2 | 1 | 1,00 | 1 | Marta baja de grado 2 a 1 |
| Selección manual: Ana y Pablo | 2 | 0 | 0,00 | 2 | Ambos quedan aislados |

### Interpretación

La densidad de 0,67 del primer subgrafo no es la densidad de la red completa (0,50): el denominador depende de los nodos conservados. Que un nodo cambie de grado o de intermediación al extraer el subgrafo es un **cambio de universo**, no una contradicción. Una persona poco central en la red completa puede ocupar el centro de su equipo, y un nodo que unía dos zonas deja de parecer intermediario al retirar una de ellas.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Formula la pregunta local** que justifica el subgrafo: qué ocurre alrededor de un nodo, dentro de una comunidad o entre unos nodos concretos.
2. **Elige el método de extracción.** *Vecindario* requiere un nodo de referencia y una distancia (0 a 3); *Comunidad* y *Componente* toman la que contiene al nodo de referencia; *Selección manual* admite una lista de nodos de la red vigente. Un nodo sin comunidad asignada no admite la extracción por comunidad.
3. **Extrae el subgrafo** y lee primero la auditoría (nodos de origen, nodos del subgrafo y conexiones internas).
4. **Compara los indicadores recalculados** con los de la red de origen, apoyándote en `grado_origen` y `comunidad_origen`.
5. **Consulta los nodos y los key players** del subgrafo; son candidatos dentro de esta selección, no de la red completa.
6. **Conserva la selección y la red de origen.** La descarga incluye los nodos, las conexiones, los indicadores y un script que reproduce la extracción a partir de la red de origen.

## 4. Cómo leer el subgrafo sin errores de interpretación

**Un valor recalculado no sustituye al original.** Distingue siempre entre el grado, la intermediación o la comunidad del subgrafo y los de la red completa.

**Un subgrafo pequeño o sin conexiones es un resultado.** No elimines aislados para fabricar una estructura más densa.

**Las comunidades se buscan de nuevo.** La comunidad de un nodo en el subgrafo puede no coincidir con la que tenía en la red de origen; por eso se conserva `comunidad_origen`.

**La selección condiciona la conclusión.** Un vecindario centrado en un nodo hace que ese nodo parezca central por construcción; no lo presentes como hallazgo.

**Los pesos y los documentos siguen referidos al corpus de origen.** El subgrafo no vuelve a contar documentos.

**Qué comprobar.** Que el criterio de selección responde a la pregunta, que no dependes de un umbral de la red de origen que no has contrastado y que la conclusión se matiza antes de extenderla a todo el corpus.

## 5. Pautas para documentar y redactar tu decisión

Documenta el criterio y distingue los valores: «Se examinó el subgrafo inducido por [criterio], con [n] nodos y [m] conexiones, extraído de una red de [N] nodos y [M] conexiones. Los indicadores se recalcularon en el subgrafo; [nodo] pasó de grado [a] a grado [b]».

Es una redacción modelo que debes completar con tus cifras. Conserva la selección y la red de origen para poder reproducir la extracción.

+++ Nota técnica: cálculo
`extract_subgraph()` construye el grafo no dirigido de la red de origen y toma los nodos elegidos: `ego(order, mindist = 0)` para el vecindario (distancia 0 a 3), los nodos con el mismo valor de `comunidad` o `componente` que el nodo de referencia, o la lista manual. Conserva las aristas de la red de origen con ambos extremos elegidos y sus pesos, y llama de nuevo a `network_metrics()` con los mismos parámetros de la red de origen (método de comunidades, resolución, semilla, número de key players). La disposición del dibujo se recalcula y es solo visual.
+++
