# -*- coding: utf-8 -*-
"""
Python script to read csv files and generate corresponding omx file

Author: Naveen Chandra Iraganaboina
email: naveen.chandra@insighttcinc.com
"""

import pandas as pd
import numpy as np
import openmatrix as omx
import os

tmp =globals()
cwd = os.getcwd()

# List all files in the folder and select only csv files
csv_files = os.listdir(cwd)
csv_files = list(filter(lambda f: f.endswith('.csv'), csv_files))


# Loop over csv files
for i in range(len(csv_files)):
    
    # Select the name of csv file in the folder
    file = csv_files[i]
    
    # Read csv file
    data = pd.read_csv(file)
    
    # Read all column names in the csv file
    cols = data.columns 
      
    print('..............Generating Matrices for each Column..............')
    # Iterate over the dataframe and populate the matrices
    for c in range(2, len(cols)):
        
        # pivot the dataframe to matrix
        a = data.pivot(index= 'Orig',  columns= 'Dest', values= cols[c]).fillna(0)
        
        # add columns and rows that could be missing 
        b = a.index.union(range(1,3333))
        tmp_mat = a.reindex(labels=b, axis=0).reindex(labels=b, axis=1).fillna(0.0)
        
        # store the matrix as the column name with which it is generated
        tmp.__setitem__(cols[c], tmp_mat)
        
    print('..............Matrices Generation Completed..............')
    print('..............Saving Matrices to OMX file..............')
    # Create a file name for omx file
    omx_file_name = csv_files[i][0:14]+'.omx'
    
    # Create a omx file
    omx_file = omx.open_file(omx_file_name, "w")
    
    # Save matrices to the omx file
    for c in range(2, len(cols)):
        if(cols[c] == 'BOARDS' or cols[c] == 'FARE'):
            omx_file[cols[c]] = np.rint(np.array(tmp[cols[c]]))
        elif (cols[c] != 'PerceivedTime_BestPath'):
            omx_file[cols[c]] = np.rint(np.array(tmp[cols[c]]) * 100)
    
    # close omx file instance
    omx_file.close()
    
    print('..............Saving Matrices to OMX file - Completed..............')
         
  
