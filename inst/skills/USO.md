# Skills bibliométricas de bibliolab

Esta carpeta contiene únicamente dos skills instalables: `bibliometria-paper` (redacción) y `bibliometria-review` (revisión). Cada una incluye su aviso de integridad académica en `SKILL.md` y el documento completo en `references/integridad-academica.md`, además de los recursos y scripts que necesita. Pueden instalarse por separado. Las skills de generación de análisis se conservan fuera de esta carpeta, en los materiales de prompts.

**Instalación.** En Claude, Codex u otra herramienta con soporte de skills, copia las carpetas que necesites a la ubicación de skills o usa el mecanismo de instalación de esa herramienta. Si la interfaz no admite `SKILL.md`, adjunta los archivos de instrucciones y `references/` junto al ZIP de resultados y pide aplicarlos como contexto. No se asegura que todos los productos acepten el mismo formato.

**Scripts opcionales** (Python 3.9 o superior, solo biblioteca estándar; leen, no modifican): `bibliometria-paper/scripts/inventario_entrega.py RUTA` resume versión, procedencia, modelos vigentes, advertencias y pendientes declarados; `verificar_afirmaciones.py CARPETA registro.csv` recalcula cifras contra los CSV completos. Sin ejecución de código, las skills indican qué queda sin comprobar.

**Ejemplo de redacción:** «Usa bibliometria-paper con esta entrega para preparar Métodos y Resultados en español. Pregunta: […]. Revista objetivo: […]. Entrega el registro de afirmaciones y los pendientes».

**Ejemplo de revisión:** «Aplica bibliometria-review como metodólogo, auditor de reproducibilidad y abogado del diablo a este borrador, con la entrega adjunta. Separa errores demostrados de riesgos plausibles».

Las skills son instrucciones, no un servicio de IA: no envían datos ni publican. La autoría es humana y toda asistencia exige supervisión exhaustiva de texto, cifras, referencias e interpretaciones, y la declaración de uso de IA que exijan institución y revista. Una entrega con datos ficticios se etiqueta como ejercicio.

El aviso aborda alfabetización y transparencia en el marco de los artículos 4 y 50 de la Ley de IA de la UE según su aplicación al uso concreto. No certifica el cumplimiento legal ni sustituye las políticas de la institución o revista.
