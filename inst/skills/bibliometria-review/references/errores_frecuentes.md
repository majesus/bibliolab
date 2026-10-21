# Errores frecuentes al informar resultados de bibliolab

Úsalos como lista de comprobación al contrastar un borrador con la entrega; cada ítem remite a dónde se resuelve. Un hallazgo es «error demostrado» solo si el archivo lo contradice; si depende de datos que no tienes, es «riesgo plausible».

- **Denominador equivocado.** Documentos importados frente a analizados (`auditoria.csv`, etapa «Muestra final»); proporciones sobre citas válidas, no sobre todos los documentos; citas ausentes tratadas como cero (`indicadores.csv`).
- **Cifra no reproducible.** Número del texto que no sale de ninguna columna; redondeos inconsistentes; sumas de porcentajes de LDA ≠ 100.
- **Modelo no vigente citado.** Resultado de UMAP/HDBSCAN, LDA o CA que `resumen_modelos.csv` marca como «Sin calcular / no vigente», o figuras de una ejecución anterior.
- **Etiquetas como hechos.** «Tema validado», «tema de innovación» sin lectura de documentos representativos (`lda_documentos_representativos.csv`) ni descripción de quién etiquetó.
- **Estabilidad sin evidencia.** Una sola semilla; sin `lda_seleccion_k.csv` ni `umap_hdbscan_sensibilidad.csv`.
- **Ejes sin superar el azar.** Interpretar ejes de ACP o CA con `supera_azar` falso; confundir varianza de ACP con inercia de CA; comparar distancias entre planos de objetos distintos.
- **JSD mal leída.** Causalidad o «significativa» sin referencia nula (`jsd_incertidumbre.csv`); interpretar un p alto como prueba de igualdad o un p bajo como causalidad; JSD cero entendida como equivalencia semántica total.
- **Citas como calidad; centralidad como liderazgo.** El contrato no autoriza esas equivalencias.
- **Prevalencia LDA como pertenencia exclusiva.** `lda_prevalencia.csv` es una media de mezclas; el tema dominante usado en JSD es una simplificación.
- **Grupo 0 de HDBSCAN.** Es «no asignado», no un grupo temático.
- **Redes triviales.** Densidad 1 o modularidad 0 con pocos nodos; homónimos de autores no resueltos; coautoría confundida con colaboración institucional.
- **Bradford sin contraste.** `bibliografia_concentracion_fuentes.csv` describe acumulados; no contrasta Bradford.
- **Procedencia ausente.** Base, fecha, ecuación y criterios no documentados; deducirlos de los documentos.
- **Integridad.** Autoría atribuida a la IA; declaración de uso de IA inventada; referencias que no se localizan; datos ficticios sin rotular como ejercicio; aprobación «para envío» con pendientes abiertos.
