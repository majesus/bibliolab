@echo off
setlocal EnableExtensions
set "HERE=%~dp0"
set "RS="
where Rscript.exe >nul 2>nul && set "RS=Rscript.exe"
if not defined RS for /d %%D in ("%ProgramFiles%\R\R-*") do if exist "%%D\bin\x64\Rscript.exe" set "RS=%%D\bin\x64\Rscript.exe"
if not defined RS for /d %%D in ("%LOCALAPPDATA%\Programs\R\R-*") do if exist "%%D\bin\x64\Rscript.exe" set "RS=%%D\bin\x64\Rscript.exe"
if not defined RS (
  echo No se encuentra Rscript.exe. Instale R o anada su carpeta bin al PATH.
  pause
  exit /b 1
)
echo Abriendo bibliolab. Conserve esta ventana abierta; Ctrl+C detiene la aplicacion.
"%RS%" --no-save --no-restore --no-init-file --encoding=UTF-8 "%HERE%lanzar_bibliolab.R" %*
if errorlevel 1 pause
