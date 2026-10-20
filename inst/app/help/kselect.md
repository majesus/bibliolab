---
titulo: Elegir el número de temas / leer la comparación
objetivo: Reducir el rango de valores de k con varios criterios y decidir después leyendo los temas, sin tomar ningún indicador como veredicto.
fuentes:
  - Chang et al. / reading tea leaves | https://papers.nips.cc/paper/2009/hash/f92586a25bb3145facd64ab20fd554ff-Abstract.html
---

## 1. Conceptos fundamentales: cuatro criterios, ninguno decisivo

**Lo que quieres saber.** Cuántos temas debe tener el modelo LDA para que sean interpretables y no dependan del azar de una ejecución.

**Lo que se calcula realmente.** La comparación ajusta el modelo para cada valor de k con varias semillas y resume cuatro aspectos. La **coherencia NPMI** mide si las palabras principales de un tema (diez por defecto) tienden a aparecer en los mismos documentos: para cada par se calcula la información mutua puntual normalizada, que vale −1 si nunca coinciden y se acerca a 1 si coinciden siempre; los pares cuyas dos palabras aparecen en todos los documentos no informan y se excluyen. La **diversidad** es la proporción de palabras principales distintas entre todos los temas. La **estabilidad** es el solapamiento (Jaccard) de las palabras principales entre semillas, tras emparejar de forma óptima los temas de cada par de ejecuciones. La **perplejidad reservada** mide qué tan bien predice el modelo documentos que no usó para entrenar; solo se calcula cuando se reserva una fracción de los documentos.

El **valor de compromiso** es el k que maximiza el peor de los tres primeros criterios (coherencia NPMI, estabilidad y diversidad) tras reescalarlos entre 0 y 1. La perplejidad no entra en él.

> **La analogía cotidiana:**
>
> Es como elegir cuántas secciones debe tener un periódico: demasiado pocas mezclan asuntos distintos, demasiadas separan lo que va junto. Ninguna medida sustituye a leer las secciones y decidir si el reparto tiene sentido.
>
> **Dónde deja de servir la analogía:** las secciones de un periódico las diseña una persona. Los temas de LDA los estima un algoritmo con componente aleatoria, de modo que distintas semillas pueden producir temas diferentes con el mismo k.

## 2. Ejemplo práctico: dos escenarios

Las cifras de los criterios de estos escenarios son ilustrativas (no proceden de un corpus real); el valor de compromiso y la detección de conflicto se han calculado con la función de recomendación de la aplicación.

**Primer escenario.** Con k entre 3 y 6, la coherencia NPMI es 0,10; 0,18; 0,15 y 0,08, la estabilidad 0,80; 0,70; 0,55 y 0,50, y la diversidad 1,00; 0,95; 0,90 y 0,80. Tras reescalar cada criterio entre 0 y 1, el peor de los tres vale 0,20 para k = 3 (por su coherencia), 0,67 para k = 4, 0,17 para k = 5 y 0 para k = 6. El valor de compromiso es k = 4. La coherencia es máxima en k = 4, y la estabilidad y la diversidad lo son en k = 3: los criterios coinciden de forma aproximada.

**Segundo escenario.** Si la coherencia sube hasta k = 6 (0,05; 0,10; 0,12; 0,20) mientras la estabilidad y la diversidad bajan (estabilidad 0,85; 0,80; 0,60; 0,40; diversidad 1,00; 0,98; 0,95; 0,90), cada criterio señala un k distinto: 6 para la coherencia y 3 para la estabilidad y la diversidad. El compromiso es k = 5 (puntuación 0,44) y la aplicación avisa de que no hay un k dominante.

### Interpretación

El compromiso es un resumen, no una elección: en el segundo escenario ningún criterio señala k = 5, y valores cercanos de la puntuación son prácticamente equivalentes. La perplejidad suele mejorar al aumentar k sin que mejore la interpretabilidad (Chang et al., 2009), y por eso se muestra a título informativo.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Define el rango de k** (de 2 a 12 como máximo; por defecto de 2 a 8) y el número de semillas (por defecto 3). Se admiten como máximo 60 ajustes (k × semillas).
2. **Pulsa el botón de comparación.** Cada ajuste usa las iteraciones fijadas para LDA. Con al menos 20 documentos se reserva por defecto el 10 % para la perplejidad.
3. **Lee la tabla de mejores valores** por criterio y la figura de cada indicador con su dispersión entre semillas.
4. **Mira el valor de compromiso y el aviso de conflicto.** Si los criterios señalan valores de k distintos, no hay un k dominante.
5. **Elige dos o tres valores candidatos,** ajusta cada uno y lee los documentos más representativos de cada tema.
6. **Fija el k elegido** con *Fijar este k y volver a calcular LDA* (actualiza el control de temas) y pulsa *Calcular LDA* para ajustar el modelo final.
7. **Documenta** el rango comparado, los criterios y la razón de la elección; el informe metodológico lo registra.

## 4. Cómo leer la comparación sin errores de interpretación

**La coherencia se calcula con tus propios documentos.** Orienta, pero no reemplaza el juicio humano sobre si un tema tiene sentido.

**La estabilidad baja indica que el modelo no encuentra una estructura firme con ese k.** Con una sola semilla no puede evaluarse.

**La perplejidad no equivale a interpretabilidad.** Por eso no entra en el compromiso.

**Valores cercanos son prácticamente equivalentes.** No elijas entre ellos por una diferencia pequeña de puntuación.

**Qué comprobar.** Que los valores candidatos permiten etiquetas defendibles, que no mezclan ideas distintas en un mismo tema y que el resultado se mantiene con otras semillas.

## 5. Pautas para documentar y redactar tu decisión

Puedes redactar: «Se compararon soluciones con k entre [a] y [b] ([s] semillas, [i] iteraciones) según coherencia NPMI, diversidad, estabilidad entre semillas y perplejidad reservada. El valor de compromiso fue k = [c]; se examinaron los temas de [candidatos] y se eligió k = [d] porque [razón basada en la lectura de los documentos]».

Es una redacción modelo que debes completar con tus cifras. Ningún criterio, por sí solo, justifica el número de temas.

+++ Nota técnica: criterios
La coherencia NPMI de un tema es la media, sobre los pares de sus palabras principales, de `ln(P(i,j) / (P(i)·P(j))) / (−ln P(i,j))`, con probabilidades de aparición por documento; un par que nunca coincide vale −1 y un par con P(i,j) = 1 se excluye. La diversidad es `palabras distintas / palabras totales` entre las palabras principales de todos los temas. La estabilidad de cada k es la media, sobre los pares de semillas, del Jaccard medio entre temas emparejados con una asignación óptima (húngaro). El compromiso es el k que maximiza el mínimo de las tres puntuaciones reescaladas entre su mínimo y su máximo en el rango comparado; los k sin NPMI informativa no compiten. Hay conflicto si los k óptimos de los tres criterios difieren en dos o más unidades.
+++
