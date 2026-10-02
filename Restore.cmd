@echo off
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -File "%~dp0patch.ps1" -Action restore
set "patch_exit=%errorlevel%"
pause
exit /b %patch_exit%
