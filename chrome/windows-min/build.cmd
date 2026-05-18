@echo off
setlocal enableextensions enabledelayedexpansion

REM ── webkitium-min: configure + build + run + screenshot ───────────────────
REM Run from chrome\windows-min\ on a Windows box that already has WebKit-for-
REM Windows built at C:\W\webkit-src (override via env vars).
REM
REM Override defaults via env:
REM   set WEBKIT_SRC=C:\W\webkit-src
REM   set WEBKIT_BUILD=C:\W\webkit-src\WebKitBuild\Debug
REM   set OUT_PNG=%~dp0webkitium-windows-wikipedia.png
REM   set TARGET_URL=https://en.wikipedia.org
REM   set WAIT_SECONDS=15

if "%WEBKIT_SRC%"=="" set "WEBKIT_SRC=C:\W\webkit-src"
if "%WEBKIT_BUILD%"=="" set "WEBKIT_BUILD=%WEBKIT_SRC%\WebKitBuild\Debug"
if "%OUT_PNG%"=="" set "OUT_PNG=%~dp0webkitium-windows-wikipedia.png"
if "%TARGET_URL%"=="" set "TARGET_URL=https://en.wikipedia.org"
if "%WAIT_SECONDS%"=="" set "WAIT_SECONDS=15"

echo === Settings ===
echo   WEBKIT_SRC   = %WEBKIT_SRC%
echo   WEBKIT_BUILD = %WEBKIT_BUILD%
echo   TARGET_URL   = %TARGET_URL%
echo   OUT_PNG      = %OUT_PNG%
echo   WAIT_SECONDS = %WAIT_SECONDS%
echo.

if not exist "%WEBKIT_BUILD%\bin" (
    echo [ERROR] WEBKIT_BUILD\bin not found: %WEBKIT_BUILD%\bin
    echo Run the WebKit Windows build first: cd %WEBKIT_SRC% ^&^& perl Tools\Scripts\build-webkit --debug --win
    exit /b 2
)

REM ── MSVC env ─────────────────────────────────────────────────────────────
if exist "C:\BuildTools\Common7\Tools\VsDevCmd.bat" (
    call "C:\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 || exit /b 3
) else (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do (
        if exist "%%i\Common7\Tools\VsDevCmd.bat" call "%%i\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 || exit /b 3
    )
)

REM LLVM clang-cl (existing WebKit build uses it; keeps ABI/PDB conventions aligned)
if exist "C:\Program Files\LLVM\bin\clang-cl.exe" (
    set "PATH=C:\Program Files\LLVM\bin;%PATH%"
    set "CC=C:\Program Files\LLVM\bin\clang-cl.exe"
    set "CXX=C:\Program Files\LLVM\bin\clang-cl.exe"
)

REM ── Configure ────────────────────────────────────────────────────────────
set "BUILD_DIR=%~dp0build"
if exist "%BUILD_DIR%" rd /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%" || exit /b 4

set "GENERATOR=Ninja"
where ninja >NUL 2>&1
if errorlevel 1 set "GENERATOR=NMake Makefiles"

echo === Configure (%GENERATOR%) ===
cmake -S "%~dp0." -B "%BUILD_DIR%" -G "%GENERATOR%" ^
    -DCMAKE_BUILD_TYPE=Debug ^
    -DWEBKIT_SRC="%WEBKIT_SRC:\=/%" ^
    -DWEBKIT_BUILD="%WEBKIT_BUILD:\=/%" || exit /b 5

echo.
echo === Build ===
cmake --build "%BUILD_DIR%" --config Debug || exit /b 6

set "EXE=%BUILD_DIR%\bin\webkitium_min.exe"
if not exist "%EXE%" (
    echo [ERROR] EXE not produced at %EXE%
    dir "%BUILD_DIR%"
    exit /b 7
)

echo.
echo === Run ===
echo Launching: "%EXE%" --url %TARGET_URL% --out "%OUT_PNG%" --wait-seconds %WAIT_SECONDS%
"%EXE%" --url %TARGET_URL% --out "%OUT_PNG%" --wait-seconds %WAIT_SECONDS%
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo [ERROR] webkitium_min returned %RC%
    exit /b %RC%
)

if exist "%OUT_PNG%" (
    echo.
    echo === Done ===
    echo Screenshot: %OUT_PNG%
    for %%I in ("%OUT_PNG%") do echo Size: %%~zI bytes
) else (
    echo [ERROR] Screenshot file not found: %OUT_PNG%
    exit /b 8
)

endlocal
exit /b 0
