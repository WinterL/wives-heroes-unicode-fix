@echo off
cd /d "%~dp0"
where py.exe >nul 2>nul
if errorlevel 1 goto use_python
py -3 patch.py apply
goto done
:use_python
where python.exe >nul 2>nul
if errorlevel 1 goto missing
python patch.py apply
goto done
:missing
echo Python 3.10 or newer is required. See README.md.
:done
pause
