---
titulo: LDA / Comprender el análisis
objetivo: Entender beta, gamma y prevalencia sin confundir sus denominadores, y proponer nombres para los temas con evidencia.
fuentes:
  - topicmodels / LDA | https://search.r-project.org/CRAN/refmans/topicmodels/html/lda.html
---

## 1. Finalidad y funcionamiento

**Finalidad.** Estimar patrones de palabras y describir cómo se combinan en cada texto. LDA llama temas a esos patrones; no son categorías conocidas de antemano.

**Datos de partida.** Se usan recuentos de palabras. Una unidad es un documento completo o una frase, según 02. k es el número de temas que eliges; la semilla es el número que controla el inicio aleatorio del ajuste.

**Qué produce el método.** Para cada tema se estima una distribución de palabras: un conjunto de probabilidades que suma 100 %. La probabilidad de una palabra dentro de un tema se denomina **beta**. Para cada unidad se estima una mezcla de temas, cuyas proporciones también suman 100 %; estas proporciones se denominan **gamma**. Son cantidades diferentes: beta describe palabras y gamma describe la combinación de temas de un texto.

**Prevalencia.** Es la proporción media de un tema entre los documentos. Si se ajustó por frases, primero se promedian sus proporciones dentro de cada documento, para que cada documento aporte el mismo peso a la media final.

**Cómo interpretar.** Tema 1 y Tema 2 son identificadores, no nombres de contenidos. Propón un nombre después de leer palabras y documentos, incluidos casos que no encajen. Compara otros valores de k y otras semillas: una solución repetible puede seguir siendo difícil de interpretar.

**Scopus y Web of Science.** Revisa los campos preparados en 02, su idioma y sus ausencias. El modelo no corrige por sí solo diferencias de búsqueda, cobertura o traducción entre exportaciones.

## 2. Ejemplo de lectura

Las cifras son ilustrativas. Un tema muestra, con mayor beta, «hospital», «paciente» y «prevención», y sus documentos representativos hablan de atención sanitaria: puedes proponer ese nombre de tema de forma provisional. Si otros textos del mismo tema tratan de prevención de riesgos laborales, el nombre del tema inicial sería demasiado estrecho. Leer palabras aisladas no basta; hay que contrastar el conjunto y los casos ambiguos.

Un documento con un 70 % del Tema 1 y un 30 % del Tema 2 tiene esa mezcla estimada por LDA. No significa que el 70 % de los artículos del corpus sean del Tema 1. Una beta de 0,03 describe un 3 % de probabilidad de ese término en la distribución del tema, no un 3 % de documentos.

### Interpretación

Una barra individual (la composición de un documento) y la prevalencia media de un tema (el promedio de esas mezclas) responden a escalas distintas. La prevalencia se promedia por documento; si usas frases como unidad, primero se promedian las frases retenidas dentro de cada documento.

## 3. Parámetros y cómo decidir

### Decidir el número de temas y la estimación

Cada control abre **Cómo decidir**, con punto de partida, efecto del cambio y comprobaciones. Conserva corpus y vocabulario al comparar ajustes; si cambias varias decisiones a la vez, no podrás atribuir el cambio a una de ellas.

- **Intervalo de k:** se comparan inicialmente los enteros de 2 a 8. Si una solución candidata está en el extremo, contrasta valores adyacentes permitidos. Un k mayor puede separar subtemas y también introducir redundancia.
- **Semillas por k:** el inicio es 3. Con una sola repetición no se puede valorar estabilidad entre semillas. Aumentar a 5 amplía la comprobación y requiere más tiempo.
- **k final:** el valor inicial es 4, no una recomendación universal. Fijar un candidato desde la comparación actualiza el control, pero después debes pulsar **Calcular LDA**.
- **Iteraciones:** comienza con 500 y consulta los diagnósticos. Si la log-verosimilitud —el indicador de ajuste a las palabras observadas— sigue cambiando, contrasta 1.000. La comprobación busca si el indicador de ajuste sigue cambiando entre partes de la ejecución. Que no detecte ese cambio no prueba que la estimación se haya estabilizado definitivamente.
- **Alpha:** 1/k favorece mezclas concentradas; 5/k y 50/k favorecen proporciones más repartidas. Con k = 4 son 0,25, 1,25 y 12,5 por tema. Es una preferencia previa que se combina con las palabras de la unidad, no una proporción impuesta.
- **Semilla:** 2026 permite repetir el ajuste en el mismo entorno. Contrasta otra semilla y compara contenidos, porque los identificadores de tema pueden intercambiarse.

La comparación de k usa las iteraciones, la regla alpha y la semilla base del bloque de ajuste. Si cambias esas decisiones, vuelve a comparar. Las páginas de documentos y la spline de la evolución anual solo cambian la consulta o el dibujo del resultado vigente.

### Primer recorrido

1. **Elige k con apoyo.** *Comparar soluciones* ajusta varias soluciones, con varias semillas, y las compara por coherencia, diversidad, estabilidad entre semillas y perplejidad en documentos reservados. Los criterios pueden discrepar; el valor de compromiso es solo un punto de partida. Después lee los temas de dos o tres candidatos. Si tienes una razón previa para fijar k, puedes calcularlo directamente, registrando esa razón. El número de temas admitido va de 2 a 12.
2. **Ajusta la solución elegida.** Indica k, la semilla y las iteraciones (500, 1.000 o 2.000), y pulsa *Calcular LDA*. Las unidades sin palabras tras la selección de vocabulario no entran en el modelo.
3. **Revisa el prior alpha** en *Opciones avanzadas*. El prior es una preferencia previa que favorece mezclas más concentradas o más repartidas antes de combinarla con las palabras. Se aplica a la unidad elegida: documento o frase. La aplicación usa por defecto alpha = 1/k (disperso); puedes probar 5/k o 50/k, que es el valor estándar de `topicmodels`. Informa siempre el valor utilizado.
4. **Lee las palabras por tema** (las de mayor beta), después varios documentos representativos y algún documento que mezcle temas. Solo entonces propone un nombre de tema provisional (ver *Nombrar un tema*).
5. **Estudia la sensibilidad.** Cambia una semilla o k cada vez y compara las palabras, no solo los números de tema, porque los números de tema no se corresponden entre ejecuciones.
6. **Mira la evolución** en *Prevalencia por año* (ver la guía de LDA y tiempo).

## 4. Salidas, comprobaciones y límites

**La preferencia previa (prior alpha) puede influir mucho en textos cortos.** Con alpha, la proporción estimada de un tema en un documento es aproximadamente (n_dk + alpha) / (N_d + k·alpha), donde n_dk es el número de palabras del documento asignadas al tema y N_d el total de palabras del documento. Ejemplo aritmético, con k = 4 y un resumen de 20 palabras que el modelo asigna todas a un mismo tema: con alpha = 50/k = 12,5 la proporción de ese tema es (20 + 12,5) / (20 + 50) ≈ 0,46 y cada uno de los otros tres (0 + 12,5) / 70 ≈ 0,18, una mezcla muy suavizada; con alpha = 1/k = 0,25 es (20 + 0,25) / (20 + 1) ≈ 0,96 y cada uno de los demás ≈ 0,01. El ejemplo mantiene fijas las asignaciones de palabras para mostrar el efecto aritmético de alpha. En un ajuste completo también pueden cambiar esas asignaciones; la influencia del prior depende de alpha, de k y de la cantidad de palabras, no es siempre igual a la de los datos.

**Las medidas de calidad orientan; no sustituyen la lectura.** La coherencia (NPMI y UMass) mide si las palabras principales de un tema co-ocurren en los mismos documentos, calculada con los propios documentos del corpus. La diversidad es la proporción de palabras principales distintas entre temas.

**La convergencia no se demuestra.** Se guardan estados del muestreador tras el periodo de calentamiento y se devuelve el de mayor log-verosimilitud. El cambio relativo de la log-verosimilitud entre la primera y la segunda mitad de la traza es un indicador heurístico: si es grande, aumenta las iteraciones. No es una prueba formal de convergencia.

**La aplicación no nombra los temas ni usa un modelo de lenguaje para hacerlo.**

**Qué comprobar.** Que los temas se reconocen leyendo documentos, que la solución se parece con otra semilla y que el valor de alpha está registrado.

## 5. Cómo documentar la decisión

Puedes informar: «Se ajustó una LDA con muestreo de Gibbs (k = [valor], alpha = [valor], delta = [valor], [iteraciones] iteraciones, semilla [valor]) sobre [n] unidades. El Tema [k], provisionalmente denominado [nombre propuesto], se interpretó a partir de los términos [términos] y de los documentos [ID]».

Explica los casos ambiguos y la sensibilidad al número de temas. El nombre del tema es una interpretación del investigador, no una categoría conocida por LDA. Es una redacción modelo que debes completar con tus datos.

+++ Nota técnica: estimación y parámetros
`run_lda()` ajusta `topicmodels::LDA(method = "Gibbs")` con delta = 0,1, burn-in = 100 y thin = 10 por defecto, y alpha = 1/k si no se indica otro valor. La matriz gamma procede de `topicmodels::posterior()`; la prevalencia de un tema es la media, entre documentos, del promedio de gamma de sus unidades. Los parámetros, el estado seleccionado y el número de estados guardados quedan registrados en la entrega. Referencias: Blei, Ng y Jordan (2003); Griffiths y Steyvers (2004); Wallach, Mimno y McCallum (2009) sobre la importancia de los priors; Mimno et al. (2011) y Röder et al. (2015) sobre coherencia.
+++
