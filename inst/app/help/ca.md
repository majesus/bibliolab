---
titulo: AC / Comprender el análisis
objetivo: Evaluar la calidad de representación de un plano antes de atribuir sentido a las posiciones de las palabras.
fuentes:
---

## 1. Finalidad y funcionamiento

**Finalidad.** Comparar cómo se reparten las apariciones de las palabras entre documentos o frases. El AC resume asociaciones de esa tabla de recuentos; no detecta automáticamente temas ni grupos.

**Datos de partida.** Cada fila es una unidad: documento completo o frase, según 02. Cada columna es un término. Su perfil es el reparto de sus apariciones entre las unidades. Un término con 2 apariciones en una unidad y 4 en otra tiene el mismo perfil que otro con 10 y 20 apariciones en esas mismas unidades: los dos reparten sus apariciones en proporción de uno a dos.

**Cómo se forman los ejes.** Se compara la tabla con el reparto esperado si no hubiera asociaciones específicas entre términos y unidades, dados sus totales. Los ejes resumen las desviaciones respecto a esa referencia. La inercia cuantifica esas desviaciones con la ponderación del AC; el porcentaje de un eje indica qué parte de la inercia total recoge. No es la varianza del ACP.

**Qué indica cada término.** Su masa es su proporción en el total de apariciones. Su contribución indica qué porcentaje de la construcción de un eje le corresponde. Su **cos²** indica qué proporción de su distancia al centro, elevada al cuadrado, se representa en el plano. Un cos² de 0,20 significa que el plano recoge el 20 % de esa medida geométrica y deja el 80 % fuera; no mide el porcentaje de significado comprendido ni la calidad de la palabra.

**Cómo decidir.** Revisa primero la inercia del plano; después, el cos² y las contribuciones de los términos que quieres interpretar. Lee sus documentos antes de dar nombre al contraste. Los signos positivo y negativo son direcciones de los ejes, no valoraciones.

**Scopus y Web of Science.** Revisa los campos y las unidades preparados en 02: aplicar el mismo método no elimina diferencias entre documentos recuperados, idiomas o metadatos disponibles.

## 2. Ejemplo de lectura

Las cifras proceden de ejecutar el cálculo de la aplicación (con la línea base desactivada) sobre un corpus ilustrativo de nueve resúmenes de tres temas (salud, escuela y energía) y diez términos.

El primer eje recoge el 43,6 % de la inercia y el segundo el 40,1 %: el plano recoge el 83,7 % y deja fuera el 16,3 %. En ese plano, «alumno» tiene un cos² de 0,99 y «paciente» de 0,97, de modo que el plano recoge una parte alta de su distancia cuadrática al centro; «datos», presente en todos los documentos, tiene un cos² de 0,115 y una contribución inferior al 0,2 % en ambos ejes, de modo que esa posición recoge una parte pequeña de su distancia total y necesita leerse junto a otros ejes. El eje 1 contrapone los términos de energía y edificios (contribuciones de «edificio» del 23,9 % y «energia» del 20,1 %) a los de escuela; el eje 2 separa los términos de salud (contribuciones de «paciente» del 29,1 % y de «hospital» del 26,5 %).

### Interpretación

Dos palabras próximas con cos² bajo pueden parecer semejantes solo por la proyección, aunque difieran en otros ejes. Un eje se interpreta con los términos que lo construyen y con sus documentos, no por el signo positivo o negativo en sí mismo: el signo de un eje puede invertirse sin cambiar la solución.

## 3. Parámetros y cómo decidir

### Decidir la unidad, el vocabulario y la lectura

- **Unidad de texto:** se conserva la elegida en 02. Con documentos se compara el reparto entre textos completos; con frases, entre segmentos. Cambiarla requiere volver a preparar el corpus y recalcular. El resultado responde a una comparación distinta, no a una simple ampliación del gráfico.
- **Máximo de términos:** el inicio es 40, seleccionados por frecuencia dentro del vocabulario retenido. Un máximo mayor añade perfiles y puede modificar ejes, contribuciones e inercia. Contrasta otro límite conservando las demás decisiones.
- **Búsqueda de términos:** localiza y distingue palabras, incluidas las que tienen coordenadas coincidentes. Conserva el ajuste. En la vista ampliada, el número de nombres escritos en el gráfico solo modifica los nombres dibujados.

Consulta **Cómo decidir** junto al control para revisar una secuencia práctica de comparación. Antes de atribuir significado a un eje, comprueba su inercia, el cos² de las palabras y cuáles contribuyen a construirlo. La frecuencia o masa, la representación y la contribución responden a preguntas diferentes.

### Primer recorrido

1. **Elige el número de términos** (3 a 150; los más frecuentes del vocabulario retenido) y pulsa *Calcular mapa*. Se necesitan al menos tres unidades con palabras y tres términos.
2. **Consulta primero la inercia.** El mensaje bajo el botón indica el porcentaje de inercia del plano y cuántos ejes superan la línea base.
3. **Consulta el cos² de los términos que quieres interpretar.** *Localizar un término* muestra su cos², su contribución a cada eje y su masa.
4. **Revisa las contribuciones.** Las contribuciones suman 100 % por eje e identifican qué términos construyen el contraste.
5. **Lee los documentos** que dan significado a la diferencia que ves en un eje.
6. **Mira la inercia por eje** en el gráfico que muestra el porcentaje de inercia de cada eje antes de decidir cuántos ejes merecen interpretación.

## 4. Salidas, comprobaciones y límites

**La inercia no es la varianza del ACP.** No compares ambas medidas como si fueran la misma.

**La referencia de permutaciones permite una comparación concreta.** Para cada eje se compara su porcentaje de inercia con el percentil 95 obtenido al permutar, columna a columna, las unidades en que aparece cada término (se conservan los totales por término). No superar esa referencia indica que el porcentaje de inercia no excede ese umbral de comparación. No demuestra ausencia de estructura; superarlo tampoco confirma un tema ni convierte el resultado en una prueba universal de independencia.

**Los puntos próximos no son grupos probados.** No describas como clústeres confirmados los conjuntos que parecen próximos en una proyección, ni interpretes distancias entre puntos de tipos diferentes (por ejemplo, entre una palabra y un documento en planos separados).

**Se necesitan al menos dos dimensiones útiles para dibujar un plano.** Si las unidades tienen perfiles iguales, o solo hay una dimensión interpretable, la aplicación lo indica y no dibuja el plano.

**Qué comprobar.** Cómo se comparan los ejes con esa referencia y si los términos que interpretas tienen cos² alto y que cada contraste que describes se ve en los documentos.

## 5. Cómo documentar la decisión

Una lectura prudente sería: «El plano recoge el [p] % de la inercia; el primer eje contrapone perfiles caracterizados por [términos] frente a [términos], cuya representación se comprobó mediante cos² (superior a [valor])». Si calculaste la línea base, añade cuántos ejes la superaron.

Es una redacción modelo que debes completar con tus cifras. No describas como clústeres confirmados los conjuntos que parecen próximos en una proyección.

+++ Nota técnica: cálculo
`run_ca()` construye la matriz de residuos estandarizados `(P − r cᵀ) / √(r cᵀ)`, donde P es la tabla de conteos dividida por su total, y r y c son las masas de filas y columnas; la descomposición en valores singulares da los ejes. Las coordenadas son principales (`D·U/√r` y `D·V/√c`). El cos² del plano divide la suma de las distancias al cuadrado en sus dos ejes entre la distancia cuadrática total del término al centro, calculada usando las dimensiones disponibles. La contribución de un término al eje j es `c_i · coord_ij² / λ_j × 100`. La línea base usa `B = 50` permutaciones por defecto.
+++
