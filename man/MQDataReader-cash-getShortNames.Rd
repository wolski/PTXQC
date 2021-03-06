% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/MQDataReader.R
\name{MQDataReader$getShortNames}
\alias{MQDataReader$getShortNames}
\title{Shorten a set of Raw file names and return a data frame with the mappings.}
\arguments{
\item{raw.files}{Vector of Raw files}

\item{max_len}{Maximal length of shortening results, before resorting to canonical names (file 1,...)}

\item{fallbackStartNr}{Starting index for canonical names}
}
\value{
data.frame with mapping
}
\description{
Shorten a set of Raw file names and return a data frame with the mappings.
}

