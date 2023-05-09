## created by Li Jin on 1/2/2023 to extract best transit path for each od pair.
# importing Python multiprocessing module
import multiprocessing
from Readpath_extractpath_function_2 import *

if __name__ == "__main__":
    ## args [1] is InFile. This is the input zip file name of the path file
    ## args [2] is InZippedTxtFileName. This is the text file name in the zip file
    ## args [3] is AccessandEgress_modes. This is for access and egress modes
        ## AccessandEgress_modes is 1 for WLK_TRN_WLK.
        ## AccessandEgress_modes is 2 for PNR_TRN_WLK.
        ## AccessandEgress_modes is 3 for WLK_TRN_PNR.
        ## AccessandEgress_modes is 4 for KNR_TRN_WLK.
        ## AccessandEgress_modes is 5 for WLK_TRN_KNR.
    ## args [4] is OutFile. This is the output file name
    ## args [5] is Interchange. This is the indicator using interchange list or not
        ## AccessandEgress_modes is 0 using all paths.
        ## AccessandEgress_modes is 1 using paths only for OD zones in the interchange list file.
    ## args [6] is InModes. This is the modes lookup file for different time period.
    ## args [7] is OutFile2.
    ## args [8] is OutFile3.

    ## ea
    proc1 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ea_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ea_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt",1,
    "ea_WLK_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv",0,"Modes_onlymodeandorigmode_am.csv",
    "ea_WLK_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ea_WLK_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc2 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ea_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ea_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ea_PNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ea_PNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ea_PNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc3 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ea_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ea_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ea_WLK_TRN_PNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ea_WLK_TRN_PNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ea_WLK_TRN_PNR_Link21_3332_0302_feedback_pathresults.csv"))
    proc4 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ea_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ea_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ea_KNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ea_KNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ea_KNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc5 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ea_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ea_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ea_WLK_TRN_KNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ea_WLK_TRN_KNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ea_WLK_TRN_KNR_Link21_3332_0302_feedback_pathresults.csv"))

    ## am
    proc6 = multiprocessing.Process(target=extractpath, args=(
    "path_details_am_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_am_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.txt",1,
    "am_WLK_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv",0,"Modes_onlymodeandorigmode_am.csv",
    "am_WLK_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "am_WLK_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc7 = multiprocessing.Process(target=extractpath, args=(
    "path_details_am_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_am_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "am_PNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "am_PNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "am_PNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc8 = multiprocessing.Process(target=extractpath, args=(
    "path_details_am_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_am_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "am_WLK_TRN_PNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "am_WLK_TRN_PNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "am_WLK_TRN_PNR_Link21_3332_0302_feedback_pathresults.csv"))
    proc9 = multiprocessing.Process(target=extractpath, args=(
    "path_details_am_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_am_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "am_KNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "am_KNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "am_KNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc10 = multiprocessing.Process(target=extractpath, args=(
    "path_details_am_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_am_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "am_WLK_TRN_KNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "am_WLK_TRN_KNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "am_WLK_TRN_KNR_Link21_3332_0302_feedback_pathresults.csv"))

    ## md
    proc11 = multiprocessing.Process(target=extractpath, args=(
    "path_details_md_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_md_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt",1,
    "md_WLK_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv",0,"Modes_onlymodeandorigmode_am.csv",
    "md_WLK_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "md_WLK_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc12 = multiprocessing.Process(target=extractpath, args=(
    "path_details_md_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_md_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "md_PNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "md_PNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "md_PNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc13 = multiprocessing.Process(target=extractpath, args=(
    "path_details_md_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_md_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "md_WLK_TRN_PNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "md_WLK_TRN_PNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "md_WLK_TRN_PNR_Link21_3332_0302_feedback_pathresults.csv"))
    proc14 = multiprocessing.Process(target=extractpath, args=(
    "path_details_md_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_md_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "md_KNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "md_KNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "md_KNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc15 = multiprocessing.Process(target=extractpath, args=(
    "path_details_md_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_md_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "md_WLK_TRN_KNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "md_WLK_TRN_KNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "md_WLK_TRN_KNR_Link21_3332_0302_feedback_pathresults.csv"))

    ## pm
    proc16 = multiprocessing.Process(target=extractpath, args=(
    "path_details_pm_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_pm_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.txt",1,
    "pm_WLK_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv",0,"Modes_onlymodeandorigmode_am.csv",
    "pm_WLK_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "pm_WLK_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc17 = multiprocessing.Process(target=extractpath, args=(
    "path_details_pm_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_pm_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "pm_PNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "pm_PNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "pm_PNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc18 = multiprocessing.Process(target=extractpath, args=(
    "path_details_pm_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_pm_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "pm_WLK_TRN_PNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "pm_WLK_TRN_PNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "pm_WLK_TRN_PNR_Link21_3332_0302_feedback_pathresults.csv"))
    proc19 = multiprocessing.Process(target=extractpath, args=(
    "path_details_pm_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_pm_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "pm_KNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "pm_KNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "pm_KNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc20 = multiprocessing.Process(target=extractpath, args=(
    "path_details_pm_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 2.zip",
    "path_details_pm_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 2.txt", 1,
    "pm_WLK_TRN_KNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "pm_WLK_TRN_KNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "pm_WLK_TRN_KNR_Link21_3332_0302_feedback_pathresults.csv"))

    ## ev
    proc21 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ev_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ev_WLK_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt",1,
    "ev_WLK_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv",0,"Modes_onlymodeandorigmode_am.csv",
    "ev_WLK_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ev_WLK_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc22 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ev_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ev_PNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ev_PNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ev_PNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ev_PNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc23 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ev_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ev_WLK_TRN_PNR_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ev_WLK_TRN_PNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ev_WLK_TRN_PNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ev_WLK_TRN_PNR_Link21_3332_0302_feedback_pathresults.csv"))
    proc24 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ev_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ev_KNR_TRN_WLK_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ev_KNR_TRN_WLK_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ev_KNR_TRN_WLK_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ev_KNR_TRN_WLK_Link21_3332_0302_feedback_pathresults.csv"))
    proc25 = multiprocessing.Process(target=extractpath, args=(
    "path_details_ev_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 1.zip",
    "path_details_ev_WLK_TRN_KNR_Link21_3332_0302_feedback_Iteration 1.txt", 1,
    "ev_WLK_TRN_KNR_Link21_3332_0302_feedback_bestpathresults.csv", 0, "Modes_onlymodeandorigmode_am.csv",
    "ev_WLK_TRN_KNR_Link21_3332_0302_feedback_pathoriginalinfo.txt",
    "ev_WLK_TRN_KNR_Link21_3332_0302_feedback_pathresults.csv"))


    ## Initiating process
    proc1.start()
    proc2.start()
    proc3.start()
    proc4.start()
    proc5.start()

    proc6.start()
    proc7.start()
    proc8.start()
    proc9.start()
    proc10.start()

    proc11.start()
    proc12.start()
    proc13.start()
    proc14.start()
    proc15.start()

    proc16.start()
    proc17.start()
    proc18.start()
    proc19.start()
    proc20.start()

    proc21.start()
    proc22.start()
    proc23.start()
    proc24.start()
    proc25.start()


















