library(data.table)
library(rhdf5)
library(openxlsx)


VehAvl_wt <- function(go_down, dt, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  
  origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
  outname = paste(paste(wbname, nm_set, scenario, sep="_"),'xlsx', sep = '.')

  dt_hh = dt[!duplicated(dt$hh_id),]
  dt_hh$WT = dt_hh$WT_HH
  dt_ex = dt[dt$RegularWorkExists == 'True',]
  
  output_grp = dt_hh[,.(TOTAL=sum(WT,na.rm = TRUE)), .(HHINC,HHSIZE_AV,DRIVERS,WORKERS,Auto.Ownership,Z_TYPE)]
  output_grp$TOT_CAR = output_grp$Auto.Ownership * output_grp$TOTAL

  timedist_type = dt_ex[,.(Time=sum(WT*hw_time, na.rm = TRUE),Dist=sum(WT*hw_dist, na.rm = TRUE),count=sum(WT, na.rm = TRUE)),.(AUTO_WORK)]

  output_county =dt_hh[,.(TOTAL=sum(WT,na.rm = TRUE)), .(CNTY,HHAUTO)]
  
  output_sd =dt_hh[,.(TOTAL=sum(WT,na.rm = TRUE)), .(SD,HHAUTO)]
  
  output_fp =dt[,.(TOTAL=sum(WT,na.rm = TRUE)), .(fp_choice, type, HHINC, CNTY_W)]
  
  if (go_down) {
    setwd("Survey_Populated")
    wb <- loadWorkbook(origname)
    setwd('..')
  }else{
    wb <- loadWorkbook(outname)
  }
  
  writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
  writeData(wb, sheet = sheetname, output_grp,startRow = 2, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, timedist_type,startRow = 2, startCol = 11, colNames = T)
  writeData(wb, sheet = sheetname, output_county,startRow = 2, startCol = 18, colNames = T)
  writeData(wb, sheet = sheetname, output_fp,startRow = 2, startCol = 24, colNames = T)
  writeData(wb, sheet = sheetname, output_sd,startRow = 2, startCol = 32, colNames = T)
  
  saveWorkbook(wb,outname,overwrite = T)
  
}


#################################################################
VehAvl_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, Time, Dist){
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)
  
  dt_person = merge(PersonData, HouseholdData, by='hh_id', all.x=T)
  dt_personzone = merge(dt_person, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x = TRUE, all.y = FALSE)
  dt_personzone = merge(dt_personzone, zoneMPO, by.x = 'workplace_zone_id', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_W'))
  # For those without workplace, add "None"
  dt_personzone$CNTY_W <- factor(dt_personzone$CNTY_W , 
                                 levels = c('San Francisco','San Mateo','Santa Clara','Alameda','Contra Costa','Solano','Napa','Sonoma','Marin','None'))
  dt_personzone$CNTY_W[is.na(dt_personzone$CNTY_W)] <- 'None'
  
  dt_personzone = merge(dt_personzone, Time, by.x=c('TAZ','workplace_zone_id'), by.y=c('orig','dest'), all.x=T)
  dt_personzone = merge(dt_personzone, Dist, by.x=c('TAZ','workplace_zone_id'), by.y=c('orig','dest'), all.x=T)
  setnames(dt_personzone, old=c('SOV_TIME__AM','SOV_DIST__AM'), new=c('hw_time','hw_dist'))
 
  # survey data has records with no home TAZ in MTC, fill that in
  dt_personzone$MPO[is.na(dt_personzone$MPO)] = 'MTC'
  
  # Subsets wrt MPOs:
  all_mpo = unique(zoneMPO$MPO)
  
  out_mpo_names = c("MTC") # these will change, MTC, SACOG, SJQ, AMBAG, ALL
  out_mpo_names = out_mpo_names[which(list(MTC)==TRUE)]
  
  ########################################
  ############ Write Output ##############
  ########################################
  
  setwd(xlsxPath)
  
  for (mpo in out_mpo_names) {
    if (mpo %in% all_mpo) {
      this_mpo = mpo
      subset_pp = dt_personzone[dt_personzone$MPO == this_mpo]
      VehAvl_wt(go_down, subset_pp, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      VehAvl_wt(go_down, dt_personzone, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
}
