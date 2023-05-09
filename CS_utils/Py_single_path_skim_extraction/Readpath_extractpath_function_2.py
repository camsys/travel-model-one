## updated by Li Jin on 02/15/2023 to extract best transit path for each od pair.
# importing Python multiprocessing module
def extractpath(InFileN,InZippedTxtFileNameN,AccessandEgress_modesN,OutFileN,InterchangeN,InModesN,OutFile2N,OutFile3N):
    import os
    import sys
    import zipfile
    import pandas as pd
    from datetime import datetime
    import re

    ## File Inputs for each of 5 access modes and 5 time periods. Total 25 files.
    InFile = os.getcwd() + "/" + InFileN
    InZippedTxtFileName=InZippedTxtFileNameN
    ## Parameter File
    InPara = os.getcwd() + "/Parameters.csv"
    InModes = os.getcwd()  + "/" + InModesN
    InInterchange = os.getcwd() + "/Interchange_list.csv"
    ## AccessandEgress_modes is 1 for WLK_TRN_WLK.
    ## AccessandEgress_modes is 2 for PNR_TRN_WLK.
    ## AccessandEgress_modes is 3 for WLK_TRN_PNR.
    ## AccessandEgress_modes is 4 for KNR_TRN_WLK.
    ## AccessandEgress_modes is 5 for WLK_TRN_KNR.
    AccessandEgress_modes = AccessandEgress_modesN
    ## Interchange is 0 for extracting best path for all paths.
    ## Interchange is 1 for extracting best path for the interchanges in the Interchange_list.csv file.
    Interchange = InterchangeN
    ## Output File
    OutFile = os.getcwd() + "/" + OutFileN
    OutFile2 = os.getcwd() + "/" + OutFile2N
    OutFile3 = os.getcwd() + "/" + OutFile3N

    print("Beginning Analysis")
    now = datetime.now()
    date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
    print('Start time is:', date_time_str)

    ## Read three Parameter Files into dataframe
    df_Para=pd.read_csv (InPara, sep=',')
    df_Modes=pd.read_csv (InModes, sep=',')
    df_Interchange = pd.read_csv (InInterchange, sep=',')


    ## Each time period, the letters for modes are different.
    ## First get the rail modes inclusing heavy rail, light rail, and commuter rail
    ## These rail mode letters will depend on Orig_mode column
    options = ['r', 'h', 'l']
    df_Modes_Rail = df_Modes[df_Modes['#orig_mode'].isin(options)]
    rail_modes = df_Modes_Rail['mode'].tolist()

    ## Get local bus mode letters
    options = ['b']
    df_Modes_LocalBus = df_Modes[df_Modes['#orig_mode'].isin(options)]
    LocalBus_modes = df_Modes_LocalBus['mode'].tolist()

    ## Get express bus mode letters
    options = ['x']
    df_Modes_ExpressBus = df_Modes[df_Modes['#orig_mode'].isin(options)]
    ExpressBus_modes = df_Modes_ExpressBus['mode'].tolist()

    ## Get ferry mode letters
    options = ['f']
    df_Modes_Ferry = df_Modes[df_Modes['#orig_mode'].isin(options)]
    Ferry_modes = df_Modes_Ferry['mode'].tolist()

    ## Get light rail mode letters
    options = ['l']
    df_Modes_LightRail = df_Modes[df_Modes['#orig_mode'].isin(options)]
    LightRail_modes = df_Modes_LightRail['mode'].tolist()

    ## Get heavy rail mode letters
    options = ['h']
    df_Modes_HeavyRail = df_Modes[df_Modes['#orig_mode'].isin(options)]
    HeavyRail_modes = df_Modes_HeavyRail['mode'].tolist()

    ## Get light rail mode letters
    options = ['r']
    df_Modes_CommuterRail = df_Modes[df_Modes['#orig_mode'].isin(options)]
    CommuterRail_modes = df_Modes_CommuterRail['mode'].tolist()

    ## Get all transit mode letters
    options = ['b','x','f','l','h','r']
    df_Modes_All = df_Modes[df_Modes['#orig_mode'].isin(options)]
    AllTransit_modes = df_Modes_All['mode'].tolist()

    ## Get local bus, express bus, ferry mode letters
    options = ['b','x','f']
    df_Modes_Bus = df_Modes[df_Modes['#orig_mode'].isin(options)]
    Bus_modes = df_Modes_Bus['mode'].tolist()

    ## Get Interchange Izone and Jzone
    df_Interchange.loc[:,'_']  = "_"
    df_Interchange['IJZONE'] = df_Interchange['IZONE'].astype(str) + df_Interchange['_'] + df_Interchange['JZONE'].astype(str)
    IJzone_Interchange = df_Interchange['IJZONE'].tolist()

    ## housecleaning first
    try:
        os.remove(OutFile)
        os.remove(OutFile2)
        os.remove(OutFile3)
    except:
        pass

    i=0

    ## Set up variables for perceived time using the weights
    IVT=0
    BoardingPen=0
    TransferPen=0
    Fare=0
    AccessEgress=0
    FirstTransitMode=1
    PerceivedTime=0

    otaz=0
    dtaz=0
    cost=999999999999999999

    Boards_B = 0
    DDIST_B = 0
    DTIME_B = 0
    FAREN_B = 0
    IVTN_B = 0
    IVTCOM_B = 0
    IVTEXP_B = 0
    IVTFRY_B = 0
    IVTHVY_B = 0
    IVTLOC_B = 0
    IVTLRT_B = 0
    IWAIT_B = 0
    PIVTCOM_B = 0
    PIVTEXP_B = 0
    PIVTFRY_B = 0
    PIVTHVY_B = 0
    PIVTLOC_B = 0
    PIVTLRT_B = 0
    WACC_B = 0
    WAIT_B = 0
    WAUX_B = 0
    WEGR_B = 0
    XWAIT_B = 0

    with open(OutFile, 'a') as output_file:
        output_file.write("Orig,Dest,PerceivedTime_BestPath,BOARDS,DDIST,DTIME,FARE,IVT,IVTCOM,IVTEXP,IVTFRY,IVTHVY,IVTLOC,IVTLRT,IWAIT,PIVTCOM,PIVTEXP,PIVTFRY,PIVTHVY,PIVTLOC,PIVTLRT,WACC,WAIT,WAUX,WEGR,XWAIT")
        output_file.write("\n")

    ## with open(OutFile3, 'a') as output_file3:
        ## output_file3.write("Orig,Dest,PerceivedTime_Path,BOARDS,DDIST,DTIME,FARE,IVT,IVTCOM,IVTEXP,IVTFRY,IVTHVY,IVTLOC,IVTLRT,IWAIT,PIVTCOM,PIVTEXP,PIVTFRY,PIVTHVY,PIVTLOC,PIVTLRT,WACC,WAIT,WAUX,WEGR,XWAIT")
        ## output_file3.write("\n")

    with zipfile.ZipFile(InFile) as z:
        with z.open(InZippedTxtFileName) as f:
            for line in f:
                Boards = 0
                DDIST = 0
                DTIME = 0
                FAREN = 0
                IVTN = 0
                IVTCOM = 0
                IVTEXP = 0
                IVTFRY = 0
                IVTHVY = 0
                IVTLOC = 0
                IVTLRT = 0
                IWAIT = 0
                PIVTCOM = 0
                PIVTEXP = 0
                PIVTFRY = 0
                PIVTHVY = 0
                PIVTLOC = 0
                PIVTLRT = 0
                WACC = 0
                WAIT = 0
                WAUX = 0
                WEGR = 0
                XWAIT = 0

                sline = line.decode("utf-8").split()
                if len(sline) > 1:
                    InterchangeIJzone = sline[0] + "_" + sline[1]
                i=i+1
                if ((Interchange == 0) and any(item in sline for item in rail_modes)) or ((Interchange == 1) and any(item in sline for item in rail_modes) and (InterchangeIJzone in IJzone_Interchange)) :
                    ## check if rail exclusive paths (rail only) or rail inclusive paths
                    if (not any(item in sline for item in Bus_modes) and (df_Para.iloc[1,1]=='0')) or (df_Para.iloc[1,1]=='1'):
                        ## find the last transit mode index
                        for j in range(len(sline)):
                            if (sline[j] in AllTransit_modes):
                                lasttransitmodes_index=j
                                #print (lasttransitmodes_index)
                        ## cal perceived time using the weights from here
                        ## loop through the list from each row
                        for j in range(len(sline)):
                            ## Access/egress/transfer walk component
                            if (sline[j]=='a'):
                                if AccessandEgress_modes == 1:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[16,1])*float(sline[j+2])
                                    DDIST = 0
                                    DTIME = 0
                                    WACC = float(sline[j+2])
                                if AccessandEgress_modes == 2:
                                    DDIST = float(sline[j+3])
                                    DTIME = float(sline[j+2])
                                    WACC = 0
                                if AccessandEgress_modes == 3:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[16,1])*float(sline[j+2])
                                    DDIST = 0
                                    DTIME = 0
                                    WACC = float(sline[j + 2])
                                if AccessandEgress_modes == 4:
                                    DDIST = float(sline[j+3])
                                    DTIME = float(sline[j+2])
                                    WACC = 0
                                if AccessandEgress_modes == 5:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[16,1])*float(sline[j+2])
                                    DDIST = 0
                                    DTIME = 0
                                    WACC = float(sline[j + 2])

                            if (sline[j]=='D'):
                                if AccessandEgress_modes == 1:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    DDIST = DDIST + float(sline[j+3])
                                    DTIME = DTIME + float(sline[j+2])
                                if AccessandEgress_modes == 2:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    DDIST = DDIST + float(sline[j+3])
                                    DTIME = DTIME + float(sline[j+2])
                                if AccessandEgress_modes == 3:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    DDIST = DDIST + float(sline[j+3])
                                    DTIME = DTIME + float(sline[j+2])
                                if AccessandEgress_modes == 4:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    DDIST = DDIST + float(sline[j+3])
                                    DTIME = DTIME + float(sline[j+2])
                                if AccessandEgress_modes == 5:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    DDIST = DDIST + float(sline[j+3])
                                    DTIME = DTIME + float(sline[j+2])

                            if (sline[j] == 'w') and (FirstTransitMode == 1):
                                AccessEgress = AccessEgress + float(df_Para.iloc[16, 1]) * float(sline[j + 2])
                                WACC = WACC + float(sline[j + 2])

                            if (sline[j] == 'w') and (FirstTransitMode == 0) and (j < lasttransitmodes_index):
                                AccessEgress = AccessEgress + float(df_Para.iloc[16, 1]) * float(sline[j + 2])
                                WAUX = WAUX + float(sline[j + 2])

                            if (sline[j] == 'w') and (j > lasttransitmodes_index):
                                AccessEgress = AccessEgress + float(df_Para.iloc[16, 1]) * float(sline[j + 2])
                                WEGR = WEGR + float(sline[j + 2])

                            if (sline[j] == 'e'):
                                if AccessandEgress_modes == 1:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[16,1])*float(sline[j+2])
                                    WEGR = float(sline[j + 2])
                                if AccessandEgress_modes == 2:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[16,1])*float(sline[j+2])
                                    WEGR = float(sline[j + 2])
                                if AccessandEgress_modes == 3:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    WEGR = 0
                                if AccessandEgress_modes == 4:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[16,1])*float(sline[j+2])
                                    WEGR = float(sline[j + 2])
                                if AccessandEgress_modes == 5:
                                    AccessEgress = AccessEgress + float(df_Para.iloc[17,1])*float(sline[j+2])
                                    WEGR = 0

                            ## search if the transit name has space, find and correct it
                            if (sline[j] in AllTransit_modes):
                                counter = sline[j+1].count("'")
                                if counter == 2:
                                    k = j
                                if counter == 1:
                                    for m in range (6): ## m is 0,1,2,3,4,5
                                        counter2 = sline[j+1+1+m].count("'")
                                        if counter2 == 1:
                                            k = j + 1 + m
                                            break;
                                ##print(j)
                                ##print(m)
                                ##print(k)

                            ## scan for k and p, and add ivt to the next transit mode first. If there is no next transit line, add ivt to the previous transit mode
                            if (sline[j] in ['p']):
                                k1 = j
                                k2 = j
                                counter = sline[j+1].count("'")
                                ## print (sline[j+1])
                                ## print (counter)
                                if counter == 2:
                                    k1 = j
                                if counter == 1:
                                    for m in range (6): ## m is 0,1,2,3,4,5
                                        counter2 = sline[j+1+1+m].count("'")
                                        ## print(sline[j+1+1+m])
                                        ## print(counter2)
                                        if counter2 == 1:
                                            k1 = j + 1 + m
                                            break;
                                if (sline[k1+6] in AllTransit_modes):
                                    if (sline[k1+6] in LocalBus_modes):
                                        IVTLOC = IVTLOC + float(sline[k1 + 3])
                                    if (sline[k1+6] in ExpressBus_modes):
                                        IVTEXP = IVTEXP + float(sline[k1 + 3])
                                    if (sline[k1+6] in Ferry_modes):
                                        IVTFRY = IVTFRY + float(sline[k1 + 3])
                                    if (sline[k1+6] in LightRail_modes):
                                        IVTLRT = IVTLRT + float(sline[k1 + 3])
                                    if (sline[k1+6] in HeavyRail_modes):
                                        IVTHVY = IVTHVY + float(sline[k1 + 3])
                                    if (sline[k1+6] in CommuterRail_modes):
                                        IVTCOM = IVTCOM + float(sline[k1 + 3])
                                elif (sline[j-6] in AllTransit_modes):
                                    if (sline[j-6] in LocalBus_modes):
                                        IVTLOC = IVTLOC + float(sline[k1 + 3])
                                    if (sline[j-6] in ExpressBus_modes):
                                        IVTEXP = IVTEXP + float(sline[k1 + 3])
                                    if (sline[j-6] in Ferry_modes):
                                        IVTFRY = IVTFRY + float(sline[k1 + 3])
                                    if (sline[j-6] in LightRail_modes):
                                        IVTLRT = IVTLRT + float(sline[k1 + 3])
                                    if (sline[j-6] in HeavyRail_modes):
                                        IVTHVY = IVTHVY + float(sline[k1 + 3])
                                    if (sline[j-6] in CommuterRail_modes):
                                        IVTCOM = IVTCOM + float(sline[k1 + 3])
                                else:
                                    counter3 = sline[j - 5].count("'")
                                    if counter3 == 2:
                                        k2 = j
                                    if counter3 == 1:
                                        for m in range(6):  ## m is 0,1,2,3,4,5
                                            counter4 = sline[j - 6 - 1 - m].count("'")
                                            if counter4 == 1:
                                                k2 = j - 1 - m
                                                break;
                                    if (sline[k2-6] in LocalBus_modes):
                                        IVTLOC = IVTLOC + float(sline[k1 + 3])
                                    if (sline[k2-6] in ExpressBus_modes):
                                        IVTEXP = IVTEXP + float(sline[k1 + 3])
                                    if (sline[k2-6] in Ferry_modes):
                                        IVTFRY = IVTFRY + float(sline[k1 + 3])
                                    if (sline[k2-6] in LightRail_modes):
                                        IVTLRT = IVTLRT + float(sline[k1 + 3])
                                    if (sline[k2-6] in HeavyRail_modes):
                                        IVTHVY = IVTHVY + float(sline[k1 + 3])
                                    if (sline[k2-6] in CommuterRail_modes):
                                        IVTCOM = IVTCOM + float(sline[k1 + 3])

                                ##print(j)
                                ##print(m)
                                ##print(k)

                            ## Transfer penalty component
                            if ((FirstTransitMode == 0) and (sline[j] in AllTransit_modes)):
                                Boards = Boards + 1
                                TransferPen = TransferPen + float(df_Para.iloc[15,1])
                                XWAIT = XWAIT + float(sline[k + 2])
                                ## print (XWAIT)

                            if (sline[j] in ['p']):
                                XWAIT = XWAIT + float(sline[k1 + 2])
                                ## print(XWAIT)

                            ## Boarding penalty component for first transit mode in the path
                            if ((FirstTransitMode==1) and (sline[j] in AllTransit_modes)):
                                Boards = Boards + 1
                                if (sline[j] in LocalBus_modes):
                                    BoardingPen=BoardingPen+float(df_Para.iloc[9,1])
                                    IWAIT = float(sline[k+2])
                                    FirstTransitMode = 0
                                if (sline[j] in ExpressBus_modes):
                                    BoardingPen=BoardingPen+float(df_Para.iloc[10,1])
                                    IWAIT = float(sline[k + 2])
                                    FirstTransitMode = 0
                                if (sline[j] in Ferry_modes):
                                    BoardingPen=BoardingPen+float(df_Para.iloc[11,1])
                                    IWAIT = float(sline[k + 2])
                                    FirstTransitMode = 0
                                if (sline[j] in LightRail_modes):
                                    BoardingPen=BoardingPen+float(df_Para.iloc[12,1])
                                    IWAIT = float(sline[k + 2])
                                    FirstTransitMode = 0
                                if (sline[j] in HeavyRail_modes):
                                    BoardingPen=BoardingPen+float(df_Para.iloc[13,1])
                                    IWAIT = float(sline[k + 2])
                                    FirstTransitMode = 0
                                if (sline[j] in CommuterRail_modes):
                                    BoardingPen=BoardingPen+float(df_Para.iloc[14,1])
                                    IWAIT = float(sline[k + 2])
                                    FirstTransitMode = 0

                            ## Fare Component
                            if (sline[j] in AllTransit_modes):
                                Fare = Fare + float(sline[j+4]) * 60/float(df_Para.iloc[2,1])

                            ## IVT
                            if (sline[j] in LocalBus_modes):
                                IVT = IVT + float(sline[k+3]) * float(df_Para.iloc[3, 1])
                                PIVTLOC = PIVTLOC + IVT
                                IVTLOC = IVTLOC + float(sline[k + 3])
                            if (sline[j] in ExpressBus_modes):
                                IVT = IVT + float(sline[k+3]) * float(df_Para.iloc[4, 1])
                                PIVTEXP = PIVTEXP + IVT
                                IVTEXP = IVTEXP + float(sline[k + 3])
                            if (sline[j] in Ferry_modes):
                                IVT = IVT + float(sline[k+3]) * float(df_Para.iloc[5, 1])
                                PIVTFRY = PIVTFRY + IVT
                                IVTFRY = IVTFRY + float(sline[k + 3])
                            if (sline[j] in LightRail_modes):
                                IVT = IVT + float(sline[k+3]) * float(df_Para.iloc[6, 1])
                                PIVTLRT = PIVTLRT + IVT
                                IVTLRT = IVTLRT + float(sline[k + 3])
                            if (sline[j] in HeavyRail_modes):
                                IVT = IVT + float(sline[k+3]) * float(df_Para.iloc[7, 1])
                                PIVTHVY = PIVTHVY + IVT
                                IVTHVY = IVTHVY + float(sline[k + 3])
                            if (sline[j] in CommuterRail_modes):
                                IVT = IVT + float(sline[k+3]) * float(df_Para.iloc[8, 1])
                                PIVTCOM = PIVTCOM + IVT
                                IVTCOM = IVTCOM + float(sline[k + 3])

                        PerceivedTime= AccessEgress + BoardingPen + TransferPen + Fare + IVT
                        ##Boards = float(sline[13])
                        FAREN = float(sline[5])
                        IVTN = float(sline[3])
                        WAIT = IWAIT + XWAIT

                        ## with open(OutFile2, 'a') as output_file2:
                            ## output_file2.write(line.decode("utf-8")[:len(line.decode("utf-8")) - 2])
                            ## output_file2.write("\n")
                        ## with open(OutFile3, 'a') as output_file3:
                            ## output_file3.write("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19},{20},{21},{22},{23},{24},{25}\n".format(sline[0], sline[1], PerceivedTime,Boards,DDIST,DTIME,FAREN,IVTN,IVTCOM,IVTEXP,IVTFRY,IVTHVY,IVTLOC,IVTLRT,IWAIT,PIVTCOM,PIVTEXP,PIVTFRY,PIVTHVY,PIVTLOC,PIVTLRT,WACC,WAIT,WAUX,WEGR,XWAIT))

                        if ((sline[0]!=otaz) or (sline[1]!=dtaz)):
                            if (cost!=999999999999999999):
                                with open(OutFile, 'a') as output_file:
                                    output_file.write("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19},{20},{21},{22},{23},{24},{25}\n".format(otaz, dtaz, cost,Boards_B,DDIST_B,DTIME_B,FAREN_B,IVTN_B,IVTCOM_B,IVTEXP_B,IVTFRY_B,IVTHVY_B,IVTLOC_B,IVTLRT_B,IWAIT_B,PIVTCOM_B,PIVTEXP_B,PIVTFRY_B,PIVTHVY_B,PIVTLOC_B,PIVTLRT_B,WACC_B,WAIT_B,WAUX_B,WEGR_B,XWAIT_B))
                                ##with open(OutFile2, 'a') as output_file2:
                                    ##output_file2.write(Recordline.decode("utf-8")[:len(Recordline.decode("utf-8"))-2])
                                    ##output_file2.write("\n")
                                otaz=sline[0]
                                dtaz=sline[1]
                                cost=PerceivedTime
                                Recordline=line

                                Boards_B = Boards
                                DDIST_B = DDIST
                                DTIME_B = DTIME
                                FAREN_B = FAREN
                                IVTN_B = IVTN
                                IVTCOM_B = IVTCOM
                                IVTEXP_B = IVTEXP
                                IVTFRY_B = IVTFRY
                                IVTHVY_B = IVTHVY
                                IVTLOC_B = IVTLOC
                                IVTLRT_B = IVTLRT
                                IWAIT_B = IWAIT
                                PIVTCOM_B = PIVTCOM
                                PIVTEXP_B = PIVTEXP
                                PIVTFRY_B = PIVTFRY
                                PIVTHVY_B = PIVTHVY
                                PIVTLOC_B = PIVTLOC
                                PIVTLRT_B = PIVTLRT
                                WACC_B = WACC
                                WAIT_B = WAIT
                                WAUX_B = WAUX
                                WEGR_B = WEGR
                                XWAIT_B = XWAIT

                            if (cost==999999999999999999):
                                otaz=sline[0]
                                dtaz=sline[1]
                                cost=PerceivedTime
                                Recordline=line

                                Boards_B = Boards
                                DDIST_B = DDIST
                                DTIME_B = DTIME
                                FAREN_B = FAREN
                                IVTN_B = IVTN
                                IVTCOM_B = IVTCOM
                                IVTEXP_B = IVTEXP
                                IVTFRY_B = IVTFRY
                                IVTHVY_B = IVTHVY
                                IVTLOC_B = IVTLOC
                                IVTLRT_B = IVTLRT
                                IWAIT_B = IWAIT
                                PIVTCOM_B = PIVTCOM
                                PIVTEXP_B = PIVTEXP
                                PIVTFRY_B = PIVTFRY
                                PIVTHVY_B = PIVTHVY
                                PIVTLOC_B = PIVTLOC
                                PIVTLRT_B = PIVTLRT
                                WACC_B = WACC
                                WAIT_B = WAIT
                                WAUX_B = WAUX
                                WEGR_B = WEGR
                                XWAIT_B = XWAIT

                        if ((sline[0]==otaz) and (sline[1]==dtaz)):
                            if (cost > PerceivedTime):
                                otaz=sline[0]
                                dtaz=sline[1]
                                cost=PerceivedTime
                                Recordline=line

                                Boards_B = Boards
                                DDIST_B = DDIST
                                DTIME_B = DTIME
                                FAREN_B = FAREN
                                IVTN_B = IVTN
                                IVTCOM_B = IVTCOM
                                IVTEXP_B = IVTEXP
                                IVTFRY_B = IVTFRY
                                IVTHVY_B = IVTHVY
                                IVTLOC_B = IVTLOC
                                IVTLRT_B = IVTLRT
                                IWAIT_B = IWAIT
                                PIVTCOM_B = PIVTCOM
                                PIVTEXP_B = PIVTEXP
                                PIVTFRY_B = PIVTFRY
                                PIVTHVY_B = PIVTHVY
                                PIVTLOC_B = PIVTLOC
                                PIVTLRT_B = PIVTLRT
                                WACC_B = WACC
                                WAIT_B = WAIT
                                WAUX_B = WAUX
                                WEGR_B = WEGR
                                XWAIT_B = XWAIT

                        AccessEgress=0
                        BoardingPen=0
                        TransferPen = 0
                        Fare = 0
                        IVT = 0
                        FirstTransitMode = 1
                        PerceivedTime = 0
                    #if i % 200000 == 0:
                        #print ("Scanned " + str(i) + " rows")

            with open(OutFile, 'a') as output_file:
                output_file.write("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19},{20},{21},{22},{23},{24},{25}\n".format(otaz, dtaz, cost,Boards_B,DDIST_B,DTIME_B,FAREN_B,IVTN_B,IVTCOM_B,IVTEXP_B,IVTFRY_B,IVTHVY_B,IVTLOC_B,IVTLRT_B,IWAIT_B,PIVTCOM_B,PIVTEXP_B,PIVTFRY_B,PIVTHVY_B,PIVTLOC_B,PIVTLRT_B,WACC_B,WAIT_B,WAUX_B,WEGR_B,XWAIT_B))
            ## with open(OutFile2, 'a') as output_file2:
                ## output_file2.write(Recordline.decode("utf-8")[:len(Recordline.decode("utf-8")) - 2])
                ## output_file2.write("\n")

    print ("finished!")
    print ("Total scanned " + str(i) + " rows for " + InFileN + " file")

    now = datetime.now()
    date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
    print('End time is:', date_time_str)

















