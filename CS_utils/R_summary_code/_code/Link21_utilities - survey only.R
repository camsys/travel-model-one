# install.packages("data.table")
# source("https://bioconductor.org/biocLite.R")
# biocLite("rhdf5")
# install.packages('Rcpp')
# install.packages("openxlsx")
# install.packages("zoo")
# install.packages("reshape2")
library(data.table)
library(rhdf5)
library(openxlsx)
library(zoo)
library(reshape2)

survey_process <- function(PersonData_l, HouseholdData_l, zoneMPO_l, ToursData_l, TripsData_l) {

  names_cat0 = c("Full-time worker", "Part-time worker", "University student", "Non-worker", "Retired","Student of driving age", "Student of non-driving age", "Child too young for school")
  names_cat1 = c('LowIncome','MedIncome','HighIncome','VeryHighIncome')
  names_cat2 = c('1 Person','2 Person','3 Person','4 Person','5+ Person')
  names_cat2.2 = c('1 Person','2 Persons','3 Persons','4+ Persons')
  names_cat3 = c('0 vehicles',	'1 vehicle',	'2 vehicles',	'3 vehicles',	'4+ vehicles')
  names_cat4 = c('0 Drivers', '1 Driver', '2 Drivers', '3 Drivers', '4+ Drivers')
  names_cat5 = c('0 Workers', '1 Worker', '2 Workers', '3+ Workers')
  names_cat6 = c('Zero Auto','Auto < Worker','Auto = Worker','Auto > Worker')
  names_cat7 = c('RegionalCore','CBD','UrbanBusiness','Urban','Suburban','Rural') 
  names_cat8 = c('San Francisco','San Mateo','Santa Clara','Alameda','Contra Costa','Solano','Napa','Sonoma','Marin')
  
  # 1. household variables: TAZ, hhincome, hhsize, and Auto.Ownership, WT_HH
  # DRIVERS, WORKERS and AUTO_WORK are calculated from PersonData
  setnames(HouseholdData_l, old=c('HH_ID','HHWEIGHT_SUB'),new=c('hh_id','WT_HH'))
  HouseholdData_l$HHINC  = cut(HouseholdData_l$INCOM, breaks = c(-1e+100,4, 6, 8,1e+100), labels = names_cat1, right = FALSE) 
  HouseholdData_l$HHSIZE = cut(HouseholdData_l$HHSIZ, breaks = c(1,2,3,4,5,1e+100), labels = names_cat2, right = FALSE)
  HouseholdData_l$HHSIZE_AV = cut(HouseholdData_l$HHSIZ, breaks = c(1,2,3,4,1e+100), labels = names_cat2.2, right = FALSE)
  HouseholdData_l$Auto.Ownership = ifelse(HouseholdData_l$HHVEH>4, 4, HouseholdData_l$HHVEH)
  HouseholdData_l$HHAUTO = cut(HouseholdData_l$HHVEH, breaks = c(0, 1, 2, 3, 4, 1e+10), labels = names_cat3, include.lowest = TRUE, right = FALSE)

  HouseholdData_l = HouseholdData_l[,.(hh_id,TAZ,HHINC,HHVEH,HHSIZE,HHSIZE_AV,Auto.Ownership,HHAUTO,WT_HH)]
  # if running unweighted survey, uncomment the below lines
  HouseholdData_l$WT_HH =1
  
  # 2. Person variables
  # Exact.Number.of.tours & activity_pattern will be calculated later from tour file 
  setnames(PersonData_l, old=c('HH_ID','PER_ID','AGE','GEND','PERWEIGHT_SUB','TAZ','TAZ_S'), new=c('hh_id','person_id','age','sex','WT','workplace_zone_id','school_zone_id'))
  PersonData_l=merge(PersonData_l, HouseholdData_l[,.(hh_id, TAZ)], by='hh_id', all.x=T)
  setnames(PersonData_l, old='TAZ',new='home_zone_id')
  # PersonData_l$workplace_zone_id = as.integer(PersonData_l$TAZ1454)
  # PersonData_l$school_zone_id = as.integer(PersonData_l$TAZ1454_W)
  PersonData_l$workplace_zone_id[is.na(PersonData_l$workplace_zone_id)] = 0
  PersonData_l$school_zone_id[is.na(PersonData_l$school_zone_id)] = 0
  #2.1 type, RegularWorkExists, Work.Home, Home.School,fp_choice
  PersonData_l$type = factor(PersonData_l$PERSONTYPE, levels = 1:8, label=names_cat0)
  PersonData_l$Work.Home = (PersonData_l$home_zone_id == PersonData_l$workplace_zone_id & PersonData_l$workplace_zone_id!= 0)
  PersonData_l$RegularWorkExists = ifelse(PersonData_l$workplace_zone_id!=0,'True', 'False')
  PersonData_l$Home.School = ifelse(PersonData_l$home_zone_id==PersonData_l$school_zone_id & PersonData_l$school_zone_id!= 0,'True', 'False')
  ### No data available yet - set fp_choice = 0
  PersonData_l$fp_choice = 0
  #2.2 DRIVERS, WORKERS, AUTO_WORK
  PersonData_l=PersonData_l[,.(hh_id,person_id,age,sex,type,fp_choice,workplace_zone_id,school_zone_id,
                               RegularWorkExists, Work.Home, Home.School, WT)]#activity_pattern,Exact.Number.of.tours
  df_person = data.table(PersonData_l[,.(hh_id, person_id, type, age)])
  df_person = df_person[,nWorkers := sum(type %in% c('Full-time worker','Part-time worker')), by = hh_id]
  df_person = df_person[,nDrivers := sum(age>=16), by = hh_id]
  df_person$DRIVERS = cut(df_person$nDrivers, breaks = c(0, 1, 2, 3, 4, 1e+10), labels = names_cat4, include.lowest = TRUE, right = FALSE)
  df_person$WORKERS = cut(df_person$nWorkers, breaks = c(0, 1, 2, 3, 1e+10), labels = names_cat5, include.lowest = TRUE, right = FALSE)
  df_hh = df_person[!duplicated(df_person$hh_id),.(hh_id, DRIVERS, WORKERS, nWorkers)]
  #2.3 merge back to HouseholdData_l
  HouseholdData_l = merge(HouseholdData_l, df_hh, by='hh_id', all.x=T)
  HouseholdData_l$AutoWorker = 0
  HouseholdData_l$AutoWorker[which(HouseholdData_l$Auto.Ownership==0)] = 1
  HouseholdData_l$AutoWorker[which(HouseholdData_l$AutoWorker==0 & HouseholdData_l$Auto.Ownership< HouseholdData_l$nWorkers)] = 2
  HouseholdData_l$AutoWorker[which(HouseholdData_l$AutoWorker==0 & HouseholdData_l$Auto.Ownership==HouseholdData_l$nWorkers)] = 3
  HouseholdData_l$AutoWorker[which(HouseholdData_l$AutoWorker==0 & HouseholdData_l$Auto.Ownership> HouseholdData_l$nWorkers)] = 4
  HouseholdData_l$AUTO_WORK = factor(HouseholdData_l$AutoWorker, levels = 1:4, labels = names_cat6)  
  
  # if running unweighted survey, uncomment the below lines
  PersonData_l$WT =1

  #3.Tour Data
  setnames(ToursData_l, old=c('HH_ID','PER_ID','TOUR_ID','ANCHOR_DEPART_HOUR','ANCHOR_ARRIVE_HOUR','TAZ','TAZ_D'),
                        new=c('hh_id','person_id','tour_id','start_hour','end_hour','orig_taz','dest_taz'))
  # Start_hour and end_hour
  ToursData_l$start_hour = ifelse(ToursData_l$start_hour==24,ToursData_l$start_hour-1,ToursData_l$start_hour)
  ToursData_l$end_hour = ifelse(ToursData_l$end_hour==24,ToursData_l$end_hour-1,ToursData_l$end_hour)
  # tour purpose
  ToursData_l$tour_purp = 'Other'
  ToursData_l$tour_purp[which(ToursData_l$TOURPURP %in%c(1,10))] = 'Work'
  ToursData_l$tour_purp[which(ToursData_l$TOURPURP %in% c(2:3))] = 'School'
  ToursData_l$tour_purp[which(ToursData_l$TOURPURP ==4)] = 'Escort'
  ToursData_l$tour_purp[which(ToursData_l$TOURPURP ==5)] = 'Shop'
  ToursData_l$tour_purp[which(ToursData_l$TOURPURP ==7)] = 'Meal'
  ToursData_l$tour_purp[which(ToursData_l$TOURPURP ==8)] = 'Social'
  ToursData_l$tour_purp[which(ToursData_l$IS_SUBTOUR==1)] = 'Work-based Subtour'
  # Tour Mode
  ToursData_l$tour_mode_cat = 0
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==1)] = 1
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==2)] = 2
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==3)] = 3
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==6)] = 4
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==7)] = 5
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==8)] = 6
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==4)] = 7
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==5)] = 8
  ToursData_l$tour_mode_cat[which(ToursData_l$TOURMODE ==10)] = 9
  # TourType - We are only modeling closed tours, drop records with partial tour
  ToursData_l = subset(ToursData_l, PARTIAL_TOUR==0)
  ToursData_l$TourType = 'Closed'
  # is.joint.tour and num.of.stops
  ToursData_l$is.joint.tour=ifelse(ToursData_l$FULLY_JOINT==1, 1,0)
  ToursData_l$JTOUR_ID[is.na(ToursData_l$JTOUR_ID)] = 0
  ToursData_l$num.of.stops = ToursData_l$OUTBOUND_STOPS+ToursData_l$INBOUND_STOPS
  # activity_pattern
  ToursData_l$aptype=ifelse(ToursData_l$TOURPURP %in% c(1,2,3,10),'M','N')
  ToursData_l$hh_per=paste(ToursData_l$hh_id,ToursData_l$person_id,sep="-")
  n_per_tour = dcast.data.table(ToursData_l, hh_per ~ aptype, fun.aggregate = length, value.var = 'hh_per')
  n_per_tour$activity_pattern=ifelse(n_per_tour$M>0,'M','N')
  n_per_tour = n_per_tour[, Exact.Number.of.tours :=M+N]
  idsplit <- strsplit(n_per_tour$hh_per, '-')
  n_per_tour$hh_id <- as.integer(trimws(sapply(idsplit, function(x) x[1])))
  n_per_tour$person_id <- as.integer(trimws(sapply(idsplit, function(x) x[length(x)])))
  PersonData_l=merge(PersonData_l, n_per_tour[,.(hh_id, person_id,activity_pattern,Exact.Number.of.tours)],by=c('hh_id', 'person_id'),all.x=T)
  PersonData_l <- PersonData_l[is.na(Exact.Number.of.tours), Exact.Number.of.tours:=0]
  PersonData_l <- PersonData_l[is.na(activity_pattern), activity_pattern:='H']
  # LINK21_WEIGHT 
  PersonData_l$WT_Link21=ifelse(PersonData_l$activity_pattern=='H',PersonData_l$WT*0.76, 
                                ifelse(PersonData_l$activity_pattern=='M',PersonData_l$WT*1.05,PersonData_l$WT*1.09))
  
  ToursData_l = ToursData_l[,.(hh_id,person_id,tour_id,TourType,tour_mode_cat,tour_purp,orig_taz,dest_taz,start_hour,end_hour,
                               IS_SUBTOUR,is.joint.tour,JTOUR_ID,num.of.stops)]
  
  #4.Trip Data
  setnames(TripsData_l, old=c('HH_ID','PER_ID','TOUR_ID','IS_INBOUND','ORIG_DEP_HR','DEST_ARR_HR','TAZ','TAZ_D'),
                        new=c('hh_id','person_id','tour_id','inbound','depart_hour','arrival_hour','trip_orig_taz','trip_dest_taz'))
  # Start_hour and end_hour
  TripsData_l$depart_hour = ifelse(TripsData_l$depart_hour==24,TripsData_l$depart_hour-1,TripsData_l$depart_hour)
  TripsData_l$arrival_hour = ifelse(TripsData_l$arrival_hour==24,TripsData_l$arrival_hour-1,TripsData_l$arrival_hour)
  # Trip mode
  TripsData_l$trip_mode_cat = 0
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(1,2))] = 1
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(3,4))] = 2
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(5,6))] = 3
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(9:11,21:23))] = 4
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(12:14,31:33))] = 5
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(15:17,41:43))] = 6
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(7))] = 7
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(8))] = 8
  TripsData_l$trip_mode_cat[which(TripsData_l$TRIPMODE %in% c(19))] = 9
  # trip purpose
  # need to use ToursData's "IS_SUBTOUR" to identify worked-based subtour
  TripsData_l =merge (TripsData_l, ToursData_l[,.(hh_id,person_id,tour_id,IS_SUBTOUR)],by=c('hh_id','person_id','tour_id'), all.x=T)
  TripsData_l$trip_purp = 'Other'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP %in%c(1,10))] = 'Work'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP %in% c(2:3))] = 'School'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP ==4)] = 'Escort'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP ==5)] = 'Shop'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP ==7)] = 'Meal'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP ==8)] = 'Social'
  TripsData_l$trip_purp[which(TripsData_l$IS_SUBTOUR==1)] = 'AtWork'
  TripsData_l$trip_purp[which(TripsData_l$DEST_PURP ==0)] = 'Home'
  # create stop_id which is same as the JAVA Model
  half_tours = TripsData_l[,.(min_id=min(TRIP_ID), max_id=max(TRIP_ID)), by=.(hh_id,person_id,tour_id,inbound)]
  TripsData_l = merge(TripsData_l, half_tours, by=c('hh_id','person_id','tour_id','inbound'), all.x=T)
  TripsData_l$stop_id = ifelse(TripsData_l$min_id==TripsData_l$max_id,-1,TripsData_l$TRIP_ID-TripsData_l$min_id)
  # Outbound
  TripsData_l$Outbound = abs(1-TripsData_l$inbound)
  # also exclude trips on partical tours  
  TripsData_l = merge(TripsData_l, ToursData_l[,.(hh_id,person_id,tour_id)], by=c('hh_id','person_id','tour_id'), all.y=T)
  
  TripsData_l = TripsData_l[,.(hh_id, person_id, tour_id, stop_id, trip_mode_cat, trip_purp, trip_orig_taz, trip_dest_taz, depart_hour, inbound, Outbound)]
  
  zoneMPO_l$Z_TYPE = factor(zoneMPO_l$AREATYPE, levels = 0:5, label=names_cat7)
  zoneMPO_l$CNTY = factor(zoneMPO_l$COUNTY, levels = 1:9, label=names_cat8)
  zoneMPO_l$SIZE = floor(zoneMPO_l$size)
  zoneMPO_l$SIZE[zoneMPO_l$size<1] = 0.75
  zoneMPO_l$SIZE[zoneMPO_l$size<0.75] = 0.5
  zoneMPO_l$SIZE[zoneMPO_l$size<0.5] = 0.25
  zoneMPO_l$SIZE[zoneMPO_l$size<0.25] = 0
  zoneMPO_l$SIZE[zoneMPO_l$size>=5 & zoneMPO_l$size<10] = 5
  zoneMPO_l$SIZE[zoneMPO_l$size>=10 & zoneMPO_l$size<20] = 10
  zoneMPO_l$SIZE[zoneMPO_l$size >=20] = 20
  zoneMPO_l = zoneMPO_l[,.(TAZ, SD, CNTY, MPO, Z_TYPE, SIZE)]
  

  return(list(PersonData_l, HouseholdData_l, zoneMPO_l, ToursData_l, TripsData_l))
}

skim_process <- function(Dist_AM, Time_AM, Dist_OP, Time_OP){
  Dist_AM=Dist_AM[,.(orig,dest,da)]; setnames(Dist_AM, old='da', new='SOV_DIST__AM')
  Time_AM=Time_AM[,.(orig,dest,da)]; setnames(Time_AM, old='da', new='SOV_TIME__AM')
  Dist_OP=Dist_OP[,.(orig,dest,da)]; setnames(Dist_OP, old='da', new='SOV_DIST__OP')
  Time_OP=Time_OP[,.(orig,dest,da)]; setnames(Time_OP, old='da', new='SOV_TIME__OP')
  return(list(Dist_AM, Time_AM, Dist_OP, Time_OP))
}

read_files <- function() {

  # read left data if !skip_l
  if (!skip_l) {
    if (survey_l){
      setwd(skim_dir_l)
      Dist_AM_l <- fread(skim_am_dist_l)
      Time_AM_l <- fread(skim_am_time_l)
      Dist_OP_l <- fread(skim_op_dist_l)
      Time_OP_l <- fread(skim_op_time_l)
      temp_rt = skim_process(Dist_AM_l, Time_AM_l, Dist_OP_l, Time_OP_l)
      Dist_AM_l <<- as.data.table(temp_rt[1])
      Time_AM_l <<- as.data.table(temp_rt[2])
      Dist_OP_l <<- as.data.table(temp_rt[3])
      Time_OP_l <<- as.data.table(temp_rt[4])

      setwd(output_dir_l)
      PersonData_l <<- fread(out_person_l)
      HouseholdData_l <<- fread(out_hh_l)
      ToursData_l  <<- fread(out_tours_l)
      TripsData_l  <<- fread(out_stops_l)
      zoneMPO_l <<- fread(in_MPO_l)
      temp_rt = survey_process(PersonData_l, HouseholdData_l, zoneMPO_l, ToursData_l, TripsData_l)
      PersonData_l <<- as.data.table(temp_rt[1])
      HouseholdData_l <<- as.data.table(temp_rt[2])
      zoneMPO_l <<-as.data.table(temp_rt[3])
      ToursData_l <<- as.data.table(temp_rt[4])
      TripsData_l <<- as.data.table(temp_rt[5])
    } else{
      # if left side is not survey data
      setwd(skim_dir_l)
      Dist_AM_l <- fread(skim_am_dist_l)
      Time_AM_l <- fread(skim_am_time_l)
      Dist_OP_l <- fread(skim_op_dist_l)
      Time_OP_l <- fread(skim_op_time_l)
      temp_rt = skim_process(Dist_AM_l, Time_AM_l, Dist_OP_l, Time_OP_l)
      Dist_AM_l <<- as.data.table(temp_rt[1])
      Time_AM_l <<- as.data.table(temp_rt[2])
      Dist_OP_l <<- as.data.table(temp_rt[3])
      Time_OP_l <<- as.data.table(temp_rt[4])
      
      setwd(input_dir_l)
      persons_l    <- fread(in_person_l)
      households_l <- fread(in_hh_l)
      zoneMPO_l <- fread(in_MPO_l)
      
      setwd(output_dir_l)
      PersonData_l <- fread(out_person_l)
      HouseholdData_l <- fread(out_hh_l)
      ToursData_l  <- fread(out_tours_l)
      TripsData_l  <- fread(out_stops_l)
      
      temp_rt = model_process(model_version_l, model_run_weight_l, persons_l, households_l, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, TripsData_l)
      persons_l <<- as.data.table(temp_rt[1])
      households_l <<- as.data.table(temp_rt[2])
      zoneMPO_l <<- as.data.table(temp_rt[3])
      PersonData_l <<- as.data.table(temp_rt[4])
      HouseholdData_l <<- as.data.table(temp_rt[5])
      ToursData_l <<- as.data.table(temp_rt[6])
      TripsData_l <<- as.data.table(temp_rt[7])
    }
  } else {
  }
  
}

Vehicle_Avail <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    VehAvl_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, Time_AM_l, Dist_AM_l)
  } else {
    cat('Processing tables on the right...\n')
    VehAvl_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, Time_AM_r, Dist_AM_r)
  }
}

CDAP <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    CDAP_once(TRUE,wbname, 'LeftData', delimiter,  scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l)
  } else {
    cat('Processing tables on the right...\n')
    CDAP_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r)
  }
}

Tour_Freq_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourFreq_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l)
  } else {
    cat('Processing tables on the right...\n')
    TourFreq_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  }
}

Tour_Dest_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourDest_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, Time_AM_l, Dist_AM_l)
  } else {
    cat('Processing tables on the right...\n')
    TourDest_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, Time_AM_r, Dist_AM_r)
  }
}

Workplace_Location <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    WorkLoc_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, Time_AM_l, Dist_AM_l)
    cat('Processing tables on the right...\n')
    WorkLoc_once(FALSE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, Time_AM_r, Dist_AM_r)
  } else {
    cat('Processing tables on the right...\n')
    WorkLoc_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, Time_AM_r, Dist_AM_r)
  }
}

Tour_Mode_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourMode_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l)
  } else {
    cat('Processing tables on the right...\n')
    TourMode_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  }
}

Tour_TOD_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourTOD_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l)
  } else {
    cat('Processing tables on the right...\n')
    TourTOD_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  }
}

Stop_Freq_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    StopFreq_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, TripsData_l)
  } else {
    cat('Processing tables on the right...\n')
    StopFreq_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  }
}

Stop_Dest_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    StopDest_once(TRUE,wbname, 'LeftData', delimiter, scenario,  name_model_l, main_dir, zoneMPO_l,
                  PersonData_l, HouseholdData_l, ToursData_l, TripsData_l, Time_AM_l, Dist_AM_l, Time_OP_l, Dist_OP_l)
  } else {
    cat('Processing tables on the right...\n')
    StopDest_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, 
                  PersonData_r, HouseholdData_r, ToursData_r, TripsData_r, Time_AM_r, Dist_AM_r,Time_OP_r, Dist_OP_r)
  }
}

Trip_Mode_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TripMode_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, 
                  zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, TripsData_l, Time_AM_l, Dist_AM_l)
  } else {
    cat('Processing tables on the right...\n')
    TripMode_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, 
                  zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r, Time_AM_r, Dist_AM_r)
  }
}

Trip_TOD_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TripTOD_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, TripsData_l)
  } else {
    cat('Processing tables on the right...\n')
    TripTOD_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  }
}

