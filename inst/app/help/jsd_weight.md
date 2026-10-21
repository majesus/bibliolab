---
titulo: Cómo pesa cada documento / elegir con criterio
objetivo: Elegir entre dos formas de construir el reparto de palabras de un conjunto, sabiendo que responden a preguntas diferentes.
fuentes:
  - Gallagher et al. / generalized word shifts | https://doi.org/10.1140/epjds/s13688-021-00260-3
---

## 1. Conceptos fundamentales: dos preguntas sobre el mismo conjunto

**Para situarte.** Ponderación es la regla que determina cuánto aporta cada documento al reparto de palabras. Tokens son apariciones de palabras, incluidas las repetidas. Normalizar un documento, en esta comparación, significa convertir sus recuentos de palabras en proporciones que suman 100 %.

**Lo que quieres saber.** Cuánto debe pesar un resumen largo frente a uno breve cuando se describe el vocabulario de un conjunto.

**Lo que se calcula realmente.** Las dos opciones comparan proporciones de palabras; difieren en cómo se construye el reparto de cada conjunto. Con **tokens agrupados** se suman todas las apariciones del conjunto y se dividen por su total: un documento de 400 palabras aporta cuatro veces más palabras que uno de 100. Responde a «¿cómo se reparte el vocabulario total del conjunto?». Con **documentos equilibrados** se normaliza primero cada documento y luego se promedian los repartos: cada documento con vocabulario aporta el mismo peso. Responde a «¿cuál es el perfil de un documento medio?».

## 2. Ejemplo práctico: educación y salud

Los cálculos de este apartado se han ejecutado con la función de la aplicación. Un resumen breve contiene «educación» y «salud» una vez cada una. Otro contiene «educación» ocho veces y «salud» dos. Agrupando tokens, «educación» tiene 9 de 12 apariciones: 75 %. Equilibrando los documentos, se promedian 50 % y 80 %: «educación» tiene 65 %. Ningún resultado es erróneo: expresan preguntas distintas.

Ahora, la revisión extensa. En A, «clínica» ocupa el 8 % del vocabulario. B reúne 99 textos de 100 palabras con una mención cada uno (1 %) y una revisión de 10.000 palabras con 2.000 menciones (20 %).

| Ponderación | «Clínica» en A | «Clínica» en B | Dirección de la barra | Pregunta que responde |
|---|---|---|---|---|
| Tokens agrupados | 8 % | 10,55 % | Hacia B | Reparto de todas las apariciones |
| Documentos equilibrados | 8 % | 1,19 % | Hacia A | Promedio de los repartos por documento |

### Interpretación

Al agrupar tokens, «clínica» ocupa 2.099 de 19.900 palabras (10,55 %), por encima de A. Al dar el mismo peso a cada documento, su proporción media es (99 × 1 % + 20 %) / 100 = 1,19 %, por debajo de A. La barra cambia de dirección porque has cambiado la pregunta, no porque una de las cuentas sea incorrecta. Su longitud exacta depende además del resto del vocabulario: este ejemplo no basta para afirmar que la barra sea larga ni que haya cambiado el interés de toda una disciplina.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Decide la pregunta.** Si quieres describir cómo se reparte el vocabulario total del corpus, elige *Tokens agrupados*. Si quieres comparar el perfil medio de los documentos, elige *Documentos equilibrados*.
2. **Elige la opción en el selector de esta ventana** y pulsa *Aplicar esta opción*; se actualiza el control *Cómo pesa cada documento* de la comparación.
3. **Mantén la misma ponderación en A y B.** Mezclarlas haría incomparables los repartos.
4. **Comprueba la cobertura** de las barras mostradas.
5. **Contrasta con la otra opción** si la longitud de los resúmenes puede condicionar tu lectura, y conserva ambas ejecuciones.

## 4. Cómo leer el resultado sin errores de interpretación

**Con resúmenes de longitudes desiguales**, *Documentos equilibrados* suele ser un punto de partida razonable para comparar publicaciones, porque un documento largo no domina el reparto. No es la opción correcta por defecto en todos los casos.

**Ninguna opción garantiza una verdad conceptual.** Ninguna equivale a medir lo que piensan los autores.

**La dirección de una barra puede depender de la ponderación.** Si una palabra cambia de lado al cambiar de opción, el resultado depende de la relación entre la longitud de los documentos y el uso de esa palabra. Puede deberse a unos pocos textos extensos o a diferencias de longitud repartidas entre varios; hay que consultar los documentos para distinguirlo.

**Qué comprobar.** Qué documentos aportan la mayor parte de las apariciones de la palabra que te interesa y si el resultado cambia al excluirlos.

## 5. Pautas para documentar y redactar tu decisión

Indica la ponderación elegida y por qué: «La comparación se realizó con [tokens agrupados / documentos equilibrados], porque la pregunta era [descripción del vocabulario total / del perfil medio de los documentos]; se contrastó con la otra ponderación y [el resultado se mantuvo / cambió en (descripción)]».

Es una redacción modelo que debes completar con lo que hiciste.
