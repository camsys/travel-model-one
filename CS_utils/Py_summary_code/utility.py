
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
def _merge_joint_and_indiv_trips(indiv_trips, joint_trips):
    joint_trips = joint_trips[["hh_id", "tour_id", "num_participants", "trip_mode"]]
    joint_trips = joint_trips.reindex(
        joint_trips.index.repeat(joint_trips.num_participants)
    ).reset_index(drop=True)
    joint_trips = joint_trips.drop(columns=["num_participants"])

    indiv_trips = indiv_trips[["hh_id", "tour_id", "trip_mode"]]
    trips = pd.concat([joint_trips, indiv_trips], ignore_index=True).reset_index(
        drop=True
    )

    return trips