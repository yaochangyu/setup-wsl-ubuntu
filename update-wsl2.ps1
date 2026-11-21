<#
.SYNOPSIS
    更新 WSL 本體，並在 Ubuntu 發行版內執行 update.sh 更新開發工具

.DESCRIPTION
    1. （可選）執行 wsl --update 更新 WSL 核心（部分環境需要系統管理員權限）
    2. 確認目標發行版已安裝
    3. 以 root 身分在發行版內執行 update.sh，並透過 SUDO_USER 指定 .env 的 WSL 使用者，
       讓使用者層級工具（nvm、rustup、claude 等）仍以該使用者身分更新

.PARAMETER DistroName
    目標發行版名稱（未指定時依 .env 的 UBUNTU_VERSION 推算，預設 Ubuntu-24.04）

.PARAMETER WslUsername
    要更新工具的 WSL 使用者（優先順序：參數 > .env WSL_USERNAME > 互動輸入，無預設值）

.PARAMETER SkipWslUpdate
    不執行 wsl --update

.PARAMETER SkipApt
    傳遞給 update.sh，跳過 apt 系統套件更新

.EXAMPLE
    .\update-wsl2.ps1
    # 更新 WSL 本體與 Ubuntu 內全部工具

.EXAMPLE
    .\update-wsl2.ps1 -SkipWslUpdate -SkipApt
    # 只更新 Ubuntu 內的開發工具
#>

[CmdletBinding()]
param(
    [string]$DistroName  = "",
    [string]$WslUsername = "",   # 優先順序：參數 > .env WSL_USERNAME > 互動輸入（無預設值）
    [switch]$SkipWslUpdate,
    [switch]$SkipApt
)

$ErrorActionPreference = "Stop"
$env:WSL_UTF8 = 1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Read-DotEnv {
    $envFile = Join-Path $PSScriptRoot ".env"
    $result = @{}
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and $line -notmatch '^\s*#' -and $line -match '^([^=]+)=(.*)$') {
                $result[$Matches[1].Trim()] = $Matches[2].Trim()
            }
        }
    }
    return $result
}

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`r$Message" -ForegroundColor $Color
}

$dotenv = Read-DotEnv
if (-not $DistroName) {
    $DistroName = if ($dotenv['UBUNTU_VERSION']) { "Ubuntu-$($dotenv['UBUNTU_VERSION'])" } else { "Ubuntu-24.04" }
}
# 帳號來源：參數 > .env > 互動輸入（不使用預設值，也不猜測）
$wslUser = $WslUsername
if (-not $wslUser) { $wslUser = $dotenv['WSL_USERNAME'] }
if (-not $wslUser) {
    if ([Console]::IsInputRedirected) {
        throw "未提供 WSL 使用者名稱。請使用 -WslUsername 參數，或在 .env 設定 WSL_USERNAME"
    }
    while ($true) {
        $wslUser = (Read-Host "`r請輸入要更新的 WSL 使用者名稱（小寫英文字母開頭，可含數字、_、-）").Trim()
        if ($wslUser -match '^[a-z_][a-z0-9_-]{0,31}$') { break }
        Write-Host "`r使用者名稱格式不合法，請重新輸入" -ForegroundColor Yellow
    }
}
if ($wslUser -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
    throw "WSL 使用者名稱格式不合法: $wslUser"
}

Write-Step "========================================" "Cyan"
Write-Step "WSL 開發環境更新程式" "Cyan"
Write-Step "========================================" "Cyan"
Write-Step "目標發行版: $DistroName"
Write-Step "WSL 使用者: $wslUser"

# [1/3] WSL 本體
if ($SkipWslUpdate) {
    Write-Step "[1/3] 略過 wsl --update（-SkipWslUpdate）" "Cyan"
} else {
    Write-Step "[1/3] 更新 WSL 本體（wsl --update）..." "Cyan"
    & wsl.exe --update 2>&1 | ForEach-Object { Write-Step "$_" "Gray" }
    if ($LASTEXITCODE -ne 0) {
        Write-Step "[Warning] wsl --update 未成功（exit $LASTEXITCODE），可能需要系統管理員權限，繼續更新發行版工具" "Yellow"
    }
}

# [2/3] 確認發行版存在
Write-Step "[2/3] 檢查發行版 $DistroName..." "Cyan"
$installed = & wsl.exe --list --quiet 2>$null | Where-Object { $_ -match [regex]::Escape($DistroName) }
if (-not $installed) {
    throw "找不到發行版 $DistroName，請先執行 .\setup-wsl2.ps1 或 .\setup-ubuntu.ps1"
}

# [3/3] 在發行版內執行 update.sh
Write-Step "[3/3] 在 $DistroName 內執行 update.sh..." "Cyan"
# 不傳遞任何路徑：把 update.sh 內容經 stdin 交給 WSL 內的 bash 執行
$updateScriptText = (Get-Content -Raw -Path (Join-Path $PSScriptRoot "update.sh")) -replace "`r", ""

$updateArgs = @()
if ($SkipApt) { $updateArgs += "--skip-apt" }

$updateScriptText | & wsl.exe -d $DistroName -u root -- env "SUDO_USER=$wslUser" bash -s -- @updateArgs
$updateExit = $LASTEXITCODE

Write-Host ""
if ($updateExit -eq 0) {
    Write-Step "更新完成！" "Green"
} else {
    Write-Step "更新過程有失敗項目（exit $updateExit），請查看上方摘要與 logs 目錄下的日誌" "Red"
    exit $updateExit
}
