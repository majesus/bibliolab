# Guía de estilo de las ayudas de bibliolab

Principio rector: **accesibilidad no significa superficialidad; rigor no significa complejidad innecesaria; interactividad no significa aprendizaje.**
Quien usa bibliolab quiere emplear bien el aparato, no repararlo: no es experto en bibliometría ni en estadística. Cada ayuda debe permitirle decidir y
comprobar, sin renunciar al término técnico exacto ni a los supuestos del método.

## Estructura de un concepto (patrón de los materiales del autor)

1. **Lo que quieres saber.** La pregunta natural del usuario, formulada con sus palabras («¿es real mi hallazgo?», «¿cuántas revistas necesito vigilar?»).
2. **Lo que se calcula realmente.** La pregunta que la técnica responde de verdad, con el término técnico en negrita la primera vez. Si ambas difieren, decirlo.
3. **Una analogía y hasta dónde sirve.** Una situación cotidiana que reproduzca la lógica (el ascensor de un edificio, las estanterías de una biblioteca, el mapa de una fiesta)
   y una frase explícita sobre **dónde deja de servir**. La analogía explica la pregunta, no traslada la regla.
4. **Un ejemplo con cifras** y su lectura («Ejemplo / Lectura»). Las cifras inventadas se declaran ilustrativas.
5. **Errores frecuentes.** Lo que NO es y lo que SÍ es; la inversión lógica habitual (por ejemplo, el valor p no es la probabilidad de que la hipótesis nula sea cierta).
6. **Comportamiento.** Qué ocurre al subir o bajar el control (más confianza ensancha el intervalo; más vecinos amplía el entorno).
7. **Cómo escribirlo en el informe.** Una redacción modelo con las cifras reales del corpus, cautelosa («es compatible con», «describe», «no demuestra») y con la
   condición de los supuestos. Es una frase generada, revisable por quien la copia.
8. **Nota técnica.** La fórmula o el nombre del procedimiento, plegada por defecto, para quien la necesite.

## Reglas de redacción

- Español formal, frases completas, **negrita** solo para el término técnico que se define.
- Un término técnico se mantiene con su nombre exacto; se explica en la frase siguiente, no se sustituye por un sinónimo vago.
- Cada afirmación declara su condición («bajo los supuestos del contraste», «con resúmenes cortos el resultado es poco estable»).
- Nunca se promete una causa o una garantía que el cálculo no ofrece: *describe*, *indica compatibilidad*, *no demuestra*.
- Los valores iniciales se justifican («empieza con 2: así desaparecen las palabras que solo salen en un documento»).
- Cada ayuda dice **qué cambia** y **qué comprobar**, no solo qué hacer.
- Ninguna ayuda describe en el texto algo que el cálculo no hace (auditoría H02–H17): el texto sigue al indicador activo y a los filtros vigentes.

## Dónde vive cada pieza

| Pieza | Archivo |
|---|---|
| Fichas de decisión junto al control (pregunta, empezar, cambiar, qué cambia, comprobar, ejemplo, técnica) | `R/decision_help.R` |
| Narrativa de un concepto (pregunta natural, cálculo, analogía y límite, errores) | `R/narrativas.R` |
| Lecciones del botón de ayuda (comprender, ejemplo, lectura, decidir, informe, estudio) | `R/lessons.R`, `R/pedagogy.R`, `R/study.R` |
| Lectura y frase de informe de las leyes bibliométricas | `R/leyes.R`, `inst/app/server/laws.R` |
| Vista previa de los umbrales de vocabulario | `R/vocab_preview.R` |
