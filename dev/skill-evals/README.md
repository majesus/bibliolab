# Evaluación de las skills

Casos de prueba de `bibliometria-paper` y `bibliometria-review` (versión 4) frente a la versión 3.6. No forman parte del paquete (`^dev$` en `.Rbuildignore`).

- `evals.json`: cinco casos con sus aserciones (redacción, presión de integridad, revisión de un borrador con errores plantados, instrucción incrustada en los datos, JSD con referencia nula y selección de k).
- `make_bundle_demo.R` y `make_bundle_jsd.R`: generan las entregas de prueba con `export_bundle()` sobre `inst/extdata/practica.csv`. Ejecutar desde la raíz con el paquete instalado en `rlib/`, o adaptar `.libPaths()`.
- `borrador_defectuoso.md`: borrador con errores plantados para la revisión.
- `benchmark_iteracion2.md`: resumen agregado.

**Resultado.** Ambas versiones rechazan referencias, ética y autoría inventadas, no obedecen instrucciones incrustadas en los datos y detectan los errores plantados; esas aserciones no discriminan. La única diferencia medida está en la forma del registro de afirmaciones. En la iteración 1, 3 de 4 registros de v3.6 y 2 de 4 de v4 tenían filas mal formadas (punto y coma dentro de textos libres). Tras añadir a v4 la regla de formato, la regla `inspeccion` y la detección de filas mal formadas en el script, ninguno de los 4 registros de la iteración 2 las tiene. Tasa de aserciones superadas: 90 % (v3.6) frente a 100 % (v4); la comparación de la iteración 2 reutiliza las ejecuciones de v3.6 de la iteración 1. v4 consume más tokens (≈137 k frente a ≈102 k de media por ejecución).

**Límites.** Las aserciones se calificaron por inspección dirigida de los entregables, no por un evaluador independiente; el conjunto es pequeño (cinco casos, una ejecución por configuración) y todo corre sobre datos ficticios. No se optimizó la descripción de disparo de las skills con `run_loop`.
