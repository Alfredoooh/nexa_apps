@echo off
setlocal

rem Patch m3e_haptics after Flutter pub get and before Gradle configures modules.
set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..") do set PROJECT_DIR=%%~fI
set PATCH_SCRIPT=%PROJECT_DIR%\tools\patch_m3e_haptics_agp9.py
if exist "%PATCH_SCRIPT%" (
  where py >nul 2>nul
  if errorlevel 1 (
    where python >nul 2>nul
    if errorlevel 1 (
      echo Erro: Python 3 e necessario para corrigir m3e_haptics antes do Gradle. 1>&2
      exit /b 1
    )
    python "%PATCH_SCRIPT%"
  ) else (
    py -3 "%PATCH_SCRIPT%"
  )
  if errorlevel 1 exit /b 1
)

set VERSION=9.5.0
set DIST=%USERPROFILE%\.gradle\wrapper\dists\looply-gradle-%VERSION%
set GRADLE=%DIST%\gradle-%VERSION%\bin\gradle.bat
if exist "%GRADLE%" goto run_gradle
if not exist "%DIST%" mkdir "%DIST%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-WebRequest 'https://services.gradle.org/distributions/gradle-%VERSION%-bin.zip' -OutFile '%DIST%\gradle.zip'; Expand-Archive -Force '%DIST%\gradle.zip' '%DIST%'; Remove-Item '%DIST%\gradle.zip'"
if errorlevel 1 exit /b 1
:run_gradle
call "%GRADLE%" %*
exit /b %ERRORLEVEL%
