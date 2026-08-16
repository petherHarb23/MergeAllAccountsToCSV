:: This batch file allows you to drag and drop the custodian export files onto it and run the script.
@echo off
setlocal EnableDelayedExpansion
set "FileFolder="
if not "%~1"=="" set "FileFolder=%~dp1"
if not "%FileFolder%"=="" if "%FileFolder:~-1%"=="\" set "FileFolder=%FileFolder:~0,-1%"

set "FileList="
for %%F in (%*) do (
    if defined FileList set "FileList=!FileList!,"
    set "FileList=!FileList!^"%%~fF^""
)

pwsh -NoProfile -Command "& '%~dp0MergeAllAccountsToCSV.ps1' -FileList %FileList% -OutputFile '%FileFolder%\MergedPortfolio.csv' -Verbose"
Pause