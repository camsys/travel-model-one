library(data.table)
library(rhdf5)
library(openxlsx)
library(reshape2)


TourDest_wt <- function(go_down, dt_t, scenario, nm_set, nm_model, wbname, sheetname){
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
    
    output_timedist = dt[,.(count=sum(WT,na.rm = TRUE)),.(CUT_DIST,CUT_TIME,TourType)]
    output_timedist <- dcast(output_timedist, CUT_DIST+CUT_TIME~TourType, value.var = 'count')
    
    output_grp = dt[,.(count=sum(WT,na.rm = TRUE), time=sum(WT*TIME,na.rm = TRUE), dist=sum(WT*DIST,na.rm = TRUE)),
                    .(type,HHINC,Z_TYPE_O,Z_TYPE_D,TourType)]

    output_intra = dt[,.(intra=sum(WT*(Intra.Zonal),na.rm = TRUE),count=sum(WT,na.rm = TRUE)), .(Z_TYPE_O,SIZE_O,TourType)]

    output_county = dt[,.(count=sum(WT,na.rm = TRUE)),.(CNTY_O,CNTY_D,TourType)]
    output_county = dcast(output_county, CNTY_O+CNTY_D~TourType,value.var='count')
    
    output_sd = dt[,.(count=sum(WT,na.rm = TRUE)),.(SD_O,SD_D,TourType)]
    output_sd = dcast(output_sd, SD_O+SD_D~TourType,value.var='count')
    
    if (go_down) {
      setwd("Template")
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
    
    saveWorkbook(wb,outname,overwrite = T)
  }
  
}


#################################################################
TourDest_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, 
                         zoneMPO, PersonData, HouseholdData, ToursData, Time_AM, Dist_AM) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)

  # person and household
  dt_person = merge(PersonData, HouseholdData, by = 'hh_id', all.x = TRUE)

  # tours data
  dt_tours = ToursData[,.(hh_id,person_id,tour_id,tour_purp,orig_taz,dest_taz,TourType)]
  dt_tours = merge(dt_tours, dt_person, by=c('hh_id', 'person_id'), all.x = TRUE, all.y = FALSE)
  
  # Distance and time:
  dt_tours = merge(dt_tours, Time_AM, by.x=c('orig_taz','dest_taz'), by.y=c('orig','dest'), all.x=T)
  dt_tours$TIME=floor(dt_tours$SOV_TIME__AM)
  dt_tours = merge(dt_tours, Dist_AM, by.x=c('orig_taz','dest_taz'), by.y=c('orig','dest'), all.x=T)
  dt_tours$DIST=floor(dt_tours$SOV_DIST__AM)
  dt_tours = dt_tours[,-c('SOV_TIME__AM','SOV_DIST__AM')]
  
  # Intra-zonal
  dt_tours$Intra.Zonal = (dt_tours$orig_taz == dt_tours$dest_taz)  

  # Match zones to MPOs: Need both Z_TYPE and COUNTY/SD for O/D, only need MPO and size for home taz but will include Z_TYPE/CNTY so that suffix could work
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'TAZ', by.y = 'TAZ', all.x=T, all.y= F)
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'orig_taz', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_O'))
  dt_tours = merge(dt_tours, zoneMPO, by.x = 'dest_taz', by.y = 'TAZ', all.x = T, all.y = F, suffixes = c('','_D'))

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
      TourDest_wt(go_down, subset, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      TourDest_wt(go_down, dt_tours, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
}

