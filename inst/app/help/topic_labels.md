---
titulo: Nombrar un tema / una interpretación que debes justificar
objetivo: Pasar de patrones de palabras a una etiqueta humana verificable.
fuentes:
  - topicmodels / LDA | https://search.r-project.org/CRAN/refmans/topicmodels/html/lda.html
---

## 1. Conceptos fundamentales: un nombre es una hipótesis

**Lo que quieres saber.** Cómo llamar a cada tema de LDA y con qué derecho.

**Lo que se calcula realmente.** LDA entrega temas numerados y probabilidades de términos, sin una etiqueta semántica garantizada. No hace falta un modelo de lenguaje ni para calcularlos ni para proponer una primera lectura. El investigador puede nombrarlos examinando el vocabulario y los documentos, pero debe justificar la interpretación. Nombrar un tema consiste en contrastar una **interpretación** con evidencia.

> **La analogía cotidiana:**
>
> Es como bautizar un sendero que ya existe en un mapa: el nombre ayuda a todos a orientarse, pero el sendero no se llama así por naturaleza, y otra persona podría haber elegido otro nombre con razones igual de buenas.
>
> **Dónde deja de servir la analogía:** un sendero tiene un trazado inequívoco. Un tema es una distribución de probabilidad: no tiene fronteras nítidas, y sus documentos pueden ser heterogéneos.

## 2. Ejemplo práctico: de tres palabras a una etiqueta

Las cifras de este ejemplo son ilustrativas. Un tema tiene «hospital», «paciente» y «prevención» entre sus palabras de mayor beta. Tras leer resúmenes de atención primaria puedes proponer «Atención sanitaria». Si otros textos del mismo tema hablan de planificación urbana o riesgos laborales, prueba una etiqueta más amplia o admite la heterogeneidad. No conviene tomar una palabra llamativa como explicación de todo el tema.

### Interpretación

Si otra persona propone un nombre distinto, esa discrepancia ayuda a revisar la etiqueta. Una IA puede sugerir alternativas, pero no conoce una categoría verdadera que el modelo haya descubierto.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Lee las palabras de mayor beta** de un tema.
2. **Lee varios documentos representativos** (los de mayor proporción) y al menos un caso ambiguo (que mezcle temas).
3. **Escribe una definición corta** y comprueba si incluye esos textos sin ocultar diferencias importantes.
4. **Anota** la etiqueta provisional, la definición y los identificadores de los documentos que la apoyan o la cuestionan.
5. **Contrasta** con otros temas y, si es posible, con otra persona.
6. **Si utilizas IA** para sugerir nombres, conserva la sugerencia y tu comprobación: la etiqueta final sigue siendo responsabilidad humana.

## 4. Cómo leer una etiqueta sin errores de interpretación

**Una etiqueta no es un resultado del modelo.** Si la cambias, el modelo no cambia.

**Una etiqueta que no incluye los casos ambiguos oculta lo que no encaja.** Declara qué queda fuera.

**El mismo tema en otra ejecución puede tener otro número.** Los números de tema no se corresponden entre ejecuciones con distinta semilla o k; compara por palabras.

**Qué comprobar.** Que cada documento representativo es coherente con la definición y que la etiqueta resiste la lectura de un caso que la cuestione.

## 5. Pautas para documentar y redactar tu decisión

Conserva la etiqueta, la definición, los documentos de apoyo y los casos que la cuestionan. Explica quién revisó los nombres y cómo se resolvieron las discrepancias. Una etiqueta transparente facilita que el lector evalúe tu interpretación. Una redacción modelo, que debes completar: «El Tema [k] se denominó provisionalmente [etiqueta] a partir de los términos [términos] y de la lectura de los documentos [ID]; los documentos [ID] cuestionan esa lectura por [motivo]».
