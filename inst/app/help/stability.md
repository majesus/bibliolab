---
titulo: Estabilidad de la agrupación / cómo interpretarla
objetivo: Medir si los grupos de UMAP + HDBSCAN reaparecen al cambiar la semilla o los parámetros, antes de presentarlos como un hallazgo.
fuentes:
  - Hubert y Arabie / comparing partitions | https://doi.org/10.1007/BF01908075
---

## 1. Conceptos fundamentales: una agrupación es una de varias soluciones posibles

**Para situarte.** La ejecución de referencia es el resultado con el que comparas las repeticiones. Asignación significa el grupo que recibe cada documento. Un documento sin asignar no cumple el criterio de agrupación del ajuste; no es un error del archivo ni una publicación de menor calidad.

**Lo que quieres saber.** Si los grupos que ves en el mapa son reproducibles o dependen de una semilla o de un ajuste concreto.

**Lo que se calcula realmente.** UMAP incluye azar y HDBSCAN depende de `minPts` (que regula tanto el tamaño mínimo de grupo como la estimación de densidad, es decir, la concentración de documentos próximos): dos ejecuciones razonables pueden dar agrupaciones distintas. La comprobación repite el flujo con otras semillas (**estabilidad**) y con otros valores de vecinos y `minPts` alrededor de los elegidos (**sensibilidad**), y compara cada repetición con la ejecución de referencia mediante el **índice de Rand ajustado (ARI)**.

El **ARI** compara dos agrupaciones del mismo conjunto de documentos: vale 1 si coinciden, 0 si el acuerdo es el esperable entre asignaciones al azar, y puede ser negativo. Aquí el grupo «sin asignar» cuenta como una clase más; la columna «solo asignados» ignora los documentos sin grupo en alguna de las dos agrupaciones. La **persistencia de cada grupo** es la proporción de documentos compartidos respecto a los documentos distintos de ambos grupos (Jaccard), buscando la mejor coincidencia en cada otra semilla.

## 2. Ejemplo práctico: cinco repeticiones de un mismo mapa

Los resultados se han calculado con la función de la aplicación sobre diez documentos ilustrativos. La referencia forma dos grupos de cuatro documentos y deja dos sin asignar (identificador 0).

| Repetición | Qué ocurre | ARI | ARI solo asignados |
|---|---|---|---|
| A | Reproduce la referencia | 1,00 | 1,00 |
| B | Un documento cambia de grupo | 0,63 | 0,49 |
| C | Los dos grupos se fusionan en uno | 0,37 | 0,00 |
| D | La mitad de los documentos queda sin asignar | 0,01 | 1,00 |
| E | Agrupación sin relación con la referencia | −0,17 | −0,17 |

### Interpretación

En la repetición B, el grupo 1 de la referencia (cuatro documentos) y el grupo 1 de B (tres) comparten tres documentos: persistencia (Jaccard) de 0,75; el grupo 2 tiene 0,80. En la repetición D, la agrupación entre los documentos asignados es idéntica (ARI 1,00 «solo asignados»), pero el ARI global es casi nulo porque la mitad de los documentos pasó a «sin asignar»: por eso conviene leer ambas columnas. Si la referencia no forma ningún grupo, un ARI de 1 solo indica que las repeticiones también dejan todos los documentos sin asignar: es la misma ausencia de grupos, no estabilidad de grupos temáticos.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Calcula primero la agrupación de referencia** y examina cuántos grupos forma y cuántos documentos quedan sin asignar.
2. **Evalúa la estabilidad.** Por defecto se repite con cuatro semillas derivadas de la elegida y con la mitad, el valor y el doble de los vecinos y de `minPts`.
3. **Lee el resumen:** el ARI mediano y mínimo entre semillas, el ARI mediano y mínimo al variar parámetros, el rango de grupos entre repeticiones y cuántos grupos persisten.
4. **Consulta la tabla de repeticiones,** con el ARI global, el ARI solo asignados, el número de grupos y el porcentaje sin asignar de cada una, y las repeticiones fallidas con su causa.
5. **Consulta la persistencia de cada grupo** (Jaccard medio y mínimo): un valor medio alto indica que el grupo reaparece; valores bajos muestran que su composición cambia entre las semillas probadas. Eso no identifica por sí solo la causa ni demuestra que el contenido carezca de estructura.
6. **Decide qué hacer con el resultado.** Si la estabilidad es baja, contrasta otra representación (por ejemplo BM25), otro número de vecinos u otro `minPts`, cambiando una decisión cada vez. Ningún sentido de cambio garantiza mejorar la estabilidad, o informa solo los grupos persistentes. Documenta las repeticiones.

## 4. Cómo leer la estabilidad sin errores de interpretación

**El ARI no tiene un umbral universal de validez temática.** Compara el acuerdo entre tus ejecuciones y consulta a la vez cuántos grupos hay y cuántos documentos quedan sin asignar. Una cifra alta no sustituye la lectura de sus contenidos.

**Un ARI alto no valida los temas.** Mide reproducibilidad de una agrupación, no que sus grupos tengan sentido sustantivo: lee los documentos de cada grupo.

**Los documentos sin asignar cuentan.** Un grupo estable con muchos documentos sin asignar describe solo una parte del corpus.

**Una repetición fallida no entra en los resúmenes.** Consulta su causa en la tabla antes de interpretar los medianos.

**Qué comprobar.** Que la referencia forma grupos, que el ARI «solo asignados» no oculta una pérdida de cobertura y que los grupos que interpretas tienen persistencia alta.

## 5. Pautas para documentar y redactar tu decisión

Puedes redactar: «La agrupación se repitió con [n] semillas y [m] combinaciones de vecinos y minPts; el ARI mediano fue [valor] entre semillas y [valor] al variar parámetros, y [g] de [G] grupos tuvieron un Jaccard medio ≥ 0,6. Se interpretan solo los grupos persistentes».

Es una redacción modelo que debes completar con tus cifras. Un solo mapa no demuestra que los grupos sean reproducibles.

+++ Nota técnica: cálculo
`density_sensitivity()` ejecuta la referencia y, para cada repetición, calcula `adjusted_rand(referencia, repetición)` con el grupo 0 como clase y sobre los documentos asignados en ambas. El ARI es `(Σ C(nᵢⱼ,2) − E) / (½(Σ C(aᵢ,2) + Σ C(bⱼ,2)) − E)`, con `E = Σ C(aᵢ,2) · Σ C(bⱼ,2) / C(n,2)`. La persistencia de un grupo de referencia es el Jaccard máximo con cualquier grupo de la otra semilla entre los que comparten documentos, promediado entre semillas. El resumen cuenta los grupos con Jaccard medio ≥ 0,6.
+++
