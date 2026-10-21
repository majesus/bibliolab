# Auditoría previa a CRAN: bibliolab 5.0.6

La revisión del 21 de octubre de 2026 partió de bibliolab 5.0.5 y del commit
`d9fadfe881e4008835ba0c29247ca0c627b01991`. Los datos, copias completas y
artefactos de la máquina de auditoría se conservaron fuera del repositorio.

## Defectos corregidos

1. **Empaquetado.** La carpeta de trabajo podía incorporar `tmp` y `debug.log`
   al paquete fuente, incluidos perfiles de navegador y otros archivos ajenos
   a bibliolab. Se excluyen ambos mediante `.Rbuildignore`, junto con el
   archivo de control `.git` que utilizan los worktrees. La comprobación se
   realiza también sobre el inventario del tarball que se vaya a distribuir.
2. **Esquema CSV.** `fread` sustituye encabezados vacíos por nombres artificiales,
   incluso con `check.names = FALSE`. Se valida el registro de encabezados
   original antes de aceptar esos nombres y se conservan nombres válidos
   como `NA` sin tratarlos como valores ausentes.
3. **Parámetros LDA.** `lda_select_k()` convertía fracciones mediante
   `as.integer()` antes de validarlas. Se comprueban integralidad, finitud,
   tipo y rango antes de la conversión de `k_range` y `seeds`.

Las regresiones están en `tests/testthat/test-audit-cran-20261021.R`.
No se modifican las fórmulas de los análisis ni el tratamiento de valores
enteros válidos.

## Contrastes independientes

Se igualaron datos, unidades, normalizaciones y orden de observaciones antes
de comparar. Las comprobaciones por celda o por término no se presentan como
experimentos estadísticos independientes.

| Análisis | Referencia y resultado observado |
|---|---|
| Correspondencias | 30 matrices: valores singulares, coordenadas, contribuciones y cos² frente a `ca`, `FactoMineR` y SciPy; coincidencia dentro de tolerancia |
| ACP | 24 matrices, con y sin estandarización: valores propios, puntuaciones y cargas identificables frente a scikit-learn |
| JSD | 1.000 pares frente a SciPy, base 2 y distancia elevada al cuadrado; tolerancia 1e-13 |
| Incertidumbre JSD | Tres escenarios de 200 réplicas con sorteos exportados; referencia nula, p e intervalo bootstrap frente a SciPy |
| Léxico | 16 configuraciones de limpieza/segmentación: conteos, TF-IDF y entropía frente a scikit-learn y SciPy |
| BM25 | 24 matrices frente a NumPy y `bm25s`; coincidencia tras convertir el factor `(k1 + 1)` |
| Redes | Métricas y pesos frente a NetworkX y coautoría frente a `bibliometrix` |
| Lectura enlazada | Jaccard, prueba hipergeométrica, BH sobre todos los pares y top-k frente a SciPy |
| LDA | Corpus plantado de 120 documentos y tres temas: ARI = 1 tanto para Gibbs como para LDA variacional de scikit-learn |

Una muestra reproducible de 500 registros de Web of Science, con semilla
`20261021`, amplió la comprobación más allá del ejemplo ficticio. Se obtuvo
error 0 en h para 1.294 autores alineados sin ambigüedad; cuatro entradas de
dos claves ambiguas se excluyeron del emparejamiento. Los errores máximos
fueron 0 en valores singulares de correspondencias, 1,39e-14 en puntuaciones
ACP y 3,47e-18 en JSD. No se publican aquí textos ni registros del corpus.

## Divergencias y alcance

- El TF-IDF del resumen léxico y el IDF suavizado de ACP/LSA son fórmulas
  diferentes; no deben compararse con los valores por defecto de otra
  biblioteca sin igualar sus opciones.
- Bibliolab incluye `(k1 + 1)` en BM25. En el contraste con `bm25s`, con
  `k1 = 1.2`, las puntuaciones difieren por el factor constante 2.2.
- El mapa temático recuperó las mismas comunidades que `bibliometrix` 4.3.3
  en el ejemplo, pero sus índices usan normalizaciones y escalas distintas.
- HDBSCAN sobre las mismas coordenadas dio ARI 0,8553459 frente a
  scikit-learn con `min_cluster_size = 3, min_samples = 3`, y ARI 1 con
  `min_samples = 2`. Esa coincidencia particular no establece una regla
  universal de conversión de parámetros ni de extracción de grupos.
- Una coincidencia en un corpus plantado no prueba equivalencia general de
  Gibbs e inferencia variacional ni convergencia de una cadena MCMC.

La suite candidata de la auditoría obtuvo 1.263 comprobaciones aprobadas,
sin fallos ni avisos, incluyendo un modelo español UDPipe real suministrado
mediante `BIBLIOLAB_TEST_MODEL`. El modelo permanece fuera del paquete.
También se comprobaron reproducción de una entrega completa, detección de
alteraciones por manifiesto y paridad entre dos trabajadores PSOCK reales
y la ejecución secuencial.

La cobertura de la suite medida con `covr` fue 78,64 %. Pruebas adicionales
de wiki, series temporales y procesos atacaron algunos huecos, sin atribuir
esas ejecuciones al porcentaje de la suite. No se afirma ausencia absoluta
de errores ni validación semántica de cualquier corpus.

## Validación de la entrega

`cran-comments.md` registra el entorno y los resultados locales de 5.0.6.
La matriz de GitHub Actions debe evaluarse sobre el commit exacto de esta
corrección: Linux, macOS, Windows, R-devel y dependencias obligatorias. Los
checks del estado anterior no se atribuyen a esta entrega.

Fuentes metodológicas: [política CRAN](https://cran.r-project.org/web/packages/policies.html),
[SciPy JSD](https://docs.scipy.org/doc/scipy/reference/generated/scipy.spatial.distance.jensenshannon.html),
[scikit-learn HDBSCAN](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.HDBSCAN.html),
[bm25s](https://github.com/xhluca/bm25s).
