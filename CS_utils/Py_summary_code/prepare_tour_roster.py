
import os
import pandas as pd
import numpy as np


def prepare_tour_roster_df(
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

    # outputs of CT-RAMP model for tour file
    ind_tour = pd.read_csv(_join(household_model_dir, 'indivTourData_' + str(iteration) + '.csv'))
    jnt_tour = pd.read_csv(_join(household_model_dir, 'jointTourData_' + str(iteration) + '.csv'))

    print("total joint tours:", len(jnt_tour))
    print("total inm tours:", len(ind_tour))

    jnt_tour['tours'] = 'joint'
    ind_tour['tours'] = 'inm'

    person = person.rename(columns={'person_num':'PNUM','sampleRate':'sample_rate'})
    ind_tour = ind_tour.rename(columns={'person_num':'PNUM','sampleRate':'sample_rate'})
    jnt_tour = jnt_tour.rename(columns={'sampleRate':'sample_rate'})

    tour0 = jnt_tour[['hh_id','tour_id','tour_participants','tour_mode', 'tour_purpose']]
    tour0['JTOUR_ID'] = tour0['tour_id'] + 1
    tour0['num'] = tour0['tour_participants'].apply(lambda x: len(list(x.split(" "))))

    c = pd.DataFrame(tour0.tour_participants.str.split(" ").to_list()).stack().reset_index(name="PNUM")

    tour1 = tour0.loc[tour0.index.repeat(tour0.num)]
    tour1['PNUM'] = c['PNUM']
    tour1['PNUM'] = tour1['PNUM'].astype(int)
    tour1 = tour1.merge(person[['hh_id','person_id','PNUM']], how='left', on = ['hh_id','PNUM'])
    tour1.head()

    tour1 = tour1[["hh_id","person_id","tour_id","PNUM",'JTOUR_ID']]
    tour1_2 = tour1.merge(jnt_tour, how = 'left', on = ["hh_id","tour_id"])
    tour1_2.drop(["tour_composition", "tour_participants"], axis=1, inplace=True)

    tour2 = ind_tour.copy()
    tour2 = tour2.drop(["atWork_freq", "person_type"], axis = 1)
    tour2['JTOUR_ID']=0

    #Create the tour roster
    out_tourdata = pd.concat([tour1_2, tour2])
    out_tourdata['TOURID'] = out_tourdata.fillna('')['tour_category'].apply(str) + "." + out_tourdata.fillna('')['tour_purpose'].apply(str) + "." + out_tourdata.fillna('')['tour_id'].apply(str)
    out_tourdata['TourType'] = 'Closed'
    out_tourdata = out_tourdata.sort_values(by=['hh_id','person_id','start_hour','end_hour'])

    #add transbay_od to final tours
    out_tourdata = pd.merge(out_tourdata, transbay_od, left_on= ['orig_taz', 'dest_taz'], right_on = ['transbay_o', 'transbay_d'], how = 'left')
    out_tourdata['transbay_od'] = out_tourdata['transbay_od'].fillna(0)

    out_tourdata = out_tourdata.drop(columns = ['transbay_o', 'transbay_d'])
    print(out_tourdata['transbay_od'].value_counts())

    #add geographies to final tours
    out_tourdata = pd.merge(out_tourdata, geo_cwks, left_on = ['orig_taz'], right_on = ['taz'], how = 'left')
    out_tourdata = out_tourdata.rename(columns = {'rdm_zones':'orig_rdm_zones', 
                                                'super_district': 'orig_super_dist',
                                                'county': 'orig_county'})
    del out_tourdata['taz']

    out_tourdata = pd.merge(out_tourdata, geo_cwks, left_on = ['dest_taz'], right_on = ['taz'], how = 'left')
    out_tourdata = out_tourdata.rename(columns = {'rdm_zones':'dest_rdm_zones', 
                                                'super_district': 'dest_super_dist',
                                                'county': 'dest_county'})

    del out_tourdata['taz']
    out_tourdata.columns

    #adding home zone
    out_tourdata = pd.merge(out_tourdata, hh, on = 'hh_id', how = 'left')

    #add prioirty population
    out_tourdata = pd.merge(out_tourdata, pp_perc, left_on = ['home_zone'], right_on = ['taz'], how = 'left')
    print("NAs in PP Share:",  out_tourdata['pp_share'].isna().sum())

    del out_tourdata['taz']

    print("total tours:", len(out_tourdata))
    print(out_tourdata['tours'].value_counts())

    print("Sum of NAs: ", out_tourdata.isna().sum())

    return(out_tourdata)
