<#
.SYNOPSIS
    WSL2 與 Ubuntu 環境清理與移除程式

.DESCRIPTION
    此腳本用於清理或徹底移除 WSL2 環境，方便重置測試或乾淨重裝：
    1. 終止並註銷指定的 WSL 發行版（釋放硬碟空間，刪除虛擬磁碟）
    2. 清理 Windows 端建立的 Docker Context
    3. （可選）解除安裝 Microsoft.WSL 核心套件（-RemoveWslPackage）
    4. （可選）清理 logs 目錄日誌檔案（-RemoveLogs）

.PARAMETER DistroName
    欲移除的 WSL 發行版名稱（若未指定，優先自 .env 讀取，預設為 Ubuntu-24.04）

.PARAMETER RemoveWslPackage
    若指定，將透過 winget 解除安裝 Microsoft.WSL 套件本體（回到乾淨未安裝 WSL 狀態）

.PARAMETER RemoveLogs
    若指定，將清理 logs 目錄下的歷史日誌

.PARAMETER Force
    若指定，將跳過互動式確認提示，直接執行清理

.EXAMPLE
    .\uninstall-wsl2.ps1
    # 互動式確認後移除 Ubuntu-24.04 與 Docker Context

.EXAMPLE
    .\uninstall-wsl2.ps1 -RemoveWslPackage -RemoveLogs -Force
    # 徹底清理：移除 Ubuntu、WSL 套件本體與日誌，不需手動確認
#>

[CmdletBinding()]
param(
    [string]$DistroName = "",
    [switch]$RemoveWslPackage,
    [switch]$RemoveLogs,
    [switch]$Force,
    [string]$LogPath = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"
$env:WSL_UTF8          = 1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================
# 讀取 .env 設定
# ============================================
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

$dotenv = Read-DotEnv
if (-not $DistroName) {
    if ($dotenv['UBUNTU_VERSION']) {
        $DistroName = "Ubuntu-$($dotenv['UBUNTU_VERSION'])"
    } else {
        $DistroName = "Ubuntu-24.04"
    }
}

Write-Host "`r========================================" -ForegroundColor Yellow
Write-Host "`rWSL2 環境清理 / 移除程式" -ForegroundColor Yellow
Write-Host "`r========================================" -ForegroundColor Yellow
Write-Host "`r目標發行版: $DistroName" -ForegroundColor Cyan
if ($RemoveWslPackage) {
    Write-Host "`r包含移除 WSL 核心套件本體: 是" -ForegroundColor Magenta
}
if ($RemoveLogs) {
    Write-Host "`r包含清理日誌檔案: 是" -ForegroundColor Magenta
}
Write-Host ""

# ============================================
# 安全確認
# ============================================
if (-not $Force) {
    Write-Host "`r[警告] 註銷 $DistroName 將永久刪除該發行版內的所有檔案與資料！" -ForegroundColor Red
    # Read-Host 提示前也要先 `r 回到行首，否則會沿用上一行的結尾欄位造成右移
    $response = Read-Host "`r確定要繼續移除嗎？ (輸入 YES 確認)"
    if ($response -ne "YES") {
        Write-Host "`r已取消移除操作。" -ForegroundColor Yellow
        exit 0
    }
}

# ============================================
# 步驟 1: 終止與註銷 WSL 發行版
# ============================================
Write-Host "`r[1/4] 檢查 WSL 發行版: $DistroName..." -ForegroundColor Cyan

$oldEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$installedDistros = & wsl.exe --list --quiet 2>$null
$distroExists = $installedDistros | Where-Object { $_ -match [regex]::Escape($DistroName) }

if ($distroExists) {
    Write-Host "`r正在終止 $DistroName..." -ForegroundColor Cyan
    & wsl.exe --terminate $DistroName 2>$null | Out-Null

    Write-Host "`r正在註銷並移除 $DistroName..." -ForegroundColor Yellow
    & wsl.exe --unregister $DistroName 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`r[Success] 已成功註銷並刪除 $DistroName" -ForegroundColor Green
    } else {
        Write-Host "`r[Warning] 註銷 $DistroName 可能未完全成功" -ForegroundColor Yellow
    }
} else {
    Write-Host "`r[Info] 系統中未找到發行版 $DistroName，跳過註銷" -ForegroundColor Cyan
}
$ErrorActionPreference = $oldEap

# ============================================
# 步驟 2: 清理 Windows 端 Docker Context
# ============================================
$contextName = $DistroName.ToLower()
Write-Host "`r[2/4] 檢查 Docker context: $contextName..." -ForegroundColor Cyan

if (Get-Command docker -ErrorAction SilentlyContinue) {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $existingContexts = & docker.exe context ls --format "{{.Name}}" 2>$null
    if ($existingContexts -contains $contextName) {
        & docker.exe context rm $contextName 2>&1 | Out-Null
        Write-Host "`r[Success] 已移除 Docker context: $contextName" -ForegroundColor Green
    } else {
        Write-Host "`r[Info] 未找到 Docker context: $contextName，跳過" -ForegroundColor Cyan
    }
    $ErrorActionPreference = $oldEap
} else {
    Write-Host "`r[Info] 系統未安裝 docker CLI，跳過 Context 清理" -ForegroundColor Cyan
}

# ============================================
# 步驟 3: 移除 Microsoft.WSL 套件本體（可選）
# ============================================
Write-Host "`r[3/4] WSL 套件處理..." -ForegroundColor Cyan
if ($RemoveWslPackage) {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Write-Host "`r正在透過 winget 解除安裝 Microsoft.WSL..." -ForegroundColor Yellow
        $oldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & winget.exe uninstall Microsoft.WSL --accept-source-agreements 2>&1 | Out-Null
        $ErrorActionPreference = $oldEap
        Write-Host "`r[Success] 已執行 Microsoft.WSL 套件卸載" -ForegroundColor Green
    } else {
        Write-Host "`r[Warning] 找不到 winget.exe，無法自動卸載 Microsoft.WSL 套件" -ForegroundColor Yellow
    }
} else {
    Write-Host "`r[Info] 未指定 -RemoveWslPackage，保留 WSL 平台核心套件" -ForegroundColor Cyan
}

# ============================================
# 步驟 4: 清理日誌（可選）
# ============================================
Write-Host "`r[4/4] 日誌清理..." -ForegroundColor Cyan
if ($RemoveLogs) {
    if (Test-Path $LogPath) {
        $logFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -File -ErrorAction SilentlyContinue
        if ($logFiles) {
            $logFiles | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "`r[Success] 已清理 $($logFiles.Count) 個歷史日誌檔案" -ForegroundColor Green
        } else {
            Write-Host "`r[Info] logs 目錄下無歷史日誌" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "`r[Info] 未指定 -RemoveLogs，保留日誌檔案" -ForegroundColor Cyan
}

Write-Host "`r========================================" -ForegroundColor Green
Write-Host "`r清理作業完成！" -ForegroundColor Green
Write-Host "`r========================================" -ForegroundColor Green
Write-Host "`r如需重新安裝，可直接執行：" -ForegroundColor Cyan
Write-Host "`r  .\setup-wsl2.ps1" -ForegroundColor Cyan
