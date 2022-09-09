library(data.table)
library(rhdf5)
library(openxlsx)
library(zoo)


CDAP_wt <- function(go_down, dt, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  
  origname = paste(paste(wbname, nm_set, sep='_'),'xlsx', sep = '.')
  outname = paste(paste(wbname, nm_set, scenario, sep='_'),'xlsx', sep = '.')

  if (go_down) {
    setwd("Survey_Populated")
    wb <- loadWorkbook(origname)
    setwd('..')
  }else{
    wb <- loadWorkbook(outname)
  }

  output_grp = dt[,.(count=sum(WT,na.rm=T)),.(type, HHINC, HHSIZE_AV, AGE_GRP, GENDER, AUTO_WORK, DAP)]
  writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
  writeData(wb, sheet = sheetname, output_grp,startRow = 2, startCol = 1, colNames = T)
  
  saveWorkbook(wb,outname,overwrite = T)
  
}


#################################################################
CDAP_once <- function(go_down,wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)
  
  name_model = name_model
  names_cat1 = c('Male', 'Female')
  names_cat2 = c('Child Age 0-17','Adult Age 18-25','Adult Age 26-35','Adult Age 36-50','Adult Age 51-65','Adult Age 66+')
  names_cat3 = c('Mandatory','Non-mandatory','Home')
  
  # create variables specific for CDAP model: GENDER, AGE_GRP, and DAP
  dt_person = merge(PersonData, HouseholdData, by='hh_id', all.x=T)
  # gender
  dt_person$GENDER = factor(dt_person$sex, levels = 1:2, labels = names_cat1)
  # age
  dt_person$AGE_GRP = cut(dt_person$age, breaks = c(-1,18,26,36,51,66,200), labels = names_cat2, right = FALSE)
  # activity pattern
  dt_person$activity=ifelse(dt_person$activity_pattern=="M",1,ifelse(dt_person$activity_pattern=="N",2,3))
  dt_person$DAP = factor(dt_person$activity, levels = 1:3, labels = names_cat3)
  # use WT_LINK21 for survey data
  if (name_model=='CHTS'){
    dt_person$WT = dt_person$WT_Link21
  } else{ }
  
  # Match zones to MPOs:
  zoneMPO = zoneMPO[,c('TAZ','MPO')]
  dt_person = merge(dt_person, zoneMPO, by= 'TAZ', all.x = T)

  # survey data has records with no home TAZ in MTC, fill that in
  dt_person$MPO[is.na(dt_person$MPO)] = 'MTC'
  
  # Subsets wrt MPOs:
  all_mpo = unique(zoneMPO$MPO)

  out_mpo_names = c("MTC")
  out_mpo_names = out_mpo_names[which(list(MTC)==TRUE)]
  
  ########################################
  ############ Write Output ##############
  ########################################
  
  setwd(xlsxPath)

  for (mpo in out_mpo_names) {
    if (mpo %in% all_mpo) {
      this_mpo = mpo
      subset = dt_person[dt_person$MPO == this_mpo]
      CDAP_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }

    if (mpo == 'ALL') {
      CDAP_wt(go_down, dt_person, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }

}