# Plantilla de dictamen

Estructura fija para que la persona pueda actuar sobre cada punto sin releer todo.

```
# Dictamen de [título] · rol(es): [..] · entrega: bibliolab [versión] · datos ficticios: [sí/no]

## Estado de las afirmaciones centrales
| id | afirmación | archivo/dato | estado |
|---|---|---|---|
| C1 | «…» (pasaje) | auditoria.csv · documentos | DEMOSTRADO (error) / VERIFICADO / PLAUSIBLE (riesgo) / ABIERTO / NO VERIFICABLE |

## Comentarios mayores
**M1 · [gravedad: bloqueante | alta | media | baja] · [error demostrado | riesgo plausible | cuestión abierta]**
Pasaje: «…». Contraste: archivo, columna, valor recalculado. Por qué afecta a la conclusión. Corrección o comprobación propuesta. Evidencia que cambiaría este juicio.

## Comentarios menores
(m1, m2…, mismo formato en una línea)

## Matriz de acuerdo entre roles (solo si hubo varios)
| objeción | roles que la comparten | depende de supuestos | preferencia |

## Plan de revisión proporcional
Orden de trabajo, qué se corrige primero y qué puede esperar.

## Comprobaciones realizadas y no realizadas
Qué se recalculó (con versión y entorno), qué solo se inspeccionó, qué falta por acceso.

## Recomendación editorial simulada (opcional)
Condiciones. Es una simulación, no una decisión de revista.
```

Gravedad según consecuencia: **bloqueante** invalida una afirmación central o la integridad (cifra falsa, referencia inexistente, autoría atribuida a la IA, datos ficticios presentados como reales); **alta** cambia la interpretación; **media** exige matizar o completar; **baja** es de forma. Una preferencia de método no es una objeción mayor.
