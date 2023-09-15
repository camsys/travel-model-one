import os
import numpy as np
import openmatrix as omx
import pickle
from multiprocessing import Process
import yaml
import pandas as pd

with open('config.yaml', 'r') as file:
    params = yaml.safe_load(file)
_join = os.path.join

ctramp_dir = params['ctramp_dir']
preprocess_dir = _join(ctramp_dir, '_pre_process_files')

# Define your time periods and purposes

purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 


def create_trips_segments(tripPeriod, tp_name, df_trips):

    num_zones = 3332
    OD_full_index = pd.MultiIndex.from_product([range(1,num_zones + 1), range(1,num_zones + 1)])
    purp_dict = {}

    for purp in purpose:
        print(purp)
        
        df_temp = df_trips.loc[(df_trips['util_purpose'] == purp) & (df_trips['Period'] == tp_name.lower())]
        auto = df_temp.loc[df_temp['trip_mode'].isin([1,2,3])]
        auto = auto.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values
   
        trn = df_temp.loc[df_temp['trip_mode'].isin([6,7,8])]
        trn = trn.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        nm = df_temp.loc[df_temp['trip_mode'].isin([4,5])]
        nm = nm.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        rh = df_temp.loc[df_temp['trip_mode'].isin([9])]
        rh = rh.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        data_dict = {
            "auto_trips": auto,
            "trn_trips": trn,
            "nm_trips": nm,
            "rh_trips": rh,
        }

        purp_dict[purp] = data_dict
        
    file_path = os.path.join(preprocess_dir, f"trips_{tp_name}.pkl")
    with open(file_path, "wb") as pickle_file:
        pickle.dump(purp_dict, pickle_file, protocol=pickle.HIGHEST_PROTOCOL)
          
    print(f"Data has been written to {file_path} for {purp} and {tripPeriod}.")         



if __name__ == "__main__":
    preprocess_dir = preprocess_dir  
    time_period = {1:'EA',2:'AM',3:'MD',4:'PM',5:'EV'} 

    df_trips = pd.read_parquet(_join(preprocess_dir, 'trip_roster.parquet'))
    df_trips['util_purpose'] = np.where(df_trips['inbound']==1, df_trips['orig_purpose'], df_trips['dest_purpose'])
    purp_dict = { 'work' : 'Work', 
              'shopping' : 'Shopping',
              'escort' : 'Escort', 
              'othdiscr': 'OthDiscr',
              'othmaint': 'OthMaint',
              'school' : 'School', 
              'eatout' : 'EatOut', 
              'atwork' : 'WorkBased', 
              'social' : 'Social',
              'university' : 'University'}

    df_trips['util_purpose'] = df_trips['util_purpose'].map(purp_dict)

    # Create a multiprocessing pool
    jobs = []
    multi =True
    # pool = multiprocessing.Pool(processes=multiprocessing.cpu_count())
    if multi:
        # Use the pool to process time periods and purposes in parallel
        for tripPeriod in time_period:
            #pool.apply_async(process_time_period_purpose, (tripPeriod, purp))
            #tp_trips = df_trips[df_trips['Period'] == time_period[tripPeriod].lower()]
            #print(tp_trips.columns)
            p = Process(target=create_trips_segments, args=(tripPeriod, time_period[tripPeriod], df_trips))
            p.start()
            jobs.append(p)

        #wait for all thread to complete
        for j in jobs:
            j.join() 

        errcheck = [j.exitcode for j in jobs]
        
        if 1 in errcheck:
            print('Error encountered while attempting to convert skims to Postgres.')
        else:
            print("All processing completed.")

    else:
        for tripPeriod in time_period:
            for purp in purpose:
                tp_trips = df_trips[df_trips['Period'] == time_period[tripPeriod].lower()]
                create_trips_segments(tripPeriod, time_period[tripPeriod],tp_trips)
                break
            break
