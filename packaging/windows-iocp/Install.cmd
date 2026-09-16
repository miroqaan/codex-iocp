@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
set "PatchExitCode=%ERRORLEVEL%"
echo.
if not "%PatchExitCode%"=="0" echo Installation failed. Read the error above.
pause
exit /b %PatchExitCode%
