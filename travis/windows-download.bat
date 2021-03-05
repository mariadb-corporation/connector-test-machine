@echo off
setlocal ENABLEDELAYEDEXPANSION
set v=%~1
echo "v=%v%"

for /L %%i in (70, -1, 0) do (

	curl -fLsS -o server.msi http://mirror.i3d.net/pub/mariadb/mariadb-%v%.%%i/winx64-packages/mariadb-%v%.%%i-winx64.msi
	if !ERRORLEVEL! == 0  (
	   echo "File found mariadb-%v%.%%i-winx64.msi".
	   goto end
	)

)

echo Failure Reason Given is %errorlevel%
exit /b %errorlevel%

:end
