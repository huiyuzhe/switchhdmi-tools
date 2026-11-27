@echo off
rem HDMI Input Switch - tray app launcher
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0HDMISwitch-Tray.ps1"
