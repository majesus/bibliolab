---
titulo: Comunidades, roles y key players / estructura no equivale a liderazgo
objetivo: Interpretar comunidades, centralidades, articulaciones y candidatos por cobertura con su alcance real, sin atribuirles prestigio ni influencia.
fuentes:
  - igraph / comunidades (Louvain) | https://igraph.org/r/html/latest/cluster_louvain.html
  - igraph / puntos de articulación | https://r.igraph.org/reference/articulation_points.html
---

## 1. Conceptos fundamentales: posición estructural, no mérito

**Lo que quieres saber.** Qué nodos ocupan posiciones destacadas en la red y qué grupos se distinguen, sin confundir esa posición con calidad, prestigio o influencia.

**Lo que se calcula realmente.** Una **comunidad** es un conjunto de nodos con más conexiones entre sí que con el resto, según el criterio de un algoritmo. **Louvain** busca la partición que maximiza la **modularidad** (cuánto exceden las conexiones internas a las esperables por azar a igual grado); **Walktrap** agrupa nodos que quedan cerca siguiendo recorridos aleatorios cortos. Criterios distintos pueden proponer particiones distintas sobre el mismo grafo, y la posición en pantalla no decide la comunidad.

El **grado** cuenta vecinos; la **fuerza** suma los pesos de sus conexiones; la **intermediación** es la fracción normalizada de caminos mínimos (en saltos, sin pesos) que pasan por el nodo; una **articulación** es un nodo cuya retirada aumenta el número de componentes. La **participación** que muestra la tabla de nodos es `1 − Σ pₖ²`, donde pₖ es la fracción de sus vecinos que pertenece a la comunidad k: vale 0 si todos sus vecinos son de una sola comunidad y crece cuando reparte sus conexiones. Un **key player por cobertura** es un nodo elegido por una heurística codiciosa para alcanzar vecinos distintos a un salto, contando también el propio nodo.

> **La analogía cotidiana:**
>
> Es como un organigrama visto solo por las líneas de contacto: puedes ver quién habla con más gente, quién une a dos departamentos y quién pertenece a un grupo muy cohesionado, pero no quién decide ni quién es más valioso.
>
> **Dónde deja de servir la analogía:** en un organigrama los cargos están dados. Aquí los papeles se infieren de las conexiones que tú has filtrado, de modo que cambian si cambian los umbrales, el peso o el método de comunidades.

## 2. Ejemplo práctico: cinco autores, tres papeles distintos

Los resultados se han obtenido ejecutando el cálculo de la aplicación sobre la red de coautoría ilustrativa de la guía de redes (cinco documentos; conteo completo; Louvain con semilla 2026).

| Autor | Grado | Fuerza | Intermediación | Participación | Comunidad | Rol observado |
|---|---|---|---|---|---|---|
| Ana | 2 | 4 | 0,00 | 0,00 | 1 | Conexión interna |
| Eva | 3 | 4 | 0,67 | 0,44 | 1 | Articulación / candidato a puente |
| Luis | 2 | 3 | 0,00 | 0,00 | 1 | Conexión interna |
| Marta | 2 | 2 | 0,50 | 0,50 | 2 | Articulación / candidato a puente |
| Pablo | 1 | 1 | 0,00 | 0,00 | 2 | Conexión interna |

Ana y Eva tienen la misma fuerza (4), pero ocupan posiciones distintas: Ana colabora solo dentro de su grupo, mientras que Eva reparte sus tres vecinos entre las dos comunidades y, si se retira, la red se divide en dos partes. Marta tiene menos fuerza que Ana y, sin embargo, también es una articulación: sin ella, Pablo queda aislado. La cobertura de key players (tres candidatos solicitados) elige primero a Eva, que alcanza cuatro nodos de cinco (ella misma, Ana, Luis y Marta: 80 %); el segundo, Marta, añade solo a Pablo (100 %); el tercero, Ana, no añade nada.

### Interpretación

Estos papeles describen la estructura de esta red concreta. Un nodo con alta intermediación en una red de cinco autores no es por ello influyente en su disciplina: es una posición que depende de qué documentos y qué filtros has conservado. Con el método Walktrap, la partición del ejemplo es la misma salvo por la numeración de las comunidades, que es arbitraria.

## 3. Flujo de trabajo en la aplicación: paso a paso

1. **Calcula la red** y lee primero la definición de la conexión; las comunidades dependen de ella.
2. **Elige el método de comunidades.** *Louvain* admite una resolución (de 0,1 a 3): valores mayores producen comunidades más pequeñas. *Walktrap* no la usa. Contrasta ambos métodos antes de dar sentido a una partición.
3. **Mira la modularidad y la estabilidad.** El resumen incluye la modularidad y, con Louvain, el ARI medio entre 20 ejecuciones con semillas distintas; un ARI bajo indica que la partición cambia con la semilla.
4. **Compara en la tabla de nodos** el grado, la fuerza, la intermediación y la participación. Ordena por cada columna: las listas no coinciden y cada una responde a una pregunta distinta.
5. **Identifica las articulaciones** y comprueba qué partes conectan, mirando las conexiones que las rodean.
6. **Fija el número de key players** (de 1 a 10) y lee la tabla de cobertura: cuántos nodos nuevos añade cada elección y el porcentaje acumulado.
7. **Lee los documentos** que sostienen las conexiones del nodo antes de describir su papel, y revisa variantes de nombre que puedan fragmentar un nodo en dos.

## 4. Cómo leer los roles sin errores de interpretación

**Una centralidad no es prestigio.** Describe una posición en el grafo analizado. Para hablar de liderazgo o influencia necesitas evidencia externa (por ejemplo, citas o trayectoria), que estas medidas no proporcionan.

**Grado, fuerza e intermediación miden cosas distintas.** Un nodo puede tener muchos vecinos y ninguna intermediación (Ana), o pocos vecinos y mucha (Marta).

**Una partición no demuestra grupos reales.** Louvain y Walktrap proponen una partición que optimiza un criterio; una modularidad baja o una estabilidad pobre indican que la separación es débil.

**Los key players por cobertura son una heurística.** Elegir a cada paso el nodo que añade más vecinos nuevos no garantiza el mejor conjunto posible, y si dos candidatos comparten vecinos, estos se cuentan una sola vez. No es un ranking universal.

**Las medidas dependen del universo.** Al extraer un subgrafo, o al cambiar los filtros, grado, intermediación y comunidades se recalculan; no atribuyas al nodo el valor que tenía en la red completa.

**Qué comprobar.** Que los nombres no están duplicados, que la partición se mantiene con otro método o resolución, y que el papel que describes se ve en las conexiones y en los documentos.

## 5. Pautas para documentar y redactar tu decisión

Usa términos verificables: «En la red de [entidades] (n = [nodos], m = [conexiones], peso [definición]), [nodo] presenta [métrica] = [valor], y su retirada [aumenta / no aumenta] el número de componentes. Se detectaron [c] comunidades con [método] (modularidad [valor], ARI medio [valor])».

Es una redacción modelo que debes completar con tus cifras. Si llamas «puente» a un nodo, muestra qué partes conecta; si lo llamas «líder», necesitarás evidencia que esta métrica no ofrece.

+++ Nota técnica: definiciones
La intermediación (`igraph::betweenness`, sin pesos, normalizada) y la centralidad armónica se calculan sobre saltos; la fuerza usa el peso elegido. La articulación se obtiene con `articulation_points()`. La participación se calcula para cada nodo como `1 − Σ pₖ²` sobre la distribución de comunidades de sus vecinos, y el rol observado es *Aislado* (grado 0), *Articulación / candidato a puente* (si es articulación), *Conecta comunidades* (participación > 0) o *Conexión interna*. El núcleo k es la coreness de igraph. Los key players se eligen con `keyplayers_coverage()`: en cada paso se añade el nodo con más vecinos de cierre a un salto no cubiertos aún (incluido él mismo); los empates se resuelven por orden alfabético. La estabilidad solo se evalúa con Louvain: es la media del índice de Rand ajustado (ARI) entre todos los pares de 20 ejecuciones con semillas derivadas de la elegida; con Walktrap no se calcula.
+++
