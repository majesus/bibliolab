---
titulo: Nombrar un tema / una interpretación que debes justificar
objetivo: Justificar el nombre propuesto para cada tema mediante sus palabras y documentos, sin confundirlo con un identificador del cálculo.
fuentes:
  - topicmodels / LDA | https://search.r-project.org/CRAN/refmans/topicmodels/html/lda.html
---

## 1. Conceptos fundamentales: un nombre es una hipótesis

**Para situarte.** Tema significa aquí un patrón estimado por LDA: una distribución de probabilidades sobre las palabras. Su número, como Tema 2, es un identificador. El nombre, como Atención sanitaria, lo propone una persona después de leer las palabras y los documentos; puede revisarse sin recalcular.

**Qué se está nombrando.** LDA estima temas numerados. Cada tema asigna probabilidades a las palabras; estas probabilidades se llaman beta. Un documento puede mezclar varios temas, así que no hay una frontera que lo coloque necesariamente en una categoría única.

**Identificador y nombre son distintos.** Tema 2 es un identificador del cálculo. Atención sanitaria sería un nombre propuesto por una persona después de leer palabras y documentos. El identificador procede del cálculo; el nombre procede de la interpretación documentada.

**Qué debe justificar la persona investigadora.** El nombre tiene que resumir los contenidos que has comprobado y declarar los casos que no encajan. No basta una palabra destacada, una sugerencia de IA o un gráfico. Cambiar el nombre no modifica los resultados numéricos.

## 2. Ejemplo práctico: de tres palabras a un nombre de tema

Las cifras de este ejemplo son ilustrativas. Un tema tiene «hospital», «paciente» y «prevención» entre sus palabras de mayor beta. Tras leer resúmenes de atención primaria puedes proponer «Atención sanitaria». Si otros textos del mismo tema hablan de planificación urbana o riesgos laborales, prueba un nombre de tema más amplio o admite la heterogeneidad. No conviene tomar una palabra llamativa como explicación de todo el tema.

### Interpretación

Si otra persona propone un nombre distinto, esa discrepancia ayuda a revisar el nombre del tema. Una IA puede sugerir alternativas, pero no conoce una categoría verdadera que el modelo haya descubierto.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Lee las palabras de mayor beta** de un tema.
2. **Lee varios documentos representativos** (los de mayor proporción) y al menos un caso ambiguo (que mezcle temas).
3. **Escribe una definición corta** y comprueba si incluye esos textos sin ocultar diferencias importantes.
4. **Anota** el nombre del tema provisional, la definición y los identificadores de los documentos que la apoyan o la cuestionan.
5. **Contrasta** con otros temas y, si es posible, con otra persona.
6. **Si utilizas IA** para sugerir nombres, conserva la sugerencia y tu comprobación: el nombre del tema final sigue siendo responsabilidad humana.

## 4. Cómo leer un nombre de tema sin errores de interpretación

**Un nombre de tema no es un resultado del modelo.** Si cambias el nombre, el modelo no cambia.

**Un nombre de tema que no incluye los casos ambiguos oculta lo que no encaja.** Declara qué queda fuera.

**El mismo tema en otra ejecución puede tener otro número.** Los números de tema no se corresponden entre ejecuciones con distinta semilla o k; compara por palabras.

**Qué comprobar.** Que cada documento representativo es coherente con la definición y que el nombre del tema resiste la lectura de un caso que la cuestione.

## 5. Pautas para documentar y redactar tu decisión

Conserva el nombre del tema, la definición, los documentos de apoyo y los casos que la cuestionan. Explica quién revisó los nombres y cómo se resolvieron las discrepancias. Un nombre de tema transparente facilita que el lector evalúe tu interpretación. Una redacción modelo, que debes completar: «El Tema [k] se denominó provisionalmente [nombre propuesto] a partir de los términos [términos] y de la lectura de los documentos [ID]; los documentos [ID] cuestionan esa lectura por [motivo]».
