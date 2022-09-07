library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)


TripMode_wt <- function(go_down, dt_t, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  
  names_tours = c('Work','Work-based Subtour','School','Escort','Shop','Meal','Social','Other','All')
  
  for (i in 1:length(names_tours)) {
    origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
    outname = paste(paste(wbname, nm_set, names_tours[i],scenario, sep="_"),'xlsx', sep = '.')
    
    if (names_tours[i]=="All") { dt=dt_t } 
    else { dt= subset(dt_t, tour_purp==names_tours[i]) }
    
    dt$DIST[dt$DIST>=70] = 70
    dt$TIME[dt$TIME>=100] = 100
    
    dt$HT = ifelse(dt$inbound==0,'Outbound','Inbound')
    
    output_timedist = dt[,.(count=sum(WT,na.rm = TRUE)),.(DIST,TIME,TourType,act_mode)]
    output_timedist = output_timedist[order(output_timedist$TIME),]
    output_timedist = output_timedist[order(output_timedist$DIST),]
    output_timedist <- dcast(output_timedist, DIST+TIME+act_mode~TourType, value.var = 'count')
    
    output_hh = dt[,.(count=sum(WT,na.rm = TRUE)), .(HHINC,trip_mode_cat,AUTO_WORK,TourType)]
    output_hh <- dcast(output_hh,HHINC+trip_mode_cat+AUTO_WORK~TourType, value.var = 'count')
    
    output_pp = dt[,.(count=sum(WT,na.rm = TRUE)), .(type,trip_mode_cat,sex_age,TourType)]
    output_pp <- dcast(output_pp,type+trip_mode_cat+sex_age~TourType, value.var = 'count')
    
    output_z  = dt[,.(count=sum(WT,na.rm = TRUE)), .(Z_TYPE_O,Z_TYPE_D,trip_mode_cat,TourType)]
    output_z <- dcast(output_z,Z_TYPE_O+Z_TYPE_D+trip_mode_cat~TourType, value.var = 'count')
    
    output_mode <- dt[,.(count=sum(WT,na.rm = TRUE)),.(trip_mode_cat,tour_mode_cat,TourType)]
    output_dir <-dt[,.(count=sum(WT,na.rm = TRUE)),.(trip_mode_cat,HT,TourType)]

    if (go_down) {
      setwd("Template")
      wb <- loadWorkbook(origname)
      setwd('..')
    }else{
      wb <- loadWorkbook(outname)
    }

    writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
    writeData(wb, sheet = sheetname, names_tours[i], startRow = 1, startCol = 3, colNames = T)
    writeData(wb, sheet = sheetname, output_timedist,startRow = 2, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, output_hh,startRow = 2, startCol = 8, colNames = T)
    writeData(wb, sheet = sheetname, output_pp,startRow = 2, startCol = 15, colNames = T)
    writeData(wb, sheet = sheetname, output_z,startRow = 2, startCol = 21, colNames = T)
    writeData(wb, sheet = sheetname, output_mode,startRow = 2, startCol = 28, colNames = T)
    writeData(wb, sheet = sheetname, output_dir,startRow = 2, startCol = 33, colNames = T)
    
    saveWorkbook(wb,outname,overwrite = T)
    
  }
}  


#################################################################
TripMode_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, 
                          PersonData, HouseholdData, ToursData, TripsData, Time_AM, Dist_AM) {
  
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
  
  #trip data
  dt_trip <- merge(TripsData, ToursData, by=c('hh_id','person_id','tour_id'), all.x=T)
  dt_trip <- merge(dt_trip, dt_person, by=c('hh_id','person_id'), all.x=T)
  # Mode type
  dt_trip$act_mode <- cut(dt_trip$trip_mode_cat, breaks = c(-1,0,3,4, 6 ,8,9), label = c(0, 1, 2, 3, 4,1))
  # Distance and time:
  dt_trip = merge(dt_trip, Time_AM, by.x=c('trip_orig_taz','trip_dest_taz'), by.y=c('orig','dest'), all.x=T)
  dt_trip$TIME=floor(dt_trip$SOV_TIME__AM)
  dt_trip = merge(dt_trip, Dist_AM, by.x=c('trip_orig_taz','trip_dest_taz'), by.y=c('orig','dest'), all.x=T)
  dt_trip$DIST=floor(dt_trip$SOV_DIST__AM)
  dt_trip$SOV_TIME__AM=NULL
  dt_trip$SOV_DIST__AM=NULL
  
  # Match zones to MPOs:
  dt_trip = merge(dt_trip, zoneMPO, by.x = 'TAZ', by.y='TAZ', all.x=T)
  dt_trip = merge(dt_trip, zoneMPO, by.x = 'trip_orig_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_O'))
  dt_trip = merge(dt_trip, zoneMPO, by.x = 'trip_dest_taz', by.y = 'TAZ', all.x = TRUE, all.y = FALSE, suffixes = c('','_D'))
  #df_trip$Intra.Zonal = df_trip$Origin.Zone == df_trip$Destination.Zone
  
  # survey data has records with no home TAZ in MTC, fill that in
  dt_trip$MPO[is.na(dt_trip$MPO)] = 'MTC'
  
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
      subset = dt_trip[dt_trip$MPO == this_mpo,]
      TripMode_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      TripMode_wt(go_down, dt_trip, scenario, 'ALL',  name_model, wbname, write2sheet)
    }
  }
  
}