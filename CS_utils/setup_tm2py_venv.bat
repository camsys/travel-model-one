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