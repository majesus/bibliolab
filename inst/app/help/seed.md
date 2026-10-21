---
titulo: Semilla / repetir no es demostrar estabilidad
objetivo: Distinguir reproducibilidad (obtener lo mismo al repetir) de sensibilidad (obtener algo parecido al cambiar las condiciones).
fuentes:
  - uwot / UMAP | https://jlmelville.github.io/uwot/reference/umap.html
---

## 1. Conceptos fundamentales: qué fija una semilla y qué no

**Para situarte.** Los parámetros son las opciones del cálculo que puedes cambiar. Una semilla es un número que fija el inicio del generador de números aleatorios. No es el año de los documentos ni una puntuación de calidad: 2027 no es mejor que 2026 por ser mayor.

**Lo que quieres saber.** Si, al volver a calcular, los resultados serán los mismos, y si de eso se deduce que son fiables.

**Lo que se calcula realmente.** Algunos pasos del análisis usan números aleatorios: UMAP construye sus coordenadas con un proceso estocástico, y la aproximación de LSA con matrices grandes también incorpora azar. La **semilla** fija el punto de partida de esa secuencia aleatoria: con la misma semilla, los mismos datos, los mismos parámetros y las mismas versiones de paquetes, se controla el inicio aleatorio para poder repetir el cálculo dentro de ese entorno. La semilla por sí sola no asegura coincidencia entre ordenadores o versiones diferentes. HDBSCAN, en cambio, no es aleatorio: con las mismas coordenadas devuelve los mismos grupos.

Esto separa dos preguntas. La **reproducibilidad** pregunta si otra persona puede obtener el mismo resultado; la semilla es una condición necesaria para controlar el azar, junto con datos, decisiones y entorno de software documentados; por sí sola no la garantiza. La **sensibilidad** pregunta si el resultado se mantiene cuando cambian la semilla o los parámetros; la semilla no la garantiza, y por eso una clasificación repetible puede seguir dependiendo de decisiones arbitrarias.

## 2. Ejemplo práctico: 2026 frente a 2027

Guarda una ejecución con la semilla 2026 y otra con la 2027, sin cambiar nada más. Las cifras que siguen son ilustrativas.

Si en la segunda ejecución el mapa aparece girado o reflejado, pero los 40 documentos conservan exactamente la misma agrupación, aunque cambien los números que identifican los grupos, la apariencia ha cambiado y la clasificación no: la rotación y la reflexión de un mapa no alteran las asignaciones. Si, en cambio, 12 de esos 40 documentos pasan a otro grupo, esa diferencia sí afecta a la interpretación temática.

### Interpretación

Si distintas semillas producen grupos parecidos, has observado una señal de estabilidad en esas pruebas (no una garantía). Si dos ejecuciones con la **misma** semilla difieren, comprueba las versiones de los paquetes y las demás decisiones, porque el cálculo no debería cambiar.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Fija una semilla para repetir.** En clase o en un informe, deja la semilla por defecto (2026) y registra también datos, decisiones y versiones para que otra persona pueda intentar reproducir la figura.
2. **Contrasta otras semillas.** Cambia solo la semilla y compara los grupos, leyendo los documentos que cambian de grupo.
3. **Usa la evaluación guiada.** *Evaluar estabilidad y sensibilidad* (en UMAP con HDBSCAN) repite el flujo con otras semillas y con otros vecinos y minPts, y mide el acuerdo entre ejecuciones con el índice de Rand ajustado. En LDA, la comparación de k admite varias semillas.
4. **Conserva las discrepancias.** Guarda las ejecuciones alternativas y no escojas solo la que confirma tu idea.

## 4. Cómo leer el resultado sin errores de interpretación

**Una semilla fija no prueba nada sobre la calidad de la solución.** Solo prueba que el cálculo es repetible.

**Un mapa girado no es una clasificación distinta.** Las posiciones absolutas en un mapa UMAP no tienen significado; lo tienen las relaciones de vecindad. Revisa los documentos, no solo las coordenadas.

**Las versiones también forman parte de la reproducibilidad.** La entrega conserva las versiones de R y de los paquetes (`entorno_R.txt`, `registro_reproducibilidad.json`).

**Qué comprobar.** Que los grupos que vas a interpretar persisten con al menos otras dos semillas y con valores vecinos de los parámetros principales.

## 5. Pautas para documentar y redactar tu decisión

Separa reproducibilidad y sensibilidad en el informe: «Los resultados se obtuvieron con la semilla [valor], que permite repetir el cálculo; la sensibilidad se evaluó con [n] semillas alternativas y [parámetros], con [resultado resumido, por ejemplo, un ARI entre (mín.) y (máx.)]».

Es una redacción modelo que debes completar con tus propias ejecuciones. Registra la semilla de la figura publicada y explica qué ejecuciones alternativas contrastaste.

+++ Nota técnica: dónde interviene el azar
Todas las operaciones aleatorias se ejecutan con `with_seed()`, que fija la semilla y restaura el estado previo del generador al terminar. En la ruta léxica, el azar aparece en `irlba::irlba()` (cuando la matriz es grande) y en `uwot::umap()` (inicialización aleatoria y optimización con un solo hilo para que la ejecución sea repetible). `dbscan::hdbscan()` no usa números aleatorios.
+++
