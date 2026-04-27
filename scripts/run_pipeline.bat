@echo off
echo =========================================================
echo Starting Agrarian Market Access Analysis Pipeline...
echo =========================================================
echo.
echo Running R script: 00_run_all.R
echo.

set R_SCRIPT_PATH=00_run_all.R

:: Check if Rscript is in path
where Rscript >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Rscript is not in your system PATH.
  echo Please make sure R is installed and added to the PATH environment variable.
  pause
  exit /b 1
)

Rscript "%R_SCRIPT_PATH%"

echo.
if %ERRORLEVEL% EQU 0 (
  echo =========================================================
  echo Pipeline finished successfully!
  echo =========================================================
) else (
  echo =========================================================
  echo Pipeline failed with an error. Please check the logs above.
  echo =========================================================
)

pause
