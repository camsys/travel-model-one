import os
import numpy as np
import openmatrix as omx
import pickle
from multiprocessing import Process
import yaml
import pandas as pd
from pathlib import Path

_join = os.path.join


# Define your time periods and purposes

purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 


def create_trips_segments(tripPeriod, 
                          tp_name, 
                          df_trips, 
                          output_dir,
                          ext_filename=None):

    num_zones = 3332
    OD_full_index = pd.MultiIndex.from_product([range(0,num_zones), range(0,num_zones)])
    purp_dict = {}

    for purp in purpose:
        print(purp)

        trips_omx = omx.open_file(_join(output_dir, f"trips_{tp_name}_{purp}_{ext_filename}.omx"),'w') 
        
        df_temp = df_trips.loc[(df_trips['util_purpose'] == purp) & (df_trips['Period'] == tp_name.lower())]
 
        auto = df_temp.loc[df_temp['trip_mode'].isin([1,2,3])]
        #print('auto_trips - ', auto['trips'].sum())
        auto = auto.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        trn = df_temp.loc[df_temp['trip_mode'].isin([6,7,8])]
        #print('trn_trips - ', trn['trips'].sum())
        trn = trn.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        nm = df_temp.loc[df_temp['trip_mode'].isin([4,5])]
        #print('nm_trips - ', nm['trips'].sum())
        nm = nm.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        rh = df_temp.loc[df_temp['trip_mode'].isin([9])]
        #print('rh_trips - ', rh['trips'].sum())
        rh = rh.groupby(['orig_taz', 'dest_taz'])['trips'].sum().reindex(OD_full_index, fill_value=0).unstack().values

        trips_omx["auto_trips"] = auto
        trips_omx["nm_trips"] = nm
        trips_omx["trn_trips"] = trn
        trips_omx["rh_trips"] =  rh

        trips_omx.close()
                  


if __name__ == "__main__":

    # model_folders = ['V:\TM2_2050Baseline_R2_Run4', 'V:\TM2_2050R39_R2_Run4', 'V:\TM2_2050R41_R2_Run4']
    # model_folders = ['W:\TM2_2050R40_R2_Run2']
    # model_folders = ['W:\TM2_2050STR39_R2_Run2', 'W:\TM2_2050STR40_R2_Run1', 'W:\TM2_2050STR41_R2_Run2']
    # model_folders = ['W:\TM2_2050Baseline_R2_Run7', 'W:\TM2_2050R39_R2_Run6', 'W:\TM2_2050R40_R2_Run4', 'W:\TM2_2050R41_R2_Run6']
    # model_folders = ['W:\TM2_2050STR40_R2_Run1_RS']
    # model_folders = ['D:\TM2_2050R40_R2_Run2_Conv', 'D:\TM2_2050STR40_R2_Run1_Conv']
    # model_folders = [
    #     'Z:\TM2_2050_BL_R2_Run6_PopTest_Run2',
    #     'Z:\TM2_2050_R40_R2_Run3_PopTest_Run1',
    #     'Z:\TM2_2050_R41_PopTest_Run1'
    # ]
    # model_folders = [
    #     'Z:\TM2_2050_BL_R2_Run6_TollTest_Run2',
    #     'Z:\TM2_2050_R40_R2_Run3_TollTest_Run1',
    #     'Z:\TM2_2050_R41_TollTest_Run1',
    #     'Z:\TM2_2050_BL_R2_Run6_COVID_Run3',
    #     'Z:\TM2_2050_R40_R2_Run3_COVID_Run1',
    #     'Z:\TM2_2050_R41_COVID_Run1'
    # ] 
    # model_folders = [        
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

    #model_folders = [
    #    'D:\TM2_2050R41_R2_Run4_Conv',
        #'D:\TM2_2050R39_R2_Run4_Conv',
    #]

    model_folders = [
        'D:\TM2_2050R41_R2_Run4_Conv',
        'Z:\TM2_2050_STR41_Run2_Cnvrg',
    ]

    for model_dir in model_folders:
        print(f'Model Directory: {model_dir}')
        preprocess_dir = _join(model_dir, '_pre_process')
        output_dir = _join(model_dir, 'trips')
        Path(output_dir).mkdir(parents=True, exist_ok=True)

        time_period = {1:'EA',2:'AM',3:'MD',4:'PM',5:'EV'} 
        #time_period = {2:'AM'} 

        df_trips = pd.read_parquet(_join(preprocess_dir, 'trip_roster.parquet'))
        df_trips['orig_taz'] =  df_trips['orig_taz']-1
        df_trips['dest_taz'] =  df_trips['dest_taz']-1
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
            
        # attach auto sufficiency
        hh_data = pd.read_csv(_join(preprocess_dir, 'householdData_1.csv'))

        hh_data['auto_suff_category'] = 0
        hh_data.loc[hh_data['autos'] < hh_data['workers'], 'auto_suff_category'] = 'autoDeficient'
        hh_data.loc[hh_data['autos'] >= hh_data['workers'], 'auto_suff_category'] = 'autoSufficient'
        hh_data.loc[hh_data['autos']==0, 'auto_suff_category'] = 'zeroAuto'

        hh_data = hh_data[['hh_id', 'auto_suff_category']]

        df_trips = pd.merge(df_trips, hh_data, on='hh_id', how='left')

        auto_suff_cat = ['autoSufficient', 'autoDeficient', 'zeroAuto']

        jobs = []
        multi =True

        if multi:

            for tripPeriod in time_period:

                for auto_sufficient_categories in  auto_suff_cat:
                    df_auto = df_trips.loc[(df_trips['auto_suff_category'] == auto_sufficient_categories)]
                    print(len(df_auto), '-', auto_sufficient_categories)
                    p = Process(target=create_trips_segments, args=(tripPeriod, 
                                                                    time_period[tripPeriod], 
                                                                    df_auto, 
                                                                    output_dir, 
                                                                    auto_sufficient_categories))
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
