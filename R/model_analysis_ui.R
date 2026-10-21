# Fichas de orientacion: solo contenido y presentacion, sin calculos ni reactivos.
model_analysis_sheets <- function() list(
  thematic = list(
    name = "Mapa tem\u00e1tico / Centralidad y densidad de Callon",
    help = "help_thematic",
    question = "\u00bfQu\u00e9 temas conectan con el resto del campo y cu\u00e1les presentan mayor cohesi\u00f3n interna?",
    purpose = "Un t\u00e9rmino es una palabra o expresi\u00f3n conservada en los datos. Dos t\u00e9rminos se conectan si aparecen en el mismo documento. Louvain propone comunidades: grupos formados a partir de esas conexiones, cuyo contenido debes revisar leyendo los textos. La centralidad de Callon resume las conexiones de una comunidad con otras; su densidad resume las conexiones entre sus propios t\u00e9rminos, divididas por el n\u00famero de t\u00e9rminos de la comunidad. Cohesi\u00f3n interna significa aqu\u00ed intensidad de esas conexiones, no calidad cient\u00edfica, acuerdo entre autores ni madurez hist\u00f3rica del tema.",
    input = "Puedes utilizar las palabras clave del campo asignado en 02 o el vocabulario retenido tras preparar los textos. No se mezclan ambos or\u00edgenes. Una palabra clave compuesta conserva su expresi\u00f3n completa; en vocabulario se utilizan los t\u00e9rminos preparados. Cada t\u00e9rmino cuenta una sola vez por documento, incluso si se repite o la preparaci\u00f3n utiliza frases.",
    outputs = c(
      "Mapa y tama\u00f1o: cada c\u00edrculo es un grupo de t\u00e9rminos propuesto por Louvain. Su \u00e1rea representa documentos distintos con al menos un t\u00e9rmino de esa comunidad. Un documento puede contribuir a varios temas. El texto junto a cada c\u00edrculo re\u00fane los tres t\u00e9rminos de su comunidad presentes en m\u00e1s documentos. Esas palabras no son un nombre de tema comprobado por lectura.",
      "Cuadrantes: motores (centralidad y densidad por encima del valor central de esas medidas entre los temas del mapa); especializados o de nicho (menor centralidad, mayor densidad); b\u00e1sicos o transversales (mayor centralidad, menor densidad); emergentes o en declive (ambas inferiores). Las igualdades quedan En el l\u00edmite. Son posiciones relativas al mapa y no valoraciones de calidad.",
      "Tablas y cobertura: permiten revisar medidas, t\u00e9rminos, copresencias y exclusiones. Si solo se obtiene un tema, no se interpretan cuadrantes. Un \u00fanico mapa no distingue emergencia de declive: hace falta comparar periodos."),
    parameters = list(
      c("Origen", "Palabras clave declaradas", "Utiliza el campo asignado en 02. Si carece de datos, puedes elegir vocabulario preparado. Revisa si las palabras clave proceden de autores o de \u00edndices de la base."),
      c("Presencia m\u00ednima y m\u00e1ximo de t\u00e9rminos", "2 documentos; 100 t\u00e9rminos", "Se conservan primero los t\u00e9rminos que aparecen en m\u00e1s documentos distintos. Si dos aparecen en el mismo n\u00famero, se ordenan por el texto del t\u00e9rmino, alfab\u00e9ticamente. El l\u00edmite de esta herramienta es 150 t\u00e9rminos. Al cambiar estos filtros cambia qu\u00e9 t\u00e9rminos y conexiones entran en el c\u00e1lculo, no solo el dibujo."),
      c("Copresencias m\u00ednimas", "1 documento", "Una conexi\u00f3n se conserva si ambos t\u00e9rminos aparecen juntos en al menos ese n\u00famero de documentos. Los t\u00e9rminos sin conexiones se excluyen del mapa y se registran en la auditor\u00eda."),
      c("Resoluci\u00f3n Louvain y semilla", "1 y 2026", "Una resoluci\u00f3n mayor suele favorecer comunidades m\u00e1s peque\u00f1as; contrasta 0,5, 1 y 1,5 con la misma red. La semilla permite repetir el ajuste; contrasta otra resoluci\u00f3n o semilla antes de considerar estable una partici\u00f3n.")),
    steps = c("Elige el origen y revisa su cobertura. Calcula el mapa con los valores iniciales como exploraci\u00f3n.",
      "Lee las medidas y los t\u00e9rminos de cada tema. Comprueba los documentos que contienen esos t\u00e9rminos antes de nombrarlo.",
      "Contrasta otros filtros y resoluciones. Guarda el mapa, sus tablas y el m\u00e9todo; no infieras una tendencia temporal con una sola ejecuci\u00f3n."),
    limit = "Los temas dependen del corpus, los t\u00e9rminos seleccionados, la normalizaci\u00f3n y la partici\u00f3n. Densidad no es frecuencia ni la densidad de HDBSCAN; centralidad no es calidad. La densidad de Callon no es un porcentaje de conexiones posibles."),
  density = list(
    name = "UMAP + HDBSCAN / Agrupaci\u00f3n de documentos por densidad",
    help = "help_density",
    question = "\u00bfQu\u00e9 documentos forman grupos y qu\u00e9 vocabulario los caracteriza?",
    purpose = "Este an\u00e1lisis representa cada documento mediante una lista de n\u00fameros y busca grupos de documentos pr\u00f3ximos seg\u00fan esa representaci\u00f3n. UMAP reduce el n\u00famero de coordenadas procurando conservar qu\u00e9 documentos son vecinos. HDBSCAN busca concentraciones de documentos en ese espacio: eso significa densidad aqu\u00ed. Puede dejar documentos sin asignar. c-TF-IDF asigna despu\u00e9s pesos a las palabras de cada grupo para orientar su descripci\u00f3n. El n\u00famero de grupos se obtiene del ajuste; no se fija previamente ni confirma categor\u00edas por significado.",
    input = "Utiliza documentos completos. Puedes representar su vocabulario con TF-IDF o BM25 y resumirlo con LSA \u2014un resumen del vocabulario en un n\u00famero menor de coordenadas\u2014, o importar vectores num\u00e9ricos externos, listas de n\u00fameros por documento con su procedencia documentada. La ruta l\u00e9xica no traduce ni reconoce sin\u00f3nimos por significado.",
    outputs = c(
      "Mapa y asignaciones: cada punto es un documento. Los colores indican grupos; el grupo 0 re\u00fane los documentos sin asignar. El mapa de dos ejes es una vista de lectura: la agrupaci\u00f3n utiliza las dimensiones elegidas para agrupar.",
      "Palabras por grupo: c-TF-IDF se\u00f1ala vocabulario distintivo. Lee documentos representativos antes de proponer un nombre para el grupo; una palabra destacada no basta para nombrar un grupo.",
      "Pertenencia y estabilidad: la pertenencia cuantifica la asociaci\u00f3n de un documento con su grupo seg\u00fan la estimaci\u00f3n de densidad de HDBSCAN; no es una probabilidad tem\u00e1tica. La sensibilidad compara asignaciones de los mismos documentos al cambiar semillas, vecinos o minPts, mediante el \u00edndice de Rand ajustado (ARI): 1 significa la misma agrupaci\u00f3n de los documentos y 0 el acuerdo esperado por azar. Eso no valida el contenido de los grupos."),
    parameters = list(
      c("Representaci\u00f3n", "TF-IDF + LSA", "Determina las distancias entre documentos que recibe UMAP. Los vectores externos requieren documentar el modelo y la versi\u00f3n que los generaron."),
      c("Vecinos UMAP", "10", "N\u00famero de vecinos utilizados para construir la representaci\u00f3n reducida. Un valor menor prioriza relaciones entre documentos m\u00e1s pr\u00f3ximos; uno mayor incorpora relaciones con documentos m\u00e1s distantes. Debe ser menor que el total de documentos."),
      c("minPts de HDBSCAN", "5", "Al aumentarlo se exigen grupos m\u00e1s grandes y cambia la estimaci\u00f3n de densidad; pueden quedar m\u00e1s documentos sin asignar."),
      c("Semilla", "2026", "Permite repetir la ejecuci\u00f3n con los mismos datos y opciones. Contrasta otra semilla para revisar estabilidad."),
      c("Opciones avanzadas", "30 dimensiones LSA; 5 para agrupar; min_dist = 0; 300 \u00e9pocas", "Puedes dejarlas inicialmente. Una dimensi\u00f3n es una coordenada num\u00e9rica por documento. HDBSCAN usa las dimensiones para agrupar; los dos ejes del mapa se calculan aparte; min_dist afecta al espacio de agrupaci\u00f3n; la vista 2D se calcula aparte con min_dist = 0,15.")),
    steps = c("Elige la representaci\u00f3n y revisa vecinos y minPts; puedes conservar los valores iniciales para una primera exploraci\u00f3n.",
      "Calcula, consulta los documentos sin asignar y lee ejemplos de cada grupo junto a sus palabras.",
      "Eval\u00faa estabilidad y sensibilidad antes de presentar los grupos como un resultado consistente."),
    limit = "La proximidad en el mapa no es una medida exacta de semejanza tem\u00e1tica. La pertenencia no es una probabilidad de tema. No encontrar grupos puede ser un resultado v\u00e1lido."),
  lda = list(
    name = "LDA / Modelo de mezclas de temas",
    help = "help_lda",
    question = "\u00bfQu\u00e9 vocabulario caracteriza cada tema y c\u00f3mo se combinan los temas en cada texto?",
    purpose = "LDA estima patrones de palabras, llamados temas, y describe c\u00f3mo se combinan en cada unidad: un documento o una frase, seg\u00fan 02. Cada tema es un reparto de probabilidades sobre las palabras; asigna m\u00e1s peso a unas que a otras. Cada unidad tiene proporciones de esos temas que suman 100 %. Por eso un documento puede mezclar temas sin quedar en una categor\u00eda \u00fanica. Tema 1 o Tema 2 son identificadores del c\u00e1lculo. Los nombres de contenidos se proponen despu\u00e9s de leer palabras y documentos.",
    input = "Utiliza recuentos de palabras del vocabulario preparado. La unidad es el documento o la frase, seg\u00fan lo que hayas elegido en 02. Aunque hayas usado TF-IDF para seleccionar vocabulario, LDA recibe recuentos de apariciones.",
    outputs = c(
      "Palabras por tema (beta): muestran la probabilidad de cada palabra condicionada al tema, estimada por el modelo. Una palabra puede tener probabilidad positiva en varios temas; beta no es un porcentaje de documentos.",
      "Composici\u00f3n y prevalencia: las proporciones de temas de una unidad (gamma) suman el 100 %. La prevalencia es la media de las proporciones documentales de cada tema, con igual peso por documento. Si se usaron frases, primero se promedian dentro de cada documento. No cuenta pertenencias exclusivas a un tema.",
      "Calidad y comparaci\u00f3n de soluciones: la coherencia mide la asociaci\u00f3n de las palabras principales de cada tema en el corpus; la diversidad registra cu\u00e1nto se repiten esas palabras entre temas; la estabilidad compara las soluciones obtenidas con distintas semillas. Eval\u00faa estas medidas junto con los documentos, no como una puntuaci\u00f3n \u00fanica de calidad."),
    parameters = list(
      c("N\u00famero de temas (k)", "4 para el ajuste final", "Fija el n\u00famero de distribuciones de palabras que se estimar\u00e1n como temas. La comparaci\u00f3n de distintos k permite evaluar el efecto de esa decisi\u00f3n."),
      c("Comparaci\u00f3n de k", "De 2 a 8; 3 semillas por k", "Compara soluciones con diferente n\u00famero de temas. Es un paso de apoyo opcional: no enfrenta LDA con los dem\u00e1s an\u00e1lisis."),
      c("Semilla", "2026", "Permite repetir un ajuste. Otra semilla puede producir una soluci\u00f3n distinta, que conviene contrastar."),
      c("Iteraciones", "500", "Son pasos de ajuste del modelo. Revisa los diagn\u00f3sticos; aumentar este n\u00famero no garantiza temas m\u00e1s interpretables."),
      c("Mezcla de temas / alpha", "1/k; opci\u00f3n avanzada", "Un valor peque\u00f1o favorece mezclas concentradas en pocos temas. Cambiarlo puede alterar las proporciones, sobre todo con textos cortos.")),
    steps = c("Si no tienes un k justificado, usa la comparaci\u00f3n de n\u00fameros de temas. Si ya lo has fijado por una raz\u00f3n documentada, puedes ajustar LDA directamente.",
      "Calcula la soluci\u00f3n elegida y revisa palabras, calidad, composici\u00f3n y documentos representativos.",
      "Prop\u00f3n nombres para los temas basados en los documentos que has le\u00eddo y comprueba si se mantienen al cambiar k o la semilla."),
    limit = "Un tema no es una categor\u00eda verdadera ni una causa. Las proporciones dependen del vocabulario, de k y de los par\u00e1metros de mezcla; no indican relevancia o calidad de una publicaci\u00f3n."),
  pca = list(
    name = "ACP / An\u00e1lisis de componentes principales",
    help = "help_pca",
    question = "\u00bfEn qu\u00e9 se diferencian los documentos seg\u00fan el vocabulario representado en este an\u00e1lisis y qu\u00e9 palabras explican esas diferencias?",
    purpose = "El ACP resume diferencias entre los valores TF-IDF del vocabulario de los documentos. TF-IDF asigna peso a las palabras combinando su uso relativo dentro del texto con su presencia entre documentos. Un componente es una combinaci\u00f3n ponderada de esos valores. La varianza mide su dispersi\u00f3n entre documentos: el primer componente recoge la mayor posible y cada siguiente la mayor que queda por representar, sin correlaci\u00f3n lineal con los anteriores. El plano muestra dos componentes; su porcentaje de varianza explicada indica cu\u00e1nto de la variaci\u00f3n total se est\u00e1 viendo. Los ejes se interpretan leyendo las palabras y documentos que m\u00e1s contribuyen a ellos, no como temas o grupos detectados.",
    input = "Utiliza documentos completos y pesos TF-IDF. Esta ponderaci\u00f3n combina la frecuencia relativa de un t\u00e9rmino en el documento con un factor mayor para los t\u00e9rminos presentes en menos documentos del corpus. Se necesitan al menos tres documentos y tres t\u00e9rminos con variaci\u00f3n \u00fatil.",
    outputs = c(
      "Documentos: cada punto contiene las puntuaciones del texto en los dos componentes elegidos. El cos\u00b2 indica qu\u00e9 proporci\u00f3n de su distancia al centro, elevada al cuadrado, representa el plano; no es una proporci\u00f3n de su significado. Un cos\u00b2 bajo exige revisar componentes adicionales antes de interpretar su posici\u00f3n.",
      "Variables y contribuciones: muestran qu\u00e9 palabras construyen cada contraste. El gr\u00e1fico de variables muestra t\u00e9rminos y sus correlaciones con los componentes, es decir, c\u00f3mo var\u00edan conjuntamente sus valores y utiliza una escala distinta del mapa de documentos; no compares distancias entre ambos dibujos.",
      "Varianza explicada y referencia de azar: muestran qu\u00e9 porcentaje de la varianza total representa cada componente. La referencia compara ese porcentaje con el valor que deja por debajo el 95 % de los resultados obtenidos al redistribuir al azar los valores de cada t\u00e9rmino entre documentos; superarlo aporta una comprobaci\u00f3n frente al azar, no una interpretaci\u00f3n sustantiva autom\u00e1tica."),
    parameters = list(
      c("M\u00e1ximo de t\u00e9rminos", "100", "Limita el an\u00e1lisis a los t\u00e9rminos m\u00e1s frecuentes del vocabulario retenido; puede haber menos si faltan t\u00e9rminos con variaci\u00f3n."),
      c("Estandarizar t\u00e9rminos", "Desactivado", "El centrado resta siempre la media de cada t\u00e9rmino para expresar sus desviaciones respecto a esa media. Activar la estandarizaci\u00f3n divide adem\u00e1s por su desviaci\u00f3n t\u00edpica, para que las variables tengan varianza 1 antes del ajuste."),
      c("Ejes para leer", "Componentes 1 y 2", "Despu\u00e9s del c\u00e1lculo puedes elegir otra pareja de componentes con variaci\u00f3n \u00fatil. Revisa la varianza explicada por los dos seleccionados.")),
    steps = c("Revisa el m\u00e1ximo de t\u00e9rminos y empieza con la estandarizaci\u00f3n desactivada; calcula el ACP.",
      "Consulta la varianza y su referencia de azar; despu\u00e9s revisa representaci\u00f3n y contribuciones.",
      "Lee los documentos que sostienen cada contraste y comprueba su sensibilidad a la estandarizaci\u00f3n o al vocabulario elegido."),
    limit = "Un componente no es un tema ni demuestra una causa o una agrupaci\u00f3n de documentos. El signo positivo o negativo no es una valoraci\u00f3n. Los puntos pr\u00f3ximos pueden diferir en las dimensiones que no se muestran."),
  ca = list(
    name = "AC / An\u00e1lisis de correspondencias",
    help = "help_ca",
    question = "\u00bfQu\u00e9 palabras se parecen por c\u00f3mo se reparten entre los textos y qu\u00e9 contrastes forman?",
    purpose = "El AC compara c\u00f3mo se reparten las apariciones de las palabras entre documentos o frases. El perfil de un t\u00e9rmino es ese reparto en proporciones, no su significado. El m\u00e9todo compara los recuentos con los esperados si solo contaran los totales de palabras y unidades, sin asociaciones espec\u00edficas entre ellas. Los ejes resumen las desviaciones respecto a esa referencia. La inercia cuantifica esas desviaciones con la ponderaci\u00f3n del AC; su porcentaje indica qu\u00e9 parte recoge cada eje. Dos palabras con perfiles parecidos pueden tener frecuencias totales distintas. El plano no demuestra sinonimia ni detecta grupos por s\u00ed solo.",
    input = "Utiliza una tabla de recuentos de palabras. Las unidades son documentos o frases, seg\u00fan lo elegido en 02. Se necesitan al menos tres unidades con vocabulario y tres t\u00e9rminos; los perfiles deben permitir m\u00e1s de una dimensi\u00f3n.",
    outputs = c(
      "Mapa de t\u00e9rminos: sit\u00faa palabras con perfiles de reparto parecidos. Es una proyecci\u00f3n de los datos; la cercan\u00eda solo merece interpretaci\u00f3n si las palabras est\u00e1n bien representadas.",
      "Cos\u00b2, contribuci\u00f3n y masa: el cos\u00b2 es la proporci\u00f3n de la distancia cuadr\u00e1tica del t\u00e9rmino al centro representada en el plano; la contribuci\u00f3n es su participaci\u00f3n porcentual en la inercia de un eje; la masa es su proporci\u00f3n en el total de apariciones.",
      "Inercia y referencia de azar: la inercia cuantifica las desviaciones ponderadas respecto al reparto independiente. El porcentaje de cada eje indica qu\u00e9 parte de la inercia total representa. La referencia lo compara con el percentil 95 de las permutaciones; esta medida no es la varianza del ACP."),
    parameters = list(
      c("M\u00e1ximo de t\u00e9rminos", "40", "Limita el an\u00e1lisis a los t\u00e9rminos m\u00e1s frecuentes del vocabulario retenido. Ampliarlo puede cambiar el contraste que muestra el plano."),
      c("Unidad de texto", "La elegida en 02", "Con documentos, los perfiles comparan el reparto de palabras entre textos completos; con frases, entre segmentos de texto. Para cambiarla, vuelve a preparar el corpus en 02."),
      c("Lectura del plano", "Dos primeros ejes", "La inercia informa de lo que recoge el plano; revisa tambi\u00e9n el cos\u00b2 y las contribuciones de cada palabra.")),
    steps = c("Revisa la unidad de texto y el m\u00e1ximo de t\u00e9rminos; calcula el mapa.",
      "Consulta la inercia y la referencia de azar, y comprueba el cos\u00b2 antes de interpretar una palabra.",
      "Localiza los t\u00e9rminos que m\u00e1s contribuyen a cada eje y lee sus documentos para explicar el contraste."),
    limit = "El plano no confirma grupos ni causas. No confundas una palabra muy frecuente con una bien representada o una que construye el eje. Cerca del centro, una posici\u00f3n puede aportar poca informaci\u00f3n.")
)

model_analysis_ui <- function(key) {
  sheet <- model_analysis_sheets()[[key]]
  card <- panel("Comprender el an\u00e1lisis",
    tags$p(class = "model-analysis-name", sheet$name),
    tags$div(class = "model-analysis-grid",
      ui_subblock("Finalidad y datos de partida", tags$p(class = "analysis-question", tags$strong(sheet$question)),
        tags$p(sheet$purpose), tags$p(tags$strong("Datos de partida. "), sheet$input)),
      ui_subblock("Salidas y c\u00f3mo interpretarlas", tags$ul(lapply(sheet$outputs, tags$li))),
      ui_subblock("Par\u00e1metros y primer ajuste", tags$p(class = "hint", "Estos son los valores iniciales de la aplicaci\u00f3n, no una receta universal. Las opciones se ajustan en Configurar el an\u00e1lisis. Junto a cada control, C\u00f3mo decidir explica el efecto del cambio, un recorrido de comparaci\u00f3n y sus l\u00edmites."),
        tags$div(class = "analysis-parameters", tags$table(
          tags$thead(tags$tr(tags$th("Opci\u00f3n"), tags$th("Punto de partida"), tags$th("Qu\u00e9 significa"))),
          tags$tbody(lapply(sheet$parameters, function(row) tags$tr(lapply(row, tags$td))))))),
      ui_subblock("Primer recorrido y l\u00edmites", tags$ol(lapply(sheet$steps, tags$li)),
        tags$p(class = "analysis-limit", tags$strong("L\u00edmite de interpretaci\u00f3n. "), sheet$limit))),
    tags$div(class = "figure-tools", actionButton(sheet$help, "Abrir gu\u00eda completa del an\u00e1lisis", class = "btn-quiet")),
    class = "model-analysis-card")
  card$attribs$id <- paste0("model_intro_", key)
  card$attribs[["data-analysis"]] <- key
  card
}
