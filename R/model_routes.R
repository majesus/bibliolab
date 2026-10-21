# Rutas de entrada a 04 / Modelos: la pregunta de investigacion va antes que la tecnica. Cada ruta declara que devuelve,
# que decision exige y que no permite concluir; los controles de cada analisis siguen en sus pestanas.
model_routes <- function() list(
  patrones = list(
    question = "\u00bfQu\u00e9 patrones de palabras contrastan los documentos?", technique = "ACP y correspondencias",
    returns = "Ejes que resumen c\u00f3mo var\u00eda el vocabulario entre documentos (ACP, sobre pesos TF-IDF) o entre repartos de apariciones de palabras entre las unidades (correspondencias), con las palabras que m\u00e1s contribuyen a cada eje y la posici\u00f3n de cada documento o t\u00e9rmino.",
    decision = "Cu\u00e1ntos t\u00e9rminos y ejes se leen y, en el ACP, si se estandarizan los t\u00e9rminos a varianza 1; en las correspondencias, si la unidad son documentos o frases, seg\u00fan lo elegido en 02.",
    limit = "Un eje no es un tema ni explica causas. Un porcentaje alto de varianza o de inercia puede deberse a la longitud de los textos o a unas pocas palabras muy frecuentes; lee los documentos que m\u00e1s pesan en cada eje.",
    tabs = c("ACP", "Correspondencias"), labels = c("Abrir ACP", "Abrir correspondencias")),
  mezclas = list(
    question = "\u00bfQu\u00e9 mezclas de temas aparecen?", technique = "LDA",
    returns = "Para cada unidad, las proporciones de k temas, y para cada tema, sus palabras m\u00e1s probables y los documentos que m\u00e1s lo contienen.",
    decision = "El n\u00famero de temas k, que se compara con varias semillas antes de fijarlo, y la unidad (documentos o frases, seg\u00fan 02).",
    limit = "Un tema es una distribuci\u00f3n de palabras, no una categor\u00eda de investigaci\u00f3n. Las proporciones dependen de k y de las preferencias previas del modelo, como alpha, y la semilla permite repetir una ejecuci\u00f3n pero no prueba que los temas sean estables; el nombre del tema lo decide el investigador tras leer los documentos.",
    tabs = "LDA", labels = "Abrir LDA"),
  grupos = list(
    question = "\u00bfQu\u00e9 documentos forman grupos?", technique = "UMAP + HDBSCAN",
    returns = "Grupos de documentos pr\u00f3ximos en un espacio reducido, con un grado de pertenencia por documento, los documentos que no encajan en ning\u00fan grupo (grupo 0) y los t\u00e9rminos m\u00e1s propios de cada grupo seg\u00fan c-TF-IDF.",
    decision = "La representaci\u00f3n (TF-IDF o BM25 con LSA, o vectores importados), los vecinos de UMAP y el tama\u00f1o m\u00ednimo de grupo (minPts) de HDBSCAN; despu\u00e9s, evaluar la estabilidad.",
    limit = "Un grupo no es una taxonom\u00eda, el grado de pertenencia no es una probabilidad tem\u00e1tica y quedar sin asignar no es un error. Las distancias del mapa en dos dimensiones no son distancias exactas entre documentos.",
    tabs = "UMAP + HDBSCAN", labels = "Abrir UMAP + HDBSCAN"),
  tematico = list(
    question = "\u00bfC\u00f3mo se conectan los temas y qu\u00e9 cohesi\u00f3n interna presentan?", technique = "Mapa tem\u00e1tico / Callon",
    returns = "Comunidades de t\u00e9rminos copresentes por documento, con centralidad externa, densidad interna, cuadrantes y una auditor\u00eda de t\u00e9rminos incluidos y excluidos.",
    decision = "Origen de t\u00e9rminos (palabras clave o vocabulario preparado), filtros de presencia y copresencia, m\u00e1ximo de t\u00e9rminos y resoluci\u00f3n de Louvain.",
    limit = "Las posiciones son relativas a las medianas del mapa. No miden calidad ni distinguen emergencia de declive sin un an\u00e1lisis temporal. Los temas no son agrupaciones exclusivas de documentos.",
    tabs = "Mapa tem\u00e1tico", labels = "Abrir mapa tem\u00e1tico"),
  describir = list(
    question = "\u00bfSolo necesito describir el corpus?", technique = "sin modelos",
    returns = "Los recuentos y relaciones observadas de 03 / Indicadores (producci\u00f3n, fuentes, autores, palabras clave, redes y comparaciones de vocabulario) y su descarga en 05 / Entrega.",
    decision = "Revisar la cobertura y la calidad del corpus y decidir qu\u00e9 tablas y figuras del informe se presentan.",
    limit = "Esta ruta no permite inferir temas, grupos ni estructura latente del vocabulario: son recuentos y coapariciones observadas, no resultados de un modelo.",
    tabs = NULL, labels = "Finalizar descripci\u00f3n y descargar")
)
