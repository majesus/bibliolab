---
titulo: Preprocesamiento paralelo / repartir trabajo sin cambiar el análisis
objetivo: Elegir los recursos del equipo y verificar qué vía se utilizó realmente, sabiendo que repartir el trabajo no cambia las reglas del análisis.
fuentes:
  - R / procesos PSOCK y cierre | https://www.stat.ethz.ch/R-manual/R-devel/library/parallel/html/makeCluster.html
---

## 1. Conceptos fundamentales: más procesos no implican otro análisis

**Para situarte.** Secuencial significa procesar el trabajo en un solo proceso de R. Paralelo significa repartir lotes de documentos entre varios procesos locales, llamados trabajadores. Un lote es una parte del conjunto que se procesa de una vez. Estas opciones afectan a los recursos y al tiempo, no a las reglas del análisis.

**Lo que quieres saber.** Si activar el procesamiento paralelo acelera la preparación de tu corpus y si cambia algún resultado.

**Lo que se calcula realmente.** Un **trabajador** es un proceso local de R (tipo PSOCK, compatible con Windows). Varios trabajadores examinan a la vez lotes independientes de documentos para estimar idiomas, limpiar texto, lematizar o normalizar, y los resultados vuelven a sus posiciones originales. El método de cada etapa y la selección de documentos son los mismos con uno o con varios trabajadores: repartir el trabajo no añade documentos ni altera significados.

Iniciar procesos, cargar modelos y comunicar resultados también consume tiempo y memoria. Por eso la aplicación decide, etapa por etapa, si compensa repartir: solo lo hace cuando hay volumen suficiente. Con un corpus pequeño aparece *Secuencial* aunque la casilla esté marcada. Si un trabajador falla, se retoma por la vía secuencial y se registra la recuperación.

## 2. Ejemplo práctico: 36 resúmenes frente a 5.000

Los resultados proceden de aplicar la regla de decisión de la aplicación (con dos trabajadores solicitados y hasta cuatro disponibles) a dos corpus ilustrativos de resúmenes de unos 1.500 caracteres.

Con 36 resúmenes, ninguna etapa alcanza su umbral de volumen y la aplicación indica «Volumen pequeño: evitar coste de iniciar procesos»: todo se ejecuta en secuencial. Con 5.000 resúmenes, las cuatro etapas (idiomas, limpieza léxica, lematización y normalización) superan su umbral y se reparten en lotes entre los trabajadores.

### Interpretación

El umbral depende de la etapa: la estimación de idiomas se reparte desde 1.000 textos o 500.000 caracteres; la limpieza léxica, desde 3.000 textos o un millón de caracteres; la lematización, con al menos dos unidades y 100.000 caracteres; la normalización, con al menos cuatro unidades y un millón de caracteres. Dos trabajadores no garantizan el doble de velocidad: una parte del trabajo es serial y cada proceso necesita su propia memoria.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Decide si activar la casilla** *Usar procesamiento paralelo en tareas grandes* (activa por defecto), que está en *Opciones avanzadas* de la sección *Ejecución del preprocesamiento*. En el primer recorrido no necesitas cambiarla; el botón *Restablecer valores iniciales* devuelve la casilla y el número de trabajadores a su estado inicial.
2. **Elige el máximo de trabajadores.** Por defecto, dos; se deja al menos un núcleo libre y se usan como máximo cuatro. En equipos con un solo núcleo disponible, el control no ofrece más de un trabajador.
3. **Prepara el corpus** y espera al resultado antes de cambiar opciones; el indicador de progreso muestra la etapa y el avance entre lotes.
4. **Abre *Ejecución de la última preparación / etapas y tiempos*.** La tabla indica, por etapa, el modo (*Secuencial*, *PSOCK local* o *Secuencial / recuperación*), los trabajadores, los lotes, los elementos, los segundos y la nota con el motivo.
5. **Para un portátil con poca memoria, o para descartar un problema**, desmarca la casilla o limita a un trabajador.
6. **Compara ejecuciones** con el mismo corpus y las mismas opciones, y verifica que las tablas coinciden, no solo los tiempos.

## 4. Cómo leer la ejecución sin errores de interpretación

**La casilla expresa una autorización, no una garantía.** El modo efectivo de cada etapa es el que consta en la tabla de ejecución.

**Más trabajadores no son siempre más rápido.** Con memoria limitada o lotes pequeños, el coste de iniciar procesos puede superar el ahorro.

**El orden y la asignación de cada documento deben permanecer iguales.** Si comparas dos ejecuciones, compara los resultados (tablas, asignación de idiomas, lemas), no solo los tiempos.

**Los tiempos dependen del equipo.** Varían con el tamaño de los textos y con los modelos cargados; no son comparables entre ordenadores.

**Qué comprobar.** Que el modo efectivo de cada etapa coincide con tu expectativa, que no hay notas de recuperación inesperadas y que los resultados son idénticos con y sin paralelismo.

## 5. Pautas para documentar y redactar tu decisión

Si necesitas documentar recursos: «La preparación se ejecutó con [n] trabajadores locales de R en las etapas [lista] y de forma secuencial en el resto; la configuración de paralelismo no modifica las reglas ni la selección de documentos».

Es una redacción modelo que debes completar con lo que hiciste. Las decisiones y la ejecución efectiva se conservan en la descarga.

+++ Nota técnica: reglas de decisión
`processing_plan()` activa el reparto si la opción está habilitada, hay más de un trabajador y se supera el umbral de la etapa: idiomas, `n ≥ 1000` o `caracteres ≥ 5·10⁵`; léxica, `n ≥ 3000` o `caracteres ≥ 10⁶`; lematización, `n ≥ 2` y `caracteres ≥ 10⁵`; normalización, `n ≥ 4` y `caracteres ≥ 10⁶`. El límite de trabajadores es `min(4, núcleos físicos − 1)`. Los trabajadores son procesos PSOCK locales (`parallel::makePSOCKcluster`), que se cierran al terminar o al interrumpir la preparación.
+++
