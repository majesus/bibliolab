# Orientacion editorial de los controles. No modifica valores ni ajustes.
model_parameter_catalog <- function() {
  out <- list()
  add <- function(ids, title, hint, meaning, start, change, decision, limit,
                  effect = "Ajuste", sources = character()) {
    card <- list(title = title, hint = hint, meaning = meaning, start = start,
      change = change, decision = decision, limit = limit, effect = effect, sources = sources)
    for (id in ids) out[[id]] <<- card
  }
  umap <- c("UMAP / par\u00e1metros" = "https://umap-learn.readthedocs.io/en/latest/parameters.html")
  hdb <- c("dbscan / HDBSCAN en R" = "https://search.r-project.org/CRAN/refmans/dbscan/html/hdbscan.html")
  lda <- c("topicmodels / controles" = "https://search.r-project.org/CRAN/refmans/topicmodels/html/tmcontrol-class.html")
  louvain <- c("igraph / Louvain" = "https://r.igraph.org/reference/cluster_louvain.html",
    "Fortunato y Barth\u00e9lemy / l\u00edmite de resoluci\u00f3n" = "https://arxiv.org/abs/physics/0607100")

  add("density_rep", "UMAP + HDBSCAN / representaci\u00f3n de documentos",
    "Empieza con la ruta l\u00e9xica, calculada a partir del vocabulario, si no tienes listas de n\u00fameros por documento producidas por otro modelo y con procedencia comprobada.",
    "La representaci\u00f3n convierte cada documento en una fila de n\u00fameros. En la ruta l\u00e9xica esos n\u00fameros proceden del vocabulario compartido; los vectores externos son filas de n\u00fameros calculadas por otro modelo. UMAP usa esa informaci\u00f3n para elegir los documentos m\u00e1s semejantes, llamados vecinos; cambiarla puede cambiar toda la agrupaci\u00f3n.",
    "TF-IDF + LSA, calculado dentro de Bibliolab. La alternativa importa vectores preparados fuera de la aplicaci\u00f3n.",
    "La ruta l\u00e9xica compara vocabulario compartido. Los vectores externos pueden recoger relaciones distintas, seg\u00fan el modelo, el idioma y el texto con que se generaron.",
    c("Revisa la limpieza y el vocabulario de 02 antes de agrupar.", "Si importas vectores, comprueba sus identificadores, su cobertura y el modelo y versi\u00f3n de origen.", "Compara grupos leyendo documentos; no elijas una ruta solo por el aspecto del mapa."),
    "La ruta l\u00e9xica no traduce ni reconoce sin\u00f3nimos por significado. La ruta externa tambi\u00e9n necesita vocabulario preparado para describir los grupos.")
  add("density_weighting", "UMAP + HDBSCAN / TF-IDF o BM25",
    "Compara las ponderaciones si la repetici\u00f3n de palabras o la longitud de los textos condicionan los grupos.",
    "Ponderar asigna un valor a cada palabra dentro de un documento; el conjunto de valores es su perfil num\u00e9rico. TF-IDF combina uso relativo y rareza entre documentos. BM25 limita el crecimiento por repeticiones y ajusta por longitud. LSA resume despu\u00e9s esos valores en menos coordenadas.",
    "TF-IDF. BM25 es una alternativa que limita la aportaci\u00f3n de las repeticiones y permite corregir por longitud.",
    "Cambiar la ponderaci\u00f3n modifica las semejanzas de entrada, aunque el corpus y el resto de par\u00e1metros sean iguales.",
    c("Calcula primero con TF-IDF y lee ejemplos de cada grupo.", "Contrasta BM25 conservando semilla, vecinos y minPts.", "Comprueba si separa contenidos sustantivos o diferencias de longitud y estilo."),
    "Ninguna ponderaci\u00f3n garantiza una mejor clasificaci\u00f3n. La gu\u00eda Elegir ponderaci\u00f3n explica sus f\u00f3rmulas y ejemplos.")
  add("density_k1", "BM25 / aportaci\u00f3n de las repeticiones (k1)",
    "1,2 es el inicio. Un valor mayor permite que repetir una palabra siga aportando hasta frecuencias m\u00e1s altas.",
    "k1 regula la saturaci\u00f3n: cu\u00e1nto aumenta el peso de una palabra cuando se repite dentro del mismo documento.",
    "1,2; solo interviene cuando eliges BM25.",
    "Con k1 menor, las repeticiones adicionales aumentan el peso cada vez menos a partir de frecuencias menores. Con k1 mayor permiten que las diferencias de frecuencia sigan modificando el peso en un intervalo mayor de frecuencias; su aportaci\u00f3n contin\u00faa siendo limitada.",
    c("Mant\u00e9n inicialmente 1,2 y b = 0,75.", "Si un mismo t\u00e9rmino se repite intensamente en algunos textos, compara por ejemplo 0,8 y 1,6, cambiando solo k1.", "Lee qu\u00e9 documentos cambian de grupo y si esa repetici\u00f3n informa sobre contenido o sobre estilo."),
    "k1 no fija un n\u00famero de repeticiones permitido ni elimina palabras.")
  add("density_b", "BM25 / correcci\u00f3n por longitud (b)",
    "0,75 es el inicio. Con 0 no se corrige por longitud; con 1 el ajuste usa la raz\u00f3n entre longitud del texto y longitud media. No es un porcentaje de correcci\u00f3n de errores.",
    "b controla cu\u00e1nto se ajusta la frecuencia de una palabra por la longitud del documento respecto a la longitud media del corpus representado.",
    "0,75; solo interviene con BM25.",
    "Un b mayor reduce m\u00e1s la ventaja de las repeticiones en textos largos y aumenta relativamente el peso en textos cortos. Un b menor conserva m\u00e1s las diferencias asociadas a longitud.",
    c("Revisa si se est\u00e1n comparando res\u00famenes de extensiones muy distintas.", "Contrasta 0 y 0,75 con el mismo k1 y los dem\u00e1s par\u00e1metros fijos.", "Lee los textos que cambian de grupo: corregir longitud es una decisi\u00f3n sobre la comparaci\u00f3n, no una mejora autom\u00e1tica."),
    "La longitud se calcula con el vocabulario que entra en la representaci\u00f3n; no necesariamente coincide con todas las palabras del archivo original.")
  add(c("vectors_file", "vector_id", "embedding_model"), "Vectores externos / archivo, correspondencia y procedencia",
    "Cada fila debe corresponder al documento correcto; registra el modelo y su versi\u00f3n.",
    "El CSV aporta coordenadas num\u00e9ricas por documento. La columna de alineaci\u00f3n indica a qu\u00e9 documento pertenece cada fila: doc_id es el identificador asignado por Bibliolab y original_id el que se import\u00f3 del archivo.",
    "doc_id como columna de alineaci\u00f3n. El archivo y la descripci\u00f3n del modelo no tienen un valor inicial.",
    "Elegir otro identificador cambia la correspondencia entre filas y documentos. Escribir el nombre del modelo solo documenta la procedencia: no genera ni transforma los vectores.",
    c("Comprueba los identificadores en la tabla de documentos preparados.", "Verifica que las columnas de coordenadas son num\u00e9ricas y que cubren todos los documentos preparados, incluidos los que despu\u00e9s puedan quedar fuera del ajuste por falta de vocabulario.", "Registra modelo, versi\u00f3n, idioma y texto utilizado; carga el CSV y revisa cualquier aviso de alineaci\u00f3n."),
    "No uses el n\u00famero de fila como sustituto de una correspondencia comprobada. Bibliolab reescala cada fila de n\u00fameros a longitud geom\u00e9trica 1 antes de UMAP; mantiene su direcci\u00f3n y no cambia el n\u00famero de coordenadas.")
  add("umap_neighbors", "UMAP / n\u00famero de vecinos",
    "Empieza con 10 y compara 15 o 20: menos vecinos prioriza relaciones locales; m\u00e1s ampl\u00eda el entorno considerado.",
    "Es cu\u00e1ntos documentos cercanos, seg\u00fan los n\u00fameros que los representan, considera UMAP alrededor de cada documento al construir la representaci\u00f3n reducida. No es el n\u00famero de grupos ni de documentos que se mostrar\u00e1n.",
    "10, siempre menor que el n\u00famero de documentos con vocabulario que entran en el modelo.",
    "Valores menores dan m\u00e1s peso a relaciones pr\u00f3ximas; valores mayores incorporan un entorno m\u00e1s amplio. Los grupos pueden fusionarse, dividirse o cambiar de composici\u00f3n: no existe una correspondencia fija con su n\u00famero.",
    c("Calcula con 10 manteniendo minPts = 5.", "Contrasta 15 o 20 sin cambiar simult\u00e1neamente minPts ni la semilla.", "Revisa documentos sin asignar, contenido de los grupos y evaluaci\u00f3n de estabilidad y sensibilidad."),
    "La separaci\u00f3n visual de puntos no demuestra separaci\u00f3n tem\u00e1tica. El mapa 2D es una proyecci\u00f3n independiente del espacio usado para agrupar.", sources = umap)
  add("hdb_min_pts", "HDBSCAN / tama\u00f1o m\u00ednimo y densidad (minPts)",
    "Empieza con 5 y compara 10. Revisa grupos peque\u00f1os y documentos sin asignar, adem\u00e1s del n\u00famero de grupos.",
    "En la implementaci\u00f3n de R utilizada aqu\u00ed, minPts cumple dos funciones: fija un tama\u00f1o m\u00ednimo de grupo y regula la suavizaci\u00f3n con que se estima la densidad. Densidad significa concentraci\u00f3n de documentos en el espacio reducido.",
    "5, menor que el n\u00famero de documentos analizados.",
    "Un valor mayor exige grupos m\u00e1s grandes y una estructura de densidad menos local; puede fusionar o eliminar grupos y aumentar los documentos sin asignar. La respuesta concreta depende de los datos.",
    c("Lee los grupos peque\u00f1os y los documentos del grupo 0 con minPts = 5.", "Repite con 10 dejando fija la representaci\u00f3n y UMAP.", "Comprueba qu\u00e9 grupos persisten y si los documentos sin asignar son heterog\u00e9neos o forman un conjunto reconocible."),
    "No es un radio ni una probabilidad. No equivale a cambiar por separado min_cluster_size y min_samples de otras implementaciones. Cero grupos puede ser un resultado v\u00e1lido.", sources = hdb)
  add("lsa_dims", "LSA / m\u00e1ximo de dimensiones",
    "Empieza con 30. Un l\u00edmite menor resume m\u00e1s el vocabulario y puede perder contrastes relevantes.",
    "LSA resume los valores del vocabulario en un n\u00famero menor de coordenadas num\u00e9ricas, llamadas dimensiones, antes de UMAP. No asigna un significado tem\u00e1tico a cada coordenada. El control fija el m\u00e1ximo solicitado; la matriz puede permitir menos dimensiones \u00fatiles.",
    "30; solo se aplica a la ruta l\u00e9xica.",
    "Reducir el m\u00e1ximo conserva menos contrastes del vocabulario. Aumentarlo puede retener contrastes adicionales y tambi\u00e9n variaci\u00f3n que no ayude a interpretar los documentos.",
    c("Conserva 30 para la primera exploraci\u00f3n.", "Contrasta, por ejemplo, 20 y 50 si el tama\u00f1o de la matriz lo permite, con los dem\u00e1s par\u00e1metros fijos.", "Revisa cambios de asignaci\u00f3n y lee los documentos afectados."),
    "Una dimensi\u00f3n LSA no es un tema. El m\u00e1ximo no puede compensar un vocabulario insuficiente o mal preparado.")
  add("umap_dims", "UMAP / dimensiones para agrupar",
    "HDBSCAN recibe inicialmente 5 dimensiones. El mapa de lectura utiliza 2 calculadas por separado.",
    "Una dimensi\u00f3n es una coordenada num\u00e9rica por documento. Este control determina cu\u00e1ntas coordenadas produce UMAP para que HDBSCAN busque grupos. No cambia el n\u00famero de ejes dibujados en pantalla.",
    "5. Debe ser compatible con las dimensiones \u00fatiles de la representaci\u00f3n de entrada.",
    "M\u00e1s dimensiones permiten distribuir relaciones entre m\u00e1s coordenadas, pero no garantizan grupos m\u00e1s estables o interpretables.",
    c("Empieza con 5.", "Contrasta 10 si la representaci\u00f3n lo permite y deja fijos vecinos, minPts y semilla.", "Compara las asignaciones y los documentos de cada grupo, no solo la figura."),
    "Agrupar directamente en los dos ejes visibles puede dar un resultado distinto; Bibliolab no lo hace.", sources = umap)
  add("umap_min_dist", "UMAP / compactaci\u00f3n (min_dist)",
    "Empieza con 0 y compara 0,1. Modifica el espacio para agrupar, no el min_dist de la vista 2D.",
    "Regula cu\u00e1nto pueden compactarse los puntos al optimizar la representaci\u00f3n UMAP que recibe HDBSCAN.",
    "0 en el espacio de agrupaci\u00f3n. La vista 2D independiente usa internamente 0,15.",
    "Valores bajos permiten concentraciones m\u00e1s compactas; valores mayores tienden a extenderlas. Esto puede modificar la densidad y las asignaciones de HDBSCAN.",
    c("Calcula con 0 y conserva el resto de opciones.", "Repite con 0,1 y compara tama\u00f1o, composici\u00f3n y documentos sin asignar.", "Busca grupos que mantengan una interpretaci\u00f3n documentada en ambos ajustes."),
    "No es un radio de HDBSCAN ni una distancia m\u00ednima estricta entre todos los puntos. No elijas su valor para embellecer la figura.", sources = umap)
  add("umap_epochs", "UMAP / \u00e9pocas de optimizaci\u00f3n",
    "Empieza con 300; compara 500 si necesitas comprobar sensibilidad a la duraci\u00f3n del ajuste.",
    "Una \u00e9poca es una pasada del procedimiento que ajusta las coordenadas num\u00e9ricas de UMAP. Este control interviene en el espacio para agrupar y en la vista 2D.",
    "300; tambi\u00e9n se ofrecen 500 y 1.000.",
    "M\u00e1s \u00e9pocas dan m\u00e1s tiempo de optimizaci\u00f3n y aumentan el tiempo de c\u00e1lculo; pueden cambiar coordenadas y asignaciones.",
    c("Conserva 300 en la exploraci\u00f3n inicial.", "Con par\u00e1metros fijos, contrasta 500 si las asignaciones son sensibles.", "Eval\u00faa tambi\u00e9n otras semillas: aumentar \u00e9pocas no sustituye esa comprobaci\u00f3n."),
    "M\u00e1s \u00e9pocas no garantizan convergencia, coherencia tem\u00e1tica ni un mejor resultado.", sources = umap)
  add("density_seed", "UMAP + HDBSCAN / semilla y estabilidad",
    "2026 permite repetir una ejecuci\u00f3n. Compara 2027 para comprobar cu\u00e1nto depende de la inicializaci\u00f3n.",
    "La semilla inicializa las operaciones aleatorias de UMAP y, cuando procede, la aproximaci\u00f3n de LSA. HDBSCAN es determinista si recibe las mismas coordenadas.",
    "2026. Es un identificador de la secuencia aleatoria, no un a\u00f1o del corpus.",
    "Cambiarla mantiene la pregunta y las opciones, pero puede modificar coordenadas y grupos. Un n\u00famero mayor no mejora el ajuste.",
    c("Guarda el resultado con 2026.", "Contrasta otra semilla con id\u00e9nticos datos y opciones, o usa Evaluar estabilidad y sensibilidad.", "Revisa si los mismos documentos permanecen juntos. El ARI resume acuerdo global entre agrupaciones; la persistencia comprueba cu\u00e1nto se parecen los documentos de cada grupo entre repeticiones."),
    "Repetir la misma semilla demuestra repetibilidad dentro del entorno, no estabilidad ante otras inicializaciones ni equivalencia entre versiones.")

  add(c("kselect_min", "kselect_max"), "LDA / intervalo de n\u00fameros de temas a comparar",
    "Se comparan inicialmente k = 2 a 8. El m\u00e1ximo debe superar al m\u00ednimo y ser compatible con el corpus.",
    "k es el n\u00famero de temas que LDA debe estimar. La comparaci\u00f3n ajusta todos los enteros entre Desde k y Hasta k; no compara LDA con otros m\u00e9todos.",
    "De 2 a 8, con 3 semillas por k. Usa las iteraciones, la regla alpha y la semilla base del bloque de ajuste LDA.",
    "Ampliar el intervalo permite explorar soluciones m\u00e1s generales o m\u00e1s detalladas y requiere m\u00e1s ajustes. Un k mayor puede separar subtemas, pero tambi\u00e9n producir temas peque\u00f1os o redundantes.",
    c("Empieza con 2 a 8 si no tienes un k justificado.", "Compara las medidas con sus preguntas: coherencia, si las palabras principales aparecen juntas; diversidad, cu\u00e1nto se repiten entre temas; estabilidad, cu\u00e1nto se parecen entre semillas; y perplejidad, qu\u00e9 ajuste hay a textos reservados cuando se puede calcular; lee las soluciones candidatas.", "Si una candidata est\u00e1 en un extremo del intervalo, contrasta valores adyacentes permitidos antes de fijarla."),
    "k debe ser menor que el n\u00famero de unidades y t\u00e9rminos disponibles. Ning\u00fan indicador identifica por s\u00ed solo el n\u00famero verdadero de temas.", sources = lda)
  add("kselect_seeds", "LDA / semillas por n\u00famero de temas",
    "3 repeticiones por k permiten contrastar inicializaciones; con 1 no se puede estimar estabilidad entre semillas.",
    "Es el n\u00famero de ajustes con inicializaciones distintas que se realizan para cada k del intervalo.",
    "3. La primera semilla procede del control Semilla de LDA y se derivan las restantes de ella.",
    "M\u00e1s semillas ampl\u00edan la comprobaci\u00f3n de sensibilidad y aumentan el tiempo de c\u00e1lculo; no cambian el n\u00famero de temas de cada ajuste.",
    c("Utiliza 3 para la primera comparaci\u00f3n.", "Si los diagn\u00f3sticos var\u00edan entre repeticiones, contrasta 5 y lee los temas que cambian.", "Consulta la dispersi\u00f3n entre semillas, adem\u00e1s de las medias."),
    "Cinco repeticiones siguen siendo una exploraci\u00f3n limitada. La repetibilidad no demuestra validez tem\u00e1tica.")
  add(c("k", "kselect_choice"), "LDA / n\u00famero de temas (k)",
    "4 es el valor inicial del ajuste final. Justifica k mediante lectura y comparaci\u00f3n de soluciones.",
    "Fija cu\u00e1ntas distribuciones de palabras estimar\u00e1 el modelo. Un documento puede combinar esos temas en proporciones diferentes.",
    "4 en el ajuste final. El selector de la comparaci\u00f3n propone un candidato, que puedes sustituir.",
    "Un k menor puede reunir contenidos distintos; uno mayor puede separar subtemas o generar temas redundantes. El resultado depende del vocabulario y del corpus.",
    c("Consulta la comparaci\u00f3n de n\u00fameros de temas o documenta una raz\u00f3n previa para elegir k.", "Si usas el selector de comparaci\u00f3n, pulsa Fijar este k y despu\u00e9s Calcular LDA: el selector no ajusta el modelo final.", "Lee palabras y documentos por tema; contrasta un k cercano antes de nombrarlos."),
    "Los identificadores de tema no se corresponden autom\u00e1ticamente entre ajustes. M\u00e1s temas no implica mayor calidad.", sources = lda)
  add("lda_seed", "LDA / semilla del ajuste",
    "Empieza con 2026 y contrasta otra semilla con el mismo k; el n\u00famero mayor no significa mejor ajuste.",
    "Inicializa el procedimiento aleatorio de estimaci\u00f3n de LDA. Tambi\u00e9n es la base de las semillas de la comparaci\u00f3n de k.",
    "2026.",
    "Otra semilla puede cambiar las palabras y proporciones estimadas, incluso con el mismo k. Los temas pueden cambiar de n\u00famero sin cambiar de contenido.",
    c("Guarda palabras, documentos y diagn\u00f3sticos del primer ajuste.", "Repite con otra semilla manteniendo k, alpha e iteraciones.", "Compara el contenido de los temas y sus proporciones, teniendo en cuenta que sus identificadores pueden permutarse."),
    "Una \u00fanica ejecuci\u00f3n repetible no demuestra estabilidad ni convergencia.", sources = lda)
  add("iterations", "LDA / iteraciones de estimaci\u00f3n",
    "Empieza con 500. Si el indicador de ajuste a las palabras observadas (log-verosimilitud) sigue cambiando, contrasta 1.000 antes de interpretar.",
    "Son pasos del muestreo de Gibbs utilizado para estimar LDA. La aplicaci\u00f3n guarda estados del ajuste y conserva el de mayor log-verosimilitud entre los guardados.",
    "500; se ofrecen tambi\u00e9n 1.000 y 2.000. Se aplica al ajuste final y a la comparaci\u00f3n de k.",
    "Aumentarlas permite explorar m\u00e1s estados y requiere m\u00e1s tiempo. Las palabras y proporciones pueden cambiar aunque conserves la semilla.",
    c("Calcula con 500 y consulta Calidad del modelo ajustado.", "Si se detecta deriva o hay pocos estados para evaluarla, contrasta 1.000.", "Revisa tambi\u00e9n otras semillas y la lectura de documentos antes de aceptar los temas."),
    "La comprobaci\u00f3n busca si el indicador de ajuste sigue cambiando entre partes de la ejecuci\u00f3n. Es una regla orientativa: su ausencia no prueba que la estimaci\u00f3n se haya estabilizado definitivamente. M\u00e1s iteraciones no garantizan temas interpretables.", sources = lda)
  add("lda_alpha_mode", "LDA / mezcla de temas por unidad (alpha)",
    "Empieza con 1/k. Valores mayores favorecen mezclas m\u00e1s repartidas, especialmente en unidades cortas.",
    "Alpha expresa una preferencia previa del modelo sobre c\u00f3mo se reparten los temas en cada unidad. Se combina con la evidencia de sus palabras; no decide nombres de temas.",
    "Disperso, alpha = 1/k. Se ofrecen 5/k y 50/k. Con k = 4 corresponden a 0,25; 1,25 y 12,5 por tema.",
    "Un alpha menor favorece proporciones concentradas en pocos temas; uno mayor favorece mezclas m\u00e1s uniformes. La evidencia del texto puede modificar esa tendencia.",
    c("Mant\u00e9n 1/k en la primera exploraci\u00f3n.", "Si las mezclas documentales son una conclusi\u00f3n relevante, contrasta 5/k con k, semilla e iteraciones fijos.", "Revisa las composiciones y ejemplos, especialmente si en 02 elegiste frases: alpha se aplica a la unidad de ajuste."),
    "50/k no obliga a proporciones iguales. Cambiar alpha tambi\u00e9n cambia la comparaci\u00f3n de k; si cambia la regla, vuelve a compararla.", sources = lda)

  add(c("pca_terms", "ca_terms"), "ACP y AC / m\u00e1ximo de t\u00e9rminos",
    "ACP empieza con 100 t\u00e9rminos y AC con 40. El l\u00edmite selecciona vocabulario y puede cambiar los ejes.",
    "Selecciona los t\u00e9rminos m\u00e1s frecuentes del vocabulario retenido en 02, hasta el m\u00e1ximo indicado. No limita solo las nombres escritos en el gr\u00e1fico.",
    "100 en ACP y 40 en AC. Puede haber menos t\u00e9rminos si el corpus no permite utilizar todos.",
    "Un m\u00e1ximo mayor introduce t\u00e9rminos adicionales y puede cambiar coordenadas, contribuciones y porcentajes de los ejes; uno menor restringe la pregunta al vocabulario m\u00e1s frecuente.",
    c("Revisa antes qu\u00e9 t\u00e9rminos han quedado retenidos en 02.", "Calcula con el valor inicial y lee los t\u00e9rminos que m\u00e1s contribuyen a los ejes.", "Contrasta un l\u00edmite menor o mayor manteniendo las dem\u00e1s opciones, y comprueba si la interpretaci\u00f3n persiste."),
    "Si buscas legibilidad, utiliza los controles de lectura del plano; retirar t\u00e9rminos cambia el an\u00e1lisis, no solo el dibujo.")
  add("pca_scale", "ACP / estandarizar t\u00e9rminos",
    "Empieza desactivado. Activarlo iguala la varianza de los t\u00e9rminos y puede dar m\u00e1s peso a variaciones peque\u00f1as.",
    "El ACP centra siempre cada t\u00e9rmino restando su media. Si marcas esta opci\u00f3n, divide adem\u00e1s por su desviaci\u00f3n t\u00edpica, una medida de dispersi\u00f3n para que su varianza inicial sea 1.",
    "Desactivado: se conservan las diferencias de varianza entre los pesos TF-IDF de los t\u00e9rminos.",
    "Activarlo evita que los t\u00e9rminos con mayor varianza dominen por esa raz\u00f3n, pero puede aumentar la influencia de t\u00e9rminos poco frecuentes con variaci\u00f3n peque\u00f1a.",
    c("Calcula primero sin estandarizar y revisa las contribuciones.", "Contrasta con la opci\u00f3n activada usando el mismo vocabulario.", "Lee los t\u00e9rminos y documentos que sostienen cada eje y documenta qu\u00e9 comparaci\u00f3n responde a tu pregunta."),
    "Ninguna opci\u00f3n es universalmente superior. Estandarizar no elimina sesgos del corpus ni convierte los componentes en temas.",
    sources = c("R / prcomp" = "https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prcomp.html"))
  add(c("pca_axis_x", "pca_axis_y"), "ACP / componentes del plano",
    "Empieza por 1 y 2. Consulta la varianza que recoge el par elegido y el cos\u00b2 de cada objeto.",
    "Selecciona qu\u00e9 dos componentes ya calculados se dibujan. Los primeros recogen m\u00e1s varianza; los siguientes pueden mostrar contrastes que el primer plano no representa.",
    "Componentes 1 y 2; deben ser distintos. Solo se ofrecen componentes con variaci\u00f3n \u00fatil.",
    "Otro par cambia la proyecci\u00f3n, el cos\u00b2 del plano y las contribuciones que se muestran para sus ejes; conserva el ajuste calculado.",
    c("Consulta qu\u00e9 porcentaje de la variaci\u00f3n de los valores TF-IDF representan los componentes elegidos; ese porcentaje se llama varianza explicada.", "Comprueba el cos\u00b2: indica la representaci\u00f3n geom\u00e9trica de cada punto en el plano. Un 0,20 no significa que se muestre el 20 % de su significado o del contenido de un texto.", "Lee los t\u00e9rminos con mayor contribuci\u00f3n y los documentos asociados a sus contrastes."),
    "Los signos positivo y negativo no expresan calidad. No hay un umbral de cos\u00b2 que garantice por s\u00ed solo una interpretaci\u00f3n correcta.", effect = "Lectura")
  add(c("pca_quadrant", "pca_labels", "pca_focus", "ca_focus"), "ACP y AC / localizar y leer el plano",
    "Estos controles facilitan la lectura del resultado; no vuelven a ajustar el an\u00e1lisis.",
    "Buscar localiza un documento o t\u00e9rmino. En ACP, el cuadrante selecciona una parte del plano para leer variables y el m\u00e1ximo de nombres escritos en la figura limita los nombres dibujados.",
    "Vista general y plano completo; en ACP, hasta 16 nombres escritos junto a los puntos y distribuidos por el espacio.",
    "Mostrar menos nombres en la figura reduce solapamientos; elegir un cuadrante facilita leer una zona. Los puntos coincidentes conservan sus coordenadas.",
    c("Empieza con el plano completo y consulta qu\u00e9 parte de la variaci\u00f3n de pesos TF-IDF recoge en ACP (varianza) o de las diferencias de reparto de recuentos en AC (inercia).", "Busca un t\u00e9rmino relevante y revisa su representaci\u00f3n en el plano (cos\u00b2), participaci\u00f3n en la construcci\u00f3n del eje (contribuci\u00f3n) y, en AC, proporci\u00f3n de apariciones del t\u00e9rmino (masa).", "Usa la tabla para consultar puntos cuyo nombre no se ha dibujado o con coordenadas coincidentes."),
    "Que no se dibuje el nombre de un punto no significa que se haya excluido del an\u00e1lisis. Un cuadrante no es un grupo detectado. La proximidad en dos ejes puede ocultar diferencias en los restantes.", effect = "Lectura")
  add(c("lda_document_mode", "lda_document_page", "lda_document_page_size", "lda_documents"), "LDA / documentos que quieres consultar",
    "Recorre p\u00e1ginas o busca documentos; esta selecci\u00f3n solo cambia lo mostrado.",
    "Permite revisar las proporciones de temas del modelo vigente en documentos concretos. El modo por p\u00e1ginas conserva el orden de la tabla; el otro permite buscar por ID, t\u00edtulo o DOI.",
    "Primera p\u00e1gina de 18 documentos. Puedes cambiar el tama\u00f1o de p\u00e1gina o elegir hasta 100 documentos concretos.",
    "Cambiar p\u00e1gina, tama\u00f1o o selecci\u00f3n modifica el gr\u00e1fico y la tabla de lectura, sin reestimar temas ni prevalencias del corpus.",
    c("Consulta ejemplos de cada tema y documentos con mezclas distintas.", "Busca tambi\u00e9n casos que no encajen con el nombre de tema que est\u00e1s proponiendo.", "Comprueba siempre los t\u00edtulos y el texto original; los primeros documentos no son una muestra aleatoria."),
    "No generalices a todo el corpus a partir de la primera p\u00e1gina. Las proporciones no son probabilidades de que la publicaci\u00f3n pertenezca a una categor\u00eda verdadera.", effect = "Lectura")
  add("lda_time_spline", "LDA / l\u00edneas de la evoluci\u00f3n anual",
    "La spline de esta vista solo interpola el dibujo; los puntos y las medias anuales no cambian.",
    "Alterna segmentos rectos y una interpolaci\u00f3n c\u00fabica que conecta las medias anuales de los mismos temas LDA.",
    "Desactivada: segmentos rectos entre a\u00f1os consecutivos observados.",
    "Activarla redondea los tramos conservando los puntos, la suma de las proporciones y las interrupciones en a\u00f1os sin datos.",
    c("Lee primero los puntos y el n\u00famero de documentos de cada a\u00f1o.", "Activa la spline si facilita seguir las series.", "Interpreta el cambio a partir de las medias observadas y de la cobertura anual, no de una curvatura entre puntos."),
    "No estima tendencias, intervalos ni a\u00f1os ausentes. Los temas son fijos para todo el periodo; no es un modelo din\u00e1mico.", effect = "Lectura")
  add("density_time_view", "UMAP + HDBSCAN / evoluci\u00f3n de los grupos",
    "Barras para volumen; proporciones para peso anual; spline para una estimaci\u00f3n adicional de un grupo frente al resto.",
    "Compara grupos ya calculados entre a\u00f1os de publicaci\u00f3n. Cambia la representaci\u00f3n temporal, manteniendo las asignaciones de documentos.",
    "Barras apiladas de documentos por a\u00f1o. Solo entran documentos del modelo con a\u00f1o v\u00e1lido.",
    "Los recuentos muestran volumen; las proporciones dividen por el total anual e incluyen sin asignar. La spline necesita seleccionar un grupo y ajustar una curva adicional.",
    c("Revisa primero volumen y cobertura por a\u00f1o.", "Usa proporciones para separar cambios de peso relativo y cambios de tama\u00f1o anual del corpus.", "Considera la spline solo con cobertura suficiente y revisa sus diagn\u00f3sticos."),
    "M\u00e1s documentos de un grupo no implica mayor peso relativo. Las categor\u00edas se mantienen fijas: no se detecta autom\u00e1ticamente aparici\u00f3n o desaparici\u00f3n de temas.", effect = "Lectura")
  add("density_spline_group", "Evoluci\u00f3n / grupo frente al resto",
    "Elige un grupo cuya trayectoria puedas justificar y contrasta la curva con sus proporciones observadas.",
    "La curva estima la proporci\u00f3n anual de documentos de ese grupo frente a todos los dem\u00e1s documentos del modelo con a\u00f1o v\u00e1lido, incluidos los no asignados.",
    "Primer grupo asignado disponible. Despu\u00e9s de elegirlo debes pulsar Ajustar spline.",
    "Elegir otro grupo cambia la serie estudiada y exige volver a ajustar la curva, pero conserva la agrupaci\u00f3n UMAP + HDBSCAN.",
    c("Revisa las proporciones y el total de documentos por a\u00f1o.", "Elige el grupo por su relaci\u00f3n con la pregunta de investigaci\u00f3n.", "Ajusta y consulta puntos, banda y diagn\u00f3sticos; contrasta otros valores de complejidad."),
    "La banda es aproximada y condicional al ajuste. No incluye incertidumbre en el corpus ni en las asignaciones tem\u00e1ticas.", effect = "An\u00e1lisis temporal")
  add("density_spline_k", "Evoluci\u00f3n / complejidad m\u00e1xima de la spline",
    "Empieza con 5 y contrasta 4 o 6. Este n\u00famero limita flexibilidad; no fija el n\u00famero de curvas o de giros.",
    "Es el n\u00famero m\u00e1ximo solicitado de funciones base, piezas num\u00e9ricas que permiten construir una curva flexible. Una penalizaci\u00f3n regula cu\u00e1nta flexibilidad utiliza finalmente el ajuste.",
    "5; valores disponibles de 3 a 8. Se requieren al menos 10 a\u00f1os observados y cinco documentos del modelo por a\u00f1o.",
    "Un m\u00e1ximo menor restringe la forma de la curva. Uno mayor permite m\u00e1s detalle, aunque la penalizaci\u00f3n puede mantenerla suave; tambi\u00e9n aumenta el riesgo de interpretar oscilaciones poco respaldadas.",
    c("Ajusta con 5 y compara la curva con los puntos anuales.", "Contrasta 4 o 6 manteniendo el mismo grupo y revisa la flexibilidad realmente utilizada (grados de libertad efectivos) y las diferencias entre los puntos observados y las estimaciones de la curva (residuos).", "Si la conclusi\u00f3n cambia, informa de la sensibilidad y conserva los puntos como referencia."),
    "Los m\u00ednimos de cobertura son condiciones de la herramienta, no una garant\u00eda estad\u00edstica. La curva no pronostica y el dibujo se interrumpe donde faltan a\u00f1os.", effect = "An\u00e1lisis temporal",
    sources = c("mgcv / elegir la dimensi\u00f3n de base" = "https://stat.ethz.ch/R-manual/R-devel/library/mgcv/html/choose.k.html"))
  add("density_word_group", "Evoluci\u00f3n / vocabulario de un grupo",
    "Elige un grupo y compara sus t\u00e9rminos observados por a\u00f1o; no se vuelve a estimar la agrupaci\u00f3n.",
    "Selecciona el grupo fijo del que se muestran apariciones y presencia documental anual de t\u00e9rminos.",
    "Primer grupo asignado disponible.",
    "Cambiarlo sustituye el vocabulario y los documentos que se resumen en la tabla; no cambia las asignaciones.",
    c("Lee las palabras junto al n\u00famero de documentos del grupo en cada a\u00f1o.", "Distingue apariciones, documentos con el t\u00e9rmino y proporci\u00f3n de apariciones de palabras.", "Contrasta los cambios con los textos de los a\u00f1os correspondientes."),
    "Es una descripci\u00f3n del vocabulario observado; no demuestra evoluci\u00f3n de significados ni reentrena un modelo din\u00e1mico.", effect = "Lectura")

  add("thematic_field", "Mapa tem\u00e1tico / origen de los t\u00e9rminos",
    "Palabras clave y vocabulario preparado responden a preguntas distintas. Revisa su cobertura antes de elegir.",
    "Decide qu\u00e9 palabras o expresiones se convierten en puntos de la red. Las palabras clave usan el campo asignado en 02; el vocabulario utiliza los t\u00e9rminos retenidos de los textos.",
    "Palabras clave de la columna elegida en 02. El separador es el signo que distingue varias palabras clave dentro de una celda, por ejemplo punto y coma; una expresi\u00f3n como salud mental se conserva entera.",
    "Cambiar el origen cambia los t\u00e9rminos, las conexiones y el universo que se describe. Las palabras clave no reciben los filtros ling\u00fc\u00edsticos del texto.",
    c("Comprueba si el campo contiene palabras de autor o t\u00e9rminos de indizaci\u00f3n y cu\u00e1ntos documentos lo tienen.", "Usa vocabulario preparado si tu pregunta se refiere al texto y revisa su limpieza en 02.", "Documenta el campo exacto y el origen Scopus o Web of Science: no presupongas equivalencia entre campos."),
    "No se mezclan ambos or\u00edgenes. Cada t\u00e9rmino cuenta una sola vez por documento, aunque se repita o se haya preparado por frases.")
  add("thematic_presence", "Mapa tem\u00e1tico / presencia m\u00ednima",
    "Empieza con 2 documentos. Subir el umbral retira t\u00e9rminos menos extendidos y puede ocultar temas espec\u00edficos.",
    "Es el m\u00ednimo de documentos distintos que deben contener un t\u00e9rmino para que pueda entrar en la red.",
    "2 documentos; despu\u00e9s se aplica el m\u00e1ximo de t\u00e9rminos.",
    "Un umbral mayor reduce vocabulario poco presente y tambi\u00e9n puede excluir temas minoritarios. Uno menor ampl\u00eda cobertura y puede introducir t\u00e9rminos circunstanciales.",
    c("Consulta cobertura y t\u00e9rminos excluidos con el valor inicial.", "Contrasta un umbral cercano, por ejemplo 3, si el tama\u00f1o del corpus lo permite.", "Revisa qu\u00e9 contenidos se pierden y c\u00f3mo cambian comunidades y cuadrantes."),
    "No cuenta repeticiones dentro del mismo documento. Superar el umbral no demuestra relevancia tem\u00e1tica.")
  add("thematic_terms", "Mapa tem\u00e1tico / m\u00e1ximo de t\u00e9rminos",
    "Empieza con 100. Reducirlo simplifica la red analizada y puede cambiar centralidad y densidad.",
    "El m\u00e1ximo limita cu\u00e1ntas palabras o expresiones entran en la red. Solo pueden seleccionarse las que aparecen en al menos el n\u00famero de documentos elegido en Presencia m\u00ednima. Entre ellas se conservan primero las que est\u00e1n en m\u00e1s documentos. Si dos tienen el mismo n\u00famero, se usa el texto con que est\u00e1n escritas para desempatar, alfab\u00e9ticamente. Ese desempate no indica mayor importancia.",
    "100; el m\u00e1ximo admitido es 150.",
    "Un l\u00edmite mayor puede incluir vocabulario especializado, conexiones y comunidades adicionales. Uno menor centra la red en los t\u00e9rminos m\u00e1s presentes.",
    c("Consulta la selecci\u00f3n y los t\u00e9rminos que quedan fuera.", "Cambia solo el m\u00e1ximo de t\u00e9rminos. Mant\u00e9n los valores de los controles Presencia m\u00ednima, Copresencias m\u00ednimas, Resoluci\u00f3n y Semilla para poder comparar.", "Comprueba si las palabras que describen cada comunidad y su posici\u00f3n en el mapa cambian al retirar o a\u00f1adir t\u00e9rminos."),
    "Cambiar el m\u00e1ximo modifica los c\u00e1lculos, no solo los nombres escritos en la figura. Tambi\u00e9n pueden cambiar las medianas: los valores centrales de cada medida al ordenar los temas. Esos valores separan los cuadrantes de este mapa; no son umbrales universales de calidad.")
  add("thematic_shared", "Mapa tem\u00e1tico / copresencias m\u00ednimas",
    "Empieza con 1 documento compartido. Subir el umbral elimina conexiones y puede dejar t\u00e9rminos aislados.",
    "Exige que dos t\u00e9rminos aparezcan juntos en al menos ese n\u00famero de documentos para conservar su conexi\u00f3n.",
    "1. Despu\u00e9s de filtrar conexiones, se excluyen del mapa los t\u00e9rminos que quedan aislados y se registran en la auditor\u00eda.",
    "Un umbral mayor retira conexiones apoyadas por pocos documentos, pero puede fragmentar la red y retirar vocabulario espec\u00edfico.",
    c("Revisa cu\u00e1ntas conexiones y t\u00e9rminos se conservan con 1.", "Contrasta 2 si hay suficiente cobertura documental.", "Comprueba los t\u00e9rminos excluidos y los cambios en comunidades, centralidad y densidad."),
    "El umbral es un recuento documental, no el peso normalizado de la conexi\u00f3n ni una prueba de significaci\u00f3n.")
  add(c("thematic_resolution", "network_resolution"), "Louvain / resoluci\u00f3n de las comunidades",
    "Empieza con 1 y compara 0,5 y 1,5, con la misma red y semilla. Lee qu\u00e9 comunidades se unen o se separan.",
    "Controla el grado de detalle de los grupos propuestos por Louvain, llamados comunidades. Un nodo es un elemento de la red, como un t\u00e9rmino o autor. El algoritmo usa sus conexiones y pesos, no la proximidad que ves en el dibujo. Puede entenderse como un zoom conceptual, aunque cambiarlo recalcula las comunidades y no solo ampl\u00eda el dibujo.",
    "1. Es un punto de partida, no un valor \u00f3ptimo universal ni un n\u00famero deseado de temas.",
    "Valores menores suelen favorecer comunidades mayores; valores mayores suelen favorecer comunidades m\u00e1s peque\u00f1as. El n\u00famero y la composici\u00f3n no cambian de manera necesariamente uniforme. Una resoluci\u00f3n alta puede separar contenidos que convendr\u00eda interpretar juntos.",
    c("Calcula con 1 y conserva la selecci\u00f3n de nodos, conexiones, pesos y semilla.", "Contrasta 0,5 y 1,5; identifica qu\u00e9 comunidades se fusionan o dividen y lee sus t\u00e9rminos y documentos.", "Repite la candidata con otra semilla. Elige una escala \u00fatil para tu pregunta y documenta alternativas y cambios."),
    "La modularidad compara las conexiones internas de los grupos con un reparto de referencia de la red. Su l\u00edmite de resoluci\u00f3n significa que el procedimiento puede fusionar comunidades peque\u00f1as en funci\u00f3n de la red completa. Ajustar la resoluci\u00f3n explora otras escalas, pero no garantiza resolver ese l\u00edmite ni validar temas. Louvain no reconoce sin\u00f3nimos. La centralidad y densidad de Callon describen conexiones; no prueban coherencia sem\u00e1ntica.", sources = louvain)
  add("thematic_seed", "Mapa tem\u00e1tico / semilla de Louvain",
    "Empieza con 2026 y contrasta 2027 manteniendo fija la red y la resoluci\u00f3n.",
    "Inicializa las decisiones aleatorias del algoritmo de comunidades. Permite repetir la partici\u00f3n con id\u00e9nticos datos, par\u00e1metros y entorno.",
    "2026. No se refiere al a\u00f1o de publicaci\u00f3n.",
    "Otra semilla puede dar una partici\u00f3n distinta y modificar centralidad, densidad y cuadrantes, porque cambia qu\u00e9 conexiones se consideran internas o externas.",
    c("Guarda la partici\u00f3n inicial y sus t\u00e9rminos por comunidad.", "Repite con otra semilla, manteniendo todos los filtros y la resoluci\u00f3n.", "Compara contenidos, no solo identificadores T1 o T2, que pueden cambiar entre mapas."),
    "Una semilla no valida una partici\u00f3n. Este m\u00f3dulo no calcula autom\u00e1ticamente una puntuaci\u00f3n de estabilidad tem\u00e1tica.")
  out
}

model_parameter_modal <- function(id) {
  card <- model_parameter_catalog()[[id]]
  if (is.null(card)) return(NULL)
  tags$div(class = "help-doc parameter-help-doc",
    tags$p(class = "parameter-impact", tags$strong("Tipo de decisi\u00f3n: "), card$effect,
      switch(card$effect, Ajuste = ". Cambiarla requiere volver a calcular el an\u00e1lisis.",
        Lectura = ". Cambia la consulta o el dibujo del resultado vigente.",
        ". Cambia el ajuste temporal; conserva la agrupaci\u00f3n de documentos.")),
    tags$section(tags$h3("1. Qu\u00e9 controla y para qu\u00e9 sirve"), tags$p(card$meaning)),
    tags$section(tags$h3("2. Con qu\u00e9 empezar"), tags$p(card$start)),
    tags$section(tags$h3("3. Qu\u00e9 cambia al elegir otro valor"), tags$p(card$change)),
    tags$section(tags$h3("4. C\u00f3mo decidir paso a paso"), tags$ol(lapply(card$decision, tags$li))),
    tags$section(tags$h3("5. Qu\u00e9 no permite concluir"), tags$p(card$limit)),
    if (length(card$sources)) tags$details(class = "help-fold", tags$summary("Fuentes metodol\u00f3gicas"),
      tags$ul(lapply(seq_along(card$sources), function(i) tags$li(tags$a(href = card$sources[[i]],
        target = "_blank", rel = "noopener noreferrer", names(card$sources)[i]))))))
}

# Se anade orientacion al contenedor del control, conservando el control intacto.
# Sirve tanto para el arbol inicial como para los controles creados con renderUI.
model_parameter_guidance <- function(ui) {
  catalog <- model_parameter_catalog()
  walk <- function(node) {
    if (inherits(node, "shiny.tag")) {
      if (!is.null(node$attribs[["data-parameter-guidance"]])) return(node)
      node$children <- lapply(node$children, walk)
      if (ui_has_class(node, "shiny-input-container")) {
        ids <- names(catalog)[vapply(names(catalog), function(id) ui_has_id(node, id), TRUE)]
        if (length(ids) == 1L) {
          id <- ids[[1]]; card <- catalog[[id]]
          node$attribs[["data-parameter-guidance"]] <- id
          node$children <- c(node$children, list(tags$div(class = "parameter-guidance",
            tags$p(class = "parameter-note", card$hint),
            actionButton(paste0("help_parameter_", id), "C\u00f3mo decidir", class = "btn-quiet parameter-help-button",
              `aria-label` = paste("C\u00f3mo decidir:", card$title)))))
        }
      }
      return(node)
    }
    if (is.list(node)) node[] <- lapply(node, walk)
    node
  }
  walk(ui)
}
