---
titulo: LDA y tiempo / prevalencia fija no es modelo dinámico
objetivo: Distinguir dos preguntas temporales diferentes: cuánto participa un tema fijo en cada año, y si el propio tema cambia de significado.
fuentes:
  - Blei y Lafferty / Dynamic Topic Models | https://www.cs.cmu.edu/afs/cs/usr/lafferty/www/pub/dtm.pdf
---

## 1. Conceptos fundamentales: prevalencia anual de un tema fijo

**Para situarte.** La prevalencia anual es la media de las proporciones de un tema entre los documentos de ese año. Por ejemplo, proporciones de 20 % y 60 % en dos documentos dan una media del 40 %. No significa que el 40 % de los artículos pertenezca exclusivamente a ese tema.

**Lo que quieres saber.** Si un tema ocupa más o menos espacio en los documentos con el paso de los años.

**Lo que se calcula realmente.** La LDA de la aplicación se ajusta **una sola vez** con el corpus completo. Las distribuciones de palabras de cada tema permanecen fijas durante toda la ejecución. Después, las mezclas de temas de los documentos se agrupan por año y se calcula la **proporción media** de cada tema entre los documentos de ese año. Eso responde a «¿cuánto participa el tema en los documentos de cada año?», sin cambiar la definición del tema.

Un **modelo dinámico de temas** hace otra pregunta: incorpora el tiempo dentro de la estimación del modelo y permite que las probabilidades asignadas a las palabras de cada tema evolucionen entre periodos (Blei y Lafferty, 2006). Ajustar varias LDA por separado, una por periodo, tampoco lo sustituye: los identificadores y las distribuciones de los temas pueden cambiar entre ajustes, y habría que alinearlos y validarlos.

## 2. Ejemplo práctico: de 20 % a 35 %

Las cifras son ilustrativas. El Tema 2 mantiene las mismas probabilidades de «hospital» y «escuela» en toda la ejecución. Su proporción media pasa del 20 % al 35 % entre los documentos de dos años.

### Interpretación

Es un cambio de prevalencia de un tema fijo: en los documentos del segundo año, la mezcla de vocabulario que define el Tema 2 pesa más. No demuestra que el Tema 2 haya cambiado internamente de significado o de vocabulario entre esos años, ni que el 35 % de los artículos de ese año «sean del Tema 2».

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Calcula primero la LDA** y revisa los temas y propón sus nombres leyendo palabras y documentos (ver Nombrar un tema).
2. **Abre *Prevalencia por año*.** Los puntos y la tabla conservan las medias anuales observadas.
3. **Decide si usas líneas suavizadas.** La opción *Líneas spline* redondea los segmentos mediante interpolación cúbica: mantiene los extremos y la suma de los temas, y se interrumpe en los años sin datos. Desmarcada, la figura une los puntos con segmentos rectos. En ningún caso estima tendencias, incertidumbre ni valores de años ausentes.
4. **Consulta la tabla** para ver cuántos documentos respaldan cada año; con pocos documentos, uno solo puede modificar mucho la media; comprueba el efecto antes de describir una tendencia.
5. **Registra la cobertura.** Solo cuentan los documentos con año válido, y los cambios de búsqueda o de idioma a lo largo del tiempo pueden mover la prevalencia.

## 4. Cómo leer la figura sin errores de interpretación

**Una media de mezclas no es un recuento.** No conviertas la proporción media en un número de artículos exclusivos de un tema.

**El tema conserva su definición.** Lo que cambia por año es cuánto participa en los documentos.

**La aplicación no implementa un modelo dinámico** ni presenta esta vista como tal; el análisis dinámico exige otro modelo y su validación.

**Qué comprobar.** Que cada año tiene documentos suficientes, que la tendencia que describes se ve también en los documentos representativos de cada año y que no coincide con un cambio en la forma de recuperar los datos.

## 5. Pautas para documentar y redactar tu decisión

Puedes escribir: «Se describió la prevalencia anual de los temas estimados con una LDA ajustada sobre el corpus completo (k = [valor]); para cada año se calculó la proporción media de cada tema entre los [n] documentos con año válido [rango de años]».

Es una redacción modelo que debes completar con tus cifras. Informa los años y los documentos disponibles, y evita llamar a este análisis «LDA dinámica» o convertir una media de mezclas en un recuento de artículos exclusivos de un tema.

+++ Nota técnica: cálculo de la prevalencia anual
`lda_yearly()` toma la matriz de proporciones de tema por documento (`document_topics`), selecciona los documentos con año válido y, para cada año, calcula la media por columna (`colMeans`). Los años se agrupan en tramos contiguos (`segmento`) para interrumpir las líneas donde faltan años. La interpolación de la opción spline es cúbica y no ajusta ningún modelo estadístico.
+++
