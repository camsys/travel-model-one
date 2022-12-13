:: Creates a venv in the Emme Shell that works with tm2py.
:: Needs to be called from within the Emme shell.
:: Open Emme Shell, and call this batch file using the full file path
:: call C:\path_name\setup_tm2py_venv.bat

:: venv_path is the target folder for the virtual environment. It needs to exist on the machine.
set venv_path=C:\PY_VENV\tm2py
:: tm2py_path is the root path of the tm2py repository cloned to the machine. There cannot be trailing space on line 9.
set tm2py_path=C:\MTC_tmpy\TM2\tm2py
python -m venv %venv_path%
call %venv_path%\Scripts\activate.bat
python -m pip install --upgrade pip
pip install pipwin
pipwin install gdal
pipwin install fiona
pip install -r %tm2py_path%\requirements.txt
copy "%emmepath%\emme.pth" %venv_path%\Lib\site-packages\emme.pth
cd %tm2py_path%