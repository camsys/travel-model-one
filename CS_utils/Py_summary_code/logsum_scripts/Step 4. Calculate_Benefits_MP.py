import os
import numpy as np
import openmatrix as omx
import pickle
from multiprocessing import Process
import yaml
import pandas as pd
from pathlib import Path

_join = os.path.join


"""
The purpose of the script is to calculate benefits for R39 and R41. 
The benefits are calculated at OD level sgemented by time period, 
purpose and auto sufficiency group. 

"""


def create_benefits_files(
                          tp_name, 
                          baseline,
                          concept,
                          logsum_scen,
                          benefits_folder,
                          auto_suff,
                          purp,
                          purp_ivt
                          ):

    b_ivt = -1*purp_ivt[purp]    
    print(f"{tp_name}_{purp}_{auto_suff}")
    #print(f"reading baseline logsums")
    purp_bl = omx.open_file(_join(baseline, logsum_scen, f'logsums_{tp_name}_{purp}_{auto_suff}.omx'))

    #print(f"reading concept logsums")
    purp_cpt = omx.open_file(_join(concept, logsum_scen, f'logsums_{tp_name}_{purp}_{auto_suff}.omx'))                                

    #print(f"reading baseline trips")
    trp_bl = omx.open_file(_join(baseline, 'trips', f'trips_{tp_name}_{purp}_{auto_suff}.omx'))

    #print(f"reading concept trips")
    trp_cpt = omx.open_file(_join(concept, 'trips', f'trips_{tp_name}_{purp}_{auto_suff}.omx'))
    
    # proportion difference
    auto_proportion_diff = np.array(purp_cpt['auto_proportion']) - np.array(purp_bl['auto_proportion'])
    trn_proportion_diff = np.array(purp_cpt['trn_proportion']) - np.array(purp_bl['trn_proportion'])
    nm_proportion_diff = np.array(purp_cpt['nm_proportion']) - np.array(purp_bl['nm_proportion'])
    rh_proportion_diff = np.array(purp_cpt['rh_proportion']) - np.array(purp_bl['rh_proportion'])

    # composite logsum differences
    composite_LS_cpt = np.array(purp_cpt['auto_proportion']) + np.array(purp_cpt['trn_proportion']) \
                       + np.array(purp_cpt['nm_proportion']) + np.array(purp_cpt['rh_proportion'])
    composite_LS_bl = np.array(purp_bl['auto_proportion']) + np.array(purp_bl['trn_proportion']) \
                      + np.array(purp_bl['nm_proportion']) + np.array(purp_bl['rh_proportion'])
    composite_LS_diff = composite_LS_cpt - composite_LS_bl

    # pure logsum difference
    auto_ls_diff = np.array(purp_cpt['auto_ls']) - np.array(purp_bl['auto_ls'])
    trn_ls_diff = np.array(purp_cpt['trn_ls']) - np.array(purp_bl['trn_ls'])
    nm_ls_diff = np.array(purp_cpt['non_mot_ls']) - np.array(purp_bl['non_mot_ls'])
    rh_ls_diff = np.array(purp_cpt['ridehail_ls']) - np.array(purp_bl['ridehail_ls'])
    
    # trips difference
    auto_trips_nu = np.array(trp_cpt['auto_trips']) - np.array(trp_bl['auto_trips'])
    trn_trips_nu = np.array( trp_cpt['trn_trips']) - np.array(trp_bl['trn_trips'])
    nm_trips_nu = np.array(trp_cpt['nm_trips']) - np.array(trp_bl['nm_trips'])
    rh_trips_nu = np.array(trp_cpt['rh_trips']) - np.array(trp_bl['rh_trips'])
    
    #auto_trips_nu[auto_trips_nu<0] = 0
    #trn_trips_nu[trn_trips_nu<0] = 0
    #nm_trips_nu[nm_trips_nu<0] = 0
    #rh_trips_nu[rh_trips_nu<0] = 0

    #print(f"calculate benefits -- proportions")
    auto_benefits_eu = (trp_bl['auto_trips']) * auto_proportion_diff / b_ivt
    trn_benefits_eu = (trp_bl['trn_trips']) * trn_proportion_diff / b_ivt
    nm_benefits_eu = (trp_bl['nm_trips']) * nm_proportion_diff / b_ivt
    rh_benefits_eu = (trp_bl['rh_trips']) * rh_proportion_diff / b_ivt
    
    #new users
    auto_benefits_nu = (auto_trips_nu) * auto_proportion_diff * 0.5 /b_ivt
    trn_benefits_nu = (trn_trips_nu) * trn_proportion_diff * 0.5 / b_ivt
    nm_benefits_nu = (nm_trips_nu) * nm_proportion_diff * 0.5 / b_ivt
    rh_benefits_nu = (rh_trips_nu) * rh_proportion_diff * 0.5 / b_ivt
    
    # print(f"calculate benefits -- logsum nests")
    auto_benefits_eu_ls = (trp_bl['auto_trips']) * auto_ls_diff / b_ivt
    trn_benefits_eu_ls = (trp_bl['trn_trips']) * trn_ls_diff / b_ivt
    nm_benefits_eu_ls = (trp_bl['nm_trips']) * nm_ls_diff / b_ivt
    rh_benefits_eu_ls = (trp_bl['rh_trips']) * rh_ls_diff / b_ivt
    
    # new users
    auto_benefits_nu_ls = (auto_trips_nu) * auto_ls_diff * 0.5 /b_ivt
    trn_benefits_nu_ls = (trn_trips_nu) * trn_ls_diff * 0.5 / b_ivt
    nm_benefits_nu_ls = (nm_trips_nu) * nm_ls_diff * 0.5 / b_ivt
    rh_benefits_nu_ls = (rh_trips_nu) * rh_ls_diff * 0.5 / b_ivt
        
    # print(f"calculate benefits -- composite logsums")
    auto_benefits_eu_cls = (trp_bl['auto_trips']) * composite_LS_diff / b_ivt
    trn_benefits_eu_cls = (trp_bl['trn_trips']) * composite_LS_diff / b_ivt
    nm_benefits_eu_cls = (trp_bl['nm_trips']) * composite_LS_diff / b_ivt
    rh_benefits_eu_cls = (trp_bl['rh_trips']) * composite_LS_diff / b_ivt
    
    # new users -- composite logsums
    auto_benefits_nu_cls = (auto_trips_nu) * composite_LS_diff * 0.5 /b_ivt
    trn_benefits_nu_cls = (trn_trips_nu) * composite_LS_diff * 0.5 / b_ivt
    nm_benefits_nu_cls = (nm_trips_nu) * composite_LS_diff * 0.5 / b_ivt
    rh_benefits_nu_cls = (rh_trips_nu) * composite_LS_diff * 0.5 / b_ivt

    #all benefits - proportion method 
    auto_benefits_pr = (np.array(trp_cpt['auto_trips']) + np.array(trp_bl['auto_trips'])) * auto_proportion_diff * 0.5 / b_ivt
    trn_benefits_pr = (np.array( trp_cpt['trn_trips']) + np.array(trp_bl['trn_trips'])) * trn_proportion_diff * 0.5 / b_ivt
    nm_benefits_pr = (np.array(trp_cpt['nm_trips']) + np.array(trp_bl['nm_trips'])) * nm_proportion_diff * 0.5 / b_ivt
    rh_benefits_pr = (np.array(trp_cpt['rh_trips']) + np.array(trp_bl['rh_trips'])) * rh_proportion_diff * 0.5 / b_ivt

    #all benefits using logsums method
    auto_benefits_ls = (np.array(trp_cpt['auto_trips']) + np.array(trp_bl['auto_trips'])) * auto_ls_diff * 0.5 / b_ivt
    trn_benefits_ls = (np.array( trp_cpt['trn_trips']) + np.array(trp_bl['trn_trips'])) * trn_ls_diff * 0.5 / b_ivt
    nm_benefits_ls = (np.array(trp_cpt['nm_trips']) + np.array(trp_bl['nm_trips'])) * nm_ls_diff * 0.5 / b_ivt
    rh_benefits_ls = (np.array(trp_cpt['rh_trips']) + np.array(trp_bl['rh_trips'])) * rh_ls_diff * 0.5 / b_ivt

    #all benefits composite logsums method
    auto_benefits_cls = (np.array(trp_cpt['auto_trips']) + np.array(trp_bl['auto_trips'])) * composite_LS_diff * 0.5 / b_ivt
    trn_benefits_cls = (np.array( trp_cpt['trn_trips']) + np.array(trp_bl['trn_trips'])) * composite_LS_diff * 0.5 / b_ivt
    nm_benefits_cls = (np.array(trp_cpt['nm_trips']) + np.array(trp_bl['nm_trips'])) * composite_LS_diff * 0.5 / b_ivt
    rh_benefits_cls = (np.array(trp_cpt['rh_trips']) + np.array(trp_bl['rh_trips'])) * composite_LS_diff * 0.5 / b_ivt

    # Write to OMX
    benefits_omx = omx.open_file(_join(benefits_folder, f"benefits_{tp_name}_{purp}_{auto_suff}_bivt_mp.omx"), 'w')

    # Trips
    benefits_omx['auto_trips_nu'] = auto_trips_nu
    benefits_omx['trn_trips_nu'] = trn_trips_nu
    benefits_omx['nm_trips_nu'] = nm_trips_nu
    benefits_omx['rh_trips_nu'] = rh_trips_nu

    benefits_omx['auto_trips_eu'] = trp_bl['auto_trips']
    benefits_omx['trn_trips_eu'] = trp_bl['trn_trips']
    benefits_omx['nm_trips_eu'] = trp_bl['nm_trips']
    benefits_omx['rh_trips_eu'] = trp_bl['rh_trips']

    benefits_omx['auto_trips_all'] = np.array(trp_cpt['auto_trips']) + np.array(trp_bl['auto_trips'])
    benefits_omx['trn_trips_all'] = np.array( trp_cpt['trn_trips']) + np.array(trp_bl['trn_trips'])
    benefits_omx['nm_trips_all'] = np.array(trp_cpt['nm_trips']) + np.array(trp_bl['nm_trips'])
    benefits_omx['rh_trips_all'] = np.array(trp_cpt['rh_trips']) + np.array(trp_bl['rh_trips'])

    # Proportioned logsums
    benefits_omx['auto_proportion_diff'] = auto_proportion_diff
    benefits_omx['trn_proportion_diff'] = trn_proportion_diff
    benefits_omx['nm_proportion_diff'] = nm_proportion_diff
    benefits_omx['rh_proportion_diff'] = rh_proportion_diff

    benefits_omx['auto_benefits_eu'] = auto_benefits_eu
    benefits_omx['trn_benefits_eu'] = trn_benefits_eu
    benefits_omx['nm_benefits_eu'] = nm_benefits_eu
    benefits_omx['rh_benefits_eu'] = rh_benefits_eu

    benefits_omx['auto_benefits_nu'] = auto_benefits_nu
    benefits_omx['trn_benefits_nu'] = trn_benefits_nu
    benefits_omx['nm_benefits_nu'] = nm_benefits_nu
    benefits_omx['rh_benefits_nu'] = rh_benefits_nu

    benefits_omx['auto_benefits_pr'] = auto_benefits_pr
    benefits_omx['trn_benefits_pr'] = trn_benefits_pr
    benefits_omx['nm_benefits_pr'] = nm_benefits_pr
    benefits_omx['rh_benefits_pr'] = rh_benefits_pr

    # Logsum nests
    benefits_omx['auto_ls_diff'] = auto_ls_diff
    benefits_omx['trn_ls_diff'] = trn_ls_diff
    benefits_omx['nm_ls_diff'] = nm_ls_diff
    benefits_omx['rh_ls_diff'] = rh_ls_diff

    benefits_omx['auto_benefits_eu_ls'] = auto_benefits_eu_ls
    benefits_omx['trn_benefits_eu_ls'] = trn_benefits_eu_ls
    benefits_omx['nm_benefits_eu_ls'] = nm_benefits_eu_ls
    benefits_omx['rh_benefits_eu_ls'] = rh_benefits_eu_ls

    benefits_omx['auto_benefits_nu_ls'] = auto_benefits_nu_ls
    benefits_omx['trn_benefits_nu_ls'] = trn_benefits_nu_ls
    benefits_omx['nm_benefits_nu_ls'] = nm_benefits_nu_ls
    benefits_omx['rh_benefits_nu_ls'] = rh_benefits_nu_ls

    benefits_omx['auto_benefits_ls'] = auto_benefits_ls
    benefits_omx['trn_benefits_ls'] = trn_benefits_ls
    benefits_omx['nm_benefits_ls'] = nm_benefits_ls
    benefits_omx['rh_benefits_ls'] = rh_benefits_ls

    # Composite logsums
    benefits_omx['composite_LS_diff'] = composite_LS_diff
    
    benefits_omx['auto_benefits_eu_cls'] = auto_benefits_eu_cls
    benefits_omx['trn_benefits_eu_cls'] = trn_benefits_eu_cls
    benefits_omx['nm_benefits_eu_cls'] = nm_benefits_eu_cls
    benefits_omx['rh_benefits_eu_cls'] = rh_benefits_eu_cls

    benefits_omx['auto_benefits_nu_cls'] = auto_benefits_nu_cls
    benefits_omx['trn_benefits_nu_cls'] = trn_benefits_nu_cls
    benefits_omx['nm_benefits_nu_cls'] = nm_benefits_nu_cls
    benefits_omx['rh_benefits_nu_cls'] = rh_benefits_nu_cls

    benefits_omx['auto_benefits_cls'] = auto_benefits_cls
    benefits_omx['trn_benefits_cls'] = trn_benefits_cls
    benefits_omx['nm_benefits_cls'] = nm_benefits_cls
    benefits_omx['rh_benefits_cls'] = rh_benefits_cls

    benefits_omx.close()
    
    purp_bl.close()
    purp_cpt.close()
    trp_bl.close()
    trp_cpt.close()



if __name__ == "__main__":

    # path to model folders
    # model_folders = ['W:\TM2_2050R39_R2_Run4', 'W:\TM2_2050R41_R2_Run4']
    # model_folders = ['W:\TM2_2050R40_R2_Run2']
    # model_folders = ['W:\TM2_2050R39_R2_Run6', 'W:\TM2_2050R40_R2_Run4', 'W:\TM2_2050R41_R2_Run6']
    # model_folders = ['W:\TM2_2050STR40_R2_Run1_VY'] #, 'D:\TM2_2050STR39_R2_Run2_VY', 'D:\TM2_2050STR41_R2_Run2_VY']    
    # model_folders = ['D:\TM2_2050STR40_R2_Run1_Conv']
    # model_folders = [        
    #     'Z:\TM2_2050_R40_R2_Run3_PopTest_Run1',
    #     'Z:\TM2_2050_R41_PopTest_Run1',        
    #     'Z:\TM2_2050_R40_R2_Run3_TollTest_Run1',
    #     'Z:\TM2_2050_R41_TollTest_Run1',        
    #     'Z:\TM2_2050_R40_R2_Run3_COVID_Run1',
    #     'Z:\TM2_2050_R41_COVID_Run1'
    # ]
    # model_folders = [             
    #     'Z:\TM2_2050_R40_R2_Run3_COVID_Run1',
    #     'Z:\TM2_2050_R41_COVID_Run1'
    # ]
    model_folders = [
        #'Z:\TM2_2050_STR39_Run2_Cnvrg',
        'Z:\TM2_2050_STR41_Run2_Cnvrg'
    ]

    # path to baseline run model directory
    # baseline = r'W:\TM2_2050Baseline_R2_Run4'
    # baseline_folders = ['W:\TM2_2050Baseline_R2_Run7', 'W:\TM2_2050Baseline_R2_Run7_Copy1', 'W:\TM2_2050Baseline_R2_Run7_Copy2']
    # baseline_folders = ['W:\TM2_2050Baseline_R2_Run7', 'W:\TM2_2050Baseline_R2_Run7', 'W:\TM2_2050Baseline_R2_Run7']
    # baseline_folders = ['W:\TM2_2050R40_R2_Run2_VY'] #, 'D:\TM2_2050R39_R2_Run4_VY', 'D:\TM2_2050R41_R2_Run4_VY']
    # baseline_folders = ['D:\TM2_2050R40_R2_Run2_Conv']
    # baseline_folders = [
    #     'Z:\TM2_2050_BL_R2_Run6_PopTest_Run2',
    #     'Z:\TM2_2050_BL_R2_Run6_PopTest_Run2',
    #     'Z:\TM2_2050_BL_R2_Run6_TollTest_Run2',
    #     'Z:\TM2_2050_BL_R2_Run6_TollTest_Run2',
    #     'Z:\TM2_2050_BL_R2_Run6_COVID_Run3',
    #     'Z:\TM2_2050_BL_R2_Run6_COVID_Run3'
    # ]
    # baseline_folders = [    
    #     'Z:\TM2_2050_BL_R2_Run6_COVID_Run3',
    #     'Z:\TM2_2050_BL_R2_Run6_COVID_Run3'
    # ]
    baseline_folders = [
        #'D:\TM2_2050R39_R2_Run4_Conv',
        'D:\TM2_2050R41_R2_Run4_Conv',  
    ]

    folder_comb = zip(model_folders, baseline_folders)

    # purpose 
    purpose = ['Work', 'University', 'School', 'Escort', 'Shopping', 'EatOut', 
           'OthMaint', 'Social', 'OthDiscr', 'WorkBased'] 
    
    # time period
    time_period = {1:'EA',2:'AM',3:'MD',4:'PM',5:'EV'} 

    # auto sufficiency categories
    auto_suff_cat = ['autoSufficient', 'autoDeficient', 'zeroAuto']


    # loop over the model folders
    for model_dir, baseline_dir in folder_comb: #model_folders:

        
        concept = model_dir
        baseline = baseline_dir 
        # path to logsum files
        logsum_scen = 'logsums11'

        # path to store benefits file
        benefits_scen = 'benefits13'

        benefits_folder = _join(concept, benefits_scen)
        Path(benefits_folder).mkdir(parents=True, exist_ok=True)
        
        purp_ivt =  pd.read_csv("bivt_purpose.csv") # has the beta IVT values for each purpose
        purp_ivt = dict(zip(purp_ivt['util_purpose'], round(purp_ivt['b_ivt'],4)))


        # jobs = []
        multi =True

        if multi:

            # for tripPeriod in time_period:
            #     for auto_suff in  auto_suff_cat:
            #         for purp in purpose:
            #             tp_name = time_period[tripPeriod]
            #             p = Process(target=create_benefits_files, args=( 
            #                                                             tp_name, 
            #                                                             baseline,
            #                                                             concept,
            #                                                             logsum_scen,
            #                                                             benefits_folder,
            #                                                             auto_suff,
            #                                                             purp,
            #                                                             purp_ivt
            #                                                             ))
            #             p.start()
            #             jobs.append(p)


            # #wait for all thread to complete
            # for j in jobs:
            #     j.join() 

            # errcheck = [j.exitcode for j in jobs]
            
            # if 1 in errcheck:
            #     print('Error encountered.')
            # else:
            #     print("All processing completed.")

            for auto_suff in  auto_suff_cat:
                print(f'\n\n\nAuto Sufficiency: {auto_suff}')
                print('============================================')
                jobs = []
                for tripPeriod in time_period:                
                    for purp in purpose:
                        tp_name = time_period[tripPeriod]
                        p = Process(target=create_benefits_files, args=( 
                                                                        tp_name, 
                                                                        baseline,
                                                                        concept,
                                                                        logsum_scen,
                                                                        benefits_folder,
                                                                        auto_suff,
                                                                        purp,
                                                                        purp_ivt
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
