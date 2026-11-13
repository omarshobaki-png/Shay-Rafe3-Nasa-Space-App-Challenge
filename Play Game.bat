@echo off
rem Double-click to launch Space Mission Designer with Godot 4.7.2.
setlocal
set "PROJ=%~dp0game"
set "GODOT="
for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT for /f "delims=" %%G in ('dir /b /s "%LOCALAPPDATA%\Microsoft\WinGet\Packages\Godot_v4.7.2-stable_win64.exe" 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT (
  echo Godot 4.7.2 not found. Install it with:  winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%PROJ%"
