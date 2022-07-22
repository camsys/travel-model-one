::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
:: RunIteration.bat
::
:: MS-DOS batch file to execute a single iteration of the MTC travel model.  This script is repeatedly 
:: called by the RunModel batch file.  
::
:: For complete details, please see http://mtcgis.mtc.ca.gov/foswiki/Main/RunIterationBatch.
::
:: dto (2012 02 15) gde (2009 10 9)
::
::~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:: ------------------------------------------------------------------------------------------------------
::
:: Step 0:  If iteration equals zero, go to step four (i.e. skip the demand models)
::
:: ------------------------------------------------------------------------------------------------------

:: ------------------------------------------------------------------------------------------------------
::
:: Step 2:  Execute the choice models using CT-RAMP java code
::
:: ------------------------------------------------------------------------------------------------------

:core

if %ITER%==1 (
  rem run matrix manager, household manager and jppf driver
  cd CTRAMP\runtime
  call javaOnly_runMain.cmd 

  rem run jppf node
  cd CTRAMP\runtime
  call javaOnly_runNode0.cmd
)

::  Call the MtcTourBasedModel class
java -showversion -Xmx120000m -cp %CLASSPATH% -Dlog4j.configuration=log4j.xml -Djava.library.path=%RUNTIME% -Djppf.config=jppf-clientDistributed.properties com.pb.mtc.ctramp.MtcTourBasedModel mtcTourBased -iteration %ITER% -sampleRate %SAMPLESHARE% -sampleSeed %SEED%
if ERRORLEVEL 2 goto done


:: ------------------------------------------------------------------------------------------------------
::
:: Last Step:  Stamp the time of completion to the feedback report file
::
:: ------------------------------------------------------------------------------------------------------

echo FINISHED ITERATION %ITER%  %DATE% %TIME% >> logs\feedback.rpt 