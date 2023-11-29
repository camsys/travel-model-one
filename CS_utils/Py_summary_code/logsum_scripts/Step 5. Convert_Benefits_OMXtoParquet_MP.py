import os
import numpy as np
import openmatrix as omx
from multiprocessing import Process
import yaml
import pandas as pd
from pathlib import Path

_join = os.path.join


"""
The purpose of this script is to convert all the benefits outputs files (150 count) to
parquet files. This will help in summarizing the benefits by origin and destination 
information more easily and quickly. 

"""

# Define purpose, time periods and auto sufficiency group
purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 

time_period = {1:'EA',2:'AM',3:'MD',4:'PM',5:'EV'} 

auto_suff_cat = ['autoSufficient', 'autoDeficient', 'zeroAuto']

def array2df(array, cols =['orig', 
                           'dest', 
                           'mode']
                           ):
    
    """ converts 2-D numpy arrays to pandas dataframe"""
    df = pd.DataFrame(array)
    df = pd.melt(df.reset_index(), id_vars='index', value_vars=df.columns)
    df['index'] = df['index'] + 1
    df['variable'] = df['variable'] + 1
    df.columns = cols
    
    return df

def create_parquet(benefits_folder,
                      column_ext, 
                      tp_name, 
                      auto_suff, 
                      purp):
    
    """
    
    Creates parquet file for the matrix core. 

    column_ext can be any column in the benefits_{tp_name}_{purp}_{auto_suff}_bivt_mp.omx file
    Example - benefits_pr, benefits_ls, benefits_cls, benefits_ls_nu, benefits_ls_eu
    
    """
    

    # read the benefits file generated in step 4
    purp_benefit = omx.open_file(_join(benefits_folder, f"benefits_{tp_name}_{purp}_{auto_suff}_bivt_mp.omx"))

    # extract the matrix core
    auto = np.array(purp_benefit['auto_'+ column_ext])
    trn = np.array(purp_benefit['trn_'+column_ext])
    nm = np.array(purp_benefit['nm_'+column_ext])
    rh = np.array(purp_benefit['rh_'+column_ext])

    # clsoe the OMX file
    purp_benefit.close()

    # fill the diagonal elements with zero as intrazonals are being excluded 
    np.fill_diagonal(auto, 0)
    np.fill_diagonal(trn, 0)
    np.fill_diagonal(nm, 0)
    np.fill_diagonal(rh, 0)

    # convert the 2-D numpy arrays to pandas dataframe
    auto_ben = array2df(auto, cols =['orig_taz', 'dest_taz', 'auto_'+column_ext])
    trn_ben = array2df(trn, cols =['orig_taz', 'dest_taz', 'transit_'+column_ext])
    nm_ben = array2df(nm, cols =['orig_taz', 'dest_taz', 'non-motorized_'+column_ext])
    rh_ben = array2df(rh, cols =['orig_taz', 'dest_taz', 'ridehail_'+column_ext])

    # merge all the dataframe on origin and destination TAZ
    all_benefits_tp = pd.merge(auto_ben, trn_ben, on = ['orig_taz', 'dest_taz'], how='left').merge(
                                        nm_ben, on = ['orig_taz', 'dest_taz'], how='left').merge(
                                        rh_ben, on = ['orig_taz', 'dest_taz'], how='left')
    
    print("writing parquet file")
    all_benefits_tp.to_parquet(_join(benefits_folder, f"{column_ext}_{tp_name}_{purp}_{auto_suff}.parquet"))

if __name__ == "__main__":

    # # model folders for R39 and R41
    # # RS: Prefereably, do not include baseline folders in the list below. If you include them, nothing will go wrong, though.
    # model_folders = ['W:\TM2_2050R39_R2_Run4', 'W:\TM2_2050R41_R2_Run4']
    # model_folders = ['W:\TM2_2050R40_R2_Run2']
    # model_folders = ['W:\TM2_2050STR39_R2_Run2', 'W:\TM2_2050STR40_R2_Run1', 'W:\TM2_2050STR41_R2_Run2']
    # model_folders = ['W:\TM2_2050R39_R2_Run6', 'W:\TM2_2050R40_R2_Run4', 'W:\TM2_2050R41_R2_Run6']
    # model_folders = ['W:\TM2_2050STR40_R2_Run1_VY']
    # model_folders = ['D:\TM2_2050STR39_R2_Run2_VY', 'D:\TM2_2050STR41_R2_Run2_VY']
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
        #'Z:\TM2_2050_STR39_Run2_Cnvrg',
        'Z:\TM2_2050_STR41_Run2_Cnvrg',
    ]

    for model_dir in model_folders:

        concept = model_dir 

        # path to benefits files
        benefits_scen = 'benefits13'

        benefits_folder = _join(concept, benefits_scen)

        jobs = []
        multi =True

        if multi:
          
            for tripPeriod in time_period:

                for auto_suff in  auto_suff_cat:
                    
                    for purp in purpose:

                        tp_name = time_period[tripPeriod]
                        p = Process(target=create_parquet, args=(benefits_folder,
                                                                "benefits_cls", #Update this as needed - #"benefits_ls", #"ls_diff", #"benefits", #benefits_cls
                                                                tp_name, 
                                                                auto_suff, 
                                                                purp
                                                            ))
                        
                        p.start()
                        jobs.append(p)


                #wait for all thread to complete
                for j in jobs:
                    j.join() 

                errcheck = [j.exitcode for j in jobs]

                if 1 in errcheck:
                    print('Error encountered.')
                else:
                    print("All processing completed.")
