---
titulo: 03 / Descripción bibliométrica
objetivo: Redactar observaciones verificables sobre el corpus, sabiendo qué registros aportan datos a cada cifra y cuál es su denominador.
fuentes:
  - Hirsch / el índice h | https://doi.org/10.1073/pnas.0507655102
---

## 1. Conceptos fundamentales: qué describen los indicadores

**Lo que quieres saber.** Cuántos documentos hay, cuándo se publicaron, dónde, quién los firma y cuánto se citan, y hasta qué punto puedes fiarte de esas cifras.

**Lo que se calcula realmente.** Los indicadores **describen el corpus preparado**, es decir, los documentos que han superado los filtros de 02. La producción cuenta documentos por año. Las fuentes, los autores y las palabras clave cuentan en cuántos documentos aparece cada elemento (**presencia documental**: un autor que firma un documento dos veces cuenta una vez). Las citas registradas provienen de la base de datos y de la fecha de extracción.

La **cobertura** es la disponibilidad de información. Si falta el año de un documento, no se sabe dónde situarlo en el tiempo; si falta su número de citas, no se sabe si recibió cero citas o si el dato no se exportó. Los resultados que dependen de un campo se calculan solo con los registros válidos para ese campo, y la cobertura permite ver cuántos son.

> **La analogía cotidiana:**
>
> Es como el cuadro de mandos de un coche: cada indicador es útil, pero ninguno dice nada sobre el motor si el sensor no está conectado. Un cuadro con la aguja a cero puede significar «sin consumo» o «sensor desconectado».
>
> **Dónde deja de servir la analogía:** en un coche, el sensor desconectado suele avisar con un piloto. Aquí, un valor ausente se muestra como ausente en la cobertura, pero nada te avisa de que la búsqueda original dejó fuera documentos relevantes.

## 2. Ejemplo práctico: dos autores, diez citas y un índice h

Las cifras son ilustrativas. Un artículo firmado por Ana y Luis suma un documento al ranking de cada uno. Si Ana firma 6 de 10 documentos y Luis 5, sus porcentajes (60 % y 50 %) suman más de 100 % porque la colaboración cuenta en ambos rankings.

Si en un corpus hay diez artículos con citas conocidas y otros cinco sin ese dato, la media de citas usa diez observaciones. Imputar un cero a los cinco desconocidos bajaría la media sin base alguna.

Para el **índice h del corpus**, ordena las citas de mayor a menor. Con cinco documentos citados 10, 8, 5, 4 y 3 veces, el índice h es 4: hay cuatro documentos con al menos 4 citas cada uno, y el quinto no llega a 5.

### Interpretación

Un ranking es una puerta de entrada a los documentos, no una conclusión. Si una autora encabeza la lista, abre sus registros y comprueba variantes del nombre y coautorías. Si suben las citas medias, comprueba cuántos documentos tienen ese dato y cuándo se extrajo: los años antiguos han tenido más tiempo para recibir citas.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Lee la cobertura primero.** Antes de interpretar un ranking, comprueba cuántos documentos tienen año válido, citas válidas, texto, autores y fuente.
2. **Producción.** La evolución anual cuenta documentos con año válido. Los años sin registros entre el primero y el último se dibujan con valor cero, solo para el gráfico. El último año puede estar incompleto si la extracción se hizo durante él.
3. **Fuentes, autores y palabras clave.** Son presencias documentales. El conteo completo de autores puede sumar más del 100 % por la colaboración. Para unificar variantes que solo difieren en mayúsculas, acentos o puntuación (*Machine Learning* y *machine learning*), la aplicación aplica la opción de 02 *Unificar variantes de escritura*; la tabla de variantes unificadas permite revisar lo fusionado. No resuelve homónimos ni abreviaturas de revistas.
4. **Citas.** La distribución excluye las ausencias. El índice h es el del corpus importado (con las citas de esta base y fecha), no el índice h personal de los autores; si faltan citas, es un límite inferior.
5. **Términos, JSD, redes, n-gramas, cobertura y referencias.** Cada pestaña tiene su propia guía.
6. **Cifras exactas y figuras.** *Ver tabla* muestra las cifras exactas; *Ampliar gráfico* sirve para estudiar o enseñar una figura. Las descargas conservan la precisión completa.
7. **Decide cómo continuar.** Si tu objetivo es describir el corpus, pulsa *Finalizar descripción y descargar*: los modelos temáticos son opcionales y no hace falta ajustarlos para obtener la entrega. Si necesitas estudiar patrones de vocabulario, mezclas de temas o grupos de documentos, pulsa *Explorar modelos temáticos*.

## 4. Cómo leer los indicadores sin errores de interpretación

**Las citas recibidas no son las referencias citadas.** Las primeras vienen de la base de datos y cuentan cuántas veces se cita un documento; las segundas son la bibliografía que el documento utiliza. Ninguna prueba calidad por sí sola.

**Producción y citas no prueban calidad, causalidad ni exhaustividad.** Un aumento de documentos sobre un tema describe el corpus recuperado; solo sustenta un aumento de interés del campo si has comprobado que la producción total, la búsqueda y la completitud del último año no explican el cambio.

**Un ranking no es una evaluación.** Antes de hablar de una tendencia del campo, distingue lo observado en esta búsqueda de lo que podría ocurrir fuera de ella.

**Qué comprobar.** Que los primeros puestos corresponden a entidades reales (no a variantes del mismo nombre), que el denominador de cada porcentaje es el que esperas y que la fecha de extracción no distorsiona la comparación entre años.

## 5. Pautas para documentar y redactar tu decisión

Una formulación verificable es: «En el corpus recuperado, [fuente] reúne [n] documentos de los [total con fuente] que tienen ese dato». Añade siempre la cobertura y el criterio de conteo. Sustituir esa frase por «la revista más importante» introduciría una valoración que el ranking no ha medido.

Para las citas: «Las [m] observaciones con citas válidas tienen una mediana de [x] citas (extracción de [fecha]); [k] documentos carecen de este dato y no se han contado como cero». Son redacciones modelo; completa y revisa cada cifra antes de copiarlas.

+++ Nota técnica: definiciones de los indicadores
`biblio_summary()` calcula la producción por año sobre los documentos con año válido; el índice h es `sum(sorted >= seq_along(sorted))` con las citas válidas ordenadas de mayor a menor; la media y la mediana de citas excluyen los valores ausentes. En autores, `author_citation_metrics()` calcula por autor las citas válidas, las ausentes, su suma y su índice h dentro del corpus. Las variantes de escritura se unifican con `variant_map()` al contar autores, palabras clave y fuentes cuando `normalize_labels` está activo.
+++
