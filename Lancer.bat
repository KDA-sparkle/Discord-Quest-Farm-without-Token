@echo off
rem conhost --headless : aucune console visible, meme si Windows Terminal est le terminal par defaut
start "" conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0QuestSpoofer.ps1"
