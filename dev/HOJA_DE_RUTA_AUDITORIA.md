# Hoja de ruta derivada de la auditoría del 22/10/2026

Estado de los 46 hallazgos (BL-01 a BL-46) sobre bibliolab 5.0.5; los cambios se integraron sobre `main` (5.0.7) y se publican como la versión 5.0.8. Esta hoja registra qué se corrigió, qué se
mitigó con texto o avisos y qué se difiere, con el motivo. No se difiere nada por comodidad: cada hallazgo
diferido exige un diseño o una validación que no puede improvisarse sin riesgo de degradar la aplicación antes de
la entrega a CRAN.

## Corregidos con prueba de regresión (`tests/testthat/test-auditoria-506.R`)

| Ficha | Cambio |
|---|---|
| BL-01 | La deduplicación por título y año exige compatibilidad de autores (`author_tokens()`); la contradicción deja el par en `ambiguous` con el motivo «Autores distintos». |
| BL-02 | La fila conservada completa campos vacíos desde el duplicado y lo registra en `campos_completados`. |
| BL-03 | `lda_diagnostics()` recibe la prevalencia documental de `run_lda()`; una sola definición en las dos tablas. |
| BL-04 | `stopword_language_check()` y aviso `AVISO DE IDIOMA`; no cambia la elección del usuario. |
| BL-05 | `reference_doi()` y `reference_sets()`: el mismo DOI define una entidad; sin DOI, cadena exacta normalizada. |
| BL-06 | Huella del código instalado (`code_fingerprint()`) en el registro y comprobación previa, como aviso, en el guion. |
| BL-07 | `reproducir_diagnosticos.R` termina con error si difiere o no compara nada y escribe `verificacion_diagnosticos.json`. |
| BL-08 | El mapa temático vigente entra en informe, informe metodológico, evidencia para IA, registro, manifiesto y subcarpeta `mapa_tematico/`. |
| BL-17 | Aviso específico para grupos endógenos (LDA, UMAP + HDBSCAN) en la salida y en la ayuda de JSD. |
| BL-20 | `top_n` se recorta al vocabulario y se registra `top_n_pedido`; la recomendación señala empates (< 0.05), estabilidad plana y vocabularios pequeños. |
| BL-25 | El error de celdas largas nombra la columna; los avisos de tamaño explican lo que se pierde al quitar referencias. |
| BL-40 | Botón «Usar este k en el modelo LDA» con notificación de que el modelo final aún no existe. |

## Mitigados con texto o aviso; queda trabajo de fondo

- **BL-19.** Se declara en la interfaz y en la ayuda que la reserva es un diagnóstico interno condicionado al vocabulario. Pendiente: aprender vocabulario y filtros solo con el entrenamiento y aplicarlos al reservado, si se quiere hablar de predicción fuera de muestra.
- **BL-32.** Se documenta lo que conserva y rompe el nulo de las líneas base y su carácter Monte Carlo. Pendiente: nulos alternativos (otros márgenes) y análisis paralelo.
- **BL-35.** El estado pasa a «resultados calculados con las opciones actuales» con una nota emergente. Pendiente: estados independientes (datos revisados, decisiones justificadas, interpretación contrastada, entrega documentada) y una versión no dependiente de `title` para teclado y pantallas táctiles.
- **BL-44.** El lanzador pide consentimiento antes de instalar `pkgload`. Pendiente: mostrar capacidades disponibles y versión local al abrir.
- **BL-17/18.** La ayuda explica la unidad de remuestreo (documento) y su dependencia. Pendiente: remuestreo estratificado o por conglomerados y corrección de multiplicidad.

## Diferidos (módulos nuevos o validaciones externas)

| Ficha | Motivo del aplazamiento |
|---|---|
| BL-09 | Separar firma de datos, de parámetros y de documentación del proyecto toca el sistema de invalidación (`settings`, `stale`) del que dependen todos los modelos; exige un diseño con pruebas de estado en Shiny. |
| BL-10 | Reapertura completa de proyectos: nuevo formato de proyecto, versionado y validación de integridad. |
| BL-11, BL-12, BL-13 | Integración multifuente, adaptadores nativos y tesauros: módulos de datos nuevos con corpus de validación propios. |
| BL-14 | Perfil «entrega académica» con pendientes de recuperación documentada: requiere decidir el contenido del perfil con la persona responsable del método. |
| BL-15, BL-16, BL-46 | Selección por relevancia, expediente de validación de etiquetas y síntesis conceptual: flujos de trabajo humanos que no deben automatizarse sin diseño. |
| BL-18 | Remuestreo por bloques: ver arriba. |
| BL-21, BL-22 | Sensibilidad ampliada de decisiones y estabilidad ante nuevos documentos: diseños experimentales nuevos. |
| BL-23 | Separar la elegibilidad para agrupar por vectores de la elegibilidad para describir con c-TF-IDF cambia `run_density()`; necesita pruebas con embeddings reales. |
| BL-24 | Límites de escala: requiere pruebas de rendimiento con corpus mayores. |
| BL-26, BL-27, BL-28, BL-29 | Evolución temática, ráfagas/RPYS, entidades normalizadas y grafo de citas locales: análisis nuevos. |
| BL-30 | Separar cálculo analítico y dibujo de redes y añadir sensibilidad a los límites; hoy la advertencia ya consta en el código. |
| BL-31 | Sensibilidad automatizada y nulo bipartito; las cautelas actuales se mantienen. |
| BL-33, BL-34 | Modo guiado y reducción de la primera pasada: requieren rediseño de interacción y pruebas moderadas con usuarios no técnicos. |
| BL-36 | Cancelación y recuperación de trabajos largos: cambios en la ejecución asíncrona. |
| BL-37, BL-38, BL-39 | Validación tipográfica, de teclado/lectores de pantalla y de reflujo: solo se pueden cerrar con pruebas dinámicas en navegador y tecnologías de apoyo. |
| BL-41, BL-42 | Libro de afirmaciones y evidencias dirigidas: módulo nuevo; la evidencia actual ya declara filas totales e incluidas. |
| BL-43 | Intercambio de proyectos con otras suites: formato de intercambio por definir. |
| BL-45 | Benchmarks externos y pruebas con usuarios: no son tareas de código. |

## Antes de enviar a CRAN

1. Repetir `R CMD check --as-cran` en Windows con R 4.6.1 y actualizar `cran-comments.md`: las cifras que contiene proceden del chequeo previo a estos cambios.
2. Revisar la interfaz en un navegador real con la persona usuaria: se hizo una prueba de humo automatizada en Chromium (carga, ejemplo, preparación, aviso de idioma), pero no una validación visual completa ni de accesibilidad (BL-37 a BL-39).
3. Verificar que la versión 5.0.8 es la que se envía: el código difiere del tarball 5.0.7 comprobado en CI.
