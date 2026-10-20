---
titulo: ACP / componentes principales y perfiles léxicos
objetivo: Distinguir coordenadas, varianza, contribución y calidad de representación al leer un plano de componentes principales.
fuentes:
  - R / prcomp | https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prcomp.html
---

## 1. Conceptos fundamentales: un perfil TF-IDF y sus componentes

**Lo que quieres saber.** En qué se diferencian los documentos por su vocabulario, y qué palabras explican esas diferencias.

**Lo que se calcula realmente.** Un **perfil TF-IDF** es una fila de números que resume el vocabulario de un documento: hay un valor por término, y es cero si el término no aparece. El TF-IDF pondera cuánto se usa el término dentro del documento y su rareza entre documentos. El perfil no es un tema, una etiqueta ni una valoración de calidad: es una representación para comparar textos numéricamente.

El **ACP** (análisis de componentes principales) busca combinaciones de esas variables que recojan las diferencias entre documentos. El primer componente resume la mayor variación posible; el siguiente recoge otra parte sin repetir la dirección del primero. El mapa muestra los dos primeros y pierde la variación de los restantes. La **varianza explicada** de un componente es la parte de la variación total que recoge; el **cos²** de un punto es la parte de su posición que queda representada en el plano; la **contribución** indica cuánto participa un documento o un término en construir un eje.

> **La analogía cotidiana:**
>
> Es como fotografiar una nube de puntos en el espacio desde el ángulo que más los separa: la foto resume la forma de la nube, pero dos puntos que parecen tocarse pueden estar a distinta profundidad.
>
> **Dónde deja de servir la analogía:** en una foto sabes qué ángulo has elegido. Aquí el ángulo lo decide el método (el que maximiza la varianza), y esa dirección puede corresponder a una diferencia puramente léxica, como la longitud de los textos, que no es el contraste temático que buscas.

## 2. Ejemplo práctico: el efecto de estandarizar

Las cifras proceden de ejecutar el cálculo de la aplicación (con la línea base desactivada) sobre el mismo corpus ilustrativo de nueve resúmenes y diez términos que se usa en la guía de correspondencias.

Sin estandarizar, los dos primeros componentes recogen el 45,0 % y el 41,9 % de la varianza: el plano recoge el 86,8 % y deja fuera el 13,2 %. Los términos «alumno» (cos² 0,99), «edificio» (0,99) y «paciente» (0,98) están muy bien representados; «datos», presente en todos los documentos, tiene un cos² de 0,10 y no debe interpretarse en ese plano. Al estandarizar los términos a varianza 1, el plano recoge el 75,9 % (38,4 % y 37,5 %) y «datos», un término de poca variación, sube a un cos² de 0,21: la estandarización da más peso relativo a los términos de poca variación y cambia la solución.

### Interpretación

Un perfil de documento en el plano no es un tema: dos documentos próximos pueden diferir en los componentes que no se dibujan. El plano de documentos muestra puntuaciones y el de variables muestra las correlaciones de cada término con los componentes, en otra escala: una flecha y un documento no son comparables por la distancia entre esos dos dibujos.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Empieza sin estandarizar.** Deja desmarcada *Estandarizar términos a varianza 1* (el valor inicial) y fija el máximo de términos (100 por defecto; de 3 a 300, los más frecuentes). El ACP siempre **centra** cada término (le resta su media); estandarizar, además, lo divide por su desviación típica.
2. **Calcula el ACP.** Se necesitan al menos tres documentos con vocabulario y tres términos con variación; los términos sin variación se excluyen y se registran.
3. **Mira primero la varianza** de los ejes (pestaña *Varianza explicada*) y su línea base.
4. **Mira después la representación.** Consulta el cos² de los documentos y términos que quieres interpretar y sus contribuciones.
5. **Lee la dirección de un eje** con los términos asociados y vuelve a los resúmenes de los documentos que lo definen.
6. **Contrasta la decisión de estandarizar.** Calcula con y sin estandarización, comprueba qué términos de poca variación adquieren peso y si esa decisión responde a tu pregunta; documenta el vocabulario.

## 4. Cómo leer el ACP sin errores de interpretación

**Una varianza alta no demuestra una estructura temática.** Un componente puede recoger mucha variación por razones léxicas o de longitud. La línea base ayuda a distinguir estructura de azar: cada término se permuta de forma independiente entre documentos, se calcula el porcentaje de varianza por componente y su percentil 95 es el umbral; un componente por debajo no se distingue de la varianza esperable con términos independientes.

**El ACP no identifica clases.** No ha encontrado temas ni grupos; resume variación. Los conjuntos de puntos que parecen próximos no son grupos confirmados.

**El TF-IDF del ACP no es el de Preparación.** En el ACP y en LSA se usa una variante suavizada del IDF para que los términos presentes en todo el corpus no tengan necesariamente peso cero; el indicador descriptivo de Preparación conserva `ln(N/df)` sin suavizar. Ambas fórmulas se documentan y no deben confundirse al reproducir cifras.

**Los signos de los ejes son arbitrarios.** Invertir un eje no cambia la solución.

**Qué comprobar.** Que los ejes superan la línea base, que los puntos que interpretas tienen cos² alto y que el contraste que lees en un eje se confirma al leer los documentos.

## 5. Pautas para documentar y redactar tu decisión

Puedes indicar: «Se aplicó ACP a perfiles TF-IDF centrados [con / sin] estandarización, con los [n] términos más frecuentes; el plano explicó el [p] % de la varianza». Añade el vocabulario, las exclusiones y la calidad de representación (cos²) de los objetos que interpretes.

Es una redacción modelo que debes completar con tus cifras. El ACP por sí solo no ha identificado clases temáticas.

+++ Nota técnica: cálculo
`run_pca()` calcula la matriz de proporciones de término por documento sobre el vocabulario retenido (los `max_terms` más frecuentes), la multiplica por el IDF suavizado `ln((1 + N) / (1 + df)) + 1` y aplica `stats::prcomp(center = TRUE, scale. = estandarizar)`. El cos² de un documento es el cuadrado de su distancia al origen en el plano dividido por el cuadrado de su distancia total al origen; el de un término es la suma de los cuadrados de sus correlaciones con los dos ejes. La contribución de un documento al eje j es `puntuación² / ((N − 1) λ_j) × 100`, y la de un término, `carga² × 100`. Se invierte el signo de cada componente de modo que su mayor carga sea positiva. La línea base usa B = 50 permutaciones independientes por término.
+++
