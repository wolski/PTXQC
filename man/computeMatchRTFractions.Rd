% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fcn_MQalign.R
\name{computeMatchRTFractions}
\alias{computeMatchRTFractions}
\title{Combine several data structs into a final picture for segmentation incurred by 'Match-between-runs'.}
\usage{
computeMatchRTFractions(qMBR, qMBRSeg_Dist_inGroup)
}
\arguments{
\item{qMBR}{A data.frame as computed by peakSegmentation()}

\item{qMBRSeg_Dist_inGroup}{A data.frame as computed by inMatchWindow()}
}
\value{
A data.frame which details the distribution of singlets and pairs (inRT and outRT) for each Raw file and genuine vs. all
}
\description{
qMBRSeg_Dist_inGroup might be empty if there are only singlets (transferred and genuine), but then the scores will be pretty
boring as well (100%).
}

