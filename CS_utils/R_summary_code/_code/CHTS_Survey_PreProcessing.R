library(data.table)
library(readxl)
library(plyr)

survey_data_dir = 'E:/_projects/Link21/Survey Data/'
setwd(survey_data_dir)

# read MTC survey data
# MTC survey
in_hh <-fread('CHTS_processed/households_SUBSET.csv')
in_person <-fread('CHTS_processed/persons_subset.csv')
in_tours <-fread('CHTS_processed/tours.csv')
in_trips <-fread('CHTS_processed/trips.csv')
# MTZ to TAZ crosswalk
MAZtoTAZ <- read_excel("TAZ Correspondance v18.xlsx", sheet = "MTC")
# CHTS data
chts_hh <- read_excel("CHTS Megaregion Data/1-HH.xlsx", sheet = "_1_HH")
chts_per <- read_excel("CHTS Megaregion Data/2-PER.xlsx", sheet = "_2_PER")
# Location file
hloc <- fread('Trip End Geocodes/CHTS1213hhloc.csv')
wloc <- fread('Trip End Geocodes/CHTS1213workloc.csv')
sloc <- fread('Trip End Geocodes/CHTS1213schlloc.csv')
place <-fread('Trip End Geocodes/CHTS1213placeloc.csv') 

# 0. clean crosswalk
MAZtoTAZ =data.table(MAZtoTAZ[,c('MTC TM2 MAZ', 'MTC 1454 TAZs')])
setnames(MAZtoTAZ, c('MAZ','TAZ'))

# 1. Use CHTS data to fill missing hh/person data
chts_hh = data.table(chts_hh[,c('SAMPN','HHVEH','INCOM','HHSIZ')])
hh = merge(in_hh, chts_hh, by.x='HH_ID', by.y='SAMPN', all.x=T)

chts_per = data.table(chts_per[,c('SAMPN','PERNO','GEND','AGE')])
person = merge(in_person, chts_per, by.x=c('HH_ID','PER_ID'), by.y=c('SAMPN','PERNO'),all.x=T)

# 3.use geocodes to fill all location info
hh = merge(hh, MAZtoTAZ, by.x='HLOC_MAZ',by.y='MAZ',all.x=T)
hh = hh[,.(HH_ID,TAZ,INCOM,HHSIZ,HHVEH,HHWEIGHT_SUB)]

person = merge(person, wloc[,c('SAMPN','PERNO','MAZ_V10')], by.x=c('HH_ID','PER_ID'), by.y=c('SAMPN','PERNO'),all.x=T, suffixes = c('','_W'))
person = merge(person, sloc[,c('SAMPN','PERNO','MAZ_V10')], by.x=c('HH_ID','PER_ID'), by.y=c('SAMPN','PERNO'),all.x=T, suffixes = c('','_S'))
person = merge(person, MAZtoTAZ, by.x='MAZ_V10',by.y='MAZ',all.x=T)
person = merge(person, MAZtoTAZ, by.x='MAZ_V10_S',by.y='MAZ',all.x=T, suffixes = c('','_S'))
person = person[,.(HH_ID,PER_ID,AGE,GEND,PERSONTYPE,TAZ,TAZ_S,PERWEIGHT_SUB)]

trips=merge(in_trips, place[,.(SAMPN,PERNO,PLANO,MAZ_V10)], by.x=c('HH_ID','PER_ID','ORIG_PLACENO'),by.y=c('SAMPN','PERNO','PLANO'),all.x=T, suffix=c('','_O'))
trips=merge(trips, place[,.(SAMPN,PERNO,PLANO,MAZ_V10)], by.x=c('HH_ID','PER_ID','DEST_PLACENO'),by.y=c('SAMPN','PERNO','PLANO'),all.x=T, suffix=c('','_D'))
trips=merge(trips,MAZtoTAZ, by.x='MAZ_V10', by.y='MAZ',all.x=T)
trips=merge(trips,MAZtoTAZ, by.x='MAZ_V10_D', by.y='MAZ',all.x=T,suffix=c('','_D'))
trips=trips[,.(HH_ID,PER_ID,TOUR_ID,TRIP_ID,IS_INBOUND,TRIPMODE,DEST_PURP,ORIG_DEP_HR,DEST_ARR_HR,TAZ,TAZ_D)]

tours=merge(in_tours, place[,.(SAMPN,PERNO,PLANO,MAZ_V10)], by.x=c('HH_ID','PER_ID','ORIG_PLACENO'),by.y=c('SAMPN','PERNO','PLANO'),all.x=T, suffix=c('','_O'))
tours=merge(tours, place[,.(SAMPN,PERNO,PLANO,MAZ_V10)], by.x=c('HH_ID','PER_ID','DEST_PLACENO'),by.y=c('SAMPN','PERNO','PLANO'),all.x=T, suffix=c('','_D'))
tours=merge(tours,MAZtoTAZ, by.x='MAZ_V10', by.y='MAZ',all.x=T)
tours=merge(tours,MAZtoTAZ, by.x='MAZ_V10_D', by.y='MAZ',all.x=T,suffix=c('','_D'))
tours=tours[,.(HH_ID,PER_ID,TOUR_ID,TOURMODE,TOURPURP,IS_SUBTOUR,PARTIAL_TOUR,JTOUR_ID,FULLY_JOINT,JOINT_STATUS,
               ANCHOR_DEPART_HOUR,ANCHOR_ARRIVE_HOUR,TAZ,TAZ_D,OUTBOUND_STOPS,INBOUND_STOPS)]

write.csv(hh, "household.csv",row.names=F)
write.csv(person, "person.csv",row.names=F)
write.csv(tours, 'tours.csv',row.names=F)
write.csv(trips, 'trips.csv',row.names=F)






