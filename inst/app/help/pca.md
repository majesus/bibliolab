---
titulo: ACP / Comprender el análisis
objetivo: Distinguir coordenadas, varianza, contribución y calidad de representación al leer un plano de componentes principales.
fuentes:
  - R / prcomp | https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prcomp.html
---

## 1. Finalidad y funcionamiento

**Finalidad.** Resumir diferencias de vocabulario entre documentos y localizar qué palabras contribuyen a esos contrastes. El ACP no asigna temas ni grupos.

**Datos de partida.** Cada fila representa un documento y cada columna un término del vocabulario retenido. La celda contiene un peso TF-IDF: combina la proporción de la palabra dentro del documento con un factor mayor cuando aparece en menos documentos. La fila completa es el perfil numérico de ese documento; no es una descripción de su significado.

**Cómo se forman los ejes.** Un componente es una combinación ponderada de esas columnas. La varianza mide la dispersión de sus valores entre documentos. El primer componente recoge la mayor varianza posible; cada siguiente recoge la mayor que queda por representar, sin correlación lineal con los anteriores. El centrado resta siempre la media de cada término. La estandarización opcional divide además por su desviación típica, una medida de dispersión, para igualar sus varianzas iniciales.

**Tres cifras distintas.** La varianza explicada indica qué porcentaje de la variación total recoge un eje o un plano. El **cos²** indica representación geométrica: para un documento es la proporción de su distancia al centro, elevada al cuadrado, recogida por el plano; para un término es la proporción de su varianza representada por los componentes elegidos. Un cos² de 0,20 no significa representar el 20 % del contenido o del significado del texto. La contribución indica qué parte de la construcción de un eje corresponde a cada documento o término; no mide calidad científica.

**Cómo leer los dibujos.** En el plano de documentos, los puntos son documentos. En el de variables, las flechas son términos y muestran su correlación con los componentes: cómo cambian conjuntamente sus valores. Son objetos y escalas distintos; no compares una flecha con un documento por la distancia entre dos dibujos.

**Scopus y Web of Science.** Se utilizan los textos y el vocabulario preparados en 02. Revisa su cobertura e idioma y comprueba los documentos antes de nombrar un contraste.

## 2. Ejemplo de lectura

Las cifras proceden de ejecutar el cálculo de la aplicación (con la línea base desactivada) sobre el mismo corpus ilustrativo de nueve resúmenes y diez términos que se usa en la guía de correspondencias.

Sin estandarizar, los dos primeros componentes recogen el 45,0 % y el 41,9 % de la varianza: el plano recoge el 86,8 % y deja fuera el 13,2 %. Los términos «alumno» (cos² 0,99), «edificio» (0,99) y «paciente» (0,98) están muy bien representados; «datos», presente en todos los documentos, tiene un cos² de 0,10 por lo que el plano recoge solo una parte pequeña de su variación y no basta para interpretar su posición. Al estandarizar los términos a varianza 1, el plano recoge el 75,9 % (38,4 % y 37,5 %) y «datos», un término de poca variación, sube a un cos² de 0,21: la estandarización da más peso relativo a los términos de poca variación y cambia la solución.

### Interpretación

Un perfil de documento en el plano no es un tema: dos documentos próximos pueden diferir en los componentes que no se dibujan. El plano de documentos muestra puntuaciones y el de variables muestra las correlaciones de cada término con los componentes, en otra escala: una flecha y un documento no son comparables por la distancia entre esos dos dibujos.

## 3. Parámetros y cómo decidir

### Decidir el vocabulario, la estandarización y el plano

Los botones **Cómo decidir** explican qué cambia el ajuste y qué cambia solo su lectura.

- **Máximo de términos:** empieza con 100 términos frecuentes del vocabulario retenido. No es un máximo de nombres escritos en el gráfico: cambiarlo modifica la matriz y puede cambiar componentes y contribuciones. Contrasta un límite próximo y lee qué palabras entran o salen.
- **Estandarización:** empieza desactivada. El centrado resta siempre la media de cada término; estandarizar divide además por su desviación típica. Así todos parten de varianza 1. Puede impedir que domine una variable por su varianza y también aumentar la influencia de términos poco frecuentes con variación pequeña. Compara ambas opciones con el mismo vocabulario.
- **Componentes horizontal y vertical:** comienza por 1 y 2 y consulta cuánto explican conjuntamente. Otro par permite revisar variación no recogida por el primero. Cambiar de plano conserva el ajuste, pero actualiza el cos² y las contribuciones que se muestran para los ejes elegidos.
- **Cuadrante, búsqueda y nombres escritos en el gráfico:** facilitan consultar la figura. No crean grupos ni cambian las coordenadas. Un punto sin nombre escrito sigue formando parte del resultado.

No elijas una configuración por obtener mayor separación visual. Revisa varianza explicada, cos² y contribuciones y lee los textos que sostienen el contraste.

### Primer recorrido

1. **Empieza sin estandarizar.** Deja desmarcada *Estandarizar términos a varianza 1* (el valor inicial) y fija el máximo de términos (100 por defecto; de 3 a 300, los más frecuentes). El ACP siempre **centra** cada término (le resta su media); estandarizar, además, lo divide por su desviación típica.
2. **Calcula el ACP.** Se necesitan al menos tres documentos con vocabulario y tres términos con variación; los términos sin variación se excluyen y se registran.
3. **Mira primero la varianza** de los ejes (pestaña *Varianza explicada*) y la referencia calculada al redistribuir al azar los valores de cada término entre documentos. Esa referencia no certifica la interpretación de los ejes.
4. **Mira después la representación.** Consulta el cos² de los documentos y términos que quieres interpretar y sus contribuciones.
5. **Lee la dirección de un eje** con los términos asociados y vuelve a los resúmenes de los documentos que lo definen.
6. **Contrasta la decisión de estandarizar.** Calcula con y sin estandarización, comprueba qué términos de poca variación adquieren peso y si esa decisión responde a tu pregunta; documenta el vocabulario.

## 4. Salidas, comprobaciones y límites

**Una varianza alta no demuestra una estructura temática.** Un componente puede recoger mucha variación por razones léxicas o de longitud. La referencia de permutaciones permite una comparación concreta: cada término se permuta de forma independiente entre documentos, se calcula el porcentaje de varianza por componente y su percentil 95 es el umbral; no superarlo significa que su porcentaje no excede esa referencia. No demuestra que no haya estructura, y superarlo tampoco valida un significado temático. Este nulo conserva la distribución de cada término por separado, pero rompe la asociación entre términos dentro de cada documento y la longitud del documento; es una referencia definida por ese procedimiento, no una prueba general de dimensionalidad, y otro criterio (por ejemplo, el análisis paralelo con otros márgenes) puede dar otro resultado. El umbral es una estimación Monte Carlo: depende del número de permutaciones y de la semilla, ambos registrados en la entrega, y *supera_azar* no es una etiqueta de validez sustantiva.

**El ACP no identifica clases.** No ha encontrado temas ni grupos; resume variación. Los conjuntos de puntos que parecen próximos no son grupos confirmados.

**El TF-IDF del ACP no es el de Preparación.** En el ACP y en LSA se usa una variante suavizada del IDF para que los términos presentes en todo el corpus no tengan necesariamente peso cero; el indicador descriptivo de Preparación conserva `ln(N/df)` sin suavizar. Ambas fórmulas se documentan y no deben confundirse al reproducir cifras.

**Los signos de los ejes son arbitrarios.** Invertir un eje no cambia la solución.

**Qué comprobar.** Cómo se sitúan los ejes respecto a esa referencia y si los puntos que interpretas tienen cos² alto y que el contraste que lees en un eje se confirma al leer los documentos.

## 5. Cómo documentar la decisión

Puedes indicar: «Se aplicó ACP a perfiles TF-IDF centrados [con / sin] estandarización, con los [n] términos más frecuentes; el plano explicó el [p] % de la varianza». Añade el vocabulario, las exclusiones y la calidad de representación (cos²) de los objetos que interpretes.

Es una redacción modelo que debes completar con tus cifras. El ACP por sí solo no ha identificado clases temáticas.

+++ Nota técnica: cálculo
`run_pca()` calcula la matriz de proporciones de término por documento sobre el vocabulario retenido (los `max_terms` más frecuentes), la multiplica por el IDF suavizado `ln((1 + N) / (1 + df)) + 1` y aplica `stats::prcomp(center = TRUE, scale. = estandarizar)`. El cos² de un documento es el cuadrado de su distancia al origen en el plano dividido por el cuadrado de su distancia total al origen; el de un término es la suma de los cuadrados de sus correlaciones con los dos ejes. La contribución de un documento al eje j es `puntuación² / ((N − 1) λ_j) × 100`, y la de un término, `carga² × 100`. Se invierte el signo de cada componente de modo que su mayor carga sea positiva. La línea base usa B = 50 permutaciones independientes por término.
+++
