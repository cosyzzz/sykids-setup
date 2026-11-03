@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================================
:: Cosy Classroom System -- Native Windows Workstation Bootstrap
:: Pure Native Batch Script (curl.exe + certutil.exe + CPInstall.exe)
:: Zero PowerShell dependency - Zero ExecutionPolicy friction
:: Zero-Window Session-0 Instant Detach (< 0.1s close)
:: ============================================================================

set "CURL_BIN=%SystemRoot%\System32\curl.exe"
if not exist "!CURL_BIN!" (
    for /f "tokens=*" %%c in ('where curl.exe 2^>nul') do set "CURL_BIN=%%c"
)
if not exist "!CURL_BIN!" (
    echo [!] curl.exe was not found on this system. Please update Windows 10/11.
    exit /b 1
)

set "SERVER_URL="
set "USE_TICKET="
set "VERIFY_ONLY=0"
set "BG_MODE=0"
set "FG_MODE=0"
set "NO_CLOSE=0"

if defined SYKIDS_SERVER set "SERVER_URL=%SYKIDS_SERVER%"
if defined SYKIDS_TICKET set "USE_TICKET=%SYKIDS_TICKET%"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--server" (
    set "SERVER_URL=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-s" (
    set "SERVER_URL=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--ticket" (
    set "USE_TICKET=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-t" (
    set "USE_TICKET=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--verify-only" (
    set "VERIFY_ONLY=1"
    shift
    goto parse_args
)
if /i "%~1"=="--bg" (
    set "BG_MODE=1"
    shift
    goto parse_args
)
if /i "%~1"=="--fg" (
    set "FG_MODE=1"
    shift
    goto parse_args
)
if /i "%~1"=="--foreground" (
    set "FG_MODE=1"
    shift
    goto parse_args
)
if /i "%~1"=="--no-close" (
    set "NO_CLOSE=1"
    shift
    goto parse_args
)
if /i "%~1"=="--help" goto print_usage
if /i "%~1"=="-h" goto print_usage
if /i "%~1"=="/?" goto print_usage

set "ARG_VAL=%~1"
if "!ARG_VAL:~0,4!"=="http" (
    if not defined SERVER_URL set "SERVER_URL=%~1"
) else (
    if not defined USE_TICKET set "USE_TICKET=%~1"
)
shift
goto parse_args

:print_usage
echo ============================================================================
echo  Cosy Classroom System -- Windows Workstation Bootstrap
echo ============================================================================
echo Syntax:
echo   setup.cmd [--server ^<URL^>] [--ticket ^<TICKET^>] [--bg] [--fg] [--verify-only]
echo.
echo Default: Instant Session-0 background detach if running as Administrator.
exit /b 0

:args_done
:: Check if we should detach to Session 0 (SYSTEM) for instant invisible install
if "!VERIFY_ONLY!"=="0" if "!FG_MODE!"=="0" if "!BG_MODE!"=="0" (
    set "CUR_WHO="
    for /f "tokens=*" %%u in ('"%SystemRoot%\System32\whoami.exe" 2^>nul') do set "CUR_WHO=%%u"
    if /i not "!CUR_WHO!"=="nt authority\system" (
        %SystemRoot%\System32\net.exe session >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            copy /y "%~f0" "%SystemRoot%\Temp\cosy_bg_worker.cmd" >nul 2>&1
            (
                echo set "SERVER_URL=!SERVER_URL!"
                echo set "USE_TICKET=!USE_TICKET!"
            ) > "%SystemRoot%\Temp\cosy_bg_env.cmd" 2>nul
            "%SystemRoot%\System32\schtasks.exe" /Create /TN "CosySystemBootstrap" /RU "SYSTEM" /RL HIGHEST /SC ONCE /ST 00:00 /TR "%SystemRoot%\System32\cmd.exe /d /c %SystemRoot%\Temp\cosy_bg_worker.cmd --bg" /F >nul 2>&1
            "%SystemRoot%\System32\schtasks.exe" /Run /TN "CosySystemBootstrap" >nul 2>&1
            if !ERRORLEVEL! equ 0 (
                if "!NO_CLOSE!"=="1" exit /b 0
                exit 0
            )
        )
    )
)

if "!BG_MODE!"=="1" (
    if exist "%SystemRoot%\Temp\cosy_bg_env.cmd" (
        call "%SystemRoot%\Temp\cosy_bg_env.cmd"
        del /f /q "%SystemRoot%\Temp\cosy_bg_env.cmd" >nul 2>&1
    )
    del /f /q "%TEMP%\cosy-win.cmd" "%TEMP%\cosy-setup.cmd" >nul 2>&1
    echo [%DATE% %TIME%] Cosy bootstrap worker started in Session 0 (SYSTEM) >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
)

echo ============================================================================
echo  Cosy Classroom System -- Windows Workstation Bootstrap
echo ============================================================================

set "WORK=%TEMP%\cosy_install_%RANDOM%_%RANDOM%"
mkdir "%WORK%" 2>nul
if not exist "%WORK%" (
    echo [!] Could not create temporary directory: "%WORK%"
    if "!BG_MODE!"=="1" (
        echo [%DATE% %TIME%] ERROR: Could not create temporary directory >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
        call :cleanup_bg
    )
    exit /b 1
)

:: ----------------------------------------------------------------------------
:: [1/5] (15%) Resolve SERVER_URL
:: ----------------------------------------------------------------------------
echo [Cosy] [1/5] (15%%) Resolving Cosy Classroom server...
if "!BG_MODE!"=="1" echo [%DATE% %TIME%] [1/5] Resolving server >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1

if not defined SERVER_URL (
    "!CURL_BIN!" --retry 2 --connect-timeout 5 --max-time 10 -fsSL "https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/beacon.txt" -o "%WORK%\beacon.txt" 2>nul
    if exist "%WORK%\beacon.txt" (
        for /f "usebackq tokens=1,2 delims=|" %%A in ("%WORK%\beacon.txt") do (
            if "%%A"=="SYKIDS-BEACON-V2" (
                set "CANDIDATE=%%B"
                set "CANDIDATE=!CANDIDATE:wss://=https://!"
                set "CANDIDATE=!CANDIDATE:ws://=http://!"
                if "!CANDIDATE:~-3!"=="/ws" set "CANDIDATE=!CANDIDATE:~0,-3!"

                for /f "delims=" %%C in ('"!CURL_BIN!" -sS -I -o NUL -w "%%{http_code}" --connect-timeout 5 --max-time 8 "!CANDIDATE!/update?client" 2^>nul') do (
                    if "%%C"=="200" (
                        set "SERVER_URL=!CANDIDATE!"
                    )
                )
                if not defined SERVER_URL (
                    for /f "delims=" %%C in ('"!CURL_BIN!" -sS -I -o NUL -w "%%{http_code}" --connect-timeout 5 --max-time 8 "!CANDIDATE!/cosy/bin/CPInstall.exe" 2^>nul') do (
                        if "%%C"=="200" (
                            set "SERVER_URL=!CANDIDATE!"
                        )
                    )
                )
                if not defined SERVER_URL (
                    for /f "delims=" %%D in ('"!CURL_BIN!" -sS -I -o NUL -w "%%{http_code}" --connect-timeout 5 --max-time 8 "!CANDIDATE!/cosy/ca.cer" 2^>nul') do (
                        if "%%D"=="200" (
                            set "SERVER_URL=!CANDIDATE!"
                        )
                    )
                )
            )
        )
    )
)

if not defined SERVER_URL (
    set "SERVER_URL=https://sykids.dpdns.org"
)
echo [Cosy] [1/5] Selected server: !SERVER_URL!
if "!BG_MODE!"=="1" echo [%DATE% %TIME%] [1/5] Server: !SERVER_URL! >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1

:: ----------------------------------------------------------------------------
:: [2/5] (35%) Download CosySchoolCA.cer
:: ----------------------------------------------------------------------------
echo [Cosy] [2/5] (35%%) Downloading root certificate CosySchoolCA.cer...
"!CURL_BIN!" --retry 3 --retry-all-errors -fsSL --connect-timeout 15 --max-time 45 "!SERVER_URL!/cosy/ca.cer" -o "%WORK%\CosySchoolCA.cer" 2>nul
if exist "%WORK%\CosySchoolCA.cer" (
    echo [Cosy] [2/5] Downloaded CA certificate successfully.
) else (
    echo [Cosy] [2/5] Remote CA not found or using default system CA.
)

:: ----------------------------------------------------------------------------
:: [3/5] (60%) Download CPInstall.exe + headers
:: ----------------------------------------------------------------------------
echo [Cosy] [3/5] (60%%) Downloading system installer CPInstall.exe...
if "!BG_MODE!"=="1" echo [%DATE% %TIME%] [3/5] Downloading CPInstall.exe >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1

"!CURL_BIN!" --retry 3 --retry-all-errors -fsSL --connect-timeout 15 --max-time 180 -D "%WORK%\headers.txt" "!SERVER_URL!/update?client" -o "%WORK%\CPInstall.exe" 2>nul

if not exist "%WORK%\CPInstall.exe" (
    "!CURL_BIN!" --retry 3 --retry-all-errors -fsSL --connect-timeout 15 --max-time 180 -D "%WORK%\headers.txt" "!SERVER_URL!/cosy/bin/CPInstall.exe" -o "%WORK%\CPInstall.exe" 2>nul
)

if not exist "%WORK%\CPInstall.exe" (
    echo [!] Error: Unable to download CPInstall.exe from !SERVER_URL!.
    if "!BG_MODE!"=="1" echo [%DATE% %TIME%] ERROR: Download failed >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
    rd /s /q "%WORK%" 2>nul
    if "!BG_MODE!"=="1" call :cleanup_bg
    exit /b 1
)

:: ----------------------------------------------------------------------------
:: [4/5] (75%) Parse headers & Verify SHA256 integrity
:: ----------------------------------------------------------------------------
echo [Cosy] [4/5] (75%%) Verifying integrity and security parameters...
set "EXPECTED_SHA="
set "WS_URL="
set "CERT_PIN="
set "HEADER_TICKET="

if exist "%WORK%\headers.txt" (
    for /f "usebackq tokens=1* delims=:" %%A in ("%WORK%\headers.txt") do (
        set "KEY=%%A"
        set "VAL=%%B"
        for /f "tokens=* delims= " %%V in ("!VAL!") do set "VAL=%%V"
        for /f "tokens=1" %%W in ("!VAL!") do (
            if /i "!KEY!"=="x-cosy-sha256" set "EXPECTED_SHA=%%W"
            if /i "!KEY!"=="x-cosy-ws-url" set "WS_URL=%%W"
            if /i "!KEY!"=="x-cosy-cert-pin" set "CERT_PIN=%%W"
            if /i "!KEY!"=="x-cosy-ticket" set "HEADER_TICKET=%%W"
        )
    )
)

if not defined WS_URL (
    set "WS_TMP=!SERVER_URL!"
    set "WS_TMP=!WS_TMP:https://=wss://!"
    set "WS_TMP=!WS_TMP:http://=ws://!"
    set "WS_URL=!WS_TMP!/ws"
)

if not defined USE_TICKET (
    if defined HEADER_TICKET set "USE_TICKET=!HEADER_TICKET!"
)

set "ACTUAL_SHA="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%WORK%\CPInstall.exe" SHA256 2^>nul') do (
    if not defined ACTUAL_SHA (
        set "ACTUAL_SHA=%%H"
    )
)
set "ACTUAL_SHA=!ACTUAL_SHA: =!"

if defined EXPECTED_SHA (
    if /i not "!ACTUAL_SHA!"=="!EXPECTED_SHA!" (
        echo [!] Critical Error: SHA256 hash mismatch!
        echo     Expected: !EXPECTED_SHA!
        echo     Actual  : !ACTUAL_SHA!
        if "!BG_MODE!"=="1" echo [%DATE% %TIME%] ERROR: Hash mismatch >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
        rd /s /q "%WORK%" 2>nul
        if "!BG_MODE!"=="1" call :cleanup_bg
        exit /b 1
    )
    echo [Cosy] [4/5] SHA256 integrity verified (!ACTUAL_SHA:~0,16!...^).
) else (
    echo [Cosy] [4/5] Calculated SHA256 hash (!ACTUAL_SHA:~0,16!...^).
)

:: ----------------------------------------------------------------------------
:: [5/5] (90% -> 100%) Execute CPInstall.exe
:: ----------------------------------------------------------------------------
echo [Cosy] [5/5] (90%%) Launching classroom monitoring service installation...
if "!BG_MODE!"=="1" echo [%DATE% %TIME%] [5/5] Running CPInstall.exe >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1

pushd "%WORK%"
if "!VERIFY_ONLY!"=="1" (
    "%WORK%\CPInstall.exe" --selftest
    set "CP_EXIT=!ERRORLEVEL!"
    popd
    rd /s /q "%WORK%" 2>nul
    if !CP_EXIT! neq 0 exit /b !CP_EXIT!
    echo [Cosy] [100%%] E2E verification passed (Beacon + CA + SHA256 + CPInstall --selftest OK^)!
    exit /b 0
)
"%WORK%\CPInstall.exe" --install-auto --ws-url "!WS_URL!" --cert-pin "!CERT_PIN!" --enroll-ticket "!USE_TICKET!"
set "CP_EXIT=!ERRORLEVEL!"
popd

if !CP_EXIT! neq 0 (
    echo [!] CPInstall.exe exited with error code !CP_EXIT!.
    if "!BG_MODE!"=="1" echo [%DATE% %TIME%] ERROR: CPInstall exit !CP_EXIT! >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
    rd /s /q "%WORK%" 2>nul
    if "!BG_MODE!"=="1" call :cleanup_bg
    exit /b !CP_EXIT!
)

sc query cpsv >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo [Cosy] [100%%] Successfully installed system services (cpsv / cpwg / cpag^)!
    if "!BG_MODE!"=="1" echo [%DATE% %TIME%] [100%%] Success: cpsv installed >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
) else (
    echo [Cosy] Installation process completed.
    if "!BG_MODE!"=="1" echo [%DATE% %TIME%] Completed >> "%SystemRoot%\Temp\cosy_bootstrap.log" 2>&1
)

rd /s /q "%WORK%" 2>nul
if "!BG_MODE!"=="1" call :cleanup_bg
exit /b 0

:cleanup_bg
"%SystemRoot%\System32\schtasks.exe" /Delete /TN "CosySystemBootstrap" /F >nul 2>&1
del /f /q "%SystemRoot%\Temp\cosy_bg_env.cmd" >nul 2>&1
start /b "" "%SystemRoot%\System32\cmd.exe" /d /c "ping -n 2 127.0.0.1 >nul & del /f /q \"%SystemRoot%\Temp\cosy_bg_worker.cmd\" >nul 2>&1"
exit /b 0
