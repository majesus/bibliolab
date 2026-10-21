---
titulo: Cobertura y referencias / qué mide cada tabla
objetivo: Distinguir ausencia de datos, citas recibidas y obras citadas, y saber qué cuenta exactamente cada tabla de esta pestaña.
fuentes:
  - bibliometrix / citations | https://rdrr.io/cran/bibliometrix/man/citations.html
---

## 1. Conceptos fundamentales: citas recibidas no son referencias citadas

**Para situarte.** Campo significa columna del archivo. Cobertura indica cuántos documentos tienen el dato que necesita un cálculo. Cohorte del mismo año significa los documentos del corpus publicados en ese año: no es una población externa de referencia.

**Lo que quieres saber.** Qué información bibliográfica tiene tu corpus y qué análisis permite, antes de construir redes de referencias o comparar citas.

**Lo que se calcula realmente.** Las **citas recibidas** son el número que comunica la base de datos para cada documento (la columna de citas). Las **referencias citadas** son las obras que figuran en la bibliografía de cada documento (la columna de referencias, separadas por el delimitador que elegiste). Una cifra no permite reconstruir la otra: saber que un documento recibió 10 citas no dice qué obras cita.

Esta pestaña ofrece cuatro tablas. La **cobertura** cuenta, por campo, cuántos documentos tienen un valor válido. El **ranking de referencias** cuenta en cuántos documentos del corpus figura cada obra citada. La **concentración de fuentes** acumula documentos por revista (ver su guía). Las **citas relativas a la cohorte** dividen las citas de cada documento entre la media de citas válidas del mismo año en este corpus.

## 2. Ejemplo práctico: un corpus de diez documentos

Los resultados proceden de ejecutar el cálculo de la aplicación sobre diez documentos ilustrativos, con una columna de referencias separadas por punto y coma.

| Campo | Documentos con valor válido | Total |
|---|---|---|
| Referencias citadas | 4 | 10 |
| Revista / fuente | 8 | 10 |
| Autores | 10 | 10 |
| Año | 8 | 10 |
| Citas registradas | 6 | 10 |

Cuatro documentos aportan bibliografía. «Lee 2015» y «Smith 2010» figuran en tres documentos cada una; «Gomez 2018» en uno. Un cuarto documento escribe «Smith J. 2010»: la comparación es exacta, de modo que la aplicación lo cuenta como una obra distinta y «Smith 2010» queda con tres documentos en lugar de cuatro.

Para las citas relativas, cinco documentos de 2020 tienen 10, 2, 0, 4 y 4 citas, con media 4: sus valores relativos son 2,5; 0,5; 0; 1 y 1. El único documento de 2021 con citas no tiene valor relativo, porque la cohorte tiene menos de cinco registros válidos.

### Interpretación

La tabla de cobertura limita lo que puedes afirmar: con bibliografía en el 40 % de los documentos, una red de referencias describe esas cuatro bibliografías, no el corpus entero; los otros seis documentos no tienen referencias *disponibles*, lo que no significa que no citen nada. El ranking cuenta documentos citantes dentro del corpus; no equivale a las citas que cada obra recibió en la base de datos.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Empieza por la cobertura.** Selecciona *Cobertura de metadatos* y comprueba qué campos tienen suficientes documentos para tu pregunta.
2. **Comprueba si tienes referencias citadas** o solo un número de citas recibidas. Una columna de referencias vacía no aporta bibliografías, aunque exista en el archivo.
3. **Revisa el ranking de referencias** (*Referencias citadas por documentos del corpus*). Cada obra cuenta una vez por documento citante.
4. **Busca variantes de una misma obra** («Smith 2010», «Smith J. 2010») antes de interpretar el ranking o de construir redes de cocitación o acoplamiento, que identifican las obras por esa misma cadena.
5. **Consulta las citas relativas** si necesitas comparar documentos de años distintos; ten presente que normalizan por año dentro de este corpus, no por disciplina.
6. **Si tu pregunta necesita cocitación o acoplamiento**, exporta las referencias de la base de datos y revisa su formato antes de continuar.

## 4. Cómo leer las tablas sin errores de interpretación

**Ausente no significa cero.** Un documento sin dato de citas tiene una cifra desconocida. Es distinto de un documento cuyo dato de citas es 0. Lo mismo vale para referencias, año o fuente.

**El ranking cuenta documentos del corpus, no citas globales.** Una obra muy citada en la literatura puede aparecer poco si tu búsqueda recoge pocos documentos que la citen.

**La identificación es exacta.** Se normalizan espacios y mayúsculas, pero no se resuelven acentos, abreviaturas, iniciales ni diferencias de formato. Las variantes dividen una misma obra y reducen su recuento.

**Cocitación y acoplamiento son relaciones distintas.** Dos obras están cocitadas si un mismo documento las cita a ambas; dos documentos están acoplados si comparten referencias. Sus nodos son diferentes.

**Las citas relativas no son comparables entre campos.** Dividen por la media del mismo año en este corpus, solo con al menos cinco registros válidos en la cohorte y media positiva; no corrigen diferencias entre disciplinas ni entre bases de datos.

**Qué comprobar.** Qué proporción del corpus aporta cada campo, si los faltantes se concentran en un periodo o una fuente y si las variantes de las obras principales están unificadas.

## 5. Pautas para documentar y redactar tu decisión

Informa la base disponible y el tratamiento: «[n] de [N] documentos aportan referencias citadas, separadas por [delimitador]; las obras se identificaron por cadena exacta tras normalizar espacios y mayúsculas, sin resolver variantes de escritura».

Es una redacción modelo que debes completar con tus cifras. Un ranking de referencias internas no equivale al total de citas que esas obras recibieron en la base de datos.

+++ Nota técnica: cálculo
`bibliography_extensions()` normaliza cada referencia con `tolower()` y compresión de espacios, elimina duplicados dentro del documento y cuenta documentos por cadena. La cobertura cuenta documentos con referencias no vacías, fuente no vacía, autores no vacíos, año no ausente y citas no ausentes. Las citas relativas son `citas / media(citas de la misma cohorte)`, calculadas por año solo si la cohorte tiene al menos cinco registros con citas válidas y la media es positiva.
+++
