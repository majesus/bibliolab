---
titulo: Concentración de fuentes / entender Bradford
objetivo: Entender qué muestra la curva acumulada de fuentes y qué no ha contrastado, para describir la concentración sin atribuirle una prueba.
fuentes:
  - bibliometrix / Bradford | https://cran.r-project.org/web/packages/bibliometrix/bibliometrix.pdf
---

## 1. Conceptos fundamentales: describir una concentración no es contrastar una ley

**Para situarte.** Fuente es el lugar de publicación que consta en el archivo, por ejemplo una revista. Productividad significa aquí número de documentos de este corpus, no calidad de la revista. Acumulado significa sumar los documentos desde la primera fuente hasta la posición que estás leyendo.

**Lo que quieres saber.** En cuántas revistas se concentra la mayor parte de los documentos de tu corpus.

**Lo que se calcula realmente.** La **curva de concentración de fuentes** ordena las revistas desde la que tiene más documentos, suma sus documentos hasta cada posición y divide esa suma entre todos los documentos *con fuente conocida*. El resultado es el **porcentaje acumulado**: qué parte del corpus reúnen las primeras *k* fuentes. Las líneas del 50 % y del 80 % son referencias descriptivas, no umbrales universales.

La **ley de Bradford** es un planteamiento clásico: ordenadas las revistas por productividad, pueden formarse tres zonas con una cantidad aproximadamente igual de artículos, y el número de revistas que necesita cada zona crece en una razón regular. **Contrastar** esa ley exige definir las zonas, formular un modelo y evaluar su ajuste y sus supuestos. En *Cobertura y referencias* la aplicación presenta el acumulado observado. En *03 / Indicadores → Regularidades → Bradford / fuentes* también forma tres zonas y muestra sus razones descriptivas; no realiza un contraste estadístico.

## 2. Ejemplo práctico: cinco revistas y ocho documentos

Los resultados proceden de ejecutar el cálculo de la aplicación sobre un corpus ilustrativo de diez documentos, de los cuales ocho tienen fuente conocida y dos no la tienen.

| Posición | Revista | Documentos | % acumulado |
|---|---|---|---|
| 1 | Rev A | 3 | 37,5 |
| 2 | Rev B | 2 | 62,5 |
| 3 | Rev C | 1 | 75,0 |
| 4 | Rev D | 1 | 87,5 |
| 5 | Rev E | 1 | 100,0 |

### Interpretación

La primera revista reúne el 37,5 % de los documentos con fuente conocida; las dos primeras, el 62,5 %. Hacen falta dos fuentes para alcanzar al menos el 50 % y cuatro para alcanzar al menos el 80 %. Los dos documentos sin fuente no entran en el denominador: el 37,5 % es 3 de 8, no 3 de 10. Esta descripción de concentración no estima zonas ni ajusta un modelo: con tan pocos documentos, las zonas serían muy sensibles a cómo se reparten los empates y las fronteras. Aquí se informa solo del acumulado.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Selecciona *Concentración de fuentes / acumulado*** en la pestaña *Cobertura y referencias*. La tabla muestra, para cada fuente, sus documentos, su posición y el porcentaje acumulado.
2. **Comprueba la cobertura del campo de fuente**: cuántos documentos tienen fuente conocida, porque ellos forman el denominador.
3. **Revisa nombres equivalentes** de una misma revista (siglas, abreviaturas, variantes tipográficas). Si no se unifican, una revista aparece como varias y la concentración se subestima.
4. **Marca una fuente** con el selector o pulsando un punto de la curva, y lee cuántas fuentes (y qué porcentaje de las fuentes totales) acumulan esa proporción de documentos.
5. **Lee los cruces de la curva con el 50 % y el 80 %** como descripción de esta búsqueda.
6. **Redacta lo observado**, sin atribuirle un contraste de ley.

## 4. Cómo leer la curva sin errores de interpretación

**Una subida rápida describe concentración en esta búsqueda.** No prueba la ley de Bradford ni la calidad de las revistas.

**El denominador son los documentos con fuente conocida.** Los registros sin fuente quedan fuera, de modo que la cobertura del campo condiciona la cifra.

**Las variantes de un mismo nombre fragmentan la concentración.** Una curva con muchas fuentes de un solo documento puede reflejar nombres sin unificar y no dispersión real.

**El 80/20 no es una ley de tu corpus.** Las líneas del 50 % y del 80 % sirven para leer la curva, no establecen un umbral.

**Qué comprobar.** Cuántos documentos tienen fuente, si los nombres equivalentes están unificados y si la concentración cambia al ampliar o acotar la búsqueda.

## 5. Pautas para documentar y redactar tu decisión

Escribe lo observado: «Las primeras [k] fuentes acumularon el [p] % de los documentos con fuente identificada ([n] de [N])».

Es una redacción modelo que debes completar con tus cifras. Reserva expresiones como «se confirmó la ley de Bradford» para un contraste específico, con sus zonas, su modelo y su ajuste documentados.

+++ Nota técnica: cálculo
`bibliography_extensions()` cuenta documentos por fuente (con unificación de variantes de mayúsculas, acentos y puntuación cuando la opción de unificar variantes de escritura de nombres está activa, como ocurre por defecto), ordena de mayor a menor y calcula `porcentaje_acumulado = 100 · cumsum(documentos) / sum(documentos)`, de modo que el denominador es el total de documentos con fuente no vacía.
+++
