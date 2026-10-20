---
titulo: Evolución temática / puntos, curvas y estacionalidad
objetivo: Elegir una representación temporal compatible con los datos y no atribuirle más de lo que describe.
fuentes:
  - mgcv / splines penalizadas | https://search.r-project.org/CRAN/refmans/mgcv/html/gam.html
  - Patrones temporales / Hyndman y Athanasopoulos | https://otexts.com/fpp3/graphics.html
---

## 1. Conceptos fundamentales: volumen, peso relativo y curva

**Lo que quieres saber.** Si un grupo de documentos gana o pierde presencia con el tiempo.

**Lo que se calcula realmente.** Los grupos de UMAP con HDBSCAN se estimaron una sola vez con el corpus completo; estas figuras no entrenan un tema nuevo para cada fecha. Las **barras** cuentan los documentos de cada grupo fijo por año, y responden a «¿cuántos?». Las **proporciones** dividen los documentos de un grupo entre todos los documentos del modelo con ese año, incluidos los sin asignar, y responden a «¿qué parte del año?». Son dos historias distintas: volumen y peso relativo.

Una **spline penalizada** resume cambios de forma suave en lugar de conectar los puntos con segmentos rígidos. La aplicación ajusta un modelo de un grupo frente al resto, con enlace logit y dispersión estimada; la penalización limita las curvas excesivamente onduladas. Su validez depende de la cobertura, de la clasificación, de los supuestos y de los residuos: más suavidad no garantiza más verdad.

> **La analogía cotidiana:**
>
> Es como mirar la audiencia de un programa: puede aumentar el número de espectadores y, a la vez, disminuir su cuota si todos los programas ganan público. Cantidad y cuota son lecturas legítimas, pero distintas.
>
> **Dónde deja de servir la analogía:** una cuota de audiencia se mide con datos continuos y ciclos regulares. Aquí cada punto es un año de publicación agregado: se pierde lo ocurrido dentro del año, y la curva solo une puntos anuales.

## 2. Ejemplo práctico: el volumen se duplica, el peso baja

Las cifras son ilustrativas. Un grupo pasa de 10 a 20 documentos, pero el total de documentos del modelo con año pasa de 20 a 100.

El volumen del grupo se duplica, mientras que su peso relativo baja del 50 % (10/20) al 20 % (20/100). La curva de proporción cuenta esa segunda historia. Si faltan años, conectar los extremos podría ocultar una laguna: la aplicación interrumpe las líneas observadas en los años sin datos.

### Interpretación

La **estacionalidad** es la repetición ligada a un ciclo regular, como cada mes o cada trimestre. Con un único dato anual se pierde lo ocurrido en cada estación. Los años de publicación pueden describir evolución, pero no demostrar una estacionalidad mensual; harían falta fechas suficientemente finas, varios ciclos y cobertura comprobada.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Empieza por los puntos y la tabla.** Elige *Documentos por año* o *Proporciones observadas* y consulta la tabla de conteos y denominadores.
2. **Lee juntas cantidad y proporción.** Veinte documentos pueden ser más que diez y, a la vez, representar una parte menor si el corpus anual creció mucho.
3. **Ajusta una spline solo si procede.** La opción *Spline penalizada* exige al menos 10 años observados y, en cada uno, al menos 5 documentos del modelo con año válido; además, el grupo no puede estar ausente ni reunir todos los documentos de todos los años. Son límites de la herramienta para evitar curvas con pocos puntos, no garantías estadísticas.
4. **Revisa los diagnósticos.** La tabla de diagnósticos incluye los años observados, los grados de libertad efectivos del suavizado, la dispersión estimada y la autocorrelación residual a un año.
5. **Consulta el vocabulario por año.** La tabla de palabras muestra el vocabulario observado dentro de un grupo en cada año; no equivale a estimar que la distribución temática evolucione dentro de un modelo dinámico.

## 4. Cómo leer la figura sin errores de interpretación

**La banda no incluye todos los errores posibles.** Es una banda puntual (±1,96 errores típicos en la escala logit, llevada a proporción) y condicional: no integra la incertidumbre de la búsqueda, de la clasificación ni de una dependencia temporal no modelada.

**La curva no es un pronóstico ni una prueba de causalidad.** Resume proporciones observadas con suavidad cuando la cobertura permite ajustarla; si faltan años o hay pocas observaciones, los puntos y sus denominadores ofrecen una lectura más defendible que una curva forzada.

**La aplicación no calcula estacionalidad con años agregados** ni llama DTM (modelo dinámico de temas) a estas curvas.

**Qué comprobar.** Que los denominadores anuales son suficientes, que no hay lagunas que la curva esté ocultando y que los diagnósticos (en particular la autocorrelación residual) no contradicen el supuesto de observaciones independientes.

## 5. Pautas para documentar y redactar tu decisión

Indica que los grupos son fijos y que las proporciones incluyen en el denominador los documentos sin asignar: «Se describió la evolución anual observada de [n] grupos estimados sobre el corpus completo; las proporciones se calcularon sobre los documentos del modelo con año válido, incluidos los no asignados». Si presentas una spline, documenta el ajuste y sus diagnósticos.

Habla de evolución anual observada; la estacionalidad necesita fechas más finas y varios ciclos. Es una redacción modelo que debes completar con tus cifras.

+++ Nota técnica: ajuste de la spline
`density_spline()` ajusta `mgcv::gam(cbind(documentos, total − documentos) ~ s(ano, bs = "cr", k = k), family = quasibinomial(), method = "REML")`, con k = 5 por defecto (entre 3 y 8, y como máximo el número de años menos 2). La banda es `plogis(ajuste ± 1,96 × EE)` sobre el predictor lineal. Si el ajuste no converge o emite avisos, no se muestra la curva y se conservan los puntos observados. Las predicciones se calculan dentro de cada tramo contiguo de años.
+++
