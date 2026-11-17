@echo off
set "PATH=C:\Users\daica\bin;%APPDATA%\npm;%PATH%"
cd /d "C:\Users\daica\OpenMausBot"
echo ===================================================
echo     OpenMausBot - Tao Link va Ma Pairing Moi
echo ===================================================
echo.
node --experimental-strip-types server/openmausbot.ts pair --public-url https://manus.4bytes.org --ttl 24h
echo.
pause
