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
library(omxr)

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
  
  #3.Tour Data
  setnames(ToursData_l, old=c('HH_ID','PER_ID','TOUR_ID','ANCHOR_DEPART_HOUR','ANCHOR_ARRIVE_HOUR','TAZ','TAZ_D'),
                        new=c('hh_id','person_id','tour_id','start_hour','end_hour','orig_taz','dest_taz'))
  # Start_hour and end_hour
  ToursData_l = ToursData_l[,`:=`(start_hour=start_hour -1, end_hour =end_hour-1)]
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
  TripsData_l = TripsData_l[,`:=`(depart_hour=depart_hour -1, arrival_hour =arrival_hour-1)]
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

model_process <- function(model_version_r, model_run_weight_r, persons_r, households_r, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r) {
  
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
  # DRIVERS, WORKERS and AUTO_WORK are calculated from PersonData_r
  HouseholdData_r$HHINC  = cut(HouseholdData_r$income, breaks = c(-1e+100,30000,60000,100000,1e+100), labels = names_cat1, right = FALSE) 
  HouseholdData_r$HHSIZE = cut(HouseholdData_r$hhsize, breaks = c(1,2,3,4,5,1e+100), labels = names_cat2, right = FALSE)
  HouseholdData_r$HHSIZE_AV = cut(HouseholdData_r$hhsize, breaks = c(1,2,3,4,1e+100), labels = names_cat2.2, right = FALSE)
  HouseholdData_r$HHAUTO = cut(HouseholdData_r$Auto.Ownership, breaks = c(0, 1, 2, 3, 4, 1e+10), labels = names_cat3, include.lowest = TRUE, right = FALSE)
  HouseholdData_r$WT_HH = model_run_weight_r
  HouseholdData_r = HouseholdData_r[,.(hh_id,TAZ,HHINC,HHSIZE,HHSIZE_AV,Auto.Ownership,HHAUTO,WT_HH)]
  
  # 2. Person variables: need sex from persons_r - It is later realized that survey always uses person weight. So need to include WT here to be consistent.
  PersonData_r$WT = model_run_weight_r
  PersonData_r=merge(PersonData_r, persons_r[,.(person_id,sex)], by='person_id',all.x=T)
  #2.1 RegularWorkExists, Work.Home, Home.School, and Exact.Number.of.tours
  PersonData_r$Work.Home = (PersonData_r$home_zone_id == PersonData_r$workplace_zone_id & PersonData_r$workplace_zone_id!= 0)
  PersonData_r$RegularWorkExists = ifelse(PersonData_r$workplace_zone_id!=0,'True', 'False')
  PersonData_r$Home.School = ifelse(PersonData_r$home_zone_id==PersonData_r$school_zone_id & PersonData_r$school_zone_id!= 0,'True', 'False')
  ### Exact.Number.of.tours is calculated in the pro-process utilities for the JAVA model  
  #2.2 DRIVERS, WORKERS, AUTO_WORK
  PersonData_r=PersonData_r[,.(hh_id,person_id,age,sex,type,fp_choice,activity_pattern,workplace_zone_id,school_zone_id,
                               RegularWorkExists, Work.Home, Home.School, Exact.Number.of.tours, WT)]
  df_person = data.table(PersonData_r[,.(hh_id, person_id, type, age)])
  df_person = df_person[,nWorkers := sum(type %in% c('Full-time worker','Part-time worker')), by = hh_id]
  df_person = df_person[,nDrivers := sum(age>=16), by = hh_id]
  df_person$DRIVERS = cut(df_person$nDrivers, breaks = c(0, 1, 2, 3, 4, 1e+10), labels = names_cat4, include.lowest = TRUE, right = FALSE)
  df_person$WORKERS = cut(df_person$nWorkers, breaks = c(0, 1, 2, 3, 1e+10), labels = names_cat5, include.lowest = TRUE, right = FALSE)
  df_hh = df_person[!duplicated(df_person$hh_id),.(hh_id, DRIVERS, WORKERS, nWorkers)]
  #2.3 merge back to HouseholdData_r
  HouseholdData_r = merge(HouseholdData_r, df_hh, by='hh_id', all.x=T)
  HouseholdData_r$AutoWorker = 0
  HouseholdData_r$AutoWorker[which(HouseholdData_r$Auto.Ownership==0)] = 1
  HouseholdData_r$AutoWorker[which(HouseholdData_r$AutoWorker==0 & HouseholdData_r$Auto.Ownership< HouseholdData_r$nWorkers)] = 2
  HouseholdData_r$AutoWorker[which(HouseholdData_r$AutoWorker==0 & HouseholdData_r$Auto.Ownership==HouseholdData_r$nWorkers)] = 3
  HouseholdData_r$AutoWorker[which(HouseholdData_r$AutoWorker==0 & HouseholdData_r$Auto.Ownership> HouseholdData_r$nWorkers)] = 4
  HouseholdData_r$AUTO_WORK = factor(HouseholdData_r$AutoWorker, levels = 1:4, labels = names_cat6)
  
  # 3.TAZ Data 
  zoneMPO_r$Z_TYPE = factor(zoneMPO_r$AREATYPE, levels = 0:5, label=names_cat7)
  zoneMPO_r$CNTY = factor(zoneMPO_r$COUNTY, levels = 1:9, label=names_cat8)
  zoneMPO_r$SIZE = floor(zoneMPO_r$size)
  zoneMPO_r$SIZE[zoneMPO_r$size<1] = 0.75
  zoneMPO_r$SIZE[zoneMPO_r$size<0.75] = 0.5
  zoneMPO_r$SIZE[zoneMPO_r$size<0.5] = 0.25
  zoneMPO_r$SIZE[zoneMPO_r$size<0.25] = 0
  zoneMPO_r$SIZE[zoneMPO_r$size>=5 & zoneMPO_r$size<10] = 5
  zoneMPO_r$SIZE[zoneMPO_r$size>=10 & zoneMPO_r$size<20] = 10
  zoneMPO_r$SIZE[zoneMPO_r$size >=20] = 20
  zoneMPO_r = zoneMPO_r[,.(TAZ, SD, CNTY, MPO, Z_TYPE, SIZE)]
  
  #4.Tour Data
  # tour purpose
  ToursData_r$tour_purp = 'Other'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose %in% c('work_low','work_med','work_high','work_very high'))] = 'Work'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose %in% c('atwork_business','atwork_eat','atwork_maint'))] = 'Work-based Subtour'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose %in% c('school_grade','school_high','university'))] = 'School'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose %in% c('escort_kids','escort_no kids'))] = 'Escort'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose =='shopping')] = 'Shop'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose =='eatout')] = 'Meal'
  ToursData_r$tour_purp[which(ToursData_r$tour_purpose =='social')] = 'Social'
  # Tour Mode
  if (model_version_r =='TM1.5'){
    ToursData_r$tour_mode_cat=0
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode %in% c(1,2))] = 1
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode %in% c(3,4))] = 2
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode %in% c(5,6))] = 3
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode %in% c(9:13))] = 4
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode %in% c(14:18))] = 5
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==7)] = 7
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==8)] = 8
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode %in% c(19:21))] = 9    
  } else{
    ToursData_r$tour_mode_cat=0
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==1)] = 1
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==2)] = 2
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==3)] = 3
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==6)] = 4
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==7)] = 5
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==8)] = 6
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==4)] = 7
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==5)] = 8
    ToursData_r$tour_mode_cat[which(ToursData_r$tour_mode ==9)] = 9  
  }

  # is.joint.tour and num.of.stops
  ToursData_r$is.joint.tour=ifelse(ToursData_r$tour_category=='JOINT_NON_MANDATORY', 1, 0)
  ToursData_r$num.of.stops = ToursData_r$num_ob_stops+ToursData_r$num_ib_stops
  ToursData_r = ToursData_r[,.(hh_id,person_id,tour_id,TourType, tour_mode_cat, tour_purp,orig_taz,dest_taz,start_hour,end_hour,
                               is.joint.tour,JTOUR_ID,num.of.stops)]
    
  #5.Trip Data
  setnames(TripsData_r, old=c('orig_taz','dest_taz'), new=c('trip_orig_taz','trip_dest_taz'))
  # Trip Mode
  if (model_version_r == 'TM1.5'){
    TripsData_r$trip_mode_cat= 0
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode %in% c(1,2))] = 1
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode %in% c(3,4))] = 2
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode %in% c(5,6))] = 3
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode %in% c(9:13))] = 4
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode %in% c(14:18))] = 5
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==7)] = 7
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==8)] = 8
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode %in% c(19:21))] = 9
  } else{
    TripsData_r$trip_mode_cat=0
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==1)] = 1
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==2)] = 2
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==3)] = 3
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==6)] = 4
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==7)] = 5
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==8)] = 6
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==4)] = 7
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==5)] = 8
    TripsData_r$trip_mode_cat[which(TripsData_r$trip_mode ==9)] = 9  
}
  #Trip Purpose
  TripsData_r$trip_purp = 'Other'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose %in% c('work','Work'))] = 'Work'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose=='atwork')] = 'AtWork'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose %in% c('school','University'))] = 'School'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose =='escort')] = 'Escort'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose =='shopping')] = 'Shop'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose =='eatout')] = 'Meal'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose =='social')] = 'Social'
  TripsData_r$trip_purp[which(TripsData_r$dest_purpose =='Home')] = 'Home'
  TripsData_r$Outbound = abs(1-TripsData_r$inbound)
  TripsData_r = TripsData_r[,.(hh_id, person_id, tour_id, stop_id, trip_mode_cat, trip_purp, trip_orig_taz, trip_dest_taz, depart_hour, inbound, Outbound)]
  
  return(list(persons_r, households_r, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r,TripsData_r))
}

skim_process_omx <- function(Dist_AM, Time_AM, Dist_OP, Time_OP){
  rownames(Time_AM)=1:nrow(Time_AM); colnames(Time_AM)=1:ncol(Time_AM); Time_AM <- as.data.table(as.table(Time_AM));colnames(Time_AM)=c("orig","dest","SOV_TIME__AM")
  rownames(Dist_AM)=1:nrow(Dist_AM); colnames(Dist_AM)=1:ncol(Dist_AM); Dist_AM <- as.data.table(as.table(Dist_AM));colnames(Dist_AM)=c("orig","dest","SOV_DIST__AM")
  rownames(Time_OP)=1:nrow(Time_OP); colnames(Time_OP)=1:ncol(Time_OP); Time_OP <- as.data.table(as.table(Time_OP));colnames(Time_OP)=c("orig","dest","SOV_TIME__OP")
  rownames(Dist_OP)=1:nrow(Dist_OP); colnames(Dist_OP)=1:ncol(Dist_OP); Dist_OP <- as.data.table(as.table(Dist_OP));colnames(Dist_OP)=c("orig","dest","SOV_DIST__OP")
  Time_AM$orig=as.integer(Time_AM$orig); Time_AM$dest=as.integer(Time_AM$dest)
  Dist_AM$orig=as.integer(Dist_AM$orig); Dist_AM$dest=as.integer(Dist_AM$dest)
  Time_OP$orig=as.integer(Time_OP$orig); Time_OP$dest=as.integer(Time_OP$dest)
  Dist_OP$orig=as.integer(Dist_OP$orig); Dist_OP$dest=as.integer(Dist_OP$dest)
  
  return(list(Dist_AM, Time_AM, Dist_OP, Time_OP))
}

skim_process_csv <- function(Dist_AM, Time_AM, Dist_OP, Time_OP){
  Dist_AM=Dist_AM[,.(orig,dest,da)]; setnames(Dist_AM, old='da', new='SOV_DIST__AM')
  Time_AM=Time_AM[,.(orig,dest,da)]; setnames(Time_AM, old='da', new='SOV_TIME__AM')
  Dist_OP=Dist_OP[,.(orig,dest,da)]; setnames(Dist_OP, old='da', new='SOV_DIST__OP')
  Time_OP=Time_OP[,.(orig,dest,da)]; setnames(Time_OP, old='da', new='SOV_TIME__OP')
  return(list(Dist_AM, Time_AM, Dist_OP, Time_OP))
}

get_model_weight <- function(output_dir, out_stops){
  setwd(output_dir)
  trip_first_row  <- fread(out_stops, nrows=1)
  return(1/trip_first_row$sample_rate)
}

read_files <- function() {

  # always read right data - will not be survey data
  # right side skim
  setwd(skim_dir_r)
  Dist_AM_r <- read_omx(skim_am_r, name ='DISTDA')
  Time_AM_r <- read_omx(skim_am_r, name ='TIMEDA')
  Dist_OP_r <- read_omx(skim_op_r, name ='DISTDA')
  Time_OP_r <- read_omx(skim_op_r, name ='TIMEDA')
  temp_rt = skim_process_omx(Dist_AM_r, Time_AM_r, Dist_OP_r, Time_OP_r)
  Dist_AM_r <<- as.data.table(temp_rt[1])
  Time_AM_r <<- as.data.table(temp_rt[2])
  Dist_OP_r <<- as.data.table(temp_rt[3])
  Time_OP_r <<- as.data.table(temp_rt[4])
  
  # right side inputs
  setwd(input_dir_r)
  persons_r    <- fread(in_person_r)
  households_r <- fread(in_hh_r)
  zoneMPO_r <- fread(in_MPO_r)

  # right side outputs
  setwd(output_dir_r)
  PersonData_r <- fread(out_person_r)
  HouseholdData_r <- fread(out_hh_r)
  ToursData_r  <- fread(out_tours_r)
  TripsData_r  <- fread(out_stops_r)

  temp_rt = model_process(model_version_r, model_run_weight_r, persons_r, households_r, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  persons_r <<- as.data.table(temp_rt[1])
  households_r <<- as.data.table(temp_rt[2])
  zoneMPO_r <<- as.data.table(temp_rt[3])
  PersonData_r <<- as.data.table(temp_rt[4])
  HouseholdData_r <<- as.data.table(temp_rt[5])
  ToursData_r <<- as.data.table(temp_rt[6])
  TripsData_r <<- as.data.table(temp_rt[7])

  
  # read left data if !skip_l
  if (!skip_l) {
    # first process skim - place holder for csv vs. omx format of skims processing, could be removed later if TM1.5 omx is available
    # left side skims size may be different from the right side    
  	setwd(skim_dir_l)
	  if (skim_left=="omx"){
	    Dist_AM_l <- read_omx(skim_am_r, name ='DISTDA')
      Time_AM_l <- read_omx(skim_am_r, name ='TIMEDA')
      Dist_OP_l <- read_omx(skim_op_r, name ='DISTDA')
      Time_OP_l <- read_omx(skim_op_r, name ='TIMEDA')
      temp_rt = skim_process_omx(Dist_AM_l, Time_AM_l, Dist_OP_l, Time_OP_l)
      Dist_AM_r <<- as.data.table(temp_rt[1])
      Time_AM_r <<- as.data.table(temp_rt[2])
      Dist_OP_r <<- as.data.table(temp_rt[3])
      Time_OP_r <<- as.data.table(temp_rt[4])
	  }else{
      Dist_AM_l <- fread(skim_am_dist_l)
      Time_AM_l <- fread(skim_am_time_l)
      Dist_OP_l <- fread(skim_op_dist_l)
      Time_OP_l <- fread(skim_op_time_l)
      temp_rt = skim_process_csv(Dist_AM_l, Time_AM_l, Dist_OP_l, Time_OP_l)
      Dist_AM_l <<- as.data.table(temp_rt[1])
      Time_AM_l <<- as.data.table(temp_rt[2])
      Dist_OP_l <<- as.data.table(temp_rt[3])
      Time_OP_l <<- as.data.table(temp_rt[4])      
	  }
	
	  # then read in input and output files
    if (survey_l){
      # if left side is survey data
      setwd(output_dir_l)
      PersonData_l <<- fread(out_person_l)
      HouseholdData_l <<- fread(out_hh_l)
      ToursData_l  <<- fread(out_tours_l)
      TripsData_l  <<- fread(out_stops_l)
      zoneMPO_l <<- fread(zone_MPO_l)
      temp_rt = survey_process(PersonData_l, HouseholdData_l, zoneMPO_l, ToursData_l, TripsData_l)
      PersonData_l <<- as.data.table(temp_rt[1])
      HouseholdData_l <<- as.data.table(temp_rt[2])
      zoneMPO_l <<-as.data.table(temp_rt[3])
      ToursData_l <<- as.data.table(temp_rt[4])
      TripsData_l <<- as.data.table(temp_rt[5])
    }else{
	  # if left side is model data
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
  }else{
  }
  
}

Vehicle_Avail <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    VehAvl_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, Time_AM_l, Dist_AM_l)
    cat('Processing tables on the right...\n')
    VehAvl_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, Time_AM_r, Dist_AM_r)
  } else {
    cat('Processing tables on the right...\n')
    VehAvl_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, Time_AM_r, Dist_AM_r)
  }
}

CDAP <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    CDAP_once(TRUE,wbname, 'LeftData', delimiter,  scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l)
    cat('Processing tables on the right...\n')
    CDAP_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r)
  } else {
    cat('Processing tables on the right...\n')
    CDAP_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r)
  }
}

Tour_Freq_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourFreq_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l)
    cat('Processing tables on the right...\n')
    TourFreq_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  } else {
    cat('Processing tables on the right...\n')
    TourFreq_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  }
}

Tour_Dest_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourDest_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, Time_AM_l, Dist_AM_l)
    cat('Processing tables on the right...\n')
    TourDest_once(FALSE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, Time_AM_r, Dist_AM_r)
  } else {
    cat('Processing tables on the right...\n')
    TourDest_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, Time_AM_r, Dist_AM_r)
  }
}

Tour_Mode_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourMode_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l)
    cat('Processing tables on the right...\n')
    TourMode_once(FALSE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  } else {
    cat('Processing tables on the right...\n')
    TourMode_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  }
}

Tour_TOD_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    TourTOD_once(TRUE,wbname,'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l)
    cat('Processing tables on the right...\n')
    TourTOD_once(FALSE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  } else {
    cat('Processing tables on the right...\n')
    TourTOD_once(TRUE,wbname,'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r)
  }
}

Stop_Freq_Choice <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    StopFreq_once(TRUE,wbname, 'LeftData', delimiter, scenario, name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, TripsData_l)
    
    cat('Processing tables on the right...\n')
    StopFreq_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
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
    cat('Processing tables on the right...\n')
    StopDest_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, 
                  PersonData_r, HouseholdData_r, ToursData_r, TripsData_r, Time_AM_r, Dist_AM_r, Time_OP_r, Dist_OP_r)
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
    cat('Processing tables on the right...\n')
    TripMode_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, 
                  zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r, Time_AM_r, Dist_AM_r)
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
    cat('Processing tables on the right...\n')
    TripTOD_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  } else {
    cat('Processing tables on the right...\n')
    TripTOD_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  }
}

Dest_Choice_BigData <- function(wbname){
  if (!skip_l) {
    cat('Processing tables on the left...\n')
    BigData_once(TRUE,wbname, 'LeftData', delimiter, scenario,  name_model_l, main_dir, zoneMPO_l, PersonData_l, HouseholdData_l, ToursData_l, TripsData_l)
    cat('Processing tables on the right...\n')
    BigData_once(FALSE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r, PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  } else {
    cat('Processing tables on the right...\n')
    BigData_once(TRUE,wbname, 'RightData', delimiter, scenario, name_model_r, main_dir, zoneMPO_r,  PersonData_r, HouseholdData_r, ToursData_r, TripsData_r)
  }
}
