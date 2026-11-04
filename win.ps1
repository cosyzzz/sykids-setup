param(
    [string]$ServerUrl = "",
    [string]$Ticket = "",
    [switch]$Bg,
    [switch]$Fg,
    [switch]$VerifyOnly,
    [switch]$NoClose
)

# ============================================================================
# Cosy Classroom System -- Native Windows PowerShell Workstation Bootstrap
# Compatible with Windows PowerShell 5.1+ & PowerShell 7+
# Zero-Window Session-0 Instant Detach (< 0.1s close)
# ============================================================================

$ErrorActionPreference = "Stop"

if (-not $ServerUrl -and $env:SYKIDS_SERVER) { $ServerUrl = $env:SYKIDS_SERVER }
if (-not $Ticket -and $env:SYKIDS_TICKET) { $Ticket = $env:SYKIDS_TICKET }

$CurlBin = Join-Path $env:SystemRoot "System32\curl.exe"
if (-not (Test-Path $CurlBin)) {
    $cmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($cmd) { $CurlBin = $cmd.Source }
}
if (-not (Test-Path $CurlBin)) {
    Write-Host "[!] curl.exe was not found on this system. Please update Windows 10/11." -ForegroundColor Red
    exit 1
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSystem = $currentIdentity.Name -match "^(?i)NT AUTHORITY\\SYSTEM$"

# 1. Auto-Elevate or Instant Session-0 Detach
if (-not $VerifyOnly) {
    if (-not $isAdmin) {
        $selfPath = $PSCommandPath
        if (-not $selfPath) {
            $selfPath = Join-Path $env:TEMP "cosy-win.ps1"
            & $CurlBin --retry 3 -fsSL "https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.ps1" -o $selfPath 2>$null
        }
        $argStr = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$selfPath`""
        if ($ServerUrl) { $argStr += " -ServerUrl `"$ServerUrl`"" }
        if ($Ticket) { $argStr += " -Ticket `"$Ticket`"" }
        if ($Fg) { $argStr += " -Fg" }
        Start-Process powershell.exe -ArgumentList $argStr -Verb RunAs
        exit 0
    }

    if ($isAdmin -and (-not $isSystem) -and (-not $Fg) -and (-not $Bg)) {
        $sysTemp = Join-Path $env:SystemRoot "Temp"
        $bgWorkerCmd = Join-Path $sysTemp "cosy_bg_worker.cmd"
        $bgEnvCmd = Join-Path $sysTemp "cosy_bg_env.cmd"
        & $CurlBin --retry 3 -fsSL "https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd" -o $bgWorkerCmd 2>$null
        if (Test-Path $bgWorkerCmd) {
            $envContent = @(
                "set `"SERVER_URL=$ServerUrl`"",
                "set `"USE_TICKET=$Ticket`""
            )
            [System.IO.File]::WriteAllLines($bgEnvCmd, $envContent, [System.Text.Encoding]::ASCII)
            $schtasks = Join-Path $env:SystemRoot "System32\schtasks.exe"
            $tr = "$env:SystemRoot\System32\cmd.exe /d /c `"$bgWorkerCmd`" --bg"
            & $schtasks /Create /TN "CosySystemBootstrap" /RU "SYSTEM" /RL HIGHEST /SC ONCE /ST 00:00 /TR $tr /F >$null 2>&1
            & $schtasks /Run /TN "CosySystemBootstrap" >$null 2>&1
            if ($LASTEXITCODE -eq 0) {
                Remove-Item -LiteralPath (Join-Path $env:TEMP "cosy-win.ps1"), (Join-Path $env:TEMP "cosy-win.cmd"), (Join-Path $env:TEMP "cosy-setup.cmd") -Force -ErrorAction SilentlyContinue
                exit 0
            }
        }
    }
}

# Fallback direct execution via win.cmd
$tmpCmd = Join-Path $env:TEMP ("cosy_run_" + [guid]::NewGuid().ToString("N").Substring(0, 8) + ".cmd")
& $CurlBin --retry 3 -fsSL "https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd" -o $tmpCmd 2>$null
if (Test-Path $tmpCmd) {
    $cmdArgs = @()
    if ($ServerUrl) { $cmdArgs += @("--server", $ServerUrl) }
    if ($Ticket) { $cmdArgs += @("--ticket", $Ticket) }
    if ($Bg) { $cmdArgs += "--bg" }
    if ($Fg) { $cmdArgs += "--fg" }
    if ($VerifyOnly) { $cmdArgs += "--verify-only" }
    if ($NoClose) { $cmdArgs += "--no-close" }
    & "$env:SystemRoot\System32\cmd.exe" /d /c "`"$tmpCmd`" $($cmdArgs -join ' ')"
    $code = $LASTEXITCODE
    Remove-Item -LiteralPath $tmpCmd -Force -ErrorAction SilentlyContinue
    exit $code
}
exit 1
