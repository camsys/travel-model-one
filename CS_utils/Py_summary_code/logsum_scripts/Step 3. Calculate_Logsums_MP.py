import os
import numpy as np
import openmatrix as omx
import pickle
from multiprocessing import Process
from pathlib import Path


_join = os.path.join


"""
Summary: The purpose of this script is to create logsums for each model run (baseline, R39 and R41).
The script uses multiprocessing to iterate over time period, purpose and auto sufficiency groups to 
read the utilities, add ASCs and calculate nest logsums/compostite logsums/nest proportions for
each od pair and save them as separate OMX files (total 150 files)

"""


# Define your time periods, purposes and auto sufficiency
purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 

auto_suff_cat = ['autoSufficient', 'autoDeficient', 'zeroAuto']

time_period = {1:'EA',2:'AM',3:'MD',4:'PM',5:'EV'} 

# Define your nesting coefficients
auto_nesting_coef = 0.72
trn_nesting_coef = 0.72
nm_nest_coef = 0.72
ridehail_nest_coef = 1.0


# Function to process one time period and purpose
def process_time_period_purpose(tripPeriod, 
                                tp_name, 
                                constants_dir,
                                auto_suff,
                                output_dir,
                                preprocess_dir,
                                purp,
                                ):
    
    """
    This function reads the utility files, ASC files and geography ASC files 
    and calculates the final utilities for each mode. The nest logsums
    are calculated using the nest coefficients and utilities for each mode within 
    the nest. The final logsums for each od pair segmented by time period, purpose 
    and auto sufficiency group are stored separately in OMX files.  
    
    """
    
    matrix_dict = {}

    # read the utility file for the time period and purpose 
    util = omx.open_file(os.path.join(preprocess_dir, f"util_{tripPeriod}_{purp}.omx"))

    # read all the data from the utility file and store them as dictionary
    for matrix_name in util.list_matrices():
        matrix_data = util[matrix_name][:]

        # if the utility for an OD pair is zero then assign -999 
        matrix_data = np.where(matrix_data == 0, -999, matrix_data)
        matrix_dict[matrix_name] = matrix_data

    # close OMX fie
    util.close()

    # read ASCs by mode
    asc_mats = omx.open_file(_join(constants_dir, f'ASC_{purp}_{auto_suff}.omx'))

    sr2_asc = np.array(asc_mats['sr2_asc'])
    sr3_asc = np.array(asc_mats['sr3_asc'])
    walk_asc = np.array(asc_mats['walk_asc'])
    bike_asc = np.array(asc_mats['bike_asc'])
    rh_asc = np.array(asc_mats['rh_asc'])
    WtW_asc = np.array(asc_mats['WtW_asc'])
    KnR_asc = np.array(asc_mats['KnR_asc'])
    PnR_asc = np.array(asc_mats['PnR_asc'])

    # close OMX file
    asc_mats.close()


    # read Constants by Geography
    geo_omx = omx.open_file(_join(constants_dir, f'ASC_geography_{purp}.omx'))

    walk_transit = np.array(geo_omx['walk_transit'])
    drive_transit = np.array(geo_omx['drive_transit'])

    geo_omx.close()

    # add the ASC to utilities by mode
    DA = matrix_dict["DA"] 
    SR2 = matrix_dict["SR2"] + sr2_asc
    SR3 = matrix_dict["SR3"] + sr3_asc
    WALK = matrix_dict["WALK"] + walk_asc
    BIKE = matrix_dict["BIKE"] + bike_asc
    WLK_TRN_WLK = matrix_dict["WLK_TRN_WLK"] + WtW_asc + walk_transit
    WLK_TRN_PNR = matrix_dict["WLK_TRN_PNR"] + PnR_asc + drive_transit
    PNR_TRN_WLK = matrix_dict["PNR_TRN_WLK"] + PnR_asc + drive_transit
    WLK_TRN_KNR = matrix_dict["WLK_TRN_KNR"] + KnR_asc + drive_transit
    KNR_TRN_WLK = matrix_dict["KNR_TRN_WLK"] + KnR_asc + drive_transit
    RIDEHAIL = matrix_dict["RIDEHAIL"] + rh_asc

    #auto nest
    exp_auto = (
        np.exp(DA / auto_nesting_coef)
        + np.exp(SR2 / auto_nesting_coef)
        + np.exp(SR3 / auto_nesting_coef)
    )

    #auto logsums
    auto_ls = np.where(exp_auto > 0, auto_nesting_coef * (np.log(exp_auto)), 0)

    # transit nest
    exp_trn = (
        np.exp(WLK_TRN_WLK / trn_nesting_coef)
        + np.exp(WLK_TRN_PNR / trn_nesting_coef)
        + np.exp(PNR_TRN_WLK / trn_nesting_coef)
        + np.exp(WLK_TRN_KNR / trn_nesting_coef)
        + np.exp(KNR_TRN_WLK / trn_nesting_coef)
    )

    # transit logsums
    trn_ls = np.where(exp_trn > 0, trn_nesting_coef * (np.log(exp_trn)), 0)

    # non motorized nest
    exp_nm = np.exp(WALK / nm_nest_coef) + np.exp(BIKE / nm_nest_coef)

    # non motorized logsums
    non_mot_ls = np.where(exp_nm > 0, nm_nest_coef * (np.log(exp_nm)), 0)

    # ridehail nest and logsums
    exp_ridehail = np.exp(RIDEHAIL / ridehail_nest_coef)
    ridehail_ls = np.where(exp_ridehail > 0, ridehail_nest_coef * (np.log(exp_ridehail)), 0)

    # composite logsums
    allmode_ls = np.log(
        np.exp(auto_ls) + np.exp(trn_ls) + np.exp(non_mot_ls) + np.exp(ridehail_ls)
    )

    # sum of all nest logsums
    sum_ls = np.exp(auto_ls) + np.exp(trn_ls) + np.exp(ridehail_ls) + np.exp(non_mot_ls)

    # nest proportion (Auto, Transit, non-motorized and ridehail) of the composite logsums
    auto_proportion = np.where(auto_ls != 0, (allmode_ls * (np.exp(auto_ls) / sum_ls)), 0)
    trn_proportion = np.where(trn_ls != 0, (allmode_ls * (np.exp(trn_ls) / sum_ls)), 0)
    rh_proportion = np.where(ridehail_ls != 0, (allmode_ls * (np.exp(ridehail_ls) / sum_ls)), 0)
    nm_proportion = np.where(non_mot_ls != 0, (allmode_ls * (np.exp(non_mot_ls) / sum_ls)), 0)

    # write logsums to file
    logsums_omx = omx.open_file(_join(output_dir, f"logsums_{tp_name}_{purp}_{auto_suff}.omx"),'w') 

    # Create a dictionary to store data
    logsums_omx["exp_auto"] = exp_auto
    logsums_omx["auto_ls"] = auto_ls
    logsums_omx["exp_trn"] = exp_trn
    logsums_omx["trn_ls"] = trn_ls
    logsums_omx["exp_nm"] = exp_nm
    logsums_omx["non_mot_ls"] = non_mot_ls
    logsums_omx["exp_ridehail"] = exp_ridehail
    logsums_omx["ridehail_ls"] = ridehail_ls
    logsums_omx["allmode_ls"] = allmode_ls
    logsums_omx["sum_ls"] = sum_ls
    logsums_omx["auto_proportion"]= auto_proportion
    logsums_omx["trn_proportion"] = trn_proportion
    logsums_omx["rh_proportion"] = rh_proportion
    logsums_omx["nm_proportion"] = nm_proportion

    logsums_omx.close()

if __name__ == "__main__":

    # model_folders = ['W:\TM2_2050Baseline_R2_Run4', 'W:\TM2_2050R39_R2_Run4', 'W:\TM2_2050R41_R2_Run4']
    # model_folders = ['W:\TM2_2050R40_R2_Run2']
    # model_folders = ['W:\TM2_2050STR39_R2_Run2', 'W:\TM2_2050STR40_R2_Run1', 'W:\TM2_2050STR41_R2_Run2']
    # model_folders = ['W:\TM2_2050Baseline_R2_Run7', 'W:\TM2_2050R39_R2_Run6', 'W:\TM2_2050R40_R2_Run4', 'W:\TM2_2050R41_R2_Run6']
    # model_folders = ['W:\TM2_2050STR40_R2_Run1_VY']
    # model_folders = ['W:\TM2_2050R40_R2_Run2_VY', 'D:\TM2_2050R39_R2_Run4_VY', 'D:\TM2_2050STR39_R2_Run2_VY', 
                    #  'D:\TM2_2050R41_R2_Run4_VY', 'D:\TM2_2050STR41_R2_Run2_VY']
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
    #     'Z:\TM2_2050_R39_R2_Run6_Cnvrg',
    #     'Z:\TM2_2050_R41_R2_Run6_Cnvrg',
    #     'Z:\TM2_2050_STR39_Run2_Cnvrg',
    #     'Z:\TM2_2050_STR41_Run2_Cnvrg'
    # ]

    #model_folders = [
    #    'D:\TM2_2050R41_R2_Run4_Conv',
    #    'D:\TM2_2050R39_R2_Run4_Conv',
    #]

    model_folders = [
        'D:\TM2_2050R41_R2_Run4_Conv',
        'Z:\TM2_2050_STR41_Run2_Cnvrg',
    ]

    

    for model_dir in model_folders:

        #path to utilities
        preprocess_dir = _join(model_dir, '_pre_process', 'util_rev')

        # path to save the logsums
        output_dir = _join(model_dir, 'logsums11')
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        jobs = []
        multi =True
        
        # path to constants
        constants_dir = _join(r"W:\constants")

        if multi:
            for tripPeriod in time_period:
                for auto_suff in auto_suff_cat:
                    for purp in purpose:

                        p = Process(target=process_time_period_purpose, args=(tripPeriod, 
                                                                            time_period[tripPeriod],
                                                                            constants_dir, 
                                                                            auto_suff,
                                                                            output_dir,
                                                                            preprocess_dir,
                                                                            purp,
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

        else:
            for tripPeriod in time_period:
                for auto_suff in auto_suff_cat:
                    for purp in purpose:
                        process_time_period_purpose(tripPeriod, 
                                                    time_period[tripPeriod],
                                                    constants_dir, 
                                                    auto_suff,
                                                    output_dir,
                                                    preprocess_dir,
                                                    purp,
                                                    )
                        break
                    break
                break

