@echo off
rem Kompilacja JpkViewer.exe wbudowanym w Windows kompilatorem C# (.NET Framework 4.x) - bez instalacji czegokolwiek.
setlocal
cd /d "%~dp0"
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo Nie znaleziono csc.exe ^(.NET Framework 4.x^).
  exit /b 1
)
"%CSC%" /nologo /target:winexe /optimize+ /out:JpkViewer.exe ^
  /resource:jpk_v7.xslt,jpk_v7.xslt ^
  /r:System.Windows.Forms.dll ^
  JpkViewer.cs
if errorlevel 1 (
  echo Kompilacja nie powiodla sie.
  exit /b 1
)
echo Gotowe: %~dp0JpkViewer.exe
