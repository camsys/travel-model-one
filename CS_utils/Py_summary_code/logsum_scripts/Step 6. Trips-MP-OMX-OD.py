import os
import numpy as np
import openmatrix as omx
from multiprocessing import Process
import yaml
import pandas as pd
from pathlib import Path

_join = os.path.join


# Define your time periods and purposes

purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 

def array2df(array, cols =['orig', 'dest', 'rail_od']):
    df = pd.DataFrame(array)
    df = pd.melt(df.reset_index(), id_vars='index', value_vars=df.columns)
    df['index'] = df['index'] + 1
    df['variable'] = df['variable'] + 1
    df.columns = cols
    
    return df


def create_parquet_trips(trips_folder,
                      column_ext, 
                      tp_name, 
                      auto_suff, 
                      purp):
    
    #all_benefits = []

    # Loop through time periods and purposes
    trips_mat = omx.open_file(_join(trips_folder, f"trips_{tp_name}_{purp}_{auto_suff}.omx"))

    auto = np.array(trips_mat['auto_'+ column_ext])
    trn = np.array(trips_mat['trn_'+column_ext])
    nm = np.array(trips_mat['nm_'+column_ext])
    rh = np.array(trips_mat['rh_'+column_ext])

    trips_mat.close()

    #print(np.sum(auto_temp), np.sum(trn_temp), np.sum(nm_temp), np.sum(rh_temp))
    auto_trips = array2df(auto, cols =['orig_taz', 'dest_taz', 'auto_'+column_ext])
    trn_trips = array2df(trn, cols =['orig_taz', 'dest_taz', 'transit_'+column_ext])
    nm_trips = array2df(nm, cols =['orig_taz', 'dest_taz', 'non-motorized_'+column_ext])
    rh_trips = array2df(rh, cols =['orig_taz', 'dest_taz', 'ridehail_'+column_ext])

    all_trips_tp = pd.merge(auto_trips, trn_trips, on = ['orig_taz', 'dest_taz'], how='left').merge(
                                        nm_trips, on = ['orig_taz', 'dest_taz'], how='left').merge(
                                        rh_trips, on = ['orig_taz', 'dest_taz'], how='left')
    
    print("writing parquet file")
    all_trips_tp.to_parquet(_join(trips_folder, f"{column_ext}_{tp_name}_{purp}_{auto_suff}.parquet"))


if __name__ == "__main__":

    # model_folders = ['W:\TM2_2050Baseline_R2_Run4', 'W:\TM2_2050R39_R2_Run4', 'W:\TM2_2050R41_R2_Run4']
    # model_folders = ['W:\TM2_2050R40_R2_Run2', 'W:\TM2_2050STR39_R2_Run2', 'W:\TM2_2050STR40_R2_Run1', 'W:\TM2_2050STR41_R2_Run2']
    # model_folders = ['W:\TM2_2050Baseline_R2_Run7', 'W:\TM2_2050R39_R2_Run6', 'W:\TM2_2050R40_R2_Run4', 'W:\TM2_2050R41_R2_Run6']    
    # model_folders = ['W:\TM2_2050STR40_R2_Run1_RS']
    # model_folders = ['D:\TM2_2050R40_R2_Run2_Conv', 'D:\TM2_2050STR40_R2_Run1_Conv']
    # model_folders = [
    #     'Z:\TM2_2050_BL_R2_Run6_PopTest_Run2',
    #     'Z:\TM2_2050_R40_R2_Run3_PopTest_Run1',
    #     'Z:\TM2_2050_R41_PopTest_Run1',    
    #     'Z:\TM2_2050_BL_R2_Run6_TollTest_Run2',
    #     'Z:\TM2_2050_R40_R2_Run3_TollTest_Run1',
    #     'Z:\TM2_2050_R41_TollTest_Run1',
    #     'Z:\TM2_2050_BL_R2_Run6_COVID_Run3',
    #     'Z:\TM2_2050_R40_R2_Run3_COVID_Run1',
    #     'Z:\TM2_2050_R41_COVID_Run1'
    # ]
    # model_folders = [
    #     'Z:\TM2_2050_R39_R2_Run6_Cnvrg',
    #     'Z:\TM2_2050_R41_R2_Run6_Cnvrg',
    #     'Z:\TM2_2050_STR39_Run2_Cnvrg',
    #     'Z:\TM2_2050_STR41_Run2_Cnvrg'
    # ] 

    model_folders = [
        #'D:\TM2_2050R39_R2_Run4_Conv',
        'D:\TM2_2050R41_R2_Run4_Conv',
        'Z:\TM2_2050_STR41_Run2_Cnvrg',
    ]


    for model_dir in model_folders:

        #model_folders = ['V:\TM2_2050Baseline_R2_Run4', 'V:\TM2_2050R39_R2_Run4', 'V:\TM2_2050R41_R2_Run4']
        time_period = {1:'EA', 2:'AM', 3:'MD', 4:'PM', 5:'EV'} 

        auto_suff_cat = ['autoSufficient', 'autoDeficient', 'zeroAuto']

        trips_folder = _join(model_dir, 'trips')

        multi = True
        # multi = False
        # pool = multiprocessing.Pool(processes=multiprocessing.cpu_count())
        if multi:
            # Use the pool to process time periods and purposes in parallel            
            for auto_suff in  auto_suff_cat:    
                print(f'\n\n\nAuto Sufficiency: {auto_suff}')
                print('============================================')
                # Create a multiprocessing pool
                jobs = []
                for tripPeriod in time_period:
                    for purp in purpose:                    
                        tp_name = time_period[tripPeriod]
                        p = Process(target=create_parquet_trips, args=(trips_folder,
                                                                       "trips", #proportion_diff", #"benefits_ls", #"ls_diff", #"benefits",
                                                                       tp_name,
                                                                       auto_suff,
                                                                       purp
                                                                       )
                        )
                        p.start()
                        jobs.append(p)

                #wait for all thread to complete
                for j in jobs:
                    j.join()

                errcheck = [j.exitcode for j in jobs]

                if 1 in errcheck:
                    print('Error encountered')
                else:
                    print("All processing completed.")

        else:
            for tripPeriod in time_period:
                for auto_suff in  auto_suff_cat:                    
                    for purp in purpose:
                        tp_name = time_period[tripPeriod]
                        create_parquet_trips(trips_folder, "trips", tp_name, auto_suff, purp)
