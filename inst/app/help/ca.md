---
titulo: Correspondencias / leer un plano
objetivo: Evaluar la calidad de representación de un plano antes de atribuir sentido a las posiciones de las palabras.
fuentes:
---

## 1. Conceptos fundamentales: perfiles, inercia, cos² y contribución

**Lo que quieres saber.** Qué palabras se parecen por la forma en que se reparten entre las unidades de texto, y si el plano que estás mirando permite fiarse de esas posiciones.

**Lo que se calcula realmente.** El **análisis de correspondencias** compara cómo se reparte el vocabulario entre las unidades. Dos palabras tienen perfiles parecidos si su presencia relativa se concentra en unidades similares. La técnica resume esas diferencias en ejes; el dibujo es una proyección y pierde la información que queda fuera de los ejes mostrados.

Cuatro conceptos responden a preguntas diferentes. La **inercia** cuantifica las diferencias de perfil que resume el análisis, y el porcentaje de un eje indica qué parte de esa variación recoge. El **cos²** indica qué parte de la posición de un objeto queda representada en el plano. La **contribución** responde a qué términos participan más en construir un eje. La **masa** es el peso del término: su proporción sobre el total de apariciones.

> **La analogía cotidiana:**
>
> Es como la sombra de un objeto tridimensional proyectada en una pared: dos objetos distintos pueden proyectar sombras que se tocan, y una sombra nítida (cos² alto) refleja mejor al objeto que una sombra borrosa (cos² bajo).
>
> **Dónde deja de servir la analogía:** una sombra se compara con el objeto a simple vista. Aquí nada permite ver cuánto se ha perdido salvo que consultes el cos² y la inercia de los ejes.

## 2. Ejemplo práctico: un plano con dos ejes de inercia similar

Las cifras proceden de ejecutar el cálculo de la aplicación (con la línea base desactivada) sobre un corpus ilustrativo de nueve resúmenes de tres temas (salud, escuela y energía) y diez términos.

El primer eje recoge el 43,6 % de la inercia y el segundo el 40,1 %: el plano recoge el 83,7 % y deja fuera el 16,3 %. En ese plano, «alumno» tiene un cos² de 0,99 y «paciente» de 0,97, de modo que su posición es fiable; «datos», presente en todos los documentos, tiene un cos² de 0,115 y una contribución inferior al 0,2 % en ambos ejes, de modo que su posición cerca del centro no dice nada. El eje 1 contrapone los términos de energía y edificios (contribuciones de «edificio» del 23,9 % y «energia» del 20,1 %) a los de escuela; el eje 2 separa los términos de salud (contribuciones de «paciente» del 29,1 % y de «hospital» del 26,5 %).

### Interpretación

Dos palabras próximas con cos² bajo pueden parecer semejantes solo por la proyección, aunque difieran en otros ejes. Un eje se interpreta con los términos que lo construyen y con sus documentos, no por el signo positivo o negativo en sí mismo: el signo de un eje puede invertirse sin cambiar la solución.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige el número de términos** (3 a 150; los más frecuentes del vocabulario retenido) y pulsa *Calcular mapa*. Se necesitan al menos tres unidades con palabras y tres términos.
2. **Consulta primero la inercia.** El mensaje bajo el botón indica el porcentaje de inercia del plano y cuántos ejes superan la línea base.
3. **Consulta el cos² de los términos que quieres interpretar.** *Localizar un término* muestra su cos², su contribución a cada eje y su masa.
4. **Revisa las contribuciones.** Las contribuciones suman 100 % por eje e identifican qué términos construyen el contraste.
5. **Lee los documentos** que dan significado a la diferencia que ves en un eje.
6. **Mira la inercia por eje** (*cuánta información recoge cada eje*) antes de decidir cuántos ejes merecen interpretación.

## 4. Cómo leer el plano sin errores de interpretación

**La inercia no es la varianza del ACP.** No compares ambas medidas como si fueran la misma.

**La línea base distingue estructura de azar.** Para cada eje se compara su porcentaje de inercia con el percentil 95 obtenido al permutar, columna a columna, las unidades en que aparece cada término (se conservan los totales por término). Un eje que no lo supera no se distingue de un reparto al azar con esos totales; los ejes 3 y siguientes no se interpretan como estructura salvo que lo superen.

**Los puntos próximos no son grupos probados.** No describas como clústeres confirmados los conjuntos que parecen próximos en una proyección, ni interpretes distancias entre puntos de tipos diferentes (por ejemplo, entre una palabra y un documento en planos separados).

**Perfiles idénticos o rango insuficiente no permiten un plano.** Si las unidades tienen perfiles iguales, o solo hay una dimensión interpretable, la aplicación lo indica y no dibuja el plano.

**Qué comprobar.** Que los dos ejes superan la línea base, que los términos que interpretas tienen cos² alto y que cada contraste que describes se ve en los documentos.

## 5. Pautas para documentar y redactar tu decisión

Una lectura prudente sería: «El plano recoge el [p] % de la inercia; el primer eje contrapone perfiles caracterizados por [términos] frente a [términos], cuya representación se comprobó mediante cos² (superior a [valor])». Si calculaste la línea base, añade cuántos ejes la superaron.

Es una redacción modelo que debes completar con tus cifras. No describas como clústeres confirmados los conjuntos que parecen próximos en una proyección.

+++ Nota técnica: cálculo
`run_ca()` construye la matriz de residuos estandarizados `(P − r cᵀ) / √(r cᵀ)`, donde P es la tabla de conteos dividida por su total, y r y c son las masas de filas y columnas; la descomposición en valores singulares da los ejes. Las coordenadas son principales (`D·U/√r` y `D·V/√c`). El cos² es la parte del cuadrado de la distancia al centro que recoge el plano (no solo los dos ejes mostrados). La contribución de un término al eje j es `c_i · coord_ij² / λ_j × 100`. La línea base usa `B = 50` permutaciones por defecto.
+++
