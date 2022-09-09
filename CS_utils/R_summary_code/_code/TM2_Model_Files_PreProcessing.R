library(plyr)
library(data.table)
library(omxr)
# define input and output file directory
# model_data_dir
output_rdata_dir = file.path(model_data_dir, '_pre_processed')
setwd(model_data_dir)

# read in input files
### person and households
in_person <- fread("popsyn/personFile.2015.csv")
in_hh <- fread("popsyn/hhFile.2015.csv")
### landuse/tazData
in_taz <- fread("landuse/tazData.csv")
### skims
# in_am_time <-read_omx("skims/HWYSKMAM.OMX", name ='TIMEDA')
# in_am_dist <-read_omx("skims/HWYSKMAM.OMX", name ='DISTDA')
# in_op_time <-read_omx("skims/HWYSKMEA.OMX", name ='TIMEDA')
# in_op_dist <-read_omx("skims/HWYSKMEA.OMX", name ='DISTDA')

# read in output files
### person and households
in_pdata <- fread(paste("main/PersonData_",output_iteration,".csv",sep=''))
in_hdata <- fread(paste("main/hOuseholdData_",output_iteration,".csv",sep=''))
### work/school location and auto ownership
in_wsloc <- fread(paste("main/wsLocResults_",output_iteration,".csv",sep=''))
in_ao <- fread("main/aoResults.csv")
# in_cdap <-fread("main/CDAPResults.csv")
### tour and trip
ind_tour <- fread(paste("main/indivTourData_",output_iteration,".csv",sep=''))
jot_tour <- fread(paste("main/jointTourData_",output_iteration,".csv",sep=''))
ind_trip <- fread(paste("main/indivTripData_",output_iteration,".csv",sep=''))
jot_trip <- fread(paste("main/jointTripData_",output_iteration,".csv",sep=''))

# rename a few input/output field names to be consistent with the ActivitySim model convention
names(in_person)[1:4] <- c("household_id", "person_id", "age", "sex")
names(in_hh) <- c("household_id", "TAZ", "income", "num_workers","veh", "hhsize", "HHT", "UNITTYPE", "HINCCAT")

setnames(in_pdata, old=c("person_num","sampleRate"), new=c("PNUM", "sample_rate"))
setnames(in_hdata, old=c("taz","size","sampleRate"), new=c("TAZ", "hhsize","sample_rate"))
setnames(ind_tour, old=c("person_num","sampleRate"), new=c("PNUM", "sample_rate"))
setnames(ind_trip, old=c("person_num","sampleRate"), new=c("PNUM", "sample_rate"))
setnames(jot_tour, old=c("sampleRate"), new=c("sample_rate"))
setnames(jot_trip, old=c("sampleRate"), new=c("sample_rate"))

# TAZ file: rename and calculate size in sq. miles; add "MPO"
out_taz=in_taz[,.(ZONE,DISTRICT,SD,COUNTY,TOTHH,HHPOP,TOTPOP,EMPRES,SFDU,MFDU,TOTACRE,TOTEMP,RETEMPN,FPSEMPN,HEREMPN,
                  AGREMPN,MWTEMPN,OTHEMPN,PRKCST,OPRKCST,AREATYPE,HSENROLL,COLLFTE,COLLPTE,TERMINAL)]
setnames(out_taz, old=c("ZONE","TOTHH"), new=c("TAZ","TOT_HH"))
# names(out_taz)[12:18]=c("TOT_EMP","Retailemployement","PServiceeployement","HEServiceemplyement","AGEemployement","MANUemployement","Otheremployement")
out_taz<-out_taz[,size:=TOTACRE/640]
out_taz$MPO = "MTC"

# Merge auto.ownership and work/school location into person files
names(in_ao) <- c("hh_id", "Auto.Ownership")
out_hdata = merge(in_hdata, in_ao, all.x=T)

out_wsloc = in_wsloc[,c("HHID","PersonID","HomeTAZ","WorkLocation","SchoolLocation")]
names(out_wsloc) = c("hh_id","person_id","home_zone_id","workplace_zone_id", "school_zone_id")
out_pdata = merge(in_pdata,out_wsloc, by=c("hh_id","person_id"),all.x=T)

# skims data processing
# rownames(in_am_time)=1:nrow(in_am_time); colnames(in_am_time)=1:ncol(in_am_time); out_am_time <- as.data.table(as.table(in_am_time));colnames(out_am_time)=c("orig","dest","da")
# rownames(in_am_dist)=1:nrow(in_am_dist); colnames(in_am_dist)=1:ncol(in_am_dist); out_am_dist <- as.data.table(as.table(in_am_dist));colnames(out_am_dist)=c("orig","dest","da")
# rownames(in_op_time)=1:nrow(in_op_time); colnames(in_op_time)=1:ncol(in_op_time); out_op_time <- as.data.table(as.table(in_op_time));colnames(out_op_time)=c("orig","dest","da")
# rownames(in_op_dist)=1:nrow(in_op_dist); colnames(in_op_dist)=1:ncol(in_op_dist); out_op_dist <- as.data.table(as.table(in_op_dist));colnames(out_op_dist)=c("orig","dest","da")

# tour file processing
# create a joint tour file that has one row for each participant
### It is realized later that there exists duplicated tour_id in the out files. A unique identification is tour_category/tour_purpose/tour_id
### To Avoid double counting joint tours, a JTOUR_ID is created to match survey style.
### from joint tour file, identify person id for each participants in joint tours and duplicate the joint tours to the total number of participants
tour0 = jot_tour[,.(hh_id,tour_id,tour_participants,tour_mode)]
tour0 = tour0[,JTOUR_ID:=tour_id+1]
a = strsplit(as.character(tour0$tour_participants)," ")
b = paste(unlist(a),collapse=" ")
c = as.integer(strsplit(b, " +")[[1]])
tour0$num = lengths(a)
tour1 = data.frame(tour0[rep(seq_len(dim(tour0)[1]), tour0$num),, drop = FALSE], row.names=NULL)
tour1$PNUM=c
tour1$num=NULL

### get person_id from persons file
tour1 = merge(data.table(tour1),in_pdata[,.(hh_id,person_id,PNUM)],by=c("hh_id","PNUM"),all.x=T)
tour1 = tour1[,c("hh_id","person_id","tour_id","PNUM",'JTOUR_ID')]
### join the other tour variables into the new joint tour file
tour1.2 = merge(tour1,jot_tour,by=c("hh_id","tour_id"))
##### drop jot_tour fields that don't exist in ind_tour: tour_participants; tour_composition
tour1.2=tour1.2[, -c("tour_composition", "tour_participants")]

### drop ind_tour fields that doesn't exist in jot_tour: atwork_freq; person_type
tour2=ind_tour[, -c("atWork_freq", "person_type")]
tour2$JTOUR_ID=0
### combine into a single tour file
out_tourdata=rbindlist(list(tour1.2, tour2), use.names = T)
out_tourdata <-out_tourdata[,`:=`(TOURID=paste(tour_category, tour_purpose, tour_id, sep="."), TourType="Closed")]
out_tourdata=out_tourdata[order(hh_id,person_id,start_hour,end_hour)]
out_tourdata <-out_tourdata[,tour_id:=.I, by=.(hh_id, person_id)]


# calculate Exact.Number.of.tours and add into person data file
num_tours=out_tourdata[,.(Exact.Number.of.tours=.N), keyby=.(hh_id, person_id)]
out_pdata = merge(out_pdata, num_tours, by=c("hh_id","person_id"), all.x=T)
out_pdata<-out_pdata[is.na(Exact.Number.of.tours), Exact.Number.of.tours:=0] 


# trip file processing
trip1=merge(tour1,jot_trip[,-c("num_participants")],by=c("hh_id","tour_id"),all.x=T, allow.cartesian=TRUE)
trip1$JTOUR_ID=NULL
out_tripdata=rbindlist(list(trip1, ind_trip), use.names= T)
out_tripdata <-out_tripdata[,`:=`(TOURID=paste(tour_category, tour_purpose, tour_id, sep="."), TourType="Closed")]
out_tripdata =merge(out_tripdata, out_tourdata[,.(hh_id,person_id,TOURID,tour_id)], by=c("hh_id","person_id","TOURID"),suffixes = c("","_t"))
out_tripdata =out_tripdata[,`:=`(tour_id=tour_id_t,tour_id_t=NULL)]

rm(a,b,c,tour0,tour1,tour1.2,tour2, trip1)

if (!file.exists(output_rdata_dir)){
	dir.create(output_rdata_dir)}
setwd(output_rdata_dir)
fwrite(in_person, "in_person.csv")
fwrite(in_hh, "in_hh.csv")
fwrite(out_taz, "in_taz.csv")
fwrite(out_pdata, "out_person_data.csv")
fwrite(out_hdata, "out_hh_data.csv")
fwrite(out_tourdata,"out_tour_data.csv")
fwrite(out_tripdata,"out_trip_data.csv")
# fwrite(out_am_time, "TimeSkimsDatabaseAM.csv")
# fwrite(out_am_dist, "DistanceSkimsDatabaseAM.csv")
# fwrite(out_op_time, "TimeSkimsDatabaseEA.csv")
# fwrite(out_op_dist, "DistanceSkimsDatabaseEA.csv")
#save.image("run_20220722_012100.rdata")

