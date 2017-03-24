@echo off
rem
echo ********** init.bat, v.0.65 ********** 
if not exist BACKUP mkdir BACKUP
osynca.exe /i
if errorlevel 0 (
  echo *.bat files are created
) else (
  echo Error in osynca
)
osynca.exe /f
if errorlevel 0 (
  echo *.fil file is created
) else (
  echo Error in osynca
)
echo ********** End of init.bat ********** 
pause