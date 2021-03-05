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
call connector-test-machine/travis/windows-download.bat %v%
msiexec /i server.msi INSTALLDIR=c:\projects\server SERVICENAME=mariadb ALLOWREMOTEROOTACCESS=true /qn
c:\projects\server\bin\mysql.exe -e "create database %d%" --user=root

set TEST_DB_USER=root
set TEST_DB_HOST=localhost
set TEST_DB_PASSWORD=
set TEST_DB_DATABASE=%d%
set TEST_DB_PORT=3306
set TEST_REQUIRE_TLS=0


