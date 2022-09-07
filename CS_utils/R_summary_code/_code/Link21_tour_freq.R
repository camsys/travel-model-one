library(data.table)
library(rhdf5)
library(openxlsx)


TourFreq_wt <- function(go_down, dt_h, dt_p, scenario, nm_set, nm_model, wbname, sheetname){
  cat('    Writing table for',nm_set,'\n')
  
  origname = paste(paste(wbname, nm_set, sep='_'),'xlsx', sep = '.')
  outname = paste(paste(wbname, nm_set, scenario, sep='_'),'xlsx', sep = '.')
  
  if (go_down) {
    setwd("Template")
    wb <- loadWorkbook(origname)
    setwd('..')
  }else{
    wb <- loadWorkbook(outname)
  }
  
  #hh
  output_h1 = dt_h[,.(count = sum(WT,na.rm = TRUE), sum=sum(nindtours*WT,na.rm = T)), .(HHSIZE,HHINC,AUTO_WORK,NIndTours)]
  output_h2 = dt_h[,.(count = sum(WT,na.rm = TRUE), sum=sum(njottours*WT,na.rm = T)), .(HHSIZE,HHINC,AUTO_WORK,NJotTours)]
  #person
  output_p1  = dt_p[,.(count = sum(WT,na.rm = TRUE), sum=sum(Total*WT, na.rm = T)), .(type,HHINC,AUTO_WORK,Total)]
  output_p2  = dt_p[,.(count = sum(WT,na.rm = T), work=sum(Work*WT,na.rm = T),school=sum(School*WT,na.rm = T),escort=sum(Escort*WT,na.rm = T),shop=sum(Shop*WT,na.rm = T), 
                       meal=sum(Meal*WT,na.rm = T),social=sum(Social*WT,na.rm = T),other=sum(Other*WT,na.rm = T),sub=sum(`Work-based Subtour`*WT,na.rm = T)),
                    .(type,Work,School,Escort,Shop, Meal,Social,Other,`Work-based Subtour`)]

  writeData(wb, sheet = sheetname, nm_model,startRow = 1, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, nm_set,startRow = 1, startCol = 2, colNames = T)
  writeData(wb, sheet = sheetname, output_h1,startRow = 2, startCol = 1, colNames = T)
  writeData(wb, sheet = sheetname, output_h2,startRow = 2, startCol = 10, colNames = T)
  writeData(wb, sheet = sheetname, output_p1,startRow = 2, startCol = 20, colNames = T)
  writeData(wb, sheet = sheetname, output_p2,startRow = 2, startCol = 30, colNames = T)
  
  saveWorkbook(wb,outname,overwrite = T)
  
}


#################################################################
TourFreq_once <- function(go_down, wbname, write2sheet, delimiter, scenario, name_model, main_dir, zoneMPO, PersonData, HouseholdData, ToursData) {
  
  xlsxPath = paste(main_dir, wbname, sep = delimiter)
  name_model = name_model
  names_cat1 = c('No Indiv Tours', '1 Indiv Tour', '2 Indiv Tours', '3+ Indiv Tours')
  names_cat2 = c('No Joint Tours', '1 Joint Tour', '2 Joint Tours', '3+ Joint Tours')

  # tours data: household summary needs total num. of individual and joint tours; person summary needs n. of tours by tour purpose
  # first, need to split individual tours and joint tours, note that joint tours are duplicated by persons on that tour
  dt_tours=ToursData[,.(hh_id,person_id,tour_id,TourType,tour_purp,is.joint.tour,JTOUR_ID)]

  n_ind_tour = dt_tours[is.joint.tour==0, .(nindtours = .N), by= hh_id]
  n_jot_tour = dt_tours[, .(njottours = max(JTOUR_ID)), by= hh_id]
  
  dt_tours$hh_per=paste(dt_tours$hh_id,dt_tours$person_id,sep="-")
  n_per_tour = dcast.data.table(dt_tours, hh_per ~ tour_purp, fun.aggregate = length, value.var = 'hh_per')
  n_per_tour = n_per_tour[, Total := Work + School + Escort + Shop + Meal + Social + Other + `Work-based Subtour`]
  idsplit <- strsplit(n_per_tour$hh_per, '-')
  n_per_tour$hh_id <- as.integer(trimws(sapply(idsplit, function(x) x[1])))
  n_per_tour$person_id <- as.integer(trimws(sapply(idsplit, function(x) x[length(x)])))
  n_per_tour$hh_per = NULL
  rm(idsplit)
  
  # household level - need hhsize and income, sum number of indiv tours and num. of joint tours
  dt_household = merge(HouseholdData, n_ind_tour, by='hh_id', all.x=T)
  dt_household = merge(dt_household, n_jot_tour, by='hh_id', all.x=T)
  dt_household$nindtours[is.na(dt_household$nindtours)] = 0
  dt_household$njottours[is.na(dt_household$njottours)] = 0
  dt_household$NIndTours = cut(dt_household$nindtours, breaks = c(-1, 0, 1,2,100), labels = names_cat1, right = TRUE)
  dt_household$NJotTours = cut(dt_household$njottours, breaks = c(-1, 0, 1,2,100), labels = names_cat2, right = TRUE)

  # person and household 
  # use WT_LINK21 FOR SURVEY DATA
  dt_person = merge(PersonData, dt_household[,.(hh_id,HHINC,HHSIZE,AUTO_WORK,TAZ,WT_HH)], by='hh_id', all.x=T)
  
  if (name_model =='CHTS'){
    dt_person$WT = dt_person$WT_Link21
  } else{ }
  
  dt_person = merge(dt_person, n_per_tour, by=c('hh_id','person_id'), all.x=T)
  dt_person = dt_person[is.na(Total),`:=` (Work=0,School=0,`Work-based Subtour`=0,Escort=0,Shop=0,Social=0,Meal=0,Other=0,Total=0)]
  
  # Need to create a 'WT' field in Household for summaries
  dt_household$WT=dt_household$WT_HH
  
  # Match zones to MPOs:
  zoneMPO = zoneMPO[,c('TAZ','MPO')]
  dt_household = merge(dt_household, zoneMPO, by = 'TAZ', all.X = TRUE)
  dt_person = merge(dt_person, zoneMPO, by = 'TAZ', all.x = TRUE)
  
  # survey data has records with no home TAZ in MTC, fill that in
  dt_household$MPO[is.na(dt_household$MPO)] = 'MTC'
  dt_person$MPO[is.na(dt_person$MPO)] = 'MTC'
  
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
      subset_hh = dt_household[dt_household$MPO == this_mpo]
      subset_person = dt_person[dt_person$MPO == this_mpo]
      TourFreq_wt(go_down, subset_hh, subset_person, scenario, this_mpo, name_model, wbname, write2sheet)
    }
    if (mpo == 'ALL') {
      TourFreq_wt(go_down, dt_household, dt_person, scenario, 'ALL', name_model, wbname, write2sheet)
    }
  }
    
}