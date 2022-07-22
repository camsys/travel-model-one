:: Creates a venv in the Emme Shell that works with tm2py.
:: Needs to be called from within the Emme shell.
:: Open Emme Shell, and call this batch file using the full file path
:: call C:\path_name\setup_tm2py_venv.bat

set venv_path=C:\PY_VENV\tm2py
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