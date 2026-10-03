@echo off
python "%~dp0scripts\tools\open_recording_studio.py" %*
if errorlevel 1 pause
