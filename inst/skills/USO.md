# Redacción y revisión a partir de la entrega

Esta carpeta contiene `INTEGRIDAD_ACADEMICA.md`, que debe leerse primero, y dos skills: `bibliometria-paper` (redacción) y `bibliometria-review` (revisión). Mantenlas juntas: la revisión consulta el contrato de evidencia, los scripts y la plantilla de la redacción. La descarga de resultados de la aplicación las incluye.

**Instalación.** En Claude, Codex u otra herramienta con soporte de skills, copia las dos carpetas a la ubicación de skills o usa el mecanismo de instalación de esa herramienta. Si la interfaz no admite `SKILL.md`, adjunta los archivos de instrucciones y `references/` junto al ZIP de resultados y pide aplicarlos como contexto. No se asegura que todos los productos acepten el mismo formato.

**Scripts opcionales** (Python 3, solo biblioteca estándar; leen, no modifican): `bibliometria-paper/scripts/inventario_entrega.py RUTA` resume versión, procedencia, modelos vigentes, advertencias y pendientes declarados; `verificar_afirmaciones.py CARPETA registro.csv` recalcula cifras contra los CSV completos. Sin ejecución de código, las skills indican qué queda sin comprobar.

**Ejemplo de redacción:** «Usa bibliometria-paper con esta entrega para preparar Métodos y Resultados en español. Pregunta: […]. Revista objetivo: […]. Entrega el registro de afirmaciones y los pendientes».

**Ejemplo de revisión:** «Aplica bibliometria-review como metodólogo, auditor de reproducibilidad y abogado del diablo a este borrador, con la entrega adjunta. Separa errores demostrados de riesgos plausibles».

Las skills son instrucciones, no un servicio de IA: no envían datos ni publican. La autoría es humana y toda asistencia exige supervisión exhaustiva de texto, cifras, referencias e interpretaciones, y la declaración de uso de IA que exijan institución y revista. Una entrega con datos ficticios se etiqueta como ejercicio.
