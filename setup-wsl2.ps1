#Requires -RunAsAdministrator

<#
.SYNOPSIS
    WSL2 與 Ubuntu 一鍵安裝程式

.DESCRIPTION
    此腳本會依序執行：
    1. setup-wsl2-features.ps1 - 啟用 Windows 功能（需要管理員）
    2. setup-ubuntu.ps1        - 安裝 Ubuntu（不需要管理員）

    若只需要單獨執行某個步驟：
      - 啟用 Windows 功能：.\setup-wsl2-features.ps1
      - 安裝 Ubuntu：      .\setup-ubuntu.ps1

.PARAMETER UbuntuVersion
    Ubuntu 版本，預設為 22.04

.PARAMETER WslUsername
    WSL 使用者名稱，預設為 yao

.PARAMETER WslPassword
    WSL 使用者密碼，預設為 123456

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\setup-wsl2.ps1

.EXAMPLE
    .\setup-wsl2.ps1 -UbuntuVersion 24.04 -WslUsername myuser

.NOTES
    需要管理員權限執行（因為步驟一需要啟用 Windows 功能）
#>

[CmdletBinding()]
param(
    [string]$UbuntuVersion = "22.04",
    [string]$WslUsername = "yao",
    [string]$WslPassword = "123456",
    [string]$LogPath = "$PSScriptRoot\logs"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL2 與 Ubuntu $UbuntuVersion LTS 一鍵安裝程式" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$featuresScript = Join-Path $PSScriptRoot "setup-wsl2-features.ps1"
$ubuntuScript   = Join-Path $PSScriptRoot "setup-ubuntu.ps1"

# 步驟 1：啟用 Windows 功能（需要管理員）
Write-Host "`n[步驟 1/2] 啟用 WSL2 Windows 功能..." -ForegroundColor Cyan
& $featuresScript -LogPath $LogPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n步驟 1 失敗，請檢查日誌後重試。" -ForegroundColor Red
    exit 1
}

# 步驟 2：安裝 Ubuntu（不需要管理員，但此 wrapper 已在管理員模式下執行）
Write-Host "`n[步驟 2/2] 安裝 Ubuntu $UbuntuVersion..." -ForegroundColor Cyan

$ubuntuArgs = @(
    "-UbuntuVersion", $UbuntuVersion,
    "-WslUsername",   $WslUsername,
    "-WslPassword",   $WslPassword,
    "-LogPath",       $LogPath
)

& $ubuntuScript @ubuntuArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n步驟 2 失敗，請檢查日誌後重試。" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "全部安裝完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
