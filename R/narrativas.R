# Narrativa did\u00e1ctica de las ayudas. Sigue el patr\u00f3n de los materiales del autor: pregunta natural del usuario,
# qu\u00e9 calcula realmente la t\u00e9cnica, analog\u00eda con su l\u00edmite expl\u00edcito y errores frecuentes. Accesible no es superficial:
# cada texto conserva el t\u00e9rmino t\u00e9cnico exacto y declara los supuestos. Los **t\u00e9rminos** entre asteriscos se muestran en negrita.
narrative_catalog <- function() list(
  lotka = list(natural = "\u00bfMi campo depende de unos pocos autores muy productivos, o la producci\u00f3n est\u00e1 repartida entre muchos?",
    calcula = "Cuenta cu\u00e1ntos autores firman 1, 2, 3\u2026 trabajos y busca el **exponente** n de una curva de potencia (proporci\u00f3n de autores \u221d 1/x^n) que mejor reproduce esa distribuci\u00f3n. Despu\u00e9s mide, con la **distancia de Kolmogorov-Smirnov**, cu\u00e1nto se aparta la curva observada de la ajustada.",
    analogia = "Piensa en los vecinos de un edificio y en las veces que cada uno usa el ascensor durante una semana: casi todos lo usan una o dos veces y solo unos pocos lo usan continuamente. Lotka pregunta con qu\u00e9 rapidez disminuye el n\u00famero de vecinos a medida que aumenta el n\u00famero de usos.",
    limite = "En el edificio cada vecino es una sola persona; en un corpus, un mismo autor puede figurar con varias graf\u00edas y cada variante cuenta como una persona distinta.",
    errores = c("No significa que tu campo \u00abcumple\u00bb la ley: con pocos autores casi cualquier reparto es compatible, y la prueba detecta poco.",
      "No mide la calidad ni el impacto de los autores, solo cu\u00e1ntos trabajos firman en tu b\u00fasqueda.",
      "Un exponente mayor no es \u00abmejor\u00bb: indica que dominan a\u00fan m\u00e1s los autores de un solo trabajo.",
      "El exponente 2 de la ley original es una referencia, no un objetivo que deba alcanzarse.")),
  bradford = list(natural = "\u00bfCu\u00e1ntas revistas necesito vigilar para cubrir la mayor parte de lo que se publica sobre mi tema?",
    calcula = "Ordena las revistas de la que m\u00e1s art\u00edculos aporta a la que menos y las agrupa en **tres zonas** con aproximadamente un tercio de los art\u00edculos cada una. Compara cu\u00e1ntas revistas hacen falta en cada zona: la ley describe que ese n\u00famero se multiplica de forma parecida de una zona a la siguiente (1 : k : k\u00b2).",
    analogia = "Imagina repartir todos los libros sobre un tema en tres estanter\u00edas con el mismo n\u00famero de libros. La primera cabe en unas pocas bibliotecas especializadas; la segunda exige muchas m\u00e1s bibliotecas, y la tercera, much\u00edsimas.",
    limite = "Las zonas son una convenci\u00f3n de reparto en tercios: d\u00f3nde cae el corte depende de las revistas que queden en el l\u00edmite y de c\u00f3mo se haya delimitado la b\u00fasqueda.",
    errores = c("No ordena las revistas por calidad ni prestigio: el n\u00facleo son las que m\u00e1s art\u00edculos aportan a tu b\u00fasqueda, no las \u00abmejores\u00bb.",
      "Si cambias la ecuaci\u00f3n de b\u00fasqueda, cambian las revistas del n\u00facleo y las zonas.",
      "Si una misma revista figura con nombres distintos, se fragmenta y el n\u00facleo se subestima: unifica los nombres antes de interpretar.")),
  zipf = list(natural = "\u00bfUnas pocas palabras concentran casi todas las apariciones, mientras que la mayor\u00eda aparece muy pocas veces?",
    calcula = "Ordena las palabras por frecuencia (**rango** 1 = la m\u00e1s frecuente) y ajusta una recta entre el logaritmo del rango y el logaritmo de la frecuencia. La pendiente, cambiada de signo, es el **exponente** s; el **R\u00b2** indica cu\u00e1nto se parecen los puntos a esa recta.",
    analogia = "Es parecido a los apellidos de un pa\u00eds: unos pocos son muy comunes y la gran mayor\u00eda aparece muy pocas veces. Si se ordenan por frecuencia y se dibujan rango y frecuencia en escalas logar\u00edtmicas, la nube tiende a alinearse.",
    limite = "Bibliolab no trabaja con el texto completo: elimina palabras vac\u00edas y filtra el vocabulario, lo que modifica sobre todo la parte alta de la curva.",
    errores = c("No demuestra que tu corpus \u00abcumple\u00bb una ley: muchas distribuciones producen rectas aproximadas en escala logar\u00edtmica.",
      "Con res\u00famenes cortos o pocos documentos, el exponente es poco estable.",
      "Un R\u00b2 alto describe el ajuste de la recta, no la calidad ni la riqueza del texto.")),
  jsd = list(natural = "\u00bfHablan de forma distinta los dos grupos de documentos que comparo, y qu\u00e9 palabras marcan esa diferencia?",
    calcula = "Convierte el vocabulario de cada grupo en un reparto de proporciones y mide cu\u00e1nto se separan ambos repartos con la **divergencia de Jensen-Shannon (JSD)**, que en esta aplicaci\u00f3n va de 0 (repartos id\u00e9nticos) a 1 (vocabularios sin palabras en com\u00fan). Las barras muestran cu\u00e1nto aporta cada palabra a esa separaci\u00f3n.",
    analogia = "Es como comparar la carta de dos restaurantes: no importa cu\u00e1ntos platos tenga cada uno, sino qu\u00e9 proporci\u00f3n de su carta ocupa cada plato. Si ambos reparten sus platos casi igual, la diferencia es peque\u00f1a; si cada uno se especializa en platos distintos, es grande.",
    limite = "Una carta se lee entera; en un corpus, los textos largos pueden pesar m\u00e1s o igual que los cortos seg\u00fan elijas **Tokens agrupados** o **Documentos equilibrados**.",
    errores = c("No existen umbrales universales de diferencia \u00abpeque\u00f1a\u00bb, \u00abmedia\u00bb o \u00abgrande\u00bb: interpreta el valor junto con el tama\u00f1o de los grupos.",
      "No indica cu\u00e1l de los dos grupos es \u00abmejor\u00bb ni por qu\u00e9 difieren: las barras se\u00f1alan qu\u00e9 palabras contribuyen, no la causa.",
      "Si los grupos se formaron con el mismo vocabulario, la diferencia no valida de forma independiente esos grupos.")),
  lda = list(natural = "\u00bfQu\u00e9 asuntos aparecen en mis documentos y cu\u00e1nto hay de cada uno en cada texto?",
    calcula = "Busca **k temas**, cada uno como un reparto de probabilidades sobre las palabras, y asigna a cada documento una **mezcla** de esos temas. Es un modelo probabil\u00edstico: no lee el significado, solo las palabras que tienden a aparecer juntas.",
    analogia = "Es como ordenar una biblioteca sin cat\u00e1logo en k cajones seg\u00fan qu\u00e9 palabras aparecen juntas. Un libro puede tener contenido de varios cajones; la mezcla indica cu\u00e1nto de cada uno.",
    limite = "Los cajones no tienen etiqueta: \u00abTema 1\u00bb no es un nombre. Eres t\u00fa quien propone una etiqueta tras leer palabras y documentos representativos, y el n\u00famero de cajones, k, no tiene un valor \u00abverdadero\u00bb.",
    errores = c("La prevalencia media de un tema no es el porcentaje de art\u00edculos dedicados exclusivamente a \u00e9l.",
      "\u00abTema 1\u00bb no tiene identidad fija entre ejecuciones: con otra semilla los temas pueden cambiar de orden.",
      "Un tema con buenas cifras de coherencia o diversidad puede no ser interpretable: compru\u00e9balo leyendo textos.")),
  density = list(natural = "\u00bfHay grupos de documentos parecidos entre s\u00ed, y cu\u00e1les quedan sin grupo?",
    calcula = "Resume cada documento por sus palabras (TF-IDF o BM25 y **LSA**), construye con **UMAP** una representaci\u00f3n donde los parecidos quedan cerca y **HDBSCAN** busca zonas densas. Los documentos que no pertenecen a ninguna zona densa quedan **sin asignar**.",
    analogia = "Imagina soltar los documentos en una plaza, de modo que se coloquen cerca quienes se parecen. HDBSCAN busca corros: grupos con suficiente gente apretada. Quien est\u00e1 solo, o entre dos corros, queda fuera de todos.",
    limite = "El dibujo que ves es un plano de la plaza; los corros se calculan en otra representaci\u00f3n con m\u00e1s dimensiones, y las distancias entre zonas lejanas del plano no validan los grupos.",
    errores = c("\u00abSin asignar\u00bb no es un tema, un error ni una lista de documentos que deban eliminarse.",
      "El tama\u00f1o visual de una zona del mapa no prueba que el grupo sea grande o importante.",
      "Que los grupos se repitan con otra semilla da confianza; que un solo mapa los muestre, no.")),
  networks = list(natural = "\u00bfQui\u00e9n se relaciona con qui\u00e9n, y qu\u00e9 grupos se forman?",
    calcula = "Convierte cada entidad (autor, palabra, revista\u2026) en un **nodo** y une con una **conexi\u00f3n** a las que cumplen la relaci\u00f3n elegida (firmar un mismo art\u00edculo, aparecer en los mismos documentos\u2026). El **peso** de la conexi\u00f3n resume cu\u00e1nto coinciden; las **comunidades** agrupan nodos m\u00e1s conectados entre s\u00ed que con el resto.",
    analogia = "Es como el mapa de una fiesta: cada persona es un punto y se traza una l\u00ednea entre quienes han conversado. Los corrillos que se forman son las comunidades.",
    limite = "En una fiesta se sabe qui\u00e9n habl\u00f3 con qui\u00e9n; en una red de palabras, la conexi\u00f3n solo indica que coinciden en documentos, no que una influya en otra.",
    errores = c("La posici\u00f3n en pantalla es una disposici\u00f3n visual, no una distancia de significado.",
      "Un nodo con muchas conexiones no es necesariamente un l\u00edder ni lo m\u00e1s importante.",
      "La comunidad depende del m\u00e9todo y de la resoluci\u00f3n: contr\u00e1stala leyendo los registros.")),
  tokens = list(natural = "\u00bfQu\u00e9 palabras caracterizan mis textos, y no son simplemente las m\u00e1s repetidas?",
    calcula = "Para cada palabra y cada texto combina cu\u00e1nto se usa dentro de ese texto (**TF**) con lo rara que es entre todos los textos (**IDF**). Una palabra presente en todos los textos tiene peso cero.",
    analogia = "Es como valorar los ingredientes de unas recetas: la sal aparece en casi todas y no distingue una receta de otra; el azafr\u00e1n, que aparece en pocas, s\u00ed. Su peso es alto precisamente en las recetas donde est\u00e1.",
    limite = "Una palabra rara no es necesariamente importante: puede ser una errata, un nombre propio o una cita suelta.",
    errores = c("Un TF-IDF medio bajo no demuestra que una palabra sea irrelevante: puede ser bajo porque la palabra es muy general.",
      "El peso depende del conjunto de textos: la misma palabra tiene otro peso en otro corpus.",
      "Los valores de TF-IDF de pantallas distintas (Preparaci\u00f3n, n-gramas, cuaderno\u2026) usan variantes y no coinciden entre s\u00ed.")),
  pca = list(natural = "\u00bfEn qu\u00e9 se diferencian principalmente mis documentos, y qu\u00e9 palabras marcan esa diferencia?",
    calcula = "Busca **ejes** que recogen la mayor variaci\u00f3n entre los perfiles de vocabulario ponderado de los documentos; cada documento obtiene una posici\u00f3n en cada eje. La **varianza explicada** dice qu\u00e9 parte de la variaci\u00f3n recoge cada eje.",
    analogia = "Es como fotografiar una escultura desde el \u00e1ngulo que mejor muestra sus diferencias: el primer eje es el \u00e1ngulo que recoge m\u00e1s diferencias; el segundo, el mejor \u00e1ngulo perpendicular al primero.",
    limite = "Una fotograf\u00eda aplana una forma en tres dimensiones; el plano de dos ejes aplana un perfil de cientos de palabras y pierde informaci\u00f3n. El cos\u00b2 indica cu\u00e1nto se conserva de cada punto.",
    errores = c("No es un detector autom\u00e1tico de temas: los ejes son contrastes de vocabulario, que pueden mezclar varios asuntos.",
      "Un valor positivo o negativo en un eje no es una valoraci\u00f3n buena o mala: solo indica extremos opuestos del contraste.",
      "\u00abVarianza explicada\u00bb no equivale a \u00abporcentaje de la realidad explicado\u00bb.")),
  ca = list(natural = "\u00bfQu\u00e9 palabras se asocian con qu\u00e9 unidades de texto, y cu\u00e1les ocupan posiciones opuestas?",
    calcula = "Compara el **perfil** de cada palabra (c\u00f3mo se reparte entre las unidades de texto) y el de cada unidad (qu\u00e9 palabras usa) y los coloca en un plano donde la cercan\u00eda indica perfiles parecidos. La **inercia** recoge cu\u00e1nta informaci\u00f3n conserva cada eje.",
    analogia = "Es como sentar a los invitados de una boda en mesas seg\u00fan con qui\u00e9n tienen afinidad: quienes comparten amistades quedan juntos y quienes tienen c\u00edrculos distintos, en mesas alejadas.",
    limite = "En una boda cada invitado est\u00e1 en una sola mesa; en el plano, la cercan\u00eda entre una palabra y una unidad es una pista de asociaci\u00f3n, no una pertenencia.",
    errores = c("Las palabras raras pueden dominar los extremos del plano sin ser importantes.",
      "Con frases como unidad el an\u00e1lisis cambia: no es una mejora de legibilidad.",
      "Un plano recoge solo parte de la inercia: consulta otros ejes antes de interpretar una posici\u00f3n.")),
  bm25 = list(natural = "\u00bfDebo ponderar mis palabras con TF-IDF o con BM25?",
    calcula = "Ambos dan a cada palabra un peso por texto. **BM25** modera el efecto de repetir una palabra y ajusta por la longitud del texto; TF-IDF cuenta las repeticiones de forma proporcional.",
    analogia = "Es como escuchar una conversaci\u00f3n: la tercera vez que alguien repite lo mismo aporta menos que la primera. BM25 aplica ese descuento por repetici\u00f3n.",
    limite = "En una conversaci\u00f3n importa qui\u00e9n habla; aqu\u00ed no hay consulta de b\u00fasqueda: BM25 se usa para ponderar vocabulario, no como ranking de relevancia.",
    errores = c("BM25 no es \u00abmejor\u00bb que TF-IDF: sirve para comprobar si la repetici\u00f3n o la longitud condicionan tus resultados.",
      "Con textos de longitud similar, las diferencias suelen ser peque\u00f1as.")),
  coverage = list(natural = "\u00bfPuedo fiarme de este indicador, o faltan datos?",
    calcula = "Cuenta cu\u00e1ntos registros tienen el dato necesario para cada indicador (a\u00f1o, autores, citas, referencias\u2026).",
    analogia = "Es como interpretar una encuesta sin saber cu\u00e1ntas personas contestaron: el resultado de una pregunta respondida por el 20 % de la muestra no se lee igual que el de una respondida por el 95 %.",
    limite = "En una encuesta, quien no contesta puede diferir de quien contesta; en un corpus, un dato ausente de citas o referencias no significa cero, sino que la base no lo aport\u00f3.",
    errores = c("La ausencia de citas o referencias no significa cero citas.",
      "Una cobertura baja no invalida el indicador, pero obliga a decir en el informe a qu\u00e9 documentos se refiere."))
)

# Texto con **negrita** en l\u00ednea. Escapa el HTML y convierte solo los pares de asteriscos.
rich_p <- function(x, ...) {
  safe <- htmltools::htmlEscape(x)
  html <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", safe)
  htmltools::tags$p(htmltools::HTML(html), ...)
}

# Bloque de comprensi\u00f3n de un concepto: lo que quieres saber, lo que calcula, analog\u00eda y l\u00edmite, errores frecuentes.
narrative_ui <- function(key, open = FALSE) {
  n <- narrative_catalog()[[key]]
  if (is.null(n)) return(NULL)
  tag <- htmltools::tags
  tag$section(class = "narrative",
    tag$p(class = "eyebrow", "ENTENDER ANTES DE CALCULAR"),
    tag$p(class = "narrative-question", tag$strong("Lo que quieres saber: "), n$natural),
    rich_p(paste0("**Lo que se calcula realmente:** ", n$calcula)),
    tag$details(class = "visible-disclosure", open = if (isTRUE(open)) NA else NULL,
      tag$summary("Una analog\u00eda y hasta d\u00f3nde sirve"),
      tag$p(n$analogia),
      rich_p(paste0("**D\u00f3nde deja de servir:** ", n$limite))),
    tag$details(class = "visible-disclosure", open = if (isTRUE(open)) NA else NULL,
      tag$summary("Errores frecuentes al interpretarlo"),
      tag$ul(lapply(n$errores, tag$li))))
}

# Bloque com\u00fan "C\u00f3mo escribirlo en tu informe": frase generada con las cifras vigentes.
report_sentence_ui <- function(text) {
  if (is.null(text) || !nzchar(text)) return(NULL)
  tags$div(class = "report-sentence", tags$h4("C\u00f3mo escribirlo en tu informe"), tags$blockquote(text),
    tags$p(class = "hint", "Las cifras proceden de tu ejecuci\u00f3n vigente. Revisa que la redacci\u00f3n responda a tu pregunta antes de copiarla."))
}
