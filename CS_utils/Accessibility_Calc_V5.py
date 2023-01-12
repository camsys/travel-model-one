# Version notes
# V4: added highway and transit perceived travel time accessibility measures, added percentage of regional employment accessible per employment category
# V5: fix problem with transit IVT equal to zero -- should indicate nonavailability

import pandas as pd
import numpy as np
from collections import defaultdict
from openpyxl import Workbook
import openmatrix as omx
import glob, os, sys
from datetime import datetime

skim_dir = r'C:\MTC_tmpy\TM2\tm2py\examples\Link21_3332\skims\accessibility'
os.chdir(skim_dir)

current_date = datetime.now().strftime('%Y%m%d')
out_excel_fn = r'C:\MTC_tmpy\TM2\tm2py\examples\Link21_3332\skims\accessibility\acc_measures_{date}.xlsx'.format(date = current_date)
writer = pd.ExcelWriter(out_excel_fn, engine = 'openpyxl')
writer.book = Workbook()

df_land_use = pd.read_csv(r"C:\MTC_tmpy\TM2\tm2py\examples\Link21_3332\inputs\landuse\tazData.csv")
num_zones = len(df_land_use)
tt_matrices = {}

#TODs = ['EA','AM','MD','PM','EV']
TODs = ['AM'] #Can change later to include all TODs


emp_type = ['TOTEMP','RETEMPN','HEREMPN','EMPRES']
cutoff_start = [0, 10, 20, 30, 40, 50, 60, 70]
cutoff_end = [10, 20, 30, 40, 50, 60, 70, 80]


# Aggregate transit travel times into a single TRN_TOT_TIME core, divided by 100
for tod in TODs:
    for fn in glob.glob(f'trnskm*.omx'):
        if tod in fn:
            with omx.open_file(fn, 'a') as f:
                if 'IVTX' in f.list_matrices():
                    del f['IVTX']
                if 'TRN_TOT_TIME' in f.list_matrices():
                    del f['TRN_TOT_TIME']
                print(f.list_matrices())
                ivt = np.array(f['IVT'])
                ivt1 = ivt * (ivt>0)
                ivt0 = 99999 * (ivt==0)
                ivtx = ivt0 + ivt1
                f['IVTX'] = ivtx.reshape(len(f['IVT']),len(f['IVT']))
                f['TRN_TOT_TIME'] = np.add.reduce([np.array(f[mat]) for mat in ['IVTX','IWAIT','XWAIT','WACC','WAUX','WEGR']])/ 100


acc_mode_groups = {'HWYSKM':{'mode':'highway','core':'TIMEDA'},
            'trnskm':{'mode':'transit','core':'TRN_TOT_TIME'},
            'nonmotskm':{'mode':'non-motorized','core':'DISTWALK'}}

for access_type in acc_mode_groups:
    for tod in TODs:
        for fn in glob.glob(f'{access_type}*.omx'):
            if access_type == 'nonmotskm' or tod in fn:
                with omx.open_file(fn) as f:
                    mode = acc_mode_groups[access_type]['mode']
                    skim_array = np.array(f[acc_mode_groups[access_type]['core']])
                    if acc_mode_groups[access_type]['core'] =='DISTWALK':
                        skim_array = skim_array*20
                    tt_matrices[(tod, mode)] = skim_array[:num_zones, :num_zones]

all_zones_df = pd.DataFrame(0, index = df_land_use.ZONE.values, columns = [])
all_zones_df.index.name = 'zone_ID'

all_zones_pct_df = pd.DataFrame(0, index = df_land_use.ZONE.values, columns = [])
all_zones_pct_df.index.name = 'zone_ID'

for employment in emp_type:
    for tod in TODs:        
        for access_type in acc_mode_groups:
            mode = acc_mode_groups[access_type]['mode']
            new_key = (tod,mode)
            if new_key in tt_matrices:
                for (cutoff_s, cutoff_e) in zip(cutoff_start, cutoff_end):
                    grp_tt = (tt_matrices[(tod,mode)])
                    grp_tt = ((grp_tt >= cutoff_s) & (grp_tt < cutoff_e)).astype(int)
                    all_zones_df[f'{employment}_{tod}_{mode}_{cutoff_s}_{cutoff_e}'] = (grp_tt*df_land_use[f'{employment}'].values).sum(axis=1)
                    all_zones_pct_df[f'{employment}_{tod}_{mode}_{cutoff_s}_{cutoff_e}'] = (grp_tt*df_land_use[f'{employment}'].values).sum(axis=1) / df_land_use[f'{employment}'].sum()
                    
all_zones_df.to_excel(writer,sheet_name = 'simple')
all_zones_pct_df.to_excel(writer,sheet_name = 'simple_PCT')


# Accessibility based on perceived time/cost
ptt_matrices = {}

# Highway parameters
segment_suffixes = ["LowInc", "MedInc", "HighInc", "XHighInc"]
cutoffs = [0, 30000, 60000, 100000]
VOTs = {"LowInc": 6.01, "MedInc": 8.81, "HighInc": 10.44, "XHighInc": 12.86} # uses VOT according to mean HH income per TAZ
hh = pd.read_csv('hhFile.2015.csv')
hh_mean_inc = hh.groupby(['TAZ'])['HINC'].mean().reindex(df_land_use.ZONE.values).rename('mean_inc')
hh_mean_inc = hh_mean_inc.fillna(hh.HINC.mean())
assert len(hh_mean_inc) == len(df_land_use) and hh_mean_inc.isna().sum() == 0, 'HH mean income is incomplete'
hh_mean_inc = hh_mean_inc.reset_index()
hh_mean_inc['income_seg'] = pd.cut(hh_mean_inc['mean_inc'], right = False, bins = cutoffs + [float('inf')], labels = segment_suffixes).astype(str)
hh_mean_inc['VOT_per_hour'] = hh_mean_inc['income_seg'].map(VOTs) 
hh_mean_inc['VOT_per_min'] = hh_mean_inc['VOT_per_hour']/ 60 # values from VOTs are in $/hour, convert into $/minute

# Cost units are cents, expressed in year 2000 dollars.
for fn in glob.glob('hwyskm*.omx'):
    for tod in TODs:
        if tod in fn:
            with omx.open_file(fn) as f:
                mode = 'highway'
                time_array = np.array(f['TIMEDA'])[:num_zones, :num_zones]
                cost_array = np.array(f['COSTDA'])[:num_zones, :num_zones] / 100
                toll_array = np.array(f['BTOLLDA'])[:num_zones, :num_zones] / 100 + np.array(f['VTOLLDA'])[:num_zones, :num_zones] / 100
                p_time_array = time_array + np.divide(cost_array, hh_mean_inc.VOT_per_min.values[:,None]) + np.divide(toll_array, hh_mean_inc.VOT_per_min.values[:,None])  # broadcasting VOT values horizontally to get VOT by origin zone
                ptt_matrices[(tod, mode)] = p_time_array

# Transit
waitThresh = 10 # 10 minutes per UEC
coef_dict = {'IWAIT_S': 2, 'IWAIT_L': 1, 'XWAIT' : 2, 'WACC' : 2, 'WEGR' : 2, 'WAUX' : 2}

#c_shortiWait	Short initial wait time coefficient -- see "waitThresh"	2.00 * c_ivt
#c_longiWait	Long initial wait time coefficient -- see "waitThresh"	1.00 * c_ivt
#c_wacc	Walk access time coefficient	2.00 * c_ivt
#c_wegr	Walk egress time coefficient	2.00 * c_ivt
#c_xwait Transfer wait time coefficient	2.00 * c_ivt
#c_waux	Walk auxilliary time coefficient		2.00 * c_ivt

# short wait time: c_shortiWait*min(WLK_TRN_WLK_IWAIT[tripPeriod]/100,waitThresh)
# long wait time: c_longiWait*max(WLK_TRN_WLK_IWAIT[tripPeriod]/100-waitThresh,0)
# is the initial wait time reflected as a sum of both?

for fn in glob.glob('trnskm*.omx'):
    for tod in TODs:
        if tod in fn:
            with omx.open_file(fn) as f:
                ptt = [np.array(f['IVTX']) / 100]
                mode = 'transit'
                for OVTT in ['XWAIT','WACC','WEGR','WAUX']:
                    ptt.append(np.array(f[OVTT]) * coef_dict[OVTT] / 100)
                IWAIT = coef_dict['IWAIT_S'] * np.array(f['IWAIT']) / 100 + coef_dict['IWAIT_L'] * np.clip(np.array(f['IWAIT'])/100 - waitThresh, a_min = 0, a_max = None)
                ptt.append(IWAIT)
                
                ptt_matrices[(tod, mode)] = np.add.reduce([mat[:num_zones, :num_zones] for mat in ptt]) 

all_zones_df = pd.DataFrame(0, index = df_land_use.ZONE.values, columns = [])
all_zones_df.index.name = 'zone_ID'

all_zones_pct_df = pd.DataFrame(0, index = df_land_use.ZONE.values, columns = [])
all_zones_pct_df.index.name = 'zone_ID'

for employment in emp_type:
    for tod in TODs:        
        for mode in ['highway','transit']:
            new_key = (tod,mode)
            if new_key in ptt_matrices:
                for (cutoff_s, cutoff_e) in zip(cutoff_start, cutoff_end):
                    grp_tt = (ptt_matrices[(tod,mode)])
                    grp_tt = ((grp_tt >= cutoff_s) & (grp_tt < cutoff_e)).astype(int)

                    all_zones_df[f'{employment}_{tod}_{mode}_{cutoff_s}_{cutoff_e}'] = (grp_tt*df_land_use[f'{employment}'].values).sum(axis=1)
                    all_zones_pct_df[f'{employment}_{tod}_{mode}_{cutoff_s}_{cutoff_e}'] = (grp_tt*df_land_use[f'{employment}'].values).sum(axis=1) / df_land_use[f'{employment}'].sum()

all_zones_df.to_excel(writer,sheet_name = 'perceived_TT')
all_zones_pct_df.to_excel(writer,sheet_name =  'perceived_TT_PCT')
hh_mean_inc[['TAZ','mean_inc', 'income_seg', 'VOT_per_hour', 'VOT_per_min']].to_excel(writer,sheet_name = 'HH inc & VOT', index = False)

writer.save()