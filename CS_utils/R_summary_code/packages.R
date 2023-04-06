#Included library to check if the packages are installed and loaded properly

install.packages("data.table", dependencies=TRUE)
library(data.table)

install.packages("plyr")
library(plyr)

if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
  BiocManager::install("rhdf5")
library(rhdf5)
  
install.packages("devtools")
devtools::install_github("gregmacfarlane/omxr")
library(omxr)

install.packages("openxlsx")
library(openxlsx)

install.packages("zoo")
library(zoo)

install.packages("reshape2")
library(reshape2)

install.packages('Rcpp')
library(Rcpp)

install.packages("config")
library(config)



