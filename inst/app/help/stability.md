---
titulo: Estabilidad de la agrupación / cómo interpretarla
objetivo: Medir si los grupos de UMAP + HDBSCAN reaparecen al cambiar la semilla o los parámetros, antes de presentarlos como un hallazgo.
fuentes:
  - Hubert y Arabie / comparing partitions | https://doi.org/10.1007/BF01908075
---

## 1. Conceptos fundamentales: una agrupación es una de varias soluciones posibles

**Lo que quieres saber.** Si los grupos que ves en el mapa son reproducibles o dependen de una semilla o de un ajuste concreto.

**Lo que se calcula realmente.** UMAP incluye azar y HDBSCAN depende de `minPts` (el tamaño mínimo para considerar un grupo): dos ejecuciones razonables pueden dar agrupaciones distintas. La comprobación repite el flujo con otras semillas (**estabilidad**) y con otros valores de vecinos y `minPts` alrededor de los elegidos (**sensibilidad**), y compara cada repetición con la ejecución de referencia mediante el **índice de Rand ajustado (ARI)**.

El **ARI** compara dos agrupaciones del mismo conjunto de documentos: vale 1 si coinciden, 0 si el acuerdo es el esperable entre asignaciones al azar, y puede ser negativo. Aquí el grupo «sin asignar» cuenta como una clase más; la columna «solo asignados» ignora los documentos sin grupo en alguna de las dos agrupaciones. La **persistencia de cada grupo** es el solapamiento (Jaccard) con el grupo que más documentos comparte en cada otra semilla.

> **La analogía cotidiana:**
>
> Es como pedir a varias personas que agrupen la misma pila de fichas sin saber el criterio de las demás: si todas forman los mismos montones, el criterio es robusto; si cada una forma otros, los montones dependen de quien los hace.
>
> **Dónde deja de servir la analogía:** las personas pueden explicar su criterio. Aquí el criterio es una densidad estimada sobre un mapa con azar, y la coincidencia entre repeticiones es lo único que indica que un grupo no es un accidente de esa ejecución.

## 2. Ejemplo práctico: cinco repeticiones de un mismo mapa

Los resultados se han calculado con la función de la aplicación sobre diez documentos ilustrativos. La referencia forma dos grupos de cuatro documentos y deja dos sin asignar (etiqueta 0).

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
5. **Consulta la persistencia de cada grupo** (Jaccard medio y mínimo): un valor medio alto indica que el grupo reaparece; valores bajos indican que probablemente es un artefacto de esa semilla.
6. **Decide qué hacer con el resultado.** Si la estabilidad es baja, prueba otra representación (BM25), más vecinos o un `minPts` mayor, o informa solo los grupos persistentes. Documenta las repeticiones.

## 4. Cómo leer la estabilidad sin errores de interpretación

**Las bandas del ARI son una convención orientativa.** Steinley (2004) habla de acuerdo excelente por encima de 0,90, bueno desde 0,80 y moderado desde 0,65. No es un contraste de hipótesis.

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
