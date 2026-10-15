# bibliolab

<!-- badges: start -->
[![R-CMD-check](https://github.com/majesus/bibliolab/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/majesus/bibliolab/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Análisis bibliométrico y de minería de textos, **guiado** para personas sin formación
técnica y **reproducible** para su uso en investigación. Versión 5.0.1.

> **Aviso de integridad académica.** bibliolab y sus skills asisten el trabajo del investigador; no sustituyen su criterio ni asumen autoría. Toda salida requiere verificación humana contra las fuentes originales, el uso de IA generativa debe declararse según exijan la institución y la revista, y los resultados son descriptivos o exploratorios, no confirmatorios. Las exportaciones de bases de datos con licencia (Web of Science, Scopus) se rigen por sus términos. El aviso completo, alineado con el Código Europeo de Conducta para la Integridad en la Investigación (ALLEA, 2023), las directrices de la Comisión Europea sobre IA generativa en investigación, el Reglamento (UE) 2024/1689 y el RGPD, está en [`inst/skills/INTEGRIDAD_ACADEMICA.md`](inst/skills/INTEGRIDAD_ACADEMICA.md).

## Instalación

```r
# install.packages("remotes")
remotes::install_github("majesus/bibliolab")
```

Después de instalar el paquete:

```r
library(bibliolab)
run_app()
```

`run_app()` comprueba los paquetes necesarios antes de abrir la aplicación y, si faltan
los de análisis, intenta instalarlos desde CRAN en una biblioteca de usuario. La aplicación
escucha exclusivamente en `127.0.0.1`: no necesita aceptar conexiones de otros equipos ni
enviar datos a servicios externos. Los modelos de idioma UDPipe solo se descargan si el
usuario lo solicita (`model_directory()` indica la carpeta; también puede pasarse
`model_dir` a `run_app()`).

Para probar sin datos propios, la aplicación incluye un corpus **ficticio** de práctica
(`inst/extdata/practica.csv`, 25 registros, uno de ellos duplicado por DOI para ilustrar
la deduplicación).

Funciones opcionales (en `Suggests`): `topicmodels` y `slam` (LDA), `uwot`, `dbscan` e
`irlba` (UMAP + HDBSCAN), `udpipe` (lemas), `cld2` (idioma), `mgcv` (spline temporal),
`igraph` (redes), `readxl` (Excel), `ggrepel`, `mclust`. `biblio_check_dependencies()`
indica qué falta.

## Qué ofrece

* Importación estricta de CSV/TSV/XLS/XLSX con auditoría de registros.
* Descripción bibliométrica: producción, fuentes, autores, citas, referencias, cobertura.
* Modelos exploratorios: LDA, UMAP + HDBSCAN, correspondencias, ACP, JSD, redes.
* **Decisión asistida:** comparación de soluciones LDA, estabilidad de grupos, ruido de
  muestreo de la JSD, líneas base de ejes, diagnóstico de vocabulario.
* **Reproducibilidad:** semillas, versiones, huella de los datos, informe metodológico y
  script de reproducción.

Todo es descriptivo o exploratorio: la herramienta no ofrece pruebas confirmatorias ni
inferencias causales, y no garantiza por sí misma la publicabilidad de un estudio.

## Uso en script

Consulta la viñeta: `vignette("bibliolab")`.

## Desarrollo

Registro de cambios: [NEWS.md](NEWS.md). Licencia: MIT ([LICENSE.md](LICENSE.md)).
