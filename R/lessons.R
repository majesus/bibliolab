# Cuaderno docente: explicacion -> ejemplo -> decision, sin conocimientos de R.
spaced_labels <- function(d, x, y, priority, max_labels = 10L) {
  if (!nrow(d)) return(integer())
  nx <- (d[[x]] - min(d[[x]])) / max(diff(range(d[[x]])), 1e-9)
  ny <- (d[[y]] - min(d[[y]])) / max(diff(range(d[[y]])), 1e-9)
  chosen <- integer()
  for (i in priority) {
    if (!length(chosen) || all(abs(nx[i] - nx[chosen]) > .18 | abs(ny[i] - ny[chosen]) > .075)) chosen <- c(chosen, i)
    if (length(chosen) >= max_labels) break
  }
  chosen
}

figure_explanation <- function(key) switch(key,
  jsd = "JSD resume la diferencia de proporciones de palabras entre A y B. Estas barras descomponen esa diferencia: una barra m\u00e1s larga identifica una palabra que explica m\u00e1s del contraste total. Las palabras que pesan m\u00e1s en A se colocan a la izquierda; las que pesan m\u00e1s en B, a la derecha. Se muestran hasta veinte t\u00e9rminos y se indica qu\u00e9 parte de la diferencia explican juntos. La direcci\u00f3n no representa una diferencia negativa.",
  jsd_cumulative = "Ordenamos todas las palabras por aportaci\u00f3n y sumamos su porcentaje de JSD. La l\u00ednea del 80% ayuda a planificar lectura; no indica significaci\u00f3n estad\u00edstica.",
  jsd_matrix = "Cada celda compara con JSD el reparto de palabras de dos categor\u00edas del corpus. Comparar una categor\u00eda consigo misma da 0; intercambiar A y B da el mismo valor, por eso la tabla es sim\u00e9trica. El eje usa categor\u00edas completas en tablas y c\u00f3digos si son numerosas. No es una matriz de correlaci\u00f3n.",
  jsd_time = "Cada punto compara dos a\u00f1os observados. C\u00edrculo vac\u00edo: existe un salto. No se estiman a\u00f1os sin datos ni se atribuye el cambio a un acontecimiento externo.",
  pca = "El plano de documentos resume diferencias de sus valores del vocabulario de los documentos; el plano de variables muestra relaciones de t\u00e9rminos con los ejes, en otra escala. El color indica cu\u00e1nto de cada objeto se representa en ese plano, medido con cos\u00b2. Lee la varianza de los ejes y los originales antes de dar significado a proximidades.",
  pca_documents = "Cada punto representa un documento resumido en dos componentes. El color indica su cos\u00b2: un valor mayor significa que una parte mayor de su distancia al centro, elevada al cuadrado, queda representada por estos dos ejes. Busca un ID o t\u00edtulo para leer sus cifras y consulta cu\u00e1nta varianza recogen los dos ejes.",
  pca_terms = "Las flechas representan correlaciones de t\u00e9rminos con los componentes. Una flecha pr\u00f3xima a la circunferencia se representa mejor en estos dos ejes; una muy corta deja parte importante de su relaci\u00f3n fuera del plano. Este gr\u00e1fico tiene objetos y escala diferentes del plano de documentos.",
  pca_variance = "Las barras indican qu\u00e9 porcentaje de la dispersi\u00f3n total de los valores TF-IDF recoge cada componente del ACP. La tabla conserva todos los ejes. El gr\u00e1fico muestra hasta 12 para mantener legibilidad.",
  ca_variance = "Las barras indican qu\u00e9 parte de las diferencias de reparto de los recuentos recoge cada eje del AC (porcentaje de inercia); no es la varianza de ACP. El plano anterior solo recoge los dos primeros ejes.",
  tokens = "Las barras comparan los mismos t\u00e9rminos con tres medidas distintas. Apariciones cuenta repeticiones; documentos cuenta textos distintos; TF-IDF medio resume uso relativo y rareza. El selector y la nota de selecci\u00f3n indican exactamente qu\u00e9 t\u00e9rminos est\u00e1s viendo. El mapa adicional muestra todos los t\u00e9rminos del vocabulario elegido, con puntos de tama\u00f1o constante y sin nombres escritos unos encima de otros.",
  lda_heatmap = "Cada barra es un documento y suma 100%. Cada color es un tema LDA. La vista inicial pagina 18 documentos en el orden de la tabla del modelo: no es una muestra aleatoria ni una selecci\u00f3n de calidad. Puedes recorrer p\u00e1ginas o buscar cualquier documento por ID, t\u00edtulo o DOI; la ampliaci\u00f3n tambi\u00e9n permite elegirlos. Las proporciones son mezclas estimadas, no porcentajes de art\u00edculos del corpus.",
  ca = "Cada punto representa un t\u00e9rmino y el plano resume diferencias en c\u00f3mo se reparten las apariciones de cada t\u00e9rmino entre documentos o frases. Ambos ejes tienen la misma escala para no deformar distancias. Consulta la inercia y el cos\u00b2 de los t\u00e9rminos antes de interpretar una cercan\u00eda: fuera del plano puede haber diferencias que no vemos.",
  network = "Los nodos representan las entidades de la red elegida y las l\u00edneas sus relaciones definidas en la pantalla. El tama\u00f1o refleja documentos asociados al nodo y el color identifica una comunidad calculada. Arrastrar solo cambia la disposici\u00f3n. Las m\u00e9tricas se refieren a esta red filtrada; un subgrafo requiere recalcularlas.",
  density = "Cada punto es un documento y el color identifica su grupo HDBSCAN; los documentos sin asignar se conservan en gris. Este mapa de dos ejes es una vista independiente del espacio donde se agruparon. Pulsa un punto para leer el resumen y comprobar si la agrupaci\u00f3n tiene sentido.",
  density_membership = "La caja contiene la mitad central de los valores de pertenencia; su l\u00ednea central marca la mediana. Los bigotes llegan hasta los valores situados a no m\u00e1s de 1,5 veces la amplitud de la caja desde sus bordes; pueden quedar puntos fuera. Puntos = documentos. El grado de pertenencia resume estabilidad individual dentro de la estructura de densidad del ajuste; es distinto de comprobar otras semillas; no es una probabilidad tem\u00e1tica calibrada.",
  "Comprueba t\u00edtulos, unidades y denominadores. Usa la tabla para consultar cifras completas y leer documentos cuando corresponda.")
