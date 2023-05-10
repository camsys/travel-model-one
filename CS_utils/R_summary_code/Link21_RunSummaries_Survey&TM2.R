#############################################################
##### PARAMETERS AND DIRECTORIES ############################
#############################################################
rm(list=ls())

code_base_dir = dirname(rstudioapi::getSourceEditorContext()$path)
setwd(code_base_dir)

main_config <- config::get()
run_config <- main_config$survey_comp
preprocess_suffix <- main_config$preprocess_suffix

delimiter = '//'

# This is the directory where the reports are stored:
main_dir = main_config$main_dir

# Set preprocessing parameters
preprocess_r = as.logical(run_config$preprocess_r)
output_iteration = run_config$output_iteration
model_year = run_config$model_year

# If you are doing model validation against survey data, please
# set skip_l = TRUE, otherwise, set it to FALSE.
# When skip_l == TRUE, fill out section RIGHT; otherwise fill both.
skip_l = as.logical(run_config$skip_l)

# set the following switch to TRUE to include GQ households in summaries
# Should be set to FALSE for validation (GQs are not included in hh surveys)
# include_gq = FALSE

# set the following switch to TRUE to produce summary sheet for each MPO
# When [MPO Name] = TRUE, produce summary sheet. "ALL" includes the entire dataset.
MTC = TRUE

# set the following switch to TRUE to produce county summary sheet for each county
# When [County Name] = TRUE, produce summary sheet. "ALL" includes the entire dataset.
# `San Francisco`
# `San Mateo`	
# `Santa Clara`	
# Alameda	
# `Contra Costa`
# Solano	
# Napa
# Sonoma
# Marin
ALL = TRUE

# Name of the scenario will appear in summary spreadsheets as suffix.
scenario = run_config$scenario

############################################################
source('_code//Link21_utilities.R')
source('_code//Link21_vehicle_avail.R')
source('_code//Link21_CDAP.R')
source('_code//Link21_tour_freq.R')
source('_code//Link21_tour_dest_choice.R')
source('_code//Link21_tour_mode_choice.R')
source('_code//Link21_tour_tod_choice.R')
source('_code//Link21_stop_freq.R')
source('_code//Link21_stop_dest_choice.R')
source('_code//Link21_trip_mode_choice.R')
source('_code//Link21_trip_tod_choice.R')
source('_code//Link21_dest_choice_bigdata.R')
source('_code//Link21_workplace_location.R')

setwd(paste(main_dir, '..', sep = delimiter))
#############################################################

#############################################################
################## ##########################################
##################   ########################################
######     RIGHT       ######### Fill always ################
##################   ########################################
################## ##########################################
#############################################################

##############################################################################################################################
# The MTC models produces individual and joint tour/trips, which is inconsistent with the survey and the original code design.  
# To address this, a new separate script were written to process a combined trip and tour file.
# Note that for each scenario this only needs to be done once!

model_data_dir= main_config$TM2_data_dir

#### Only (manually) run once! ####
if (preprocess_r) {
  setwd(code_base_dir)
  source('_code//TM2_Model_Files_PreProcessing.R')
}##############################################################################################################################

# These correspond to the inputs of tables on the right. These fields should always be filled.
name_model_r = run_config$right$name_model


model_version_r = run_config$right$model_version


input_dir_r = file.path(model_data_dir, paste('_pre_processed', preprocess_suffix, sep='_'))
output_dir_r = file.path(model_data_dir, paste('_pre_processed', preprocess_suffix, sep = '_'))


in_person_r = 'in_person.csv'
in_hh_r = 'in_hh.csv'
in_MPO_r = 'in_taz.csv'

out_person_r = 'out_person_data.csv'
out_hh_r     = "out_hh_data.csv"
out_tours_r  = 'out_tour_data.csv'
out_stops_r  = 'out_trip_data.csv'

model_run_weight_r = get_model_weight(output_dir_r, out_stops_r)

skim_dir_r = file.path(model_data_dir, 'skims')
skim_am_r = 'HWYSKMAM.OMX'
skim_op_r = 'HWYSKMEA.OMX'

#############################################################
########## ##################################################
########   ##################################################
######       LEFT      ######### Fill when skip_l = FALSE ###
########   ##################################################
########## ##################################################
#############################################################
survey_l = T
skim_left = "csv"

# These correspond to the inputs of tables on the left These fields should be filled when skip_l = FALSE.
name_model_l = run_config$left$name_model
output_dir_l = run_config$left$output_dir
out_person_l = 'Person.csv'
out_hh_l = 'household.csv'
out_tours_l = 'tours.csv'
out_stops_l = 'trips.csv'
zone_MPO_l = 'in_taz.csv'


# Skims - use TM1.5 skims for now
# survey was processed by MTC using TM1.5 TAZ system so skims are different.
skim_dir_l = run_config$left$skim_dir

skim_am_time_l = 'TimeSkimsDatabaseAM.csv'
skim_am_dist_l = 'DistanceSkimsDatabaseAM.csv'
skim_op_time_l = 'TimeSkimsDatabaseEA.csv'
skim_op_dist_l = 'DistanceSkimsDatabaseEA.csv'

#############################################################
######################## READ ###############################
#############################################################

read_files()

#############################################################
######################## RUN ################################
#############################################################

# Run Vehicle_Avail:
Vehicle_Avail('1 - Vehicle_Avail')

# Run CDAP:
CDAP('2 - CDAP')

# Run Tour_Frequency:
Tour_Freq_Choice('3 - Tour_Frequency')

# Run Tour_Dest_Choice:
Tour_Dest_Choice('4 - Tour_Dest_Choice')

# Run Workplace Location:
Workplace_Location('4a - Workplace_Location')

# Run Tour_Mode_Choice:
Tour_Mode_Choice('5 - Tour_Mode_Choice')

# Run Tour_TOD_Choice:
Tour_TOD_Choice('6 - Tour_TOD_Choice')

# Run Stop_Frequency:
Stop_Freq_Choice('7 - Stop_Frequency')

# Run Stop_Location_Choice
Stop_Dest_Choice('8 - Stop_Dest_Choice')

# Run Trip_Mode_Choice
Trip_Mode_Choice('9 - Trip_Mode_Choice')

# Run Trip_TOD_Choice
Trip_TOD_Choice('10 - Trip_TOD_Choice')

# Run Dest_Choice_BigData
Dest_Choice_BigData('99 - Dest_Choice_BigData')
