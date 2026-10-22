---
titulo: Comparar vocabulario (JSD) / explicar diferencias entre distribuciones
objetivo: Comparar dos conjuntos de documentos (A y B), identificar las palabras responsables de la diferencia y comprobar la cobertura y el ruido de muestreo.
fuentes:
  - Gallagher et al. / generalized word shifts | https://doi.org/10.1140/epjds/s13688-021-00260-3
  - Shifterator / código abierto | https://github.com/ryanjgallagher/shifterator
  - Sánchez-Franco y Rey-Tienda / artículo de referencia | https://doi.org/10.1108/MD-06-2023-0966
---

## 1. Conceptos fundamentales: comparar repartos, no cantidades

**Para situarte.** A y B son dos conjuntos sin documentos compartidos. El reparto de palabras indica qué porcentaje de las apariciones corresponde a cada término. Tokens significa apariciones de palabras después de la limpieza, incluidas sus repeticiones. La comparación utiliza el vocabulario conservado en 02.

**Lo que quieres saber.** Si el vocabulario de dos conjuntos de documentos (por ejemplo, dos periodos) es distinto, y qué palabras explican esa diferencia.

**Lo que se calcula realmente.** La **divergencia de Jensen–Shannon (JSD)** responde a cuánto difiere el reparto de palabras entre dos conjuntos. No compara cuántas palabras o documentos tiene cada uno, sino qué proporción ocupa cada término. Antes de calcularla, cada conjunto se transforma en un reparto que suma 100 %; así se puede comparar un conjunto grande con uno pequeño sin que el tamaño, por sí solo, cree una diferencia.

La JSD vale cero cuando los repartos coinciden, aumenta cuando los términos pesan de forma distinta y llega a uno (con logaritmos en base 2, es decir, en **bits**) cuando los conjuntos no comparten ningún término con presencia. Es una medida de **diferencia léxica del vocabulario analizado**: no es una medida de calidad, ni una prueba de significación, ni una explicación de por qué ocurrió el cambio.

## 2. Ejemplo práctico: tres situaciones

Los cálculos de este apartado se han ejecutado con la función de la aplicación.

**Mismo reparto, distinto tamaño.** En A hay 80 apariciones de «hospital» y 20 de «escuela»: «hospital» ocupa el 80 % y «escuela» el 20 %. En B hay 800 y 200; al dividir por sus mil apariciones se obtiene otra vez el 80 % y el 20 %. La JSD es 0: las cantidades absolutas son distintas, pero no la composición que se mide.

**Repartos sin nada en común.** Si A solo usa «hospital» y B solo usa «escuela», la JSD es 1 y cada palabra explica la mitad de la diferencia (50 %). En el gráfico, «hospital» se coloca a la izquierda porque pesa más en A, y «escuela» a la derecha porque pesa más en B. La dirección ayuda a leer; ninguna aportación a la diferencia es negativa.

**Grupos formados por el propio modelo.** Si comparas temas LDA o grupos UMAP + HDBSCAN, esos grupos se construyeron a partir de diferencias léxicas del mismo vocabulario que ahora se compara. La JSD y su referencia por permutación describen cuánto se separan los grupos que el modelo produjo (caracterización interna del ajuste); no confirman que sean categorías científicas, porque la separación estaba garantizada en parte por construcción. Para una confirmación externa hacen falta etiquetas independientes del modelo, como revista, periodo o disciplina. Con temas LDA, además, cada documento se asigna a su tema dominante y se pierde su mezcla de temas.

**Unidad de remuestreo.** La permutación y el bootstrap reordenan documentos completos como si fueran intercambiables. Si varios documentos comparten autores, revista o periodo, no lo son del todo: el intervalo y la p describen la variación condicional al corpus preparado, no la incertidumbre de toda la búsqueda bibliográfica, y no corrigen la dependencia entre documentos ni la multiplicidad cuando se interpretan muchas comparaciones.

**El ruido de muestreo.** Con conteos finitos, la JSD calculada es sesgada al alza: dos muestras extraídas del mismo reparto pueden mostrar una JSD positiva por las fluctuaciones de sus recuentos. En una simulación (200 términos con frecuencias decrecientes tipo Zipf, 300 repeticiones, semilla 1) la JSD media entre dos mitades del mismo reparto fue la siguiente.

| Palabras por conjunto | JSD media (bits) | Percentil 95 |
|---|---|---|
| 200 | 0,268 | 0,309 |
| 1.000 | 0,083 | 0,095 |
| 10.000 | 0,007 | 0,009 |

### Interpretación

Una misma JSD de 0,08 se lee de forma muy distinta según el tamaño: con 10.000 palabras por conjunto queda muy por encima de lo esperable por azar (media 0,007, percentil 95 de 0,009), mientras que con 1.000 palabras por conjunto coincide con el ruido (media 0,083). Por eso conviene comparar la JSD observada con la que se esperaría por azar y no leerla como una cifra absoluta. Las cifras de la tabla describen esa simulación y no tu corpus.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Define A y B.** Puedes comparar periodos de años, categorías de una columna, autores, grupos por citas, los grupos de UMAP con HDBSCAN o los temas de LDA. Los conjuntos A y B deben ser disjuntos.
2. **Elige cómo pesa cada documento** (ver *Elegir cómo pesa cada documento*): *Tokens agrupados* (los textos largos aportan más) o *Documentos equilibrados* (cada documento aporta lo mismo).
3. **Deja activo el ruido de muestreo** para comparar con el azar. Se necesitan al menos dos documentos por conjunto.
4. **Pulsa *Comparar A y B*.** Lee primero la JSD, la distancia (raíz de la JSD), el número de documentos en A y B, y la cobertura.
5. **Lee las barras.** Una barra hacia B identifica un término con mayor proporción en B; hacia A, uno con mayor proporción en A. Su longitud es el porcentaje que aporta a la JSD total. La dirección y la aportación son preguntas distintas: una palabra puede aumentar y explicar poco si otras diferencias son mucho mayores.
6. **Mira la contribución acumulada** para saber cuánto del resultado has examinado con las barras mostradas, y las pestañas de matriz y de evolución por años para ver el contexto.
7. **Lee las palabras que más aportan en sus documentos.** Un cambio puede deberse al idioma, a la búsqueda, a la longitud o a la selección del corpus; la JSD no distingue automáticamente esas causas.

## 4. Cómo leer la JSD sin errores de interpretación

**Una JSD positiva no es evolución conceptual.** No demuestra un cambio de interés ni su causa; describe una diferencia en el reparto del vocabulario retenido.

**El valor p de permutación responde a una pregunta acotada.** La permutación mantiene los tamaños de A y B y reparte al azar los documentos de A ∪ B; el valor p es `(1 + número de JSD nulas ≥ observada) / (B + 1)`. Indica si la diferencia observada es mayor que la que producirían asignaciones al azar de esos documentos. Su interpretación depende de que resulte adecuado intercambiar documentos entre A y B bajo la hipótesis de referencia; no permite generalizar automáticamente a toda una población. Un valor p pequeño no mide la magnitud ni la importancia de la diferencia. El **exceso** es la JSD observada menos la media de las redistribuciones al azar. Úsalo junto con los recuentos y los textos; no es una medida de importancia conceptual.

**El intervalo bootstrap hereda el sesgo.** Bootstrap significa tomar repetidamente muestras de documentos dentro de cada grupo, permitiendo que un mismo documento se elija varias veces y, como la JSD es sesgada al alza con pocos datos, su intervalo no está centrado en la «verdadera» diferencia; no lo uses como medida principal.

**Dos ponderaciones, dos preguntas.** Cambiar de *Tokens agrupados* a *Documentos equilibrados* puede invertir la dirección de una barra, no porque una cuenta sea incorrecta, sino porque cambia la pregunta (ver la guía de ponderación).

**Qué comprobar.** Cómo se compara la JSD observada con la obtenida al redistribuir los documentos al azar, cuántos documentos aporta cada conjunto y qué porcentaje de la diferencia explican las barras mostradas y que el contexto de las palabras principales respalda tu lectura.

## 5. Pautas para documentar y redactar tu decisión

Una redacción adaptable es: «Se compararon los perfiles léxicos de [A] y [B] mediante la divergencia de Jensen–Shannon en bits, con mezcla 50/50 y ponderación [elegida]. La JSD observada fue [valor], frente a [valor] esperada por permutación de documentos. Los términos mostrados explicaron el [p] % de la divergencia. Se contrastaron sus contextos antes de interpretar el cambio».

Es una redacción modelo que debes completar con tus cifras. Una JSD positiva no demuestra una evolución conceptual ni su causa.

+++ Nota técnica: definición y cálculo
Con las proporciones P y Q de los mismos términos y la mezcla M = (P + Q) / 2, la JSD es la media de las divergencias de Kullback–Leibler de P y de Q respecto a M, con logaritmos en base 2, lo que acota el resultado entre 0 y 1; los términos sin apariciones no aportan (convención 0·log 0 = 0). La distancia es la raíz cuadrada de la JSD, que cumple las propiedades de una métrica. La aportación de cada término es su parte de la suma, expresada como porcentaje de la JSD; las aportaciones suman 100 % si la JSD es positiva, y no se define un reparto cuando es cero. Las permutaciones son B = 500 por defecto, con semilla 2026.
+++
