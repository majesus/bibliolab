---
titulo: 05 / De resultados a un trabajo académico
objetivo: Entregar evidencia y decisiones suficientes para que otra persona pueda revisar o repetir el análisis, y usar la asistencia de IA sin ceder la autoría.
fuentes: 
---

## 1. Conceptos fundamentales: qué es una entrega reproducible

**Para situarte.** Una ejecución es un análisis con un archivo y unas decisiones concretas. Vigente significa que las opciones actuales coinciden con las utilizadas para calcularlo. La huella de un archivo es un código, como MD5, que permite comprobar si su contenido ha cambiado; no certifica que los datos sean correctos.

**Lo que quieres saber.** Qué debes guardar y compartir para que tu análisis pueda comprobarse, y cómo usar los borradores asistidos sin comprometer su validez.

**Lo que se calcula realmente.** Una entrega académica debe permitir comprobar qué datos entraron, qué decisiones se aplicaron y de dónde sale cada afirmación. El archivo ZIP reúne las tablas completas en CSV, los parámetros y las advertencias de cada paso (`parametros.json`), el informe en HTML, el informe metodológico (HTML y Markdown), el registro de reproducibilidad con versiones, semillas y huellas de los datos, la entrada original completa en RDS y el script de reproducción. El informe y los gráficos organizan la lectura; las tablas y los parámetros sostienen cada afirmación.

La autoría y la responsabilidad pertenecen siempre a autores humanos. La IA no es autora ni valida resultados: cualquier cifra, referencia, interpretación o texto asistido debe comprobarse contra los datos y las fuentes originales. Usar una respuesta sin esa comprobación puede producir errores o atribuciones falsas. Las *skills* y el banco de prompts son guías de trabajo para el investigador, no sustitutos de su criterio.

## 2. Ejemplo práctico: de una cifra a una afirmación

Un borrador dice «aumentó el interés por la salud» porque aparecen más documentos de un grupo temático. Las cifras que siguen son ilustrativas.

Antes de aceptar la frase, comprueba si también aumentó la producción total recuperada (si el corpus pasó de 100 a 200 documentos, que un grupo pase de 10 a 15 documentos es una caída de su proporción del 10 % al 7,5 %), si cambió la búsqueda y si el último año está completo. La cifra observada puede sostener que *aumentó el número de documentos de ese grupo en este corpus*; no demuestra por sí sola un aumento del interés del campo ni una causa.

### Interpretación

La fluidez de un texto asistido no sustituye su verificación. Empieza por una tabla de afirmaciones verificables, comprueba cada cifra contra su CSV completo y revisa el borrador frase por frase.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Prepara la entrega.** Las descargas se activan cuando hay un corpus preparado y vigente. Un análisis descriptivo puede terminar aquí, sin modelos temáticos. La pantalla agrupa las descargas por objetivo (revisar resultados, informar los métodos, reproducir el cálculo o conservar toda la ejecución). Descarga una entrega por ejecución; conservarlas todas permite comparar decisiones.
2. **Abre primero el informe HTML** y comprueba una cifra contra su CSV completo. Después verifica que el ZIP incluye los parámetros, la entrada original y el script de reproducción. Si faltan insumos, la entrega se declara parcial y no incluye el script.
3. **Lee el informe metodológico.** Resume procedimientos, parámetros, comprobaciones internas y limitaciones; esas comprobaciones no certifican validez científica, y puede servir de base para el apartado de método.
4. **Si usas lemas**, se registran el archivo y la huella MD5 de cada modelo; los modelos de UDPipe se descargan por separado y el script comprueba el modelo antes de repetir.
5. **Revisa el banco de prompts.** Los prompts se muestran antes de copiarse, usan solo resultados vigentes y, por defecto, no incluyen extractos de documentos; si marcas esa opción, se incorporan extractos representativos. La aplicación no envía datos a ningún servicio de IA.
6. **Verifica y registra.** Comprueba cada cifra, cada referencia y cada interpretación. Guarda el prompt, la herramienta o el modelo, la fecha y las correcciones humanas, y aplica la política de IA de tu institución y de la revista.

## 4. Cómo leer la entrega sin errores de interpretación

**Reproducible no es correcto.** El script repite el cálculo con los mismos insumos y comprueba las huellas de la entrada, de los documentos preparados y de la matriz; no comprueba que las decisiones fueran las adecuadas.

**El ZIP contiene datos completos.** Incluye `documentos.csv` y `unidades_textuales.csv` con el texto original, y la entrada original completa en RDS, incluidos los registros excluidos por filtros; puede incluir vectores importados. Revisa los datos sensibles y los derechos de uso antes de compartirlo. Los datos permanecen en tu equipo hasta que decidas compartirlos.

**Las tablas de un modelo solo aparecen si su resultado está vigente.** Si cambiaste parámetros y no volviste a calcular, ese modelo no se incluye. Los mapas no se calculan automáticamente.

**La IA no es una fuente.** Un texto asistido que cite una referencia debe comprobarse en la fuente original: no inventes referencias ni declaraciones éticas.

**Qué comprobar.** Que la fecha y la versión del paquete coinciden con las de tu análisis, que el listado `manifiesto_archivos.csv` conserva las huellas MD5 para comprobar si los archivos han cambiado y que el LEEME de la entrega no declara una entrega parcial.

## 5. Pautas para documentar y redactar tu decisión

La declaración de asistencia debe describir lo que realmente hiciste y ajustarse a tu institución y revista. Puede adoptar esta forma, que debes completar y revisar: «Se utilizó [herramienta, versión, fecha] para [tarea concreta]. Los autores comprobaron todas las cifras, referencias e interpretaciones contra los datos y las fuentes originales y asumen la responsabilidad del contenido».

Los autores humanos conservan la autoría, deciden el argumento y supervisan los datos, las referencias y la interpretación. No atribuyas a una herramienta validaciones que no realizaste.

+++ Nota técnica: contenido de la entrega
`export_bundle()` escribe los CSV con codificación UTF-8 y BOM, separador punto y coma y protección frente a fórmulas de hoja de cálculo; `parametros.json`; `informe.html`; `informe_metodologico.md` y `.html`; `registro_reproducibilidad.json`; `evidencia_ia.json` (tablas limitadas a 25 filas por ranking, sin extractos originales); `entrada_original.rds`; `reproducir_analisis.R` y `reconstruir_graficos.R`; la carpeta `skills`; `banco_prompts.md`; `entorno_R.txt`; `LEEME.txt` y `manifiesto_archivos.csv` con tamaño y MD5 de cada archivo, que `verify_bundle()` comprueba. Si falta algún insumo de reproducción, se escribe una entrega parcial sin `reproducir_analisis.R` y el LEEME lo declara.
+++
