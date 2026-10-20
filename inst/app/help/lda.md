---
titulo: LDA / mezclas de temas
objetivo: Entender beta, gamma y prevalencia sin confundir sus denominadores, y proponer etiquetas de tema con evidencia.
fuentes:
  - topicmodels / LDA | https://search.r-project.org/CRAN/refmans/topicmodels/html/lda.html
---

## 1. Conceptos fundamentales: temas como patrones de palabras

**Lo que quieres saber.** De qué temas tratan tus documentos y cuánto de cada tema contiene cada uno.

**Lo que se calcula realmente.** **LDA** (*Latent Dirichlet Allocation*, asignación latente de Dirichlet) aprende patrones de palabras que tienden a aparecer juntas y representa cada unidad como una mezcla de esos patrones. Los llama Tema 1, Tema 2 y así sucesivamente. Esos números no significan «educación», «salud» o «sostenibilidad»: el modelo no sabe si una etiqueta humana es correcta. Las etiquetas las propone el investigador.

El modelo produce dos distribuciones diferentes. **Beta** es la probabilidad que el modelo asigna a cada término dentro de un tema; describe palabras. **Gamma** expresa cuánto participa cada tema en la representación de una unidad; describe mezclas de temas. Las barras de la composición de un documento suman 100 %.

> **La analogía cotidiana:**
>
> Es como una receta de pintor: cada cuadro se obtiene mezclando pigmentos (los temas) en proporciones distintas, y cada pigmento es a su vez una mezcla de palabras. Gamma dice cuánto de cada pigmento lleva el cuadro; beta dice qué contiene cada pigmento.
>
> **Dónde deja de servir la analogía:** un pigmento tiene un nombre y un color conocidos. Un tema de LDA es solo una distribución de probabilidad sobre palabras; su nombre es una interpretación que debes justificar leyendo documentos.

## 2. Ejemplo práctico: leer una beta y una gamma

Las cifras son ilustrativas. Un tema muestra, con mayor beta, «hospital», «paciente» y «prevención», y sus documentos representativos hablan de atención sanitaria: puedes proponer esa etiqueta de forma provisional. Si otros textos del mismo tema tratan de prevención de riesgos laborales, la etiqueta inicial sería demasiado estrecha. Leer palabras aisladas no basta; hay que contrastar el conjunto y los casos ambiguos.

Un documento con un 70 % del Tema 1 y un 30 % del Tema 2 tiene esa mezcla estimada por LDA. No significa que el 70 % de los artículos del corpus sean del Tema 1. Una beta de 0,03 describe un 3 % de probabilidad de ese término en la distribución del tema, no un 3 % de documentos.

### Interpretación

Una barra individual (la composición de un documento) y la prevalencia media de un tema (el promedio de esas mezclas) responden a escalas distintas. La prevalencia se promedia por documento; si usas frases como unidad, primero se promedian las frases retenidas dentro de cada documento.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige k con apoyo.** *Comparar soluciones* ajusta varias soluciones, con varias semillas, y las compara por coherencia, diversidad, estabilidad entre semillas y perplejidad en documentos reservados. Los criterios pueden discrepar; el valor de compromiso es solo un punto de partida. Después lee los temas de dos o tres candidatos. Si tienes una razón previa para fijar k, puedes calcularlo directamente, registrando esa razón. El número de temas admitido va de 2 a 12.
2. **Ajusta la solución elegida.** Indica k, la semilla y las iteraciones (500, 1.000 o 2.000), y pulsa *Calcular LDA*. Las unidades sin palabras tras la selección de vocabulario no entran en el modelo.
3. **Revisa el prior alpha** en *Opciones avanzadas*. El prior de la mezcla de cada documento controla cuánto puede concentrarse en pocos temas. La aplicación usa por defecto alpha = 1/k (disperso); puedes probar 5/k o 50/k, que es el valor estándar de `topicmodels`. Informa siempre el valor utilizado.
4. **Lee las palabras por tema** (las de mayor beta), después varios documentos representativos y algún documento que mezcle temas. Solo entonces propone una etiqueta provisional (ver *Nombrar un tema*).
5. **Estudia la sensibilidad.** Cambia una semilla o k cada vez y compara las palabras, no solo los números de tema, porque los números de tema no se corresponden entre ejecuciones.
6. **Mira la evolución** en *Prevalencia por año* (ver la guía de LDA y tiempo).

## 4. Cómo leer el modelo sin errores de interpretación

**El prior puede decidir el resultado en textos cortos.** Con alpha, la proporción estimada de un tema en un documento es aproximadamente (n_dk + alpha) / (N_d + k·alpha), donde n_dk es el número de palabras del documento asignadas al tema y N_d el total de palabras del documento. Ejemplo aritmético, con k = 4 y un resumen de 20 palabras que el modelo asigna todas a un mismo tema: con alpha = 50/k = 12,5 la proporción de ese tema es (20 + 12,5) / (20 + 50) ≈ 0,46 y cada uno de los otros tres (0 + 12,5) / 70 ≈ 0,18, una mezcla muy suavizada; con alpha = 1/k = 0,25 es (20 + 0,25) / (20 + 1) ≈ 0,96 y cada uno de los demás ≈ 0,01. Por eso con textos cortos las proporciones por documento dependen del prior tanto como de las palabras.

**Las medidas de calidad orientan; no sustituyen la lectura.** La coherencia (NPMI y UMass) mide si las palabras principales de un tema co-ocurren en los mismos documentos, calculada con los propios documentos del corpus. La diversidad es la proporción de palabras principales distintas entre temas.

**La convergencia no se demuestra.** Se guardan estados del muestreador tras el periodo de calentamiento y se devuelve el de mayor log-verosimilitud. El cambio relativo de la log-verosimilitud entre la primera y la segunda mitad de la traza es un indicador heurístico: si es grande, aumenta las iteraciones. No es una prueba formal de convergencia.

**La aplicación no nombra los temas ni usa un modelo de lenguaje para hacerlo.**

**Qué comprobar.** Que los temas se reconocen leyendo documentos, que la solución se parece con otra semilla y que el valor de alpha está registrado.

## 5. Pautas para documentar y redactar tu decisión

Puedes informar: «Se ajustó una LDA con muestreo de Gibbs (k = [valor], alpha = [valor], delta = [valor], [iteraciones] iteraciones, semilla [valor]) sobre [n] unidades. El Tema [k], provisionalmente denominado [etiqueta], se interpretó a partir de los términos [términos] y de los documentos [ID]».

Explica los casos ambiguos y la sensibilidad al número de temas. La etiqueta es una interpretación del investigador, no una categoría conocida por LDA. Es una redacción modelo que debes completar con tus datos.

+++ Nota técnica: estimación y parámetros
`run_lda()` ajusta `topicmodels::LDA(method = "Gibbs")` con delta = 0,1, burn-in = 100 y thin = 10 por defecto, y alpha = 1/k si no se indica otro valor. La matriz gamma procede de `topicmodels::posterior()`; la prevalencia de un tema es la media, entre documentos, del promedio de gamma de sus unidades. Los parámetros, el estado seleccionado y el número de estados guardados quedan registrados en la entrega. Referencias: Blei, Ng y Jordan (2003); Griffiths y Steyvers (2004); Wallach, Mimno y McCallum (2009) sobre la importancia de los priors; Mimno et al. (2011) y Röder et al. (2015) sobre coherencia.
+++
