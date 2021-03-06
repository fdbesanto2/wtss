% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/wtss.R
\name{list_coverages}
\alias{list_coverages}
\title{List the coverages available in the WTSS service}
\usage{
list_coverages(wtss.obj)
}
\arguments{
\item{wtss.obj}{WTSS object}
}
\value{
NULL if fails, TRUE if works
}
\description{
Lists coverages available in the WTSS service
}
\examples{
{
wtss <-  WTSS("http://www.esensing.dpi.inpe.br/wtss/")
list_coverages(wtss)
}
}
