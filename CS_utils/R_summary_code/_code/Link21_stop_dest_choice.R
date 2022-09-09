library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)

StopDest_wt <- function(go_down, dt_t, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  names_tours = c('Work','Work-based Subtour','School','Escort','Shop','Meal','Social','Other','All')
  
  for (i in 1:length(names_tours)) {
    
    origname = paste(paste(wbname, nm_set, sep="_"),'xlsx', sep = '.')
    outname = paste(paste(wbname, nm_set, names_tours[i],scenario, sep="_"),'xlsx', sep = '.')
    
    if (names_tours[i]=="All") { dt=dt_t } 
    else { dt= subset(dt_t, tour_purp==names_tours[i]) }

    dt$CUT_DIST=dt$DIST
    dt$CUT_TIME=dt$TIME
    dt$CUT_DIST[dt$DIST>=70] = 70
    dt$CUT_TIME[dt$TIME>=100] = 100

    dt$HT = ifelse(dt$inbound==0,'Outbound','Inbound')
    
    output_timedist = dt[,.(count=sum(WT,na.rm = TRUE)),.(CUT_DIST,CUT_TIME,HT)]
    output_timedist <- dcast(output_timedist, CUT_DIST+CUT_TIME~HT, value.var = 'count')
    
    output_grp = dt[,.(count=sum(WT,na.rm = TRUE), time=sum(WT*TIME,na.rm = TRUE), dist=sum(WT*DIST,na.rm = TRUE)),
                     .(type,HHINC,Z_TYPE_O,Z_TYPE_D,tour_purp, HT, TourType)]

    output_intra = dt[,.(intra=sum(WT*Intra.Zonal,na.rm = TRUE),count=sum(WT,na.rm = TRUE)), .(Z_TYPE_O,SIZE_O,HT)]
    output_intra_out <- output_intra[output_intra$HT=='Outbound',]
    output_intra_in <- output_intra[output_intra$HT=='Inbound',]
    output_intra <- merge(output_intra_out[,-c('HT')],output_intra_in[,-c('HT')],by=c('Z_TYPE_O','SIZE_O'),all=T)
    colnames(output_intra) <- c('Z_TYPE_O','SIZE_O','out_intra','out_count','in_intra','in_count')
    
    output_div =dt[,.(count=sum(WT, na.rm = TRUE), 
                      sum_sh=sum(WT*DIST_SH,na.rm = TRUE), sum_sp=sum(WT*DIST_SP,na.rm = TRUE), sum_hp=sum(WT*DIST_HP,na.rm = TRUE)), 
                   .(type,HHINC,Z_TYPE_D,tour_purp,HT)]
    
    if (go_down) {
      setwd("Survey_Populated")
      wb <- loadWorkbook(origname)
      setwd('..')
    }else{
      wb <- loadWorkbook(outname)
    }

    writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
    writeData(wb, sheet = sheetname, names_tours[i],startRow = 1, startCol = 3, colNames = T)
    writeData(wb, sheet = sheetname, output_timedist,startRow = 2, startCol = 1, colNames = T)
    writeData(wb, sheet = sheetname, output_grp,startRow = 2, startCol = 8, colNames = T)
    writeData(wb, sheet = sheetname, output_intra,startRow = 2, startCol = 21, colNames = T)
    writeData(wb, sheet = sheetname, output_div,startRow = 2, startCol = 31, colNames = T)
    
    saveWorkbook(wb,outname,overwrite = T)
    
  }
  
}


#################################################################
StopDest_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, 
                          PersonData, HouseholdData, ToursData, TripsData, Time_AM, Dist_AM, Time_OP, Dist_OP) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)
  # person and household - only need type, wt, income, taz
  dt_person = merge(PersonData, HouseholdData, by = 'hh_id', all.x = TRUE)

  # tours data
  dt_tours = ToursData[,.(hh_id, person_id,tour_id,start_hour,end_hour,TourType,tour_purp,dest_taz)]
  colnames(dt_tours)[8]='primary_taz'
  dt_tours = merge(dt_tours, dt_person, by=c('hh_id','person_id'), all.x=T)
  
  #trips data
  dt_trips = TripsData
  # Identify intermediate stops - exuclde half tour end trips
  # step1: Identify min and max stop_id for each tour's each half
  stop_num = dt_trips[,.(min_id=min(stop_id), max_id=max(stop_id)), by=.(hh_id,person_id,tour_id,inbound)]
  # if max and min stop_id are all -1, means no intermediate stops on that half tour
  # if min stop_id==0 and max_stop_id>=0, then intermediate stops are those with stop_id < max_stop_id
  dt_stops =merge(dt_trips, stop_num, by=c('hh_id','person_id','tour_id','inbound'))
  dt_stops =subset(dt_stops, max_id>-1 & stop_id<max_id)
  
  # merge tour/person level info to stops file
  dt_stops = merge(dt_stops, dt_tours, by=c('hh_id','person_id','tour_id'), all.x=T)

  # Distance and time - For now, only using AM time and EA Distance
  # we need four distances: o/d for hist
  # For each stop, we need the distance between stop and home; stop & primary destination; and home and primary destination
  ### OD - time and distance
  dt_stops = merge(dt_stops, Time_AM, by.x=c('trip_orig_taz','trip_dest_taz'), by.y=c('orig','dest'), all.x=T)
  dt_stops$TIME=floor(dt_stops$SOV_TIME__AM)
  dt_stops = merge(dt_stops, Dist_OP, by.x=c('trip_orig_taz','trip_dest_taz'), by.y=c('orig','dest'), all.x=T)
  dt_stops$DIST=floor(dt_stops$SOV_DIST__OP)
  dt_stops$SOV_TIME__AM=NULL
  dt_stops$SOV_DIST__OP=NULL
 
  ### stop to home distance
  dt_stops = merge(dt_stops, Dist_OP, by.x=c('trip_dest_taz','TAZ'), by.y=c('orig','dest'), all.x=T)
  dt_stops$DIST_SH=dt_stops$SOV_DIST__OP
  dt_stops$SOV_DIST__OP=NULL  
  ### stop to primary distance
  dt_stops = merge(dt_stops, Dist_OP, by.x=c('trip_dest_taz','primary_taz'), by.y=c('orig','dest'), all.x=T)
  dt_stops$DIST_SP=dt_stops$SOV_DIST__OP
  dt_stops$SOV_DIST__OP=NULL  
  ### home to primary distance
  dt_stops = merge(dt_stops, Dist_OP, by.x=c('TAZ','primary_taz'), by.y=c('orig','dest'), all.x=T)
  dt_stops$DIST_HP=dt_stops$SOV_DIST__OP
  dt_stops$SOV_DIST__OP=NULL 
  
  # Intra-zonal
  dt_stops$Intra.Zonal = (dt_stops$trip_orig_taz == dt_stops$trip_dest_taz)  

  # Match zones to MPOs: Need both Z_TYPE and COUNTY for O/D, only need MPO and size for home taz but will include Z_TYPE/CNTY so that_O suffix could work
  dt_stops = merge(dt_stops, zoneMPO, by.x='TAZ', by.y='TAZ',all.x=T, all.y= F)
  dt_stops = merge(dt_stops, zoneMPO, by.x = 'trip_orig_taz', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_O'))
  dt_stops = merge(dt_stops, zoneMPO, by.x = 'trip_dest_taz', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_D'))

  # survey data has records with no home TAZ in MTC, fill that in
  dt_stops$MPO[is.na(dt_stops$MPO)] = 'MTC'
  
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
      subset = dt_stops[dt_stops$MPO == this_mpo]
      StopDest_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      StopDest_wt(go_down, dt_stops, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
}