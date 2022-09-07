library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)

TourMode_wt <- function(go_down, dt_t, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')

  names_tours = c('Work','Work-based Subtour','School','Escort','Shop','Meal','Social','Other','All')

  for (i in 1:length(names_tours)) {
    origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
    outname = paste(paste(wbname, nm_set, names_tours[i], scenario, sep="_"),'xlsx', sep = '.')
    
    if (names_tours[i]=="All") { dt=dt_t } 
    else { dt= subset(dt_t, tour_purp==names_tours[i]) }

    output_hh = dt[,.(count = sum(WT, na.rm = T)), .(HHINC,tour_mode_cat,AUTO_WORK,TourType)]
    output_hh <- dcast(output_hh,HHINC+tour_mode_cat+AUTO_WORK~TourType, value.var = 'count')
    output_pp = dt[,.(count = sum(WT, na.rm = T)), .(type,tour_mode_cat,sex_age,TourType)]
    output_pp <- dcast(output_pp,type+tour_mode_cat+sex_age~TourType, value.var = 'count')
    output_z  = dt[,.(count = sum(WT, na.rm = T)), .(Z_TYPE_O,Z_TYPE_D,tour_mode_cat,TourType)]
    output_z <- dcast(output_z,Z_TYPE_O+Z_TYPE_D+tour_mode_cat~TourType, value.var = 'count')

    if (go_down) {
      setwd("Template")
      wb <- loadWorkbook(origname)
      setwd('..')
    }else{
      wb <- loadWorkbook(outname)
    }

    writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
    writeData(wb, sheet = sheetname, output_hh,startRow = 2, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, output_pp,startRow = 2, startCol = 8, colNames = T)
    writeData(wb, sheet = sheetname, output_z,startRow = 2, startCol = 15, colNames = T)
    
    saveWorkbook(wb,outname,overwrite = T)
    
  }
}  


#################################################################
TourMode_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, ToursData) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)
  
  #person/household data
  dt_person = merge(PersonData, HouseholdData, by='hh_id', all.x = T)
  dt_person = dt_person[,.(hh_id, person_id, age, sex, type, TAZ, HHINC, AUTO_WORK, WT)]
  #age & sex
  dt_person$sex_age = 'NA'
  dt_person[dt_person$age<20 & dt_person$sex==1]$sex_age = 'Male < 20'
  dt_person[dt_person$age<20 & dt_person$sex==2]$sex_age = 'Female < 20'
  dt_person[dt_person$age %in% c(20:50) & dt_person$sex==1]$sex_age = 'Male 20-50'
  dt_person[dt_person$age %in% c(20:50) & dt_person$sex==2]$sex_age = 'Female 20-50'
  dt_person[dt_person$age>50 & dt_person$sex==1]$sex_age = 'Male > 50'
  dt_person[dt_person$age>50 & dt_person$sex==2]$sex_age = 'Female > 50'

  #ToursData
  dt_tours = ToursData[,.(hh_id, person_id, tour_id,tour_purp, tour_mode_cat, orig_taz, dest_taz, TourType)]
  dt_tours = merge(dt_tours, dt_person, by=c('hh_id','person_id'), all.x = TRUE)

  # Mode type
  # dt_tours$act_mode <- cut(dt_tours$tour_mode, breaks = c(0,6,8,18,21), label = c(1,2,3,1))

  # Match zones to MPOs:
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'TAZ', by.y='TAZ', all.x=T)
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'orig_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_O'))
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'dest_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_D'))

  # survey data has records with no home TAZ in MTC, fill that in
  dt_tours$MPO[is.na(dt_tours$MPO)] = 'MTC'

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
      subset = dt_tours[dt_tours$MPO == this_mpo]
      TourMode_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      TourMode_wt(go_down, dt_tours, scenario, 'ALL',  name_model, wbname, write2sheet)
    }
  }
  
}