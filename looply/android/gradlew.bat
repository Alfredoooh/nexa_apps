@echo off
setlocal
set VERSION=8.13
set DIST=%USERPROFILE%\.gradle\wrapper\dists\looply-gradle-%VERSION%
set GRADLE=%DIST%\gradle-%VERSION%\bin\gradle.bat
if exist "%GRADLE%" goto run_gradle
if not exist "%DIST%" mkdir "%DIST%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-WebRequest 'https://services.gradle.org/distributions/gradle-%VERSION%-bin.zip' -OutFile '%DIST%\gradle.zip'; Expand-Archive -Force '%DIST%\gradle.zip' '%DIST%'; Remove-Item '%DIST%\gradle.zip'"
if errorlevel 1 exit /b %ERRORLEVEL%
:run_gradle
call "%GRADLE%" %*
exit /b %ERRORLEVEL%
