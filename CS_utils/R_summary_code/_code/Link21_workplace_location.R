library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)


WorkLoc_wt <- function(go_down, dt, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')

  origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
  outname = paste(paste(wbname, nm_set, scenario, sep="_"),'xlsx', sep = '.')
    
  dt$CUT_DIST=dt$DIST
  dt$CUT_TIME=dt$TIME
  dt$CUT_DIST[dt$DIST>=70] = 70
  dt$CUT_TIME[dt$TIME>=100] = 100
    
  output_timedist = dt[,.(count=sum(WT,na.rm = TRUE)),.(CUT_DIST,CUT_TIME)]

  output_grp = dt[,.(count=sum(WT,na.rm = TRUE), time=sum(WT*TIME,na.rm = TRUE), dist=sum(WT*DIST,na.rm = TRUE)),.(type,HHINC,Z_TYPE_O,Z_TYPE_D)]

  output_intra = dt[,.(intra=sum(WT*(Intra.Zonal),na.rm = TRUE),count=sum(WT*exists,na.rm = TRUE)), .(Z_TYPE_O,SIZE_O)]

  output_county = dt[,.(count=sum(WT,na.rm = TRUE)),.(CNTY_O,CNTY_D)]

  output_sd = dt[,.(count=sum(WT,na.rm = TRUE)),.(SD_O,SD_D)]

  output_exist = dt[,.(exist=sum(WT*(exists),na.rm = TRUE), count=sum(WT,na.rm = TRUE)), .(type,gender,age16plus,HHINC)]
    
  if (go_down){
    setwd("Survey_Populated")
    wb <- loadWorkbook(origname)
    setwd('..')
  }else{
    wb <- loadWorkbook(outname)
  }
    
  writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
  writeData(wb, sheet = sheetname, output_timedist,startRow = 2, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, output_grp,startRow = 2, startCol = 11, colNames = T)
  writeData(wb, sheet = sheetname, output_intra,startRow = 2, startCol = 21, colNames = T)
  writeData(wb, sheet = sheetname, output_county,startRow = 2, startCol = 31, colNames = T)
  writeData(wb, sheet = sheetname, output_sd,startRow = 2, startCol = 41, colNames = T)
  writeData(wb, sheet = sheetname, output_exist,startRow = 2, startCol = 51, colNames = T)    
  saveWorkbook(wb,outname,overwrite = T)

}


#################################################################
WorkLoc_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, Time_AM, Dist_AM) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)

  # person and household
  dt_person = merge(PersonData, HouseholdData, by = 'hh_id', all.x = TRUE)
  
  # workplace exists
  dt_person$exists=ifelse(dt_person$workplace_zone_id==0, 0, 1)
  #age&gender
  dt_person$age16plus=ifelse(dt_person$age>=16,1,0)
  dt_person$gender =ifelse(dt_person$sex==1, 'Male', 'Female')
  
  # Distance and time:
  dt_person = merge(dt_person, Time_AM, by.x=c('TAZ','workplace_zone_id'), by.y=c('orig','dest'), all.x=T)
  dt_person$TIME=floor(dt_person$SOV_TIME__AM)
  dt_person = merge(dt_person, Dist_AM, by.x=c('TAZ','workplace_zone_id'), by.y=c('orig','dest'), all.x=T)
  dt_person$DIST=floor(dt_person$SOV_DIST__AM)
  dt_person = dt_person[,-c('SOV_TIME__AM','SOV_DIST__AM')]
  
  # Intra-zonal
  dt_person$Intra.Zonal = (dt_person$TAZ == dt_person$workplace_zone_id)  

  # Match zones to MPOs: Need both Z_TYPE and COUNTY/SD for O/D, only need MPO and size for home taz but will include Z_TYPE/CNTY so that suffix could work
  dt_person = merge(dt_person, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x=T, all.y= F)
  dt_person = merge(dt_person, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_O'))
  dt_person = merge(dt_person, zoneMPO, by.x = 'workplace_zone_id', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_D'))

  # survey data has records with no home TAZ in MTC, fill that in
  dt_person$MPO[is.na(dt_person$MPO)] = 'MTC'
  
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
      subset = dt_person[dt_person$MPO == this_mpo]
      WorkLoc_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      WorkLoc_wt(go_down, dt_person, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
}

