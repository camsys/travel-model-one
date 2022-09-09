library(openxlsx)

gen <- function(nm) {
  inputD = 'E://_projects//Link21//templates//'
  outputD = paste('E://_projects//Link21//Link21_Reports',nm,'Survey_Populated', sep = '//')
  
  in_name = paste(nm, 'xlsx', sep = '.')
  out_name = nm
  subs = c("MTC")
  setwd(inputD)
  wb <- loadWorkbook(in_name)
  if (!dir.exists(outputD)) {dir.create(outputD)}
  setwd(outputD)
  for (i in 1:length(subs)) {
    now_name = paste(paste(out_name, subs[i], sep="_"),'xlsx', sep = '.')
    saveWorkbook(wb,now_name,overwrite = T)
  }
}

gen('1 - Vehicle_Avail')

gen('2 - CDAP')

gen('3 - Tour_Frequency')

gen('4 - Tour_Dest_Choice')

gen('5 - Tour_Mode_Choice')

gen('6 - Tour_TOD_Choice')

gen('7 - Stop_Frequency')

gen('8 - Stop_Dest_Choice')

gen('9 - Trip_Mode_Choice')

gen('10 - Trip_TOD_Choice')

gen('99 - Dest_Choice_BigData')
