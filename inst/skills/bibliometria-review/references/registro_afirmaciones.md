# Registro de afirmaciones

Cada cifra, comparación o juicio que aparezca en el manuscrito entra en un CSV con estas columnas (UTF-8, separador `;`). El mismo archivo alimenta `scripts/verificar_afirmaciones.py`, así que las columnas de cálculo deben ser ejecutables, no descriptivas.

| columna | contenido |
|---|---|
| `id` | A1, A2… y el lugar del manuscrito donde se usa (`ubicacion`) |
| `archivo`, `columna` | CSV de la entrega y columna de origen |
| `regla` | `n_filas`, `suma`, `media`, `mediana`, `max`, `min`, `n_unicos`, `celda`, `proporcion` o `inspeccion` (lectura directa o interpretación que el script no recalcula) |
| `filtro_columna`, `filtro_valor` | fila o subconjunto sobre el que se calcula |
| `valor_declarado` | número decimal o porcentaje explícito (25% se interpreta como 0,25); para proporcion se usa la escala 0–1 |
| `denominador` | población sobre la que se calcula (p. ej. 24 documentos analizados, no 25 importados) |
| `nota` | texto libre breve, sin `;` (o entre comillas dobles) |
| `estado` | `verificada` (la reproduce el script), `inspeccionada` (leída en el archivo, sin recálculo), `pendiente` |

**Formato.** El separador es `;`, así que ningún texto libre puede contenerlo sin comillas dobles. Genera el archivo con un escritor CSV (por ejemplo `csv.writer(..., delimiter=';')` en Python) en lugar de componerlo a mano, y deja la explicación en `nota`. El script avisa de las filas mal formadas, pero detectarlas antes ahorra una vuelta.

Las afirmaciones que no son numéricas (una interpretación de tema, una atribución de contribución) van en el mismo registro con `regla` = `inspeccion` y estado `pendiente` hasta que el investigador documente su lectura de los textos originales.

Ejemplo:

```
id;ubicacion;archivo;columna;regla;filtro_columna;filtro_valor;valor_declarado;denominador;estado
A1;Resultados 1;auditoria.csv;documentos;celda;etapa;Muestra final;24;24 tras deduplicar;verificada
A2;Resultados 1;indicadores.csv;valor;celda;indicador;Documentos con citas válidas;21;24 analizados;verificada
```

Reglas de uso: el denominador es obligatorio en toda proporción; las citas ausentes no son ceros (el contrato lo recuerda en `indicadores.csv`); una cifra recalculable que no coincide con el archivo no se publica hasta resolver la discrepancia.

La regla `inspeccion` produce REVISION MANUAL: el script no acredita que nadie haya realizado esa lectura. Los conteos de filas y valores únicos deben coincidir exactamente; las demás reglas admiten la tolerancia relativa declarada con `--tol` (0,005 por defecto). Use `--tol 0` si necesita comparación numérica exacta. Un CSV con cabecera y cero filas permite verificar un conteo cero, pero no una media ni una proporción. Las rutas deben quedar dentro de la entrega. Se rechazan números ambiguos o no finitos; las sumas y medias omiten ausentes declarados, sin convertirlos en ceros.
