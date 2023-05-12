set emmepath=C:\Program Files\INRO\Emme\Emme 4\Emme-4.7.0.11
set venv_path=C:\PY_VENV\tm2py
copy "%emmepath%\emme.pth" %venv_path%\Lib\site-packages\emme.pth

call "C:\PY_VENV\tm2py\Scripts\activate.bat"
cd C:\MTC_tmpy\travel-model-one\CS_utils\Py_summary_code
jupyter notebook