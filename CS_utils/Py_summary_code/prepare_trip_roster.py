
import os
import pandas as pd
import numpy as np
import openmatrix as omx
import random
import yaml

from utility import *

import warnings
warnings.filterwarnings('ignore')

def prepare_trip_roster_df(
        model_outputs_dir, #
        cwks_folder, # folder which has crosswalks
        iteration
        ):
    """

    """

    # outputs of CT-RAMP model for tour and trip file
    household_model_dir = _join(model_outputs_dir, "main")

    # input household and person data
    person_file = _join(household_model_dir, 'personData_' + str(iteration) + '.csv')
    household_file = _join(household_model_dir, 'householdData_' + str(iteration) + '.csv')

    person_file = _join(household_model_dir, 'personData_' + str(iteration) + '.csv')
    person = pd.read_csv(person_file)

    hh = pd.read_csv(household_file, usecols = ['hh_id', 'taz'])
    hh = hh.rename(columns = {'taz': 'home_zone'})

    # taz to RDM zones, super districts, county
    geo_cwks = pd.read_csv(_join(cwks, "geographies.csv")) #columns taz, rdm_zones, super_district, county

    # taz to priority population
    pp_perc = pd.read_excel(_join(cwks, "TAZ_Tract_cwk_summary.xlsx")) #columns = taz, pp_share 

    # transbay od pairs
    transbay_od = pd.read_csv(_join(cwks, "transbay_od.csv")) #columns = transbay_o, transbay_d

    # input trips
    ind_trip = pd.read_csv(_join(household_model_dir, 'indivTripData_' + str(iteration) + '.csv'))
    jnt_trip = pd.read_csv(_join(household_model_dir, 'jointTripData_' + str(iteration) + '.csv'))

    # Checks
    print("total joint trips:", len(jnt_trip))
    print("total inm trips:", len(ind_trip))
    print("Sample Rate:", jnt_trip['sampleRate'].unique()," ",ind_trip['sampleRate'].unique())

    jnt_trip['tours'] = 'joint'
    ind_trip['tours'] = 'inm'

    ind_drop_columns = ['avAvailable', 'sampleRate', 'taxiWait', 'singleTNCWait', 
                        'sharedTNCWait', 'orig_walk_segment', 'dest_walk_segment',
                        'person_id', 'person_num', 'parking_taz']

    jnt_drop_columns = ['avAvailable', 'sampleRate', 'taxiWait', 'singleTNCWait', 
                        'sharedTNCWait', 'orig_walk_segment', 'dest_walk_segment',
                    'parking_taz', 'num_participants']

    ind_trip = ind_trip.drop(columns = ind_drop_columns)
    jnt_trip = jnt_trip.drop(columns = jnt_drop_columns)

    out_tripdata = pd.concat([ind_trip, jnt_trip])

    # add transbay_od to final tours
    out_tripdata = pd.merge(out_tripdata, transbay_od, left_on= ['orig_taz', 'dest_taz'], right_on = ['transbay_o', 'transbay_d'], how = 'left')
    out_tripdata['transbay_od'] = out_tripdata['transbay_od'].fillna(0)

    out_tripdata = out_tripdata.drop(columns = ['transbay_o', 'transbay_d'])
    #print(out_tripdata['transbay_od'].value_counts())

    # add geographies to final tours
    out_tripdata = pd.merge(out_tripdata, geo_cwks, left_on = ['orig_taz'], right_on = ['taz'], how = 'left')
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

    print("total trips:", len(out_tripdata))
    print(out_tripdata['tours'].value_counts())

    #Create non-transit trip data
    out_tripdata_nontransit = out_tripdata[out_tripdata['trip_mode'].isin([1,2,3,4,5,9])]
    print('total non transit trips:', len(out_tripdata_nontransit))

    #Create transit only trip data
    out_tripdata_transit = out_tripdata[out_tripdata['trip_mode'].isin([6,7,8])]
    print('total transit trips:', len(out_tripdata_transit))

    return (out_tripdata, out_tripdata_nontransit, out_tripdata_transit)
