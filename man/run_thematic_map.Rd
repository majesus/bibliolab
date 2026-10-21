\name{run_thematic_map}
\alias{run_thematic_map}
\title{Mapa tematico de centralidad y densidad de Callon}
\usage{run_thematic_map(corpus, prepared, params = list())}
\arguments{
\item{corpus, prepared}{Resultados de \code{prepare_corpus()} y \code{prepare_documents()}.}
\item{params}{Lista parcial: \code{field} (\code{"keywords"} o \code{"text"}),
\code{min_presence} (2), \code{max_terms} (100; maximo 150),
\code{min_shared} (1), \code{resolution} (1) y \code{seed} (2026).}
}
\description{Detecta comunidades de terminos mediante Louvain ponderado sobre
copresencias documentales normalizadas con el indice de equivalencia.
Calcula la centralidad y densidad de Callon sin modificar el corpus.}
\details{Cada termino cuenta una vez por documento. El peso es
\eqn{e_{ij}=c_{ij}^2/(c_i c_j)}. La centralidad es diez veces la suma de pesos
externos y la densidad es cien veces la suma de pesos internos dividida por
el numero de terminos. Cada pareja interna se cuenta una vez; una conexion
externa contribuye a ambos temas. Se retiran los aislados tras los filtros.
Los cortes son las medianas entre temas; las igualdades quedan sobre el limite.
Un unico tema no permite interpretar cuadrantes. Un unico mapa no distingue
emergencia de declive. Los documentos por tema no son exclusivos.}
\value{Lista con \code{themes}, \code{terms}, \code{edges}, \code{selection},
\code{coverage}, \code{cuts}, \code{params}, \code{incidence},
\code{modularity} y \code{method}.}
\references{Cobo et al. (2012). SciMAT: A new science mapping analysis software
tool. JASIST, 63(8), 1609--1630. doi:10.1002/asi.22688.}
