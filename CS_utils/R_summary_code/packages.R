#Included library to check if the packages are installed and loaded properly

install.packages("data.table", dependencies=TRUE)

install.packages("plyr")

if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
  BiocManager::install("rhdf5")
  
install.packages("devtools")
devtools::install_github("gregmacfarlane/omxr")

install.packages("openxlsx")

install.packages("zoo")

install.packages("reshape2")

install.packages('Rcpp')

install.packages("config")


library(data.table)
library(plyr)
library(rhdf5)
library(omxr)
library(openxlsx)
library(zoo)
library(reshape2)
library(Rcpp)
library(config)



