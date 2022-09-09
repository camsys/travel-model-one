library(data.table)
library(rhdf5)
library(openxlsx)


stopfreq_wt <- function(go_down,dt_stops, dt_tours, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  
  origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
  outname = paste(paste(wbname, nm_set, scenario, sep="_"),'xlsx', sep = '.')

  # output summaries
  s_counts <- dt_stops[,.(stops=sum(WT,na.rm=T)), .(type, HHINC, AUTO_WORK, Mode, TourType, tour_purp)]
  t_counts <- dt_tours[,.(tours=sum(WT,na.rm=T)), .(type, HHINC, AUTO_WORK, Mode, TourType, tour_purp)]
  out_counts <- merge(s_counts, t_counts, by = c('type', 'HHINC', 'AUTO_WORK', 'Mode', 'TourType','tour_purp'), all.x = T, all.y = T)
  
  out_ht <- dt_stops[,.(stops=sum(WT,na.rm=T)),.(TourType,Outbound)]

  s_tod <- dt_stops[,.(stops_out=sum(WT[Outbound==1],na.rm=T),stops_in=sum(WT[Outbound==0],na.rm=T)), .(arr_tod, dep_tod, TourType)]
  t_tod <- dt_tours[,.(tours=sum(WT,na.rm=T)),.(arr_tod,dep_tod,TourType)]
  out_tod <- merge(s_tod, t_tod, by = c('arr_tod','dep_tod','TourType'), all.x = T, all.y = T)
  
  out_purp <- dt_stops[,.(stops=sum(WT,na.rm=T)), .(trip_purp, tour_purp, Mode, Outbound)]
  
  out_seq <- dt_stops[,.(stops=sum(WT,na.rm=T)),.(StopSeq, Outbound)]
  
  if (go_down) {
    setwd("Survey_Populated")
    wb <- loadWorkbook(origname)
    setwd('..')
  }else{
    wb <- loadWorkbook(outname)
  }
  
  writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
  writeData(wb, sheet = sheetname, out_counts,startRow = 2, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, out_ht,startRow = 2, startCol = 11, colNames = T)
  writeData(wb, sheet = sheetname, out_tod,startRow = 2, startCol = 17, colNames = T)
  writeData(wb, sheet = sheetname, out_purp,startRow = 2, startCol = 26, colNames = T)
  writeData(wb, sheet = sheetname, out_seq,startRow = 2, startCol = 34, colNames = T)
  
  saveWorkbook(wb,outname,overwrite = T)
  
}

#################################################################
StopFreq_once <- function(go_down,wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, ToursData, TripsData) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)

  # person and household data
  dt_person = merge(PersonData, HouseholdData, by = 'hh_id', all.x = TRUE)
  
  # TAZ Data - only need MPO
  dt_person = merge(dt_person, zoneMPO[,.(TAZ, MPO)], by = 'TAZ', all.x = TRUE)

  # ToursData 
  dt_tours = ToursData[,.(hh_id,person_id,tour_id,tour_purp,tour_mode_cat,TourType)]
  #tour mode
  dt_tours$Mode <- cut(dt_tours$tour_mode_cat, breaks = c(-1,0,1,2,3,4, 5,6, 8), 
                       labels = c('Other','DriveAlone','SharedRide2','SharedRide3P','WalkToTransit','PNR','KNR','Other'))
  
  dt_tours = merge(dt_tours, dt_person, by=c('hh_id','person_id'), all.x=T)

  # trips data
  dt_trips = TripsData
  #Identify intermediate stops and get tour arr_tod and dep_tod
  ### first, find min and max stop_id for each half tour 
  stop_num =dt_trips[,.(min_id=min(stop_id), max_id=max(stop_id)), by=.(hh_id,person_id,tour_id,inbound)]
  ### second, add in Stop Seq (1 to N) for Intermediate stops
  dt_stops =merge(dt_trips, stop_num, by=c('hh_id','person_id','tour_id','inbound'))
  dt_stops$StopSeq = ifelse(dt_stops$stop_id==-1, -1, ifelse(dt_stops$stop_id==dt_stops$max_id, -9, dt_stops$stop_id+1))
  ### last, get arr_tod and dep_tod 
  ### this needs to be done for all tours, include both with and w/o intermediate stops
  ### for those tours without intermediate stops, there exists the problem of all stops_id = -1
  ### min outbound and max inbound hour is calculated instead of directly using the first/last stop hour for those tours
  # ideally the outbound last trip arrival hour is needed; but we only have depart hour in JAVA model so use depart_hour
  ## use outbound last trip and inbound first trip time for those with intermediate stops
  arr_tod1 = subset(dt_stops[,.(hh_id,person_id,tour_id,StopSeq,inbound,depart_hour)], inbound==0 & StopSeq==-9)
  dep_tod1 = subset(dt_stops[,.(hh_id,person_id,tour_id,StopSeq,inbound,depart_hour)], inbound==1 & StopSeq==1)
  arr_tod1 =arr_tod1[,arr_hour:=depart_hour]; arr_tod1 =arr_tod1[,-c('depart_hour','StopSeq','inbound')]
  dep_tod1 =dep_tod1[,dep_hour:=depart_hour]; dep_tod1 =dep_tod1[,-c('depart_hour','StopSeq','inbound')]
  ## use max outbound and min inbound for those without intermediate stops
  arr_tod2 = dt_stops[inbound==0 & stop_id==-1,.(arr_hour=max(depart_hour,na.rm=T)),by=.(hh_id,person_id,tour_id)]
  dep_tod2 = dt_stops[inbound==1 & stop_id==-1,.(dep_hour=min(depart_hour,na.rm=T)),by=.(hh_id,person_id,tour_id)]
  arr_tod =rbind(arr_tod1, arr_tod2)
  dep_tod =rbind(dep_tod1, dep_tod2)
  arr_dep = merge(arr_tod, dep_tod, all.x=T, all.y=T)
  ### It is also noticed in data process that some tours are missing inbound info in the survey(mainly w-b subtours.set dep_hour=arr_hour for those)
  arr_dep =arr_dep[is.na(dep_hour), dep_hour:=arr_hour]
  
  ## assign periods
  arr_dep$arr_tod = cut(arr_tod$arr_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  arr_dep$dep_tod = cut(arr_dep$dep_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  arr_dep = arr_dep[,.(hh_id,person_id,tour_id,arr_tod, dep_tod)]

  # subset stops file to intermediate stops only
  dt_stops =subset(dt_stops, StopSeq>=0)
  # merge arr_tod & dep_tod
  dt_stops = merge(dt_stops, arr_dep,  by=c('hh_id','person_id','tour_id'), all.x=T)
  # merge person/tour level data into stops
  dt_stops = merge(dt_stops[,.(hh_id,person_id,tour_id,Outbound,StopSeq,trip_purp,arr_tod,dep_tod)], dt_tours, by=c('hh_id','person_id','tour_id'), all.x=T)

  # merge arr_tod & dep_tod to tours data
  dt_tours = merge(dt_tours, arr_dep,  by=c('hh_id','person_id','tour_id'), all.x=T)

  # survey data has records with no home TAZ in MTC, fill that in
  dt_stops$MPO[is.na(dt_stops$MPO)] = 'MTC'
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
      subset_stops <- dt_stops[dt_stops$MPO == this_mpo]
      subset_tours <- dt_tours[dt_tours$MPO == this_mpo]
      stopfreq_wt(go_down,subset_stops, subset_tours, scenario, this_mpo, name_model, wbname, write2sheet)
    }

    if (mpo == 'ALL') {
      stopfreq_wt(go_down,dt_stops, dt_tours, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
  
}
