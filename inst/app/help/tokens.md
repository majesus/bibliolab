---
titulo: Entender los filtros y TF-IDF
objetivo: Elegir filtros medibles y revisar qué se elimina, sin sustituir el criterio científico por un umbral.
fuentes:
  - Stanford / ponderación TF-IDF | https://nlp.stanford.edu/IR-book/html/htmledition/tf-idf-weighting-1.html
  - R / cuantiles de tipo 7 | https://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html
---

## 1. Conceptos fundamentales: entender antes de filtrar

En bibliometría y minería de textos se analizan unidades lingüísticas. Antes de fijar números o umbrales, es necesario distinguir con precisión cuatro conceptos:

- **Token vs. palabra:** Un *token* es cada unidad individual producida al segmentar un texto. Si la palabra *«estudiante»* aparece dos veces en un párrafo, hay **2 tokens**, pero representan **1 solo término**. Si activas la lematización, diferentes formas (*«estudiante»*, *«estudiantes»*) se agrupan bajo su forma base (lema).
- **Frecuencia (conteo total o recuento bruto):** Es el número total de veces que una palabra se repite en todo el corpus. Responde a: *¿cuánto se usa este término en total?*
- **Presencia documental (df):** Es el número de documentos distintos en los que la palabra aparece al menos una vez. Responde a: *¿cuán extendido está el término en la colección?*
- **TF-IDF (especificidad y rareza):** Mide la capacidad de una palabra para **distinguir un documento de los demás**. Premia las palabras que se concentran con fuerza en pocos textos y penaliza las que aparecen en casi todos.

> **La analogía culinaria:**
>
> Imagina una colección de recetas. La *sal* aparece en todas, o en casi todas: su presencia es máxima, pero no distingue una paella de una tarta (su TF-IDF es cero si figura en todas las recetas y muy bajo si falta en alguna). En cambio, el *azafrán* aparece en muy pocas recetas: cuando está presente, define de inmediato qué plato es (su TF-IDF es alto).
>
> **Cuidado con el límite de la analogía:** Una palabra muy rara en tu corpus no siempre es importante; a menudo es simplemente una errata tipográfica, un nombre propio secundario o una sigla aislada.

## 2. Ejemplo práctico: ¿por qué la palabra más repetida no siempre es la más informativa?

Imagina un corpus muy pequeño formado por **3 resúmenes** (N = 3) de 100 palabras cada uno, donde observamos dos términos: *«estudio»* y *«hospital»*. Los datos son ilustrativos. En la aplicación, las «palabras» de cada resumen son las que quedan tras la limpieza (palabras vacías, longitud, números), antes del filtro de vocabulario.

| Documento | Total de palabras | Apariciones de «estudio» | Apariciones de «hospital» | Frecuencia relativa (TF) de hospital | Rareza (IDF) de hospital | TF-IDF de hospital |
| --- | --- | --- | --- | --- | --- | --- |
| **Resumen A** | 100 | 5 | 3 | 3 / 100 = 0,03 | ln(3 / 1) ≈ 1,10 | 0,03 × 1,10 ≈ **0,033** |
| **Resumen B** | 100 | 5 | 0 | 0 / 100 = 0,00 | ln(3 / 1) ≈ 1,10 | 0,00 × 1,10 = **0,000** |
| **Resumen C** | 100 | 5 | 0 | 0 / 100 = 0,00 | ln(3 / 1) ≈ 1,10 | 0,00 × 1,10 = **0,000** |

### Interpretación y por qué el resultado matemático es exactamente 0

- **El término «estudio»:** Aparece 5 veces en cada uno de los 3 resúmenes (frecuencia total = 15; presencia df = 3 documentos).
  - ¿Por qué su rareza (IDF) es 0? La fórmula de rareza calcula el logaritmo natural (ln) del total de documentos (N) dividido entre los documentos donde aparece el término (df):
$$ IDF = ln(N / df) = ln(3 / 3) = ln(1) = 0 $$
  - Dado que cualquier número multiplicado por cero da cero, su peso final en cada texto es:
$$ TF-IDF = frecuencia relativa (TF) × IDF = 0,05 × 0 = 0 $$
  - *¿Debemos borrarlo?* No necesariamente. Un valor de cero significa únicamente que **no ayuda a diferenciar estos tres textos entre sí** porque todos lo comparten por igual. Sin embargo, puede ser un concepto contextual indispensable para describir el campo de estudio.
- **El término «hospital»:** Aparece 3 veces, pero únicamente en el Resumen A (frecuencia total = 3; presencia df = 1 documento).
  - Su frecuencia relativa (TF) en el Resumen A es 3 / 100 = 0,03.
  - Su rareza (IDF) es ln(3 / 1) = ln(3) ≈ 1,10.
  - Su peso en el Resumen A es 0,03 × 1,10 ≈ **0,033**.
  - *¿Qué indica?* Es un término específico que permite separar temáticamente el Resumen A de los demás.
  - La tabla de vocabulario de la aplicación muestra el **TF-IDF medio** de cada término: el promedio de sus pesos en todas las unidades con palabras, ceros incluidos. Para «hospital» es (0,033 + 0 + 0) / 3 ≈ 0,011.

## 3. Flujo de trabajo en la aplicación: paso a paso

### Paso 1: Configurar y verificar los campos (02 / Preparación → Correspondencia de campos y Delimitar y documentar)

1. **Texto a analizar:** Selecciona preferentemente el resumen (*Abstract*) o el título.
2. **Palabras clave:** Distingue entre las palabras asignadas por los autores (*Author Keywords / DE*) y los términos generados automáticamente por las bases de datos (*Keywords Plus / ID / Index Keywords*). Utiliza estas últimas solo si responde a un objetivo de tu diseño y documenta su procedencia.
3. **Separadores dentro de las celdas:** Comprueba la vista previa. Si varios autores o palabras clave están en la misma celda, la aplicación suele detectarlos separados por punto y coma (`;`). Verifica que los nombres compuestos conserven sus comas internas (por ejemplo: `Sánchez-Franco, M. J.; García, A.` deben reconocerse como 2 autores distintos).
4. **Filtros de corpus preliminares:**
   - **Duplicados:** Excluye duplicados si el corpus procede de múltiples búsquedas con solapamiento.
   - **Período temporal:** Limita el rango de años si buscas una ventana histórica concreta.
   - **Muestreo:** Analiza el 100 % de los documentos salvo que el volumen bloquee la memoria del ordenador.

### Paso 2: Limpieza y normalización lingüística (02 / Preparación → Normalización lingüística)

1. **Palabras vacías (*stopwords*):** Activa la eliminación de artículos, preposiciones y conectores en el idioma principal del corpus.
2. **Limpieza accesoria:** Excluye números aislados, enlaces web, correos electrónicos y avisos de copyright al final de los textos.
3. **Lematización y categorías gramaticales:**
   - *Lematizar (UDPipe):* Unifica variantes flexivas (por ejemplo, *evaluación* y *evaluaciones* pasan a un único lema).
   - *Filtrar categorías:* Permite conservar únicamente sustantivos o adjetivos si buscas un mapa temático puramente conceptual.
   - Son decisiones independientes: puedes usar una, ambas o ninguna.

### Paso 3: Selección de vocabulario y filtros iniciales (02 / Preparación → Selección del vocabulario)

Para no descartar términos cruciales de forma prematura, sigue esta regla:

- **Configuración inicial segura:**
  - Trabaja primero con **documentos completos** (no fragmentes en frases todavía).
  - Fija la **presencia mínima en 2 documentos** (elimina erratas únicas que solo aparecen una vez).
  - **No apliques** de entrada filtros restrictivos de TF-IDF ni de entropía.
- **Corpus extensos (miles de artículos):** Evalúa una presencia mínima del **0,5 % al 1 % del total de documentos**. Tómalo siempre como una **prueba de sensibilidad** (para observar qué vocabulario desaparece) y nunca como un umbral fijo e incuestionable.

## 4. Cómo leer las estadísticas sin errores de interpretación

En bibliometría, la inmensa mayoría de las palabras solo aparecen en unos pocos documentos. La tabla de datos está dominada por ceros (*matriz dispersa*). Esto altera el significado habitual de las medidas estadísticas.

### A. ¿Por qué la mediana y los percentiles valen casi siempre 0?

- **Qué es la mediana:** El valor que queda exactamente en el medio (posición 50 %) tras ordenar los documentos de menor a mayor valor del término.
- **Por qué da cero:** Si analizas 100 artículos y un término aparece en 15 de ellos, en los otros 85 artículos su valor es 0. Al ordenar la serie de menor a mayor, las primeras 85 posiciones son ceros. El valor central (la posición 50) es, por fuerza matemática, **0**.
- **Conclusión práctica:** Que la mediana o el percentil 25 valgan 0 **no significa que el término sea irrelevante o inexistente**. Solo indica que no está generalizado en la mayoría de los documentos. Los percentiles se calculan con el tipo 7 de R.

### B. Media general vs. «Solo unidades con peso positivo»

- **Media general:** Suma todos los valores y los divide entre el total de documentos, **incluyendo todos los ceros**. Esto diluye la cifra y produce números artificialmente pequeños.
- **Solo unidades con peso positivo:** Calcula el promedio **únicamente en los artículos donde el término sí aparece y distingue textos** (ignorando los ceros). Te muestra la intensidad con la que se utiliza cuando un autor recurre a él.
- **Precaución:** Examina esta cifra junto con la presencia documental (df). Un término con un peso positivo altísimo pero presente en un solo documento sigue siendo un caso aislado o anecdótico.

### C. Dispersión (MAD: mediana de desviaciones absolutas)

- Mide cuán variable o concentrado es el uso de una palabra a lo largo del corpus respecto a su mediana (calculada de forma directa, sin aplicar el factor normalizador 1,4826).
- **No mide calidad conceptual:** Una alta dispersión describe un uso irregular, a ráfagas; no indica si el término es científicamente valioso para tu investigación.

### D. ¿Por qué las cifras de TF-IDF no coinciden entre pantallas?

Si una palabra muestra un valor de TF-IDF en la pantalla de *Preparación*, otro en los *Modelos (ACP/LSA)* y otro en la *Lectura enlazada*, **el cálculo no es erróneo**. Cada módulo adapta la fórmula matemática a su función analítica (N es el total de unidades del corpus y df el número de unidades donde aparece el término):

- **En Preparación:** Multiplica la frecuencia relativa (TF) de cada texto por la rareza simple:
$$ frecuencia relativa (TF) × ln(N / df) $$
- **En LSA y ACP:** Multiplican la frecuencia relativa (TF) por una rareza suavizada (sumando 1 al numerador y al denominador para evitar divisiones por cero y estabilizar las dimensiones):
$$ frecuencia relativa (TF) × [ln((N + 1) / (df + 1)) + 1] $$
  - En LSA, además, el vector de cada documento se normaliza a longitud 1 antes de la descomposición.
  - En el ACP, las columnas se centran siempre restando su media. Solo si activas la casilla *Estandarizar términos a varianza 1* (desactivada por defecto) se reescalan, además, dividiendo por su desviación típica.
- **En Lectura enlazada:** Suma sobre las fichas el recuento bruto amortiguado con logaritmo multiplicado por la rareza simple, evitando que un término hiperrepetido en un único párrafo eclipse al resto de fichas. Aquí N y df cuentan fichas, no documentos del corpus:
$$ ln(1 + frecuencia bruta) × ln(N / df) $$

> **Regla de oro:** No compares los números decimales exactos entre diferentes pantallas. Compara el **orden de importancia (el ranking relativo de mayor a menor)** de las palabras dentro de una misma pantalla.

## 5. Pautas para justificar y documentar tu análisis

Al redactar la sección metodológica de tu tesis o artículo científico:

1. **Evita justificaciones absolutas:** Nunca escribas que un filtro automático *«eliminó todas las palabras irrelevantes»*. Las fórmulas matemáticas no comprenden el significado ni la importancia teórica de las palabras.
2. **Justifica los umbrales por su efecto empírico:** Explica qué efecto tuvo el filtro en los datos observados. Ejemplo de redacción:

> *«Se estableció una presencia documental mínima de 2 artículos para eliminar erratas y términos accidentales. Se inspeccionaron cualitativamente los términos excluidos para asegurar que no se eliminara vocabulario teórico central para la investigación».*

3. **Conserva siempre los términos clave:** Si un concepto es el objeto principal de tu estudio (por ejemplo, *«educación»*, *«evaluación»* o *«consumo»*), consérvalo en el análisis aunque aparezca en casi todos los documentos y su valor de rareza o TF-IDF sea cero.

+++ Nota técnica: criterios avanzados y valores iniciales
Longitud de las palabras: de 3 a 40 caracteres. Frecuencia total mínima: 1. Presencia mínima: 2 documentos. Presencia máxima: 100 % (no elimina nada). TF-IDF medio mínimo: 0 (no elimina nada). Entropía normalizada máxima: 1 (no elimina nada). Máximo de términos: 1.000. Los números aislados se eliminan por defecto; el filtro de códigos alfanuméricos está desactivado porque puede perder términos científicos como COVID19 o CO2.

La presencia mínima y máxima se miden siempre por documento, aunque se usen frases. El TF-IDF se calcula por unidad (documento o frase) con TF = apariciones / palabras de la unidad e IDF = ln(N / df); N cuenta las unidades con al menos una palabra tras la limpieza. El TF-IDF medio promedia todas esas unidades, ceros incluidos, antes del filtro de vocabulario.

Entropía normalizada = −Σ p ln(p) / ln(D), donde p reparte las apariciones de un término entre los D documentos preparados. Un valor cercano a 0 indica que el término se concentra en pocos documentos; cercano a 1, que se reparte de manera uniforme. El criterio elimina los términos con entropía superior al máximo fijado; con 1 no elimina ninguno.

Cuando hay más términos elegibles que el máximo, el orden decide cuáles se conservan: por frecuencia total, por el resumen de TF-IDF elegido (en empates, mayor presencia y después orden alfabético) o por BM25 medio. Los términos que no caben figuran como «Límite de vocabulario» en la tabla de términos excluidos.
+++
