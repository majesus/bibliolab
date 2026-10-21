---
titulo: 01 / Del archivo al corpus
objetivo: Reconocer qué representa cada fila y comprobar que la importación conserva los datos.
fuentes:
  - readxl / lectura de XLS y XLSX | https://readxl.tidyverse.org/reference/read_excel.html
  - Web of Science / exportar registros | https://webofscience.help.clarivate.com/en-us/Content/export-records.htm
  - Posit / validación de entradas | https://shiny.posit.co/r/articles/improve/validation/
---

## 1. Conceptos fundamentales: ¿qué es importar un corpus?

**Para situarte.** Un registro es una fila del archivo. Un campo es una columna, como título, resumen o año. El corpus importado es el conjunto de registros cargados; el corpus preparado es el que queda después de aplicar las decisiones de 02.

**Lo que quieres saber.** Si el archivo que has subido contiene los documentos que querías estudiar y si la aplicación los ha leído tal como están.

**Lo que se calcula realmente.** Importar carga los registros del archivo; todavía no decide el corpus final ni calcula indicadores. La selección que se utilizará después se aplica en 02. Cada fila del archivo es un documento; cada columna es un campo (texto, título, año, autores, revista, citas, DOI). La aplicación propone qué columna cumple cada papel, y la propuesta es solo eso: la correspondencia definitiva la decides tú en 02 / Preparación.

Importar bien es el primer control de validez. Los resultados describen únicamente los documentos que entran en este archivo y superan después los filtros. Una búsqueda incompleta, otra base de datos o criterios de inclusión distintos cambian los resultados aunque el método sea idéntico.

## 2. Ejemplo práctico: ¿qué columna se analiza?

Supón una exportación de Web of Science con tres campos relevantes: un identificador, el título del artículo y el resumen. Las cifras son ilustrativas.

- El identificador permite rastrear cada registro hasta la base de datos.
- El título ayuda a reconocer el artículo.
- El resumen contiene el texto que se analizará.

Si, por error, asignas los títulos como texto, los resultados describirán **títulos**: son más breves, repiten menos palabras y no contienen toda la información de los artículos. Con 200 filas, de las cuales 180 tienen resumen, la importación es válida aunque 20 resúmenes estén vacíos; esas ausencias deben aparecer como cobertura del 90 % (180/200), no rellenarse con texto inventado ni contarse como documentos sin vocabulario.

### Interpretación

Abre el visor de documentos y lee tres registros completos. Si ves un resumen entero, la columna de texto es la correcta. Si solo ves títulos, cambia la correspondencia en 02 / Preparación antes de continuar.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Elige el archivo.** La aplicación acepta CSV, TSV, XLS y XLSX, con un máximo de 10.000 filas, 100 columnas y 50.000 caracteres por celda. El tamaño máximo por defecto es de 100 MB; si tu archivo lo supera, elimina columnas que no necesites (por ejemplo, las referencias citadas) o amplía el límite con `run_app(max_upload_mb = ...)`. El formato se reconoce por la firma binaria del archivo, no por su extensión.
2. **Si es Excel, confirma la hoja.** Se abre la primera hoja y puedes elegir otra. Se leen los valores guardados de las fórmulas; no se recalculan. Los encabezados repetidos o vacíos reciben un nombre único (por ejemplo, el segundo *Abstract* pasa a llamarse *Abstract / 1*; una columna sin nombre pasa a *Columna 5*), sin borrar ninguna columna, y el ajuste queda registrado en la entrega.
3. **Si es CSV o TSV, comprueba el separador y la codificación.** Con el separador automático la aplicación decide por el contenido; si las columnas aparecen unidas, elige el separador a mano. Con UTF-8 los acentos deben verse bien; si aparecen símbolos extraños, prueba Latin-1. En un CSV los encabezados deben ser únicos y no estar vacíos; si no lo son, la importación se rechaza.
4. **Abre el visor de documentos** y comprueba tres registros: que el texto es el esperado, que los acentos son correctos y que el año y el DOI corresponden al documento.
5. **Anota la procedencia.** Conserva la base de datos, la ecuación de búsqueda y la fecha de extracción: el nombre del archivo no permite reconstruirlas.

Si prefieres practicar antes con tus datos, *Cargar ejemplo* sustituye los datos de la sesión por un corpus ficticio. No uses sus resultados como si describieran un campo real.

## 4. Cómo leer la importación sin errores de interpretación

**Todas las columnas se leen como texto.** Así un identificador como `001` conserva sus ceros. Una celda numérica de Excel con formato `000` no equivale al identificador textual `001`: el formato visual de Excel no es un dato.

**La aplicación no lee de forma parcial.** Si una fila tiene un número de campos incoherente, hay comillas mal cerradas, celdas con errores o más filas o columnas de las admitidas, la importación se rechaza entera; no se calcula nada sobre un archivo mal formado.

**Un valor ausente no es cero.** Si un año o un número de citas no se reconoce, queda como ausente y aparece en la cobertura; no se convierte en 0. Un documento sin año no participa en la evolución temporal, y un documento sin citas válidas no entra en los indicadores de citación.

**La aplicación no traduce.** Las traducciones solo existen si tu archivo las trae en una columna propia, que se asigna en 02 / Preparación. No se generan ni se confunden con lemas.

**Qué comprobar tras importar.** Que el número de filas coincide con el de tu exportación, que la columna de texto es la que querías estudiar y que los acentos se ven bien. Si cambias de archivo, de hoja, de separador o de codificación, repite la preparación en 02 antes de usar resultados.

## 5. Pautas para documentar y redactar tu decisión

En el método puedes escribir, completando los corchetes con los datos reales de tu corpus: «Se importó la hoja [nombre] del archivo exportado de [base de datos] el [fecha de extracción], con [n] registros obtenidos con la ecuación de búsqueda [ecuación]. Se analizó la columna [texto] y se verificaron la correspondencia de metadatos y las ausencias en la cobertura».

Es una redacción modelo, no un resultado: revísala antes de copiarla y no afirmes que el corpus es exhaustivo, porque la aplicación no puede comprobarlo. La entrega conserva la huella MD5 del archivo y, en Excel, la hoja, el lector utilizado y la relación de encabezados ajustados.

+++ Nota técnica: lectura y límites
La lectura de texto usa `data.table::fread()` con todas las columnas como cadenas de caracteres; la de Excel usa `readxl` con `col_types = "text"` y sin reparar nombres, y la aplicación repara los encabezados con `make.unique(sep = " / ")`. Los límites son `BIBLIO_LIMITS`: 100 MB, 10.000 filas, 100 columnas y 50.000 caracteres por celda. Se rechazan los archivos con bytes nulos. La correspondencia propuesta se obtiene con `guess_columns()`, que reconoce encabezados habituales de Web of Science, Scopus y exportaciones en español o inglés; en las exportaciones con códigos de columna de dos letras de Web of Science, la columna `ID` (Keywords Plus) no se toma como identificador y se usa `UT`. Si no reconoce ninguna columna de texto, propone la columna de prosa con mediana de al menos 40 caracteres o, en su defecto, el título.
+++
