import os
import numpy as np
import openmatrix as omx
import pickle
from multiprocessing import Process
import yaml


with open('config.yaml', 'r') as file:
    params = yaml.safe_load(file)
_join = os.path.join

ctramp_dir = params['ctramp_dir']
preprocess_dir = _join(ctramp_dir, '_pre_process_files')

# Define your time periods and purposes

purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 

# Define your nesting coefficients
auto_nesting_coef = 0.72
trn_nesting_coef = 0.72
nm_nest_coef = 0.72
ridehail_nest_coef = 1.0

# Function to process one time period and purpose
def process_time_period_purpose(tripPeriod, tp_name):
    
    matrix_dict = {}
    purp_dict = {}
    #all_purp_dict = {}
    for purp in purpose:
        util = omx.open_file(os.path.join(preprocess_dir, f"util_{tripPeriod}_{purp}.omx"))

        for matrix_name in util.list_matrices():
            matrix_data = util[matrix_name][:]
            matrix_data = np.where(matrix_data == 0, -999, matrix_data)
            matrix_dict[matrix_name] = matrix_data

        util.close()

        DA = matrix_dict["DA"]
        SR2 = matrix_dict["SR2"]
        SR3 = matrix_dict["SR3"]
        WALK = matrix_dict["WALK"]
        BIKE = matrix_dict["BIKE"]
        WLK_TRN_WLK = matrix_dict["WLK_TRN_WLK"]
        WLK_TRN_PNR = matrix_dict["WLK_TRN_PNR"]
        PNR_TRN_WLK = matrix_dict["PNR_TRN_WLK"]
        WLK_TRN_PNR = matrix_dict["WLK_TRN_PNR"]
        WLK_TRN_KNR = matrix_dict["WLK_TRN_KNR"]
        KNR_TRN_WLK = matrix_dict["KNR_TRN_WLK"]
        RIDEHAIL = matrix_dict["RIDEHAIL"]

        exp_auto = (
            np.exp(DA / auto_nesting_coef)
            + np.exp(SR2 / auto_nesting_coef)
            + np.exp(SR3 / auto_nesting_coef)
        )

        auto_ls = np.where(exp_auto > 0, auto_nesting_coef * (np.log(exp_auto)), 0)

        exp_trn = (
            np.exp(WLK_TRN_WLK / trn_nesting_coef)
            + np.exp(WLK_TRN_PNR / trn_nesting_coef)
            + np.exp(PNR_TRN_WLK / trn_nesting_coef)
            + np.exp(WLK_TRN_KNR / trn_nesting_coef)
            + np.exp(KNR_TRN_WLK / trn_nesting_coef)
        )

        trn_ls = np.where(exp_trn > 0, trn_nesting_coef * (np.log(exp_trn)), 0)

        exp_nm = np.exp(WALK / nm_nest_coef) + np.exp(BIKE / nm_nest_coef)

        non_mot_ls = np.where(exp_nm > 0, nm_nest_coef * (np.log(exp_nm)), 0)

        exp_ridehail = np.exp(RIDEHAIL / ridehail_nest_coef)
        ridehail_ls = np.where(exp_ridehail > 0, ridehail_nest_coef * (np.log(exp_ridehail)), 0)

        allmode_ls = np.log(
            np.exp(auto_ls) + np.exp(trn_ls) + np.exp(non_mot_ls) + np.exp(ridehail_ls)
        )

        sum_ls = np.exp(auto_ls) + np.exp(trn_ls) + np.exp(ridehail_ls) + np.exp(non_mot_ls)

        auto_proportion = np.where(auto_ls != 0, (allmode_ls * (np.exp(auto_ls) / sum_ls)), 0)
        trn_proportion = np.where(trn_ls != 0, (allmode_ls * (np.exp(trn_ls) / sum_ls)), 0)
        rh_proportion = np.where(ridehail_ls != 0, (allmode_ls * (np.exp(ridehail_ls) / sum_ls)), 0)
        nm_proportion = np.where(non_mot_ls != 0, (allmode_ls * (np.exp(non_mot_ls) / sum_ls)), 0)
    
        # Create a dictionary to store data
        data_dict = {
            "exp_auto": exp_auto,
            "auto_ls": auto_ls,
            "exp_trn": exp_trn,
            "trn_ls": trn_ls,
            "exp_nm": exp_nm,
            "non_mot_ls": non_mot_ls,
            "exp_ridehail": exp_ridehail,
            "ridehail_ls": ridehail_ls,
            "allmode_ls": allmode_ls,
            "sum_ls": sum_ls,
            "auto_proportion": auto_proportion,
            "trn_proportion": trn_proportion,
            "rh_proportion": rh_proportion,
            "nm_proportion": nm_proportion,
        }

        # Serialize and save the data as a pickle file
        # Serialize and save the data as a pickle file, with 'purp' as the key
        purp_dict[purp] = data_dict
        #all_purp_dict[purp] = (purp_dict)

    file_path = os.path.join(preprocess_dir, f"logsums_{tp_name}.pkl")
    with open(file_path, "wb") as pickle_file:
        pickle.dump(purp_dict, pickle_file, protocol=pickle.HIGHEST_PROTOCOL)

    print(f"Data has been written to {file_path} for {purp} and {tripPeriod}.")

if __name__ == "__main__":
    preprocess_dir = preprocess_dir  
    time_period = {1:'EA',2:'AM',3:'MD',4:'PM',5:'EV'} 

    # Create a multiprocessing pool
    jobs = []
    multi =True
    # pool = multiprocessing.Pool(processes=multiprocessing.cpu_count())
    if multi:
        # Use the pool to process time periods and purposes in parallel
        for tripPeriod in time_period:
            #pool.apply_async(process_time_period_purpose, (tripPeriod, purp))
            p = Process(target=process_time_period_purpose, args=(tripPeriod, time_period[tripPeriod]))
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
                process_time_period_purpose(tripPeriod, time_period[tripPeriod])
                break
            break

