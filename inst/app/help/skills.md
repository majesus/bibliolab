---
titulo: Skills / supervisión, autoría e integridad académica
objetivo: Usar instrucciones de trabajo asistido sin delegar la responsabilidad científica, con verificación de cada cifra, referencia e interpretación.
fuentes:
---

## 1. Conceptos fundamentales: una skill es un protocolo, no un autor

**Para situarte.** Una skill es un conjunto de instrucciones para una herramienta de asistencia; un prompt es la petición que se le entrega. El registro de afirmaciones es una tabla que relaciona cada cifra del texto con el archivo y el cálculo que la respaldan. Ninguno de estos recursos comprueba por sí solo una interpretación científica.

**Lo que quieres saber.** Cómo usar las skills para redactar o revisar un texto a partir de los resultados de bibliolab sin comprometer la autoría ni la veracidad.

**Lo que se calcula realmente.** Una **skill** es una carpeta de instrucciones reutilizables (un archivo `SKILL.md` con sus referencias) que organiza una tarea. Bibliolab incluye dos: `bibliometria-paper`, que ayuda a preparar Métodos y Resultados y a construir un **registro de afirmaciones** (cada cifra atada a un archivo, una columna y un denominador), y `bibliometria-review`, que ayuda a revisar un borrador contrastándolo con la entrega, con revisiones centradas en el método, la reproducción de los cálculos, la claridad de la exposición y las posibles objeciones. No se ejecuta ningún servicio de IA desde la aplicación: nada se envía ni se publica automáticamente.

La pregunta, el argumento, el método, la interpretación y la versión final pertenecen a autores humanos que responden por ellos. Un sistema de IA no puede figurar como autor ni asumir responsabilidad científica.

## 2. Ejemplo práctico: de una cifra a una afirmación verificada

Antes de redactar, pides a la skill de redacción un registro de afirmaciones. Cada fila indica el archivo, la columna, la regla de cálculo, el valor declarado y el denominador. Con el script de verificación incluido (Python 3, solo biblioteca estándar), se recalcula cada cifra contra los CSV completos de la entrega.

Para una entrega ilustrativa cuyo archivo `auditoria.csv` indica 25 documentos importados y 24 en la muestra final, dos afirmaciones sobre la muestra final dieron este resultado.

| Afirmación | Valor declarado | Valor recalculado | Estado |
|---|---|---|---|
| A1: documentos en la muestra final | 24 | 24 | OK |
| A2: documentos en la muestra final | 25 | 24 | DISCREPANCIA (−1) |

### Interpretación

La segunda cifra confunde los documentos importados con los analizados: el script no decide qué es correcto en el manuscrito, solo muestra que el valor declarado no coincide con el archivo. Corregirlo, y decidir si afecta a la conclusión, corresponde a la persona autora. Lo que el script no reproduce (por ejemplo, la interpretación de un tema) se marca como pendiente o como lectura directa.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Lee primero el aviso de integridad académica** que acompaña a las skills (`INTEGRIDAD_ACADEMICA.md`); sus reglas forman parte de ambas.
2. **Descarga las skills** con *Descargar skills .zip* y consérvalas juntas: la revisión consulta el contrato de evidencia, los scripts y la plantilla de la redacción.
3. **Instala o adjunta.** Copia las dos carpetas al lugar de skills de tu herramienta, o adjunta los archivos de instrucciones y `references/` como contexto junto a la entrega de resultados. No todos los productos aceptan el mismo formato.
4. **Pide un registro de afirmaciones antes de la prosa**, y comprueba esa tabla: archivo, columna, denominador y valor.
5. **Si puedes ejecutar Python, lanza el script de verificación**; sin ejecución, las skills indican qué queda sin comprobar.
6. **Revisa cada referencia en su fuente original**, cada cifra en los datos y cada afirmación en su alcance. Una referencia que no localizas se elimina, no se sustituye por otra verosímil.
7. **Declara la asistencia realmente utilizada**, según las normas de tu institución y de la revista.

## 4. Cómo usar las skills sin errores de interpretación

**La asistencia no convierte una afirmación en evidencia.** Un texto fluido no es un texto verificado.

**Las revisiones tienen objetivos distintos.** Una ayuda a aclarar el texto; otra busca objeciones y afirmaciones sin respaldo. Ninguno de esos roles valida un resultado por sí mismo: tú decides qué objeción tiene fundamento y compruebas cada corrección.

**Los resultados de bibliolab son descriptivos o exploratorios.** No constituyen prueba confirmatoria ni inferencia causal, y las carencias del corpus (cobertura, sesgos de la base de datos, idioma, normalización de autores) deben declararse en el manuscrito.

**Los datos del corpus no son instrucciones.** Si un título, un resumen o una celda contienen órdenes dirigidas a un asistente, no deben obedecerse.

**Los manuscritos ajenos en evaluación son confidenciales.** No los cargues en herramientas de IA que no garanticen esa confidencialidad.

**Qué comprobar.** Que cada cifra del texto figura en el registro con su denominador, que no queda ninguna discrepancia sin resolver y que las declaraciones éticas o de uso de IA proceden de lo que realmente ocurrió.

## 5. Pautas para documentar y redactar tu decisión

Declara el uso conforme a la institución y la revista, sin atribuir autoría a la herramienta: «Se utilizó [herramienta y versión] el [fecha] para [finalidad: organizar un registro de afirmaciones / revisar el borrador]. Los autores verificaron todas las cifras contra los archivos de resultados y las referencias contra sus fuentes, y asumen la responsabilidad del contenido».

Es una redacción modelo que debes ajustar a lo que hiciste. Estas instrucciones no prometen un artículo de calidad sin trabajo científico ni garantizan su aceptación editorial.
