@echo off
set "PATH=C:\Users\daica\bin;%APPDATA%\npm;%PATH%"
set "NODE_OPTIONS=--max-old-space-size=4096"
cd /d "C:\Users\daica\OpenMausBot"
echo =================================================
echo   Starting OpenMausBot Server (Domain Mode)
echo   Domain: https://manus.4bytes.org
echo   Port:   8799
echo =================================================
node --experimental-strip-types server/openmausbot.ts serve --lan --port 8799 --public-url https://manus.4bytes.org %*
pause
