#
# Simple test to assess value of RAPTOR in tidytranst
#
# 2023-04-26 - DRS - Originally written
rm(list = ls())
library(tidytransit)
library(tidyverse)


#
# Start Time
#
start_time <- Sys.time()
cat(format(start_time, format = "%F %R %Z\n"))


#
# Read in GTFS
#
baseline_concept <- read_gtfs(
  "C://VY-Projects//Link21//notebooks//common_data//BL_GTFS//BL_GTFS"
)

#
# Prepare files needed for RAPTOR
#
results_df <- data.frame()

#
# Loop on time period
#
for (period in 1:6) {
  if (period == 1) {
    stop_times <- filter_stop_times(baseline_concept, "2000-07-26", "00:00:00", "03:00:00")
    timeperiod <- "0000-0300"
  } else if (period == 2) {
    stop_times <- filter_stop_times(baseline_concept, "2000-07-26", "03:00:00", "06:00:00")
    timeperiod <- "0300-0600"
  } else if (period == 3) {
    stop_times <- filter_stop_times(baseline_concept, "2000-07-26", "06:00:00", "10:00:00")
    timeperiod <- "0600-1000"
  } else if (period == 4) {
    stop_times <- filter_stop_times(baseline_concept, "2000-07-26", "10:00:00", "15:00:00")
    timeperiod <- "1000-1500"
  } else if (period == 5) {
    stop_times <- filter_stop_times(baseline_concept, "2000-07-26", "15:00:00", "19:00:00")
    timeperiod <- "1500-1900"
  } else if (period == 6) {
    stop_times <- filter_stop_times(baseline_concept, "2000-07-26", "19:00:00", "26:00:00")
    # Note: routes past midnight show up as 24:00:00
    timeperiod <- "1900-2600"
  }
  stop_list <- unique(stop_times$stop_id)

  #
  # Execute RAPTOR for all stations
  #
  for (i in 1:length(stop_list)) {
    cat(paste("Paths for",stop_list[i],",",i,"of",length(stop_list),", period",period,"of 6\n"))

    # Define the origin station ID
    origin_id <- c(stop_list[i])
    
    # Use the Raptor function to find the shortest paths from the origin station to all other stations
    rptr <- raptor(stop_times = stop_times, 
                   transfers = baseline_concept$transfers, 
                   # stop_ids = c("JQvWdW4gsG2T8u93P"),  # Modesto SJ
                   stop_ids = origin_id,  # All stops/stations in GTFS
                   arrival = FALSE,
                   time_range = 14400,  # 4 hours
                   max_transfers = 5,
                   # keep = "shortest")   # Keeps shortest path
                   keep = "all")          # Keeps all paths; this may be 
    
    # Convert the resulting paths to a dataframe and add the origin station ID to each row
    paths_df <- as.data.frame(rptr) %>% 
      mutate(
        travel_time = travel_time / 60.0,
        departure_time_hours = floor(journey_departure_time / 3600),
        departure_time_mins = (journey_departure_time / 3600 - floor(journey_departure_time / 3600)) * 60,
        arrival_time_hours = floor(journey_arrival_time / 3600),
        arrival_time_mins = (journey_arrival_time / 3600 - floor(journey_arrival_time / 3600)) * 60,
        time_period = timeperiod
      )
  
    # Add the resulting dataframe to the overall results dataframe
    results_df <- bind_rows(results_df, paths_df)
  }

} # end period loop

#
# Formatting final dataframe
# 
stop_df <- as.data.frame(baseline_concept$stops)
test <- left_join(results_df, stop_df, join_by(from_stop_id == stop_id), keep = NULL)
test <- left_join(test, stop_df, join_by(to_stop_id == stop_id), keep = NULL)
test <- select(test, stop_name.x, stop_name.y, transfers, travel_time, time_period)
test <- filter(test, !(stop_name.x == stop_name.y)) # Remove intra-station movements

#
# End Time
#
end_time <- Sys.time()
cat(format(start_time, format = "%F %R %Z\n"))
cat(format(end_time, format = "%F %R %Z\n"))


View(test)
# write_csv(test,file="test.csv")















