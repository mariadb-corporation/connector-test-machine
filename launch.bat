@echo off

set t="mariadb"
set v=""
set d=""

:initial
if "%1"=="" goto done
echo              %1
set aux=%1
if "%aux:~0,1%"=="-" (
   set nome=%aux:~1,250%
) else (
   set "%nome%=%1"
   set nome=
)
shift
goto initial
:done

echo %t%
echo %v%
echo %d%

IF "%t%" NEQ "mariadb" (
    echo "mariadb is actually the only supported type".
    exit /b 1
)

if "%v%"=="" (
    echo "version is mandatory".
    exit /b 2
)

if "%d%"=="" (
    echo "database is mandatory".
    exit /b 3
)


choco install curl

echo "searching msi"
call connector-test-machine/travis/windows-download.bat %v%
msiexec /i server.msi INSTALLDIR=c:\projects\server SERVICENAME=mariadb ALLOWREMOTEROOTACCESS=true /qn
c:\projects\server\bin\mysql.exe -e "create database %d%" --user=root

type connector-test-machine\travis\win.cnf >> c:\projects\server\data\my.ini
type c:\projects\server\data\my.ini

net stop mariadb && net start mariadb

REM Currently neither settings done with setx nor with set appear to be in the environment of the build script. It still won't hurt to have them 
setx TEST_DB_USER root
setx TEST_DB_HOST localhost
setx TEST_DB_PASSWORD ""
setx TEST_DB_DATABASE %d%
setx TEST_DB_PORT 3306
setx TEST_DB_ADD_PORT 3405
setx TEST_REQUIRE_TLS 0


REM setx does not change current env.
set TEST_DB_USER=root
set TEST_DB_HOST=localhost
set TEST_DB_PASSWORD=
set TEST_DB_DATABASE=%d%
set TEST_DB_PORT=3306
set TEST_DB_ADD_PORT=3405
set TEST_REQUIRE_TLS=0


echo export TEST_DB_USER=root > settestenv.sh
echo export TEST_DB_HOST=localhost >> settestenv.sh
echo export TEST_DB_PASSWORD= >> settestenv.sh
echo export TEST_DB_DATABASE=%d% >> settestenv.sh
echo export TEST_DB_PORT=3306 >> settestenv.sh
echo export TEST_DB_ADD_PORT=3405 >> settestenv.sh
echo export TEST_REQUIRE_TLS=0 >> settestenv.sh

dir .

powershell Install-WindowsFeature Net-Framework-Core
choco install wixtoolset
echo "refresh environment"
refreshenv
echo "after refresh environment"
