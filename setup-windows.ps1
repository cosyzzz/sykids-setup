<#
.SYNOPSIS
    SYKids Protection Platform - Windows Endpoint Bootstrap Launcher (CLI)
.DESCRIPTION
    Tải bộ cài đặt SYKids thông qua mã vé cài đặt 1 lần và khởi chạy minh bạch
    kèm thanh tiến trình 0% -> 100% trên cửa sổ dòng lệnh.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Ticket = $env:SYKIDS_TICKET,

    [Parameter()]
    [string]$Server = $env:SYKIDS_SERVER,

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

if ([string]::IsNullOrWhiteSpace($Server)) {
    $Server = 'https://sykids.tail983a96.ts.net'
}
$Server = $Server.Trim().TrimEnd('/')

if ($Server -notmatch '^https?://\S+$') {
    throw "[SYKids] Địa chỉ máy chủ không hợp lệ (phải bắt đầu bằng https:// hoặc http://): $Server"
}

if ($Help) {
    Write-Host ""
    Write-Host "[SYKids] Hướng dẫn thiết lập thiết bị Windows" -ForegroundColor Cyan
    Write-Host "  Cách 1 (Chạy trực tiếp từ CMD / Win + R):"
    Write-Host '    cmd /c "curl.exe -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-windows.ps1 -o "%TEMP%\sykids-setup.ps1" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\sykids-setup.ps1" <MA_VE_1_LAN>"'
    Write-Host ""
    Write-Host "  Cách 2 (Chạy trong PowerShell):"
    Write-Host '    curl.exe -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-windows.ps1 -o "$env:TEMP\sykids-setup.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\sykids-setup.ps1" "<MA_VE_1_LAN>"'
    Write-Host ""
    Write-Host "  Tham số:"
    Write-Host "    -Ticket <MA_VE_1_LAN>   Mã vé cài đặt 1 lần lấy trên Dashboard (hoặc biến SYKIDS_TICKET)"
    Write-Host "    -Server <URL>           Máy chủ SYKids (mặc định: https://sykids.tail983a96.ts.net)"
    Write-Host "    -Help                   Hiển thị hướng dẫn này"
    Write-Host ""
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Ticket)) {
    Write-Host "[SYKids] Thiếu mã vé cài đặt 1 lần (<MA_VE_1_LAN>). Hãy lấy mã vé trên Dashboard rồi truyền vào cuối câu lệnh." -ForegroundColor Red
    exit 1
}

$Ticket = $Ticket.Trim()
if ($Ticket -notmatch '^[A-Za-z0-9._~+/-]+=*$') {
    Write-Host "[SYKids] Mã vé cài đặt không hợp lệ (chứa ký tự không được phép). Hãy kiểm tra lại mã vé trên Dashboard." -ForegroundColor Red
    exit 1
}

function Show-Step([int]$Percent) {
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $filled = [int][Math]::Floor($Percent / 5)
    $empty = 20 - $filled
    $bar = ('#' * $filled) + ('-' * $empty)
    Write-Host -NoNewline ("`r[SYKids] Đang thiết lập dịch vụ... [{0}] {1,3}%   " -f $bar, $Percent) -ForegroundColor Cyan
}

$tmpExe = Join-Path $env:TEMP ("SYKids_Installer_" + [guid]::NewGuid().ToString("N") + ".exe")

try {
    Write-Host ""
    Show-Step 0

    $ticketEsc = [uri]::EscapeDataString($Ticket)
    $dlUrl = "$Server/download/CPInstall-Silent.exe?t=$ticketEsc"
    Show-Step 15

    Show-Step 30
    $curlExe = "$env:SystemRoot\System32\curl.exe"
    $httpCode = '000'

    if (Test-Path -LiteralPath $curlExe) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $curlOut = & $curlExe -sSL -w "%{http_code}" --connect-timeout 15 --max-time 90 -o $tmpExe $dlUrl 2>$null
            if ($null -ne $curlOut) {
                $httpCode = ($curlOut | Out-String).Trim()
            }
        } finally {
            $ErrorActionPreference = $prevEap
        }
    } else {
        try {
            Invoke-WebRequest -Uri $dlUrl -UseBasicParsing -OutFile $tmpExe
            $httpCode = '200'
        } catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $httpCode = ([int]$_.Exception.Response.StatusCode).ToString()
            } else {
                $httpCode = '000'
            }
        }
    }

    if ($httpCode -eq '401' -or $httpCode -eq '403') {
        Write-Host ""
        Write-Host "[SYKids] Vé cài đặt không hợp lệ hoặc đã được sử dụng (mỗi vé chỉ dùng 1 lần). Hãy tạo vé mới trên Dashboard." -ForegroundColor Red
        exit 1
    }

    if ($httpCode -eq '410') {
        Write-Host ""
        Write-Host "[SYKids] Vé cài đặt đã hết hạn. Hãy tạo vé mới trên Dashboard." -ForegroundColor Red
        exit 1
    }

    if ($httpCode -ne '200' -or -not (Test-Path -LiteralPath $tmpExe) -or (Get-Item -LiteralPath $tmpExe).Length -lt 4096) {
        Write-Host ""
        Write-Host "[SYKids] Không thể tải bộ cài từ máy chủ (HTTP $httpCode)." -ForegroundColor Red
        exit 1
    }

    Show-Step 55
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    try {
        if ($isAdmin) {
            $proc = Start-Process -FilePath $tmpExe -ArgumentList '--silent', '--no-elevate' -PassThru
        } else {
            $proc = Start-Process -FilePath $tmpExe -ArgumentList '--silent', '--no-elevate' -Verb RunAs -PassThru
        }
    } catch {
        Write-Host ""
        Write-Host "[SYKids] Không thể khởi chạy bộ cài (quyền Quản trị viên UAC bị từ chối hoặc lỗi hệ thống)." -ForegroundColor Red
        exit 1
    }

    if ($null -eq $proc) {
        Write-Host ""
        Write-Host "[SYKids] Không thể lấy tiến trình cài đặt." -ForegroundColor Red
        exit 1
    }

    $pct = 60
    while (-not $proc.WaitForExit(350)) {
        Show-Step $pct
        if ($pct -lt 92) {
            $pct += 4
        }
    }

    if ($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) {
        $exitCode = [int]$proc.ExitCode
        Write-Host ""
        Write-Host "[SYKids] Quá trình cài đặt trả về mã lỗi $exitCode." -ForegroundColor Red
        exit $exitCode
    }

    Show-Step 100
    Write-Host ""
    Write-Host "[SYKids] Đã thiết lập xong dịch vụ — Thiết bị đã sẵn sàng kết nối!" -ForegroundColor Green
} finally {
    if ($tmpExe -and (Test-Path -LiteralPath $tmpExe)) {
        Remove-Item -LiteralPath $tmpExe -Force -ErrorAction SilentlyContinue
    }
}
