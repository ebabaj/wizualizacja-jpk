@echo off
rem Aktualizuje opisy pól w jpk_v7.xslt na podstawie schemy XSD JPK_V7, a potem przebudowuje JpkViewer.exe.
rem Parametry przekazywane do skryptu, np.:  aktualizuj_opisy.bat -Xsd http://crd.gov.pl/wzor/.../schemat.xsd
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aktualizuj_opisy.ps1" %*
if errorlevel 1 (
  echo Aktualizacja opisow nie powiodla sie.
  pause
  exit /b 1
)
call "%~dp0build.bat"
pause
