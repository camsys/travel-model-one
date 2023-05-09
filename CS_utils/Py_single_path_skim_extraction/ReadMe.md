
There are three steps:
•	Step1: The “Transitpath_v9_1_alltimeperiods_EMME4_6_allclasses_iter_04072023_step1.py” exports the 25 multi path csv files using the opened EMME transit database with strats files. These are very large multi path CSV files (the size of a PNR multi path csv file for one time period may be over 100GB). We manually zip the CSV files during the emme export process since the zipping process will also take a very long time for each file (1-4 hours to zip one multi path CSV file).
•	Step 2: The “Readpath_processsample_multiprocessing_2.py” uses the function defined in the “Readpath_extractpath_function_2.py” file to read 25 zipped multi path files using paraell processing to generate the 25 single path csv file. The script will also need the parameter files in the unzipped “Parametersfiles_step2.zip” file.
•	Step 3: The “csv2omx_V2 Naveen Li_step3.py” will convert the 25 single path csv files into the omx files.
