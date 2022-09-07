library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)

tod_wt <- function(go_down, dt_t, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  
  names_tours = c('Work','Work-based Subtour','School','Escort','Shop','Meal','Social','Other','All')

  for (subtype in c(names_tours)) {
    origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
    outname = paste(paste(wbname, nm_set, subtype, scenario, sep="_"),'xlsx', sep = '.')
    
    if (subtype=="All") { dt=dt_t } 
    else { dt= subset(dt_t, tour_purp==subtype) }

    #tod
    output_tod = dt[,.(count=sum(WT,na.rm = T)), .(start_hour, end_hour,TourType)]
    
    #hh
    output_hh = dt[,.(count = sum(WT, na.rm = T),time=sum(duration*WT,na.rm = T)), .(HHINC,AUTO_WORK,dep_tod, arr_tod,TourType)]
    output_pp = dt[,.(count = sum(WT, na.rm = T),time=sum(duration*WT,na.rm = T)), .(type,dep_tod,arr_tod,TourType)]
    #zone
    output_z  = dt[,.(count = sum(WT, na.rm = T),time=sum(duration*WT,na.rm = T)), .(Z_TYPE_O,Z_TYPE_D,dep_tod,arr_tod,TourType)]
    
    #duration
    output_dur = dt[,.(count = sum(WT, na.rm = T),time=sum(duration*WT,na.rm = T)), .(duration, TourType)]
    
    #tour type
    output_tour = dt[,.(count = sum(WT, na.rm = T),time=sum(duration*WT,na.rm = T)), .(dep_tod, arr_tod, tour_stop,TourType)]

    if (go_down) {
      setwd("Template")
      wb <- loadWorkbook(origname)
      setwd('..')
    }else{
      wb <- loadWorkbook(outname)
    }
    
    writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
    writeData(wb, sheet = sheetname, subtype,startRow = 1, startCol = 3, colNames = T)
    writeData(wb, sheet = sheetname, output_tod,startRow = 2, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, output_hh,startRow = 2, startCol = 11, colNames = T)
    writeData(wb, sheet = sheetname, output_pp,startRow = 2, startCol = 21, colNames = T)
    writeData(wb, sheet = sheetname, output_z,startRow = 2, startCol = 31, colNames = T)
    writeData(wb, sheet = sheetname, output_dur,startRow = 2, startCol = 41, colNames = T)
    writeData(wb, sheet = sheetname, output_tour,startRow = 2, startCol = 51, colNames = T)
    
    saveWorkbook(wb,outname,overwrite = T)
    
  }
}  


#################################################################
TourTOD_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, ToursData) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)

  #person/household data
  dt_person = merge(PersonData, HouseholdData, by='hh_id', all.x = T)
  dt_person = dt_person[,.(hh_id, person_id, type, Exact.Number.of.tours,TAZ, HHINC, AUTO_WORK, WT)]
  
  # tour data
  dt_tours=ToursData[,.(hh_id, person_id, tour_id,tour_purp, orig_taz, dest_taz,start_hour,end_hour,num.of.stops, TourType)]

  # identify tour type - found max_stops and add to person file
  max_stop = dt_tours[, .(max_stops=max(num.of.stops)), by=.(hh_id,person_id)]
  dt_person=merge(dt_person, max_stop, by=c('hh_id','person_id'), all.x=T)
  dt_person$max_stops[is.na(dt_person$max_stops)] = 0
  dt_person$tour_stop = 0
  dt_person[Exact.Number.of.tours==1 & max_stops==0,]$tour_stop = 1
  dt_person[Exact.Number.of.tours==1 & max_stops>0,]$tour_stop = 2
  dt_person[Exact.Number.of.tours>1 & max_stops==0,]$tour_stop = 3
  dt_person[Exact.Number.of.tours>1 & max_stops>0,]$tour_stop = 4

  #Tour TOD periods
  dt_tours$dep_tod = cut(dt_tours$start_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  dt_tours$arr_tod = cut(dt_tours$end_hour  , breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  
  #tour duration
  dt_tours$duration = ifelse(dt_tours$start_hour<=dt_tours$end_hour, dt_tours$end_hour-dt_tours$start_hour, dt_tours$end_hour-dt_tours$start_hour+24 )
  
  #merge with person data
  dt_tours = merge(dt_tours, dt_person, by=c('hh_id','person_id'), all.x=T)

  # Match zones to MPOs:
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x = TRUE, all.y = FALSE)
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'orig_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_O'))
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'dest_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_D'))
  
  # survey data has records with no home TAZ in MTC, fill that in
  dt_tours$MPO[is.na(dt_tours$MPO)] = 'MTC'
  
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
      subset = dt_tours[dt_tours$MPO == this_mpo,]
      tod_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      tod_wt(go_down, dt_tours, scenario, 'ALL',  name_model, wbname, write2sheet)
    }
  }
}
