library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)


BigData_wt <- function(go_down,dt_trips, dt_tours, dt_person, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
  outname = paste(paste(wbname, nm_set, scenario, sep="_"),'xlsx', sep = '.')
  
  dt_person=subset(dt_person, worker==1)
  # output summaries  
  county_tot_tour <- dt_tours[,.(`Total Tours`=sum(WT,na.rm = TRUE)),.(CNTY_O,CNTY_D)]
  county_workplace <- dt_person[,.(`Workplace Location`=sum(WT,na.rm = TRUE)),.(CNTY_O,CNTY_D)]
  county_work_tour <- dt_tours[,.(`Work Tours`=sum(WT*worktour,na.rm = TRUE)),.(CNTY_O,CNTY_D)]  
  county_tot_trips <- dt_trips[,.(`Total Trips`=sum(WT,na.rm = TRUE)),.(CNTY_O,CNTY_D)]
  county_trn_trips <- dt_trips[,.(Total=sum(WT*trn,na.rm = TRUE),WT=sum(WT*trn_walk,na.rm = TRUE),
                                  PNR=sum(WT*trn_pnr,na.rm = TRUE), KNR=sum(WT*trn_knr,na.rm = TRUE)), .(CNTY_O,CNTY_D,dep_tod)]
  
  sd_tot_tour <- dt_tours[,.(`Total Tours`=sum(WT,na.rm = TRUE)),.(SD_O,SD_D)]
  sd_workplace <- dt_person[,.(`Workplace Location`=sum(WT,na.rm = TRUE)),.(SD_O,SD_D)]
  sd_work_tour <- dt_tours[,.(`Work Tours`=sum(WT*worktour,na.rm = TRUE)),.(SD_O,SD_D)] 
  sd_tot_trips <- dt_trips[,.(`Total Trips`=sum(WT,na.rm = TRUE)),.(SD_O,SD_D)]
  sd_trn_trips <- dt_trips[,.(Total=sum(WT*trn,na.rm = TRUE),WT=sum(WT*trn_walk,na.rm = TRUE),
                                  PNR=sum(WT*trn_pnr,na.rm = TRUE), KNR=sum(WT*trn_knr,na.rm = TRUE)), .(SD_O,SD_D,dep_tod)]
  
  county_trn_trips <-county_trn_trips[,.(CNTY_O, CNTY_D, Total, WT, PNR, KNR, dep_tod)]
  sd_trn_trips <- sd_trn_trips[,.(SD_O, SD_D, Total, WT, PNR, KNR, dep_tod)]
  
  if (go_down) {
    setwd("Survey_Populated")
    wb <- loadWorkbook(origname)
    setwd('..')
  }else{
    wb <- loadWorkbook(outname)
  }
    
  writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
  writeData(wb, sheet = sheetname, county_tot_tour,startRow = 2, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, county_workplace,startRow = 2, startCol = 5, colNames = T)
  writeData(wb, sheet = sheetname, county_work_tour,startRow = 2, startCol = 9, colNames = T)
  writeData(wb, sheet = sheetname, county_tot_trips,startRow = 2, startCol = 13, colNames = T)
  writeData(wb, sheet = sheetname, sd_tot_tour,startRow = 2, startCol = 17, colNames = T)
  writeData(wb, sheet = sheetname, sd_workplace,startRow = 2, startCol = 21, colNames = T)
  writeData(wb, sheet = sheetname, sd_work_tour,startRow = 2, startCol = 25, colNames = T)
  writeData(wb, sheet = sheetname, sd_tot_trips,startRow = 2, startCol = 29, colNames = T)
  writeData(wb, sheet = sheetname, county_trn_trips,startRow = 2, startCol = 34, colNames = T)  
  writeData(wb, sheet = sheetname, sd_trn_trips,startRow = 2, startCol = 43, colNames = T)
  
  saveWorkbook(wb,outname,overwrite = T)
  
}


#################################################################
BigData_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, ToursData, TripsData){
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)

  # person and household
  dt_person = merge(PersonData, HouseholdData, by = 'hh_id', all.x = TRUE)
  # Match zones to MPOs: Need both Z_TYPE and COUNTY/SD for O/D, only need MPO and size for home taz but will include Z_TYPE/CNTY so that suffix could work
  dt_person = merge(dt_person, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x=T, all.y= F)
  dt_person = merge(dt_person, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_O'))
  dt_person = merge(dt_person, zoneMPO, by.x = 'workplace_zone_id', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_D'))
  # indicator for Workplacelocation
  dt_person$worker = ifelse(dt_person$workplace_zone_id>0, 1, 0)
  #tours data
  dt_tours = ToursData[,.(hh_id,person_id,tour_id,tour_purp,orig_taz,dest_taz,TourType)]
  dt_tours = merge(dt_tours, dt_person[,c('hh_id','person_id','worker','TAZ','WT')], by=c('hh_id', 'person_id'), all.x = TRUE, all.y = FALSE)
  # Match zones to MPOs: ONLY NEED COUNTY/SD for O/D, only need MPO and size for home taz but will include Z_TYPE/CNTY so that suffix could work
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x=T, all.y= F)
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'orig_taz', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_O'))
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'dest_taz', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_D'))
  # survey data has records with no home TAZ in MTC, fill that in
  dt_tours$MPO[is.na(dt_tours$MPO)] = 'MTC'
  # indicator for work tours
  dt_tours$worktour=ifelse(dt_tours$tour_purp=='Work', 1, 0)
  
  #trip data
  dt_trips <- TripsData[,.(hh_id,person_id,tour_id,stop_id,trip_purp,trip_mode_cat,trip_orig_taz,trip_dest_taz,depart_hour)]
  dt_trips <- merge(dt_trips, dt_person[,c('hh_id','person_id','worker','TAZ','WT')], by=c('hh_id','person_id'), all.x=T)
  dt_trips$dep_tod = cut(dt_trips$depart_hour, breaks = c(0,5,9,14,18,23), labels = c('EA','AM','MD','PM','EV'))
  #transit trips
  dt_trips$trn_walk=ifelse(dt_trips$trip_mode_cat==4,1,0)
  dt_trips$trn_pnr=ifelse(dt_trips$trip_mode_cat==5,1,0)
  dt_trips$trn_knr=ifelse(dt_trips$trip_mode_cat==6,1,0)
  dt_trips$trn = dt_trips$trn_walk+dt_trips$trn_pnr+dt_trips$trn_knr
  # Match zones to MPOs:
  dt_trips = merge(dt_trips, zoneMPO, by.x = 'TAZ', by.y='TAZ', all.x=T)
  dt_trips = merge(dt_trips, zoneMPO, by.x = 'trip_orig_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_O'))
  dt_trips = merge(dt_trips, zoneMPO, by.x = 'trip_dest_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_D'))
  # survey data has records with no home TAZ in MTC, fill that in
  dt_trips$MPO[is.na(dt_trips$MPO)] = 'MTC'
  
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
      sub_trips = dt_trips[dt_trips$MPO== this_mpo,]
      sub_tours = dt_tours[dt_tours$MPO== this_mpo,]
      sub_person = dt_person[dt_person$MPO== this_mpo,]
      BigData_wt(go_down, sub_trips, sub_tours, sub_person, scenario, this_mpo, name_model, wbname, write2sheet)
    }

    if (mpo == 'ALL') {
      BigData_wt(go_down, dt_trips, dt_tours, dt_person, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
}