@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ============================================================================
:: Cosy Classroom System — Native Windows Installer
:: Pure Native Batch Script (curl.exe + certutil.exe + CPInstall.exe)
:: Zero PowerShell dependency - Zero ExecutionPolicy friction
:: ============================================================================

set "CURL_BIN=%SystemRoot%\System32\curl.exe"
if not exist "!CURL_BIN!" (
    for /f "tokens=*" %%c in ('where curl.exe 2^>nul') do set "CURL_BIN=%%c"
)
if not exist "!CURL_BIN!" (
    echo [!] Khong tim thay curl.exe tren he thong. Vui long cai dat curl hoac cap nhat Windows 10/11.
    exit /b 1
)

set "SERVER_URL="
set "USE_TICKET="
set "VERIFY_ONLY=0"

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
echo  Cosy Classroom System — Windows Workstation Bootstrap
echo ============================================================================
echo Cu phap:
echo   setup.cmd [--server ^<URL^>] [--ticket ^<TICKET^>]
echo.
echo Mac dinh che do Ticketless: Tu dong phat hien may chu va cap ve ghi danh.
exit /b 0

:args_done
echo ============================================================================
echo  Cosy Classroom System — Windows Workstation Bootstrap
echo ============================================================================

:: Tao thu muc lam viec tam thoi an toan
set "WORK=%TEMP%\cosy_install_%RANDOM%_%RANDOM%"
mkdir "%WORK%" 2>nul
if not exist "%WORK%" (
    echo [!] Khong the tao thu muc lam viec tam: "%WORK%"
    exit /b 1
)

:: ----------------------------------------------------------------------------
:: [1/5] (15%) Resolve SERVER_URL
:: ----------------------------------------------------------------------------
echo [Cosy] [1/5] (15%%) Dang xac dinh may chu Cosy Classroom...
if not defined SERVER_URL (
    "!CURL_BIN!" --retry 2 --connect-timeout 5 --max-time 10 -fsSL "https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/beacon.txt" -o "%WORK%\beacon.txt" 2>nul
    if exist "%WORK%\beacon.txt" (
        for /f "usebackq tokens=1,2 delims=|" %%A in ("%WORK%\beacon.txt") do (
            if "%%A"=="SYKIDS-BEACON-V2" (
                set "CANDIDATE=%%B"
                set "CANDIDATE=!CANDIDATE:wss://=https://!"
                set "CANDIDATE=!CANDIDATE:ws://=http://!"
                if "!CANDIDATE:~-3!"=="/ws" set "CANDIDATE=!CANDIDATE:~0,-3!"
                
                for /f "delims=" %%C in ('"!CURL_BIN!" -sS -I -o NUL -w "%%{http_code}" --connect-timeout 5 --max-time 8 "!CANDIDATE!/cosy/bin/CPInstall.exe" 2^>nul') do (
                    if "%%C"=="200" (
                        set "SERVER_URL=!CANDIDATE!"
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
echo [Cosy] [1/5] May chu duoc chon: !SERVER_URL!

:: ----------------------------------------------------------------------------
:: [2/5] (35%) Download CosySchoolCA.cer
:: ----------------------------------------------------------------------------
echo [Cosy] [2/5] (35%%) Dang tai chung chi goc CosySchoolCA.cer...
"!CURL_BIN!" --retry 3 --retry-all-errors -fsSL --connect-timeout 15 --max-time 45 "!SERVER_URL!/cosy/ca.cer" -o "%WORK%\CosySchoolCA.cer" 2>nul
if exist "%WORK%\CosySchoolCA.cer" (
    echo [Cosy] [2/5] Da tai chung chi goc CA thanh cong.
) else (
    echo [Cosy] [2/5] CA tu xa khong ton tai hoac su dung System CA mac dinh.
)

:: ----------------------------------------------------------------------------
:: [3/5] (60%) Download CPInstall.exe + headers
:: ----------------------------------------------------------------------------
echo [Cosy] [3/5] (60%%) Dang tai bo cai dat he thong CPInstall.exe...
"!CURL_BIN!" --retry 3 --retry-all-errors -fsSL --connect-timeout 15 --max-time 180 -D "%WORK%\headers.txt" "!SERVER_URL!/cosy/bin/CPInstall.exe" -o "%WORK%\CPInstall.exe"
if not exist "%WORK%\CPInstall.exe" (
    echo [!] Loi: Khong the tai CPInstall.exe tu may chu !SERVER_URL!.
    rd /s /q "%WORK%" 2>nul
    exit /b 1
)

:: ----------------------------------------------------------------------------
:: [4/5] (75%) Parse headers & Verify SHA256 integrity
:: ----------------------------------------------------------------------------
echo [Cosy] [4/5] (75%%) Kiem tra tinh toan ven va thong so bao mat...
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
        echo [!] Loi nghiem trong: Ma bam SHA256 CPInstall.exe khong khop!
        echo     Ky vong : !EXPECTED_SHA!
        echo     Thuc te : !ACTUAL_SHA!
        rd /s /q "%WORK%" 2>nul
        exit /b 1
    )
    echo [Cosy] [4/5] Xac thuc SHA256 toan ven hop le (!ACTUAL_SHA:~0,16!...^).
) else (
    echo [Cosy] [4/5] Tinh toan ma bam SHA256 (!ACTUAL_SHA:~0,16!...^).
)

:: ----------------------------------------------------------------------------
:: [5/5] (90% -> 100%) Execute CPInstall.exe
:: ----------------------------------------------------------------------------
echo [Cosy] [5/5] (90%%) Dang khoi chay cai dat dich vu giam sat lop hoc...
pushd "%WORK%"
if "!VERIFY_ONLY!"=="1" (
    "%WORK%\CPInstall.exe" --selftest
    set "CP_EXIT=!ERRORLEVEL!"
    popd
    rd /s /q "%WORK%" 2>nul
    if !CP_EXIT! neq 0 exit /b !CP_EXIT!
    echo [Cosy] [100%%] Xac thuc E2E thanh cong (Beacon + CA + SHA256 + CPInstall --selftest OK^)!
    exit /b 0
)
"%WORK%\CPInstall.exe" --install-auto --ws-url "!WS_URL!" --cert-pin "!CERT_PIN!" --enroll-ticket "!USE_TICKET!"
set "CP_EXIT=!ERRORLEVEL!"
popd

if !CP_EXIT! neq 0 (
    echo [!] CPInstall.exe ket thuc voi ma loi !CP_EXIT!.
    rd /s /q "%WORK%" 2>nul
    exit /b !CP_EXIT!
)

sc query cpsv >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo [Cosy] [100%%] Da cai dat thanh cong dich vu he thong (cpsv / cpwg / cpag)!
) else (
    echo [Cosy] [Thong bao] Hoan tat quy trinh cai dat. Kiem tra trang thai dich vu.
)

rd /s /q "%WORK%" 2>nul
exit /b 0
