@echo off
@REM // powershell.exe -executionpolicy bypass -windowstyle hidden -noninteractive -nologo -file "adinfo.ps1"
powershell.exe -executionpolicy bypass  -file "%~dp0adinfo.ps1"
pause 