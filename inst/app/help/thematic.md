---
titulo: Mapa temático / Comprender el análisis
objetivo: Interpretar comunidades de términos, centralidad externa y densidad interna sin atribuir calidad ni tendencias temporales a los cuadrantes.
fuentes:
  - Cobo et al. / SciMAT, 2012 | https://doi.org/10.1002/asi.22688
  - bibliometrix / thematicMap | https://cran.r-project.org/web/packages/bibliometrix/refman/bibliometrix.html
  - igraph / Louvain | https://r.igraph.org/reference/cluster_louvain.html
  - Fortunato y Barthélemy / límite de resolución | https://arxiv.org/abs/physics/0607100
---

## 1. Finalidad y funcionamiento

**Para situarte.** Un término es una palabra o expresión, como hospital o salud mental. Su presencia documental es el número de documentos distintos que lo contienen. Una conexión une dos términos que aparecen en el mismo documento; su peso mide la intensidad de esa coincidencia con la fórmula indicada más abajo. Una comunidad es un grupo de términos propuesto por el algoritmo, no un tema cuyo significado ya se haya confirmado.

El mapa temático representa **comunidades de términos que aparecen juntos en los documentos**. Puedes usar el campo de palabras clave asignado en 02 o el vocabulario retenido del texto preparado. Los dos orígenes no se mezclan: sus resultados responden a decisiones diferentes.

La pregunta es qué comunidades conectan con el resto del campo y cuáles tienen mayor cohesión interna en la red seleccionada. Louvain propone las comunidades; el diagrama de Callon las sitúa según conexiones externas e internas. Revisa sus términos y documentos antes de proponer nombres. Los valores iniciales sirven para explorar: cambia una decisión cada vez y conserva una referencia para comparar.

En Scopus y Web of Science se utilizan los campos asignados en 02. Comprueba si son palabras de autor o términos de indización y revisa cuántos documentos tienen información; no presupongas que campos de bases distintas son equivalentes.

Las palabras clave compuestas se conservan como expresiones completas, separadas según la regla de metadatos de 02. La unificación de variantes respeta la opción de normalización de metadatos. Comprueba si el campo corresponde a palabras declaradas por autores o a términos de indización de la base. No se aplican a este campo los filtros lingüísticos del texto.

Con vocabulario preparado se utilizan los términos ya retenidos tras la limpieza y los filtros. Si la unidad de preparación es la frase, primero se agregan las frases de cada documento. **Repetir un término dentro del documento no aumenta su presencia ni sus copresencias.**

## 2. Ejemplo de lectura y construcción de las medidas

Primero se filtran términos por presencia documental y se conservan los más presentes hasta el máximo elegido; si dos términos aparecen en el mismo número de documentos, se ordenan por el texto del término, alfabéticamente. Después se construyen las copresencias entre los términos seleccionados y se aplica su umbral mínimo. Los términos que quedan sin conexiones se excluyen del mapa y se registran en la tabla de selección.

La conexión entre dos términos se pondera con el **índice de equivalencia**: el cuadrado del número de documentos que contienen ambos, dividido por el producto de sus presencias documentales. Por ejemplo, si A está en 10 documentos, B en 5 y coinciden en 3, el peso es 9 / 50 = 0,18. No es una probabilidad de tema ni una prueba estadística de asociación.

**Comparación con bibliometrix 5.5.0.** Su `thematicMap()` normaliza las copresencias con fuerza de asociación: en el mismo ejemplo, 3 / 50 = 0,06. `bibliolab` usa equivalencia (0,18). Ambos cuentan cada término una vez por documento, pero los pesos, la partición de Louvain y las posiciones de los temas pueden diferir. Para comparar resultados entre programas, iguala también el campo, la selección de términos, los filtros y la semilla.

Louvain detecta comunidades en esa red ponderada. La resolución controla la escala de la partición y la semilla permite repetirla con el mismo entorno. Los identificadores T1, T2, etc. se ordenan por la suma de presencias de los términos de cada comunidad; no expresan calidad ni estabilidad.

**Centralidad de Callon, eje X.** Diez veces la suma de los pesos de las conexiones entre los términos del tema y los de otros temas. Cada conexión externa contribuye una vez a cada tema que une. Mide conexión externa en la red seleccionada.

**Densidad de Callon, eje Y.** Cien veces la suma de los pesos de las conexiones internas, dividida por el número de términos del tema. Cada pareja interna se cuenta una vez. Mide cohesión interna por término; no es el porcentaje de conexiones posibles ni la densidad de puntos de HDBSCAN. Una comunidad de un solo término tiene densidad cero.

Los ejes son lineales y las medidas no son porcentajes. No se normalizan por el valor máximo. La definición del peso, las comunidades y los cortes puede diferir entre aplicaciones; no presupongas que dos programas producirán el mismo mapa con opciones diferentes.

## 3. Parámetros y cómo decidir

Como primera exploración se proponen palabras clave, presencia mínima de 2 documentos, hasta 100 términos, copresencia mínima de 1 documento, resolución 1 y semilla 2026. Son valores iniciales, no una recomendación universal. El máximo admitido es 150 términos para mantener un cálculo y una lectura manejables.

Consulta cobertura y selección: un máximo bajo o un umbral elevado pueden alterar las comunidades, las conexiones externas y los cuadrantes. Todas las conexiones que superan el umbral intervienen en el cálculo; no se aplica un límite de aristas para simplificar el dibujo. Contrasta otra resolución, semilla y filtros antes de presentar una partición como consistente. El módulo no calcula una puntuación de estabilidad.

### Qué decisión representa cada control

- **Origen:** palabras clave o vocabulario del texto. Elige por tu pregunta y cobertura; cambiarlo cambia el universo de términos, no solo su presentación.
- **Presencia mínima:** inicio de 2 documentos por término. Un umbral mayor reduce términos poco extendidos y también puede ocultar contenidos minoritarios. Consulta la selección y las exclusiones.
- **Máximo de términos:** inicio de 100, hasta 150. Selecciona los más presentes, no solo los que tendrán su nombre escrito en la figura. Contrasta un límite próximo manteniendo los demás filtros.
- **Copresencia mínima:** inicio de 1 documento compartido por pareja. Subirla retira conexiones y puede dejar términos aislados. No es una prueba de significación.
- **Resolución de Louvain:** inicio de 1. Define la escala de las comunidades; se desarrolla a continuación.
- **Semilla:** inicio de 2026. Repite con otra semilla manteniendo fija la red para comprobar cuánto depende la partición de la inicialización. Un número mayor no representa un ajuste mejor.

### Resolución de Louvain: cómo elegir el grado de detalle

Puede entenderse como un **zoom conceptual**: valores menores suelen favorecer comunidades mayores; valores mayores suelen favorecer comunidades más pequeñas. Cambiar la resolución recalcula la partición, no solo amplía el dibujo, y no fija de antemano cuántos temas habrá.

1. Calcula con 1 y lee términos y documentos por comunidad.
2. Conserva origen, filtros, pesos y semilla, y contrasta 0,5 y 1,5. Anota qué comunidades se unen o se separan.
3. Comprueba si las divisiones distinguen contenidos relevantes para tu pregunta o separan términos que necesitas interpretar conjuntamente.
4. Repite la configuración candidata con otra semilla y documenta las alternativas, además del mapa elegido.

La modularidad compara las conexiones internas de las comunidades con un reparto de referencia de la red. Presenta un **límite de resolución**: puede fusionar comunidades pequeñas dependiendo de la red completa. Explorar otras resoluciones permite examinar otras escalas, pero no garantiza eliminar ese límite. Una resolución excesiva para la pregunta puede fragmentar contenidos relacionados. Louvain no reconoce sinónimos ni valida temas por significado; centralidad y densidad describen conexiones, no certifican coherencia semántica.

Los botones **Cómo decidir** junto a cada control reúnen significado, valores iniciales, efecto del cambio, recorrido de comparación y límites. Revisa términos, conexiones y cobertura después de cada ajuste: al cambiar la partición también pueden cambiar las medianas y los cuadrantes.

## 4. Salidas, comprobaciones y límites

Cada círculo representa un tema. **Su área indica documentos distintos con al menos un término de ese tema.** Un documento puede contribuir a varios temas; no sumes los tamaños como categorías exclusivas. El texto que acompaña al círculo reúne los tres términos de la comunidad presentes en más documentos. Es una descripción automática por palabras, no un nombre de tema comprobado por lectura. Revisa todos sus términos y lee documentos antes de darle un nombre sustantivo.

En pantallas estrechas, el gráfico muestra los identificadores T1, T2, etc. para mantener la legibilidad; la tabla conserva los tres términos principales y el número del tema correspondiente.

Los cortes son las **medianas de centralidad y densidad entre los temas del mapa**, con el mismo peso por tema. Mediana es el valor central después de ordenar los valores; si hay un número par de temas, se promedian los dos centrales. «Mayor» y «menor» se refieren a estas referencias relativas; no hay un umbral universal de desarrollo o relevancia.

| Cuadrante | Posición | Lectura estructural |
| --- | --- | --- |
| Motor | Centralidad y densidad superiores a sus medianas | Mayor conexión externa y cohesión interna relativas |
| Especializado o de nicho | Centralidad inferior; densidad superior | Mayor cohesión interna y menor conexión externa relativas |
| Básico o transversal | Centralidad superior; densidad inferior | Mayor conexión externa y menor cohesión interna relativas |
| Emergente o en declive | Ambas inferiores | Menor conexión externa y cohesión interna relativas |

**Un único mapa no distingue emergencia de declive.** Es necesario comparar periodos con una metodología consistente y revisar la cobertura. Este módulo presenta una fotografía del corpus vigente, no calcula una evolución temporal.

Si un tema coincide con alguna mediana, se indica **En el límite** y no se fuerza su clasificación. Con un único tema no se interpretan cuadrantes y su centralidad externa es cero. Cuando todas las centralidades son iguales, ese eje no distingue posiciones relativas. Dos temas pueden ocupar exactamente la misma posición: el gráfico conserva sus coordenadas y las tablas permiten distinguirlos.

## 5. Cómo documentar la decisión

Registra origen y campo exacto, cobertura, filtros, resolución, semilla, ponderación de conexiones y cortes por medianas. Justifica los nombres que propongas para los temas con lectura de documentos e informa de qué cambió al contrastar otra resolución o semilla. No describas una comunidad como validada solo porque resulte separada en el mapa.

La descarga contiene mapa PNG y PDF, tablas de temas, términos, conexiones, selección y cobertura, parámetros y cortes, una matriz de presencias y un guion de reproducción. La matriz contiene identificadores y términos, sin títulos ni resúmenes; puede revelar vocabulario del corpus. Se registran la versión de R y de igraph. El ZIP general de 05 también incorpora estos resultados si el mapa está vigente.

La centralidad no mide calidad científica y la densidad no demuestra madurez histórica. Las comunidades son una representación exploratoria de los términos y conexiones seleccionados.
