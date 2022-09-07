library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)

triptod_wt <- function(go_down, dt_t, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')

  names_tours = c('Work','Work-based Subtour','School','Escort','Shop','Meal','Social','Other','All')
    
  for (subtype in c(names_tours)) {
    origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
    outname = paste(paste(wbname, nm_set, subtype, scenario, sep="_"),'xlsx', sep = '.')
      
    if (subtype=="All") { dt=dt_t } 
    else { dt= subset(dt_t, tour_purp==subtype) }

    #tod
    output_tod = dt[,.(count = sum(WT,na.rm = TRUE)), .(depart_hour,arr_hour,TourType)]

    #hh
    output_hh = dt[,.(count = sum(WT,na.rm = TRUE),time=sum(duration*WT,na.rm = T)), .(HHINC,AUTO_WORK,arr_tod,dep_tod,TourType)]
    output_pp = dt[,.(count = sum(WT,na.rm = TRUE),time=sum(duration*WT,na.rm = T)), .(type,arr_tod,dep_tod,TourType)]
    #zone
    output_z  = dt[,.(count = sum(WT,na.rm = TRUE),time=sum(duration*WT,na.rm = T)), .(Z_TYPE_O,Z_TYPE_D,arr_tod,dep_tod,TourType)]
    
    #duration
    output_dur = dt[,.(count = sum(WT,na.rm = TRUE),time=sum(duration*WT,na.rm = T)), .(duration, TourType)]
    
    #tod
    output_tod2 = dt[,.(count = sum(WT,na.rm = TRUE), time=sum(duration*WT,na.rm = T)), .(purp_tod,arr_tod, dep_tod, arr_tod_t, dep_tod_t,Outbound)]
    
    #purpose
    output_purp = dt[,.(count = sum(WT,na.rm = TRUE),time=sum(duration*WT,na.rm = T)), .(arr_tod, dep_tod, trip_purp, trip_mode_cat)]
    
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
    writeData(wb, sheet = sheetname, output_z,startRow = 2, startCol = 32, colNames = T)
    writeData(wb, sheet = sheetname, output_dur,startRow = 2, startCol = 41, colNames = T)
    writeData(wb, sheet = sheetname, output_tod2,startRow = 2, startCol = 51, colNames = T)
    writeData(wb, sheet = sheetname, output_purp,startRow = 2, startCol = 61, colNames = T)

    saveWorkbook(wb,outname,overwrite = T)
    
  }
}  


#################################################################
TripTOD_once <- function(go_down, wbname, write2sheet, delimiter,scenario,name_model,main_dir, zoneMPO,PersonData, HouseholdData, ToursData, TripsData) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)
  
  #person/household data
  dt_person = merge(PersonData, HouseholdData, by='hh_id', all.x = T)
  dt_person = dt_person[,.(hh_id, person_id, type, TAZ, HHINC, AUTO_WORK, WT)]
  
  #tour/trip data
  dt_trips <- merge(TripsData, ToursData, by=c('hh_id','person_id','tour_id'), all.x=T)
  dt_trips <- merge(dt_trips, dt_person, by=c('hh_id','person_id'), all.x=T)
  
  #Tour TOD periods
  dt_trips$dep_tod_t = cut(dt_trips$start_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  dt_trips$arr_tod_t = cut(dt_trips$end_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  #Trip type
  dt_trips$purp_tod = 'NonWork'
  dt_trips = dt_trips[trip_purp %in% c('Work','AtWork'), purp_tod:=trip_purp]

  #Trip Departure hour
  dt_trips$arr_hour = NA
  dt_trips$arr_tod = NA
  dt_trips$dep_tod = cut(dt_trips$depart_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))

  #tour duration
  dt_trips$duration = dt_trips$end_hour - dt_trips$start_hour
  dt_trips$duration = ifelse(dt_trips$duration<0, dt_trips$duration+24, dt_trips$duration )

  # Match zones to MPOs:
  dt_trips = merge(dt_trips, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x = TRUE, all.y = FALSE)
  dt_trips = merge(dt_trips, zoneMPO, by.x = 'trip_orig_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_O'))
  dt_trips = merge(dt_trips, zoneMPO, by.x = 'trip_dest_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_D'))
  
  # survey data has records with no home TAZ in MTC, fill that in
  dt_trips$MPO[is.na(dt_trips$MPO)] = 'MTC'
  
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
      subset = dt_trips[dt_trips$MPO == this_mpo,]
      triptod_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      triptod_wt(go_down, dt_trips, scenario, 'ALL',  name_model, wbname, write2sheet)
    }
  }
  
}
