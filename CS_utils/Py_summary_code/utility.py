
import os
import openmatrix as omx
import pandas as pd
import numpy as np

_join = os.path.join
_dir = os.path.dirname
_norm = os.path.normpath

#functions
def convertMat2Df(df, mat_core):
    """
    converts the matrix core to dataframe
    
    """
    
    mat = omx.open_file(df)
    if mat_core in mat.list_matrices():
        df = pd.DataFrame(np.array(mat[mat_core]))
        df = pd.melt(df.reset_index(), id_vars='index', value_vars=df.columns)
        df['index'] = df['index'] + 1
        df['variable'] = df['variable'] + 1
        df.columns = ['orig', 'dest', mat_core]
    
    else:
        raise Exception("Matric Core not present in the matrix")
        
    return df


#generate Transbay OD pair
def generate_transbayOD_pairs(transbay_od_omx, bridge_mapping, combine=True):
    """ transbay_od_omx: path to matrix file with transbay OD
        bridge_mapping: dictionary for bridges and their respective codes
        combine: combine into single file or separate od matrices
    
    """
    
    df = omx.open_file(transbay_od_omx)
    for cores in df.list_matrices():
        if cores == 'transbayOD':
            df = pd.DataFrame(np.array(df['transbayOD']))
            df = pd.melt(df.reset_index(), id_vars='index', value_vars=df.columns)
            df['index'] = df['index'] + 1
            df['variable'] = df['variable'] + 1
            bay_bridge_od = df.loc[df['value'] == bridge_mapping['Bay Bridge']]
            san_mateo_od = df.loc[df['value'] == bridge_mapping['San Mateo']]
            dumbarton_od = df.loc[df['value'] == bridge_mapping['Dumbarton']]
            final_df = pd.concat([bay_bridge_od, san_mateo_od, dumbarton_od], ignore_index=True)
            final_df = final_df.reset_index(drop=True)
            
    if combine:
        final_df['value'] = 1
    
    final_df.columns = ['transbay_o', 'transbay_d', 'transbay_od']
        
    return final_df

#test transbay OD pair
# df = r"C:\Users\vyadav\Cambridge Systematics\PROJ 210071 BART Link21 TDLU Modeling - Documents\Task 2 - Model Dev\2.3 - Model Construction\Performance Metrics\Model Outputs\TM2_09172022\TB OD pair\Transbayconnector_OD_highway_v02162023_v93_CS.omx"
# bridge_mapping = {'Bay Bridge' : 1,
#                  'San Mateo': 10,
#                  'Dumbarton' : 100}

# df = generate_transbayOD_pairs(df, bridge_mapping, combine=True)
# df.to_csv(os.path.join(cwks, "transbay_od.csv"), index = False)

# function to convert to final trip roster

def create_trip_roster(ctramp_dir,
                        hh,
                        pp_perc, 
                        transbay_od, 
                        geo_cwks, 
                        link21_purp_mapping, 
                        iteration
                        ):

    it_full = pd.read_csv(_join(ctramp_dir, 'main\\indivTripData_' + str(iteration) + '.csv'))
    it_full['trip_type'] = 'INM'
    jt_full = pd.read_csv(_join(ctramp_dir, 'main\\jointTripData_' + str(iteration) + '.csv'))
    jt_full['trip_type'] = 'JNT'
    
    it_full['trips'] = 1/it_full.sampleRate
    jt_full['trips'] = jt_full.num_participants/jt_full.sampleRate

    out_tripdata = pd.concat([it_full,  jt_full], ignore_index=True).reset_index(
        drop=True
    )

    out_tripdata = pd.merge(out_tripdata, transbay_od, left_on= ['orig_taz', 'dest_taz'], 
                            right_on = ['transbay_o', 'transbay_d'], how = 'left')
    out_tripdata['transbay_od'] = out_tripdata['transbay_od'].fillna(0)

    out_tripdata = out_tripdata.drop(columns = ['transbay_o', 'transbay_d'])
    #print(out_tripdata['transbay_od'].value_counts())

    # add geographies to final tours
    out_tripdata = pd.merge(out_tripdata, geo_cwks, left_on = ['orig_taz'], 
                            right_on = ['taz'], how = 'left')
    out_tripdata = out_tripdata.rename(columns = {'rdm_zones':'orig_rdm_zones', 
                                                'super_district': 'orig_super_dist',
                                                'county': 'orig_county'})
    del out_tripdata['taz']

    out_tripdata = pd.merge(out_tripdata, geo_cwks, left_on = ['dest_taz'], right_on = ['taz'], how = 'left')
    out_tripdata = out_tripdata.rename(columns = {'rdm_zones':'dest_rdm_zones', 
                                                'super_district': 'dest_super_dist',
                                                'county': 'dest_county'})

    del out_tripdata['taz']

    out_tripdata = pd.merge(out_tripdata, hh, on = 'hh_id', how = 'left')

    # add prioirty population
    out_tripdata = pd.merge(out_tripdata, pp_perc, left_on = ['home_zone'], right_on = ['taz'], how = 'left')
    print("NAs in PP Share:",  out_tripdata['pp_share'].isna().sum())
    # out_tourdata['pp_share'] = out_tourdata['pp_share'].fillna(0)
    del out_tripdata['taz']
    
    #add link21 purpose definitions
    df = out_tripdata.copy()
    df['new_dest_purp'] = df['dest_purpose']
    df['new_orig_purp'] = df['orig_purpose']
    
    # changing the purpose categories for atwork purpose
    df.loc[(df['tour_purpose'] == 'atwork_eat') & (df['dest_purpose'] == 'atwork'), 'new_dest_purp'] = 'eatout'
    df.loc[(df['tour_purpose'] == 'atwork_eat') & (df['orig_purpose'] == 'atwork'), 'new_orig_purp'] = 'eatout'

    df.loc[(df['tour_purpose'] == 'atwork_business') & (df['dest_purpose'] == 'atwork'), 'new_dest_purp'] = 'business'
    df.loc[(df['tour_purpose'] == 'atwork_business') & (df['orig_purpose'] == 'atwork'), 'new_orig_purp'] = 'business'

    df.loc[(df['tour_purpose'] == 'atwork_maint') & (df['dest_purpose'] == 'atwork'), 'new_dest_purp'] = 'othmaint'
    df.loc[(df['tour_purpose'] == 'atwork_maint') & (df['orig_purpose'] == 'atwork'), 'new_orig_purp'] = 'othmaint'
    
    # adding new link21 trip purpose
    df['link21_tour_purp'] = df['tour_purpose'].map(link21_purp_mapping)
    df['link21_orig_purp'] = df['new_orig_purp'].map(link21_purp_mapping)
    df['link21_dest_purp'] = df['new_dest_purp'].map(link21_purp_mapping)

    df['link21_trip_purp'] = df['link21_dest_purp']
    
    # for last trip on tour
    df1 = df.loc[(df['link21_dest_purp'] == 'home')]
    conditions = [
        df1['link21_tour_purp'].eq('work'),
        df1['link21_tour_purp'].eq('school'),
        ~df1['link21_tour_purp'].isin(['work','school'])
    ]

    choices = ['work', 'school', df1['link21_orig_purp']]
    df1['link21_trip_purp'] = np.select(conditions, choices, default=0)
    df2 = df.loc[(df['link21_dest_purp'] != 'home')]
    df2['link21_trip_purp'] = df2['link21_dest_purp']
    df = pd.concat([df1, df2], ignore_index=True)
    
    df1 = df.loc[df['dest_purpose'] == 'atwork']
    conditions = [
        df1['link21_tour_purp'].eq('business'),
        ~df1['link21_tour_purp'].eq('business')
    ]
    choices = ['business', df1['link21_orig_purp']]
    df1['link21_trip_purp'] = np.select(conditions, choices, default=0)
    
    df2 = df.loc[(df['dest_purpose'] != 'atwork')]
    trips = pd.concat([df1, df2], ignore_index=True).reset_index(
        drop=True
        )

    return trips



def create_tour_roster(ctramp_dir,
                        hh,
                        pp_perc, 
                        transbay_od, 
                        geo_cwks,  
                        iteration
                        ):

    it_full = pd.read_csv(_join(ctramp_dir, 'main\\indivTourData_' + str(iteration) + '.csv'))
    it_full['trip_type'] = 'INM'
    jt_full = pd.read_csv(_join(ctramp_dir, 'main\\jointTourData_' + str(iteration) + '.csv'))
    jt_full['trip_type'] = 'JNT'
    
    jt_full['num_participants'] = jt_full['tour_participants'].str.count('\d')

    it_full['tours'] = 1/it_full.sampleRate
    jt_full['tours'] = jt_full.num_participants/jt_full.sampleRate

    out_tourdata = pd.concat([it_full,  jt_full], ignore_index=True).reset_index(
        drop=True
    )

    out_tourdata = pd.merge(out_tourdata, transbay_od, left_on= ['orig_taz', 'dest_taz'], 
                            right_on = ['transbay_o', 'transbay_d'], how = 'left')
    out_tourdata['transbay_od'] = out_tourdata['transbay_od'].fillna(0)

    out_tourdata = out_tourdata.drop(columns = ['transbay_o', 'transbay_d'])
    #print(out_tripdata['transbay_od'].value_counts())

    # add geographies to final tours
    out_tourdata = pd.merge(out_tourdata, geo_cwks, left_on = ['orig_taz'], 
                            right_on = ['taz'], how = 'left')
    out_tourdata = out_tourdata.rename(columns = {'rdm_zones':'orig_rdm_zones', 
                                                'super_district': 'orig_super_dist',
                                                'county': 'orig_county'})
    del out_tourdata['taz']

    out_tourdata = pd.merge(out_tourdata, geo_cwks, left_on = ['dest_taz'], right_on = ['taz'], how = 'left')
    out_tourdata = out_tourdata.rename(columns = {'rdm_zones':'dest_rdm_zones', 
                                                'super_district': 'dest_super_dist',
                                                'county': 'dest_county'})

    del out_tourdata['taz']

    out_tourdata = pd.merge(out_tourdata, hh, on = 'hh_id', how = 'left')

    # add prioirty population
    out_tourdata = pd.merge(out_tourdata, pp_perc, left_on = ['home_zone'], right_on = ['taz'], how = 'left')
    print("NAs in PP Share:",  out_tourdata['pp_share'].isna().sum())
    # out_tourdata['pp_share'] = out_tourdata['pp_share'].fillna(0)
    del out_tourdata['taz']

    
    
    return out_tourdata


def skim_core_to_df(skim, core, cols =['orig', 'dest', 'rail_od']):
    skim_df = pd.DataFrame(skim[core])
    skim_df = pd.melt(skim_df.reset_index(), id_vars='index', value_vars=skim_df.columns)
    skim_df['index'] = skim_df['index'] + 1
    skim_df['variable'] = skim_df['variable'] + 1
    skim_df.columns = cols

    return skim_df

def array2df(array, cols =['orig', 'dest', 'rail_od']):
    df = pd.DataFrame(array)
    df = pd.melt(df.reset_index(), id_vars='index', value_vars=df.columns)
    df['index'] = df['index'] + 1
    df['variable'] = df['variable'] + 1
    df.columns = cols
    
    return df

def create_rail_wacc_od_pairs(transit_demand_dir, transit_skims_dir, period, acc_egg_modes):
    
    #Creates the Rail OD eligible Files
    for per in period:
        print("Period: ",per)

        rail_acc = omx.open_file(_join(transit_demand_dir, "rail_wacc_od_v9_trim_" + per.upper() + ".omx"),'w') 
        for acc_egg in acc_egg_modes:
            print("Access Egress Mode: ",acc_egg)
            if acc_egg == 'WLK_TRN_WLK':
                trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
                wlk_time = np.array(trn_skm['WACC']) + np.array(trn_skm['WEGR'])
                
            if acc_egg == 'KNR_TRN_WLK':
                trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
                wlk_time = np.array(trn_skm['WEGR'])
                
            if acc_egg == 'PNR_TRN_WLK':
                trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
                wlk_time = np.array(trn_skm['WEGR'])
                
            if acc_egg == 'WLK_TRN_PNR':
                trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
                wlk_time = np.array(trn_skm['WACC'])
                
            if acc_egg == 'WLK_TRN_KNR':
                trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
                wlk_time = np.array(trn_skm['WACC'])
    
            #rail_dmn = trn_dmn_acc * ivtrail
            rail_acc[acc_egg] = wlk_time

        rail_acc.close()

def create_rail_od_pairs(output_dir, transit_skims_dir, period, acc_egg_modes):
    
    #Creates the Rail OD eligible Files
    for per in period:
        print("Period: ",per)

        rail_demand = omx.open_file(_join(output_dir, "rail_od_v9_trim_" + per.upper() + ".omx"),'w') 
        for acc_egg in acc_egg_modes:
            print("Access Egress Mode: ",acc_egg)
            trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.lower() + ".omx"))
            ivthvy = np.array(trn_skm['IVTHVY'])
            ivtcom = np.array(trn_skm['IVTCOM'])
            ivtrail = ivthvy + ivtcom
            ivtrail[ivtrail > 0] = 1
            #rail_dmn = trn_dmn_acc * ivtrail
            rail_demand[acc_egg] = ivtrail

        rail_demand.close()

def create_rail_fare_od_pairs(preprocess_dir, transit_skims_dir, acc_egg_modes, time_periods):
    
    #Creates the Rail OD eligible Files
    for per in time_periods:
        print("Period: ",per)

        rail_demand = omx.open_file(_join(preprocess_dir, "rail_fair_v9_trim_" + per.upper() + ".omx"),'w') 
        for acc_egg in acc_egg_modes:
            print("Access Egress Mode: ",acc_egg)
            trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
            fares = np.array(trn_skm['FARE'])
            rail_demand[acc_egg] = fares

        rail_demand.close()

def create_rail_crowding_od_pairs(transit_demand_dir, transit_skims_dir, period, acc_egg_modes):
    
    #Creates the Rail OD eligible Files
    for per in period:
        print("Period: ",per)

        rail_demand = omx.open_file(_join(transit_demand_dir, "rail_crowding_od_v9_trim_" + per.upper() + ".omx"),'w') 
        for acc_egg in acc_egg_modes:
            print("Access Egress Mode: ",acc_egg)
            trn_skm = omx.open_file(_join(transit_skims_dir, "trnskm" + per.lower() +"_" + acc_egg.upper() + ".omx"))
            crowd = np.array(trn_skm['CROWD']) * 1.62
            #rail_dmn = trn_dmn_acc * ivtrail
            rail_demand[acc_egg] = crowd

        rail_demand.close()