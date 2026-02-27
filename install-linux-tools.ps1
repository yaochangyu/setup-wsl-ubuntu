<#
.SYNOPSIS
    在指定的 WSL Ubuntu 中執行開發工具安裝腳本

.DESCRIPTION
    此腳本會執行以下操作：
    1. 確認目標 Ubuntu distro 已安裝並正常運作
    2. 將 Windows 路徑轉換為 WSL 路徑
    3. 以 root 身分執行 install-linux-tools.sh

.PARAMETER UbuntuVersion
    目標 Ubuntu 版本，預設為 22.04

.PARAMETER WslUsername
    WSL 使用者名稱，用於設定工具的擁有者（例如加入 docker 群組），預設為 yao

.PARAMETER Proxy
    代理伺服器 URL，會傳遞給安裝腳本（例如: http://proxy.example.com:8080）

.PARAMETER SkipVerify
    略過安裝腳本的驗證步驟

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\install-linux-tools.ps1

.EXAMPLE
    .\install-linux-tools.ps1 -UbuntuVersion 24.04

.EXAMPLE
    .\install-linux-tools.ps1 -Proxy http://proxy.example.com:8080

.EXAMPLE
    .\install-linux-tools.ps1 -SkipVerify

.NOTES
    執行前請確認已完成 setup-ubuntu.ps1
#>

[CmdletBinding()]
param(
    [string]$UbuntuVersion = "",   # 優先順序：參數 > .env UBUNTU_VERSION > "22.04"
    [string]$WslUsername   = "",   # 優先順序：參數 > .env WSL_USERNAME   > "yao"
    [string]$Proxy         = "",
    [switch]$SkipVerify,
    [string]$LogPath       = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"
$Global:LogFile = ""

# ============================================
# 環境變數設定
# ============================================
$env:WSL_UTF8 = 1          # 強制 wsl.exe 以 UTF-8 輸出，避免 wsl --list 亂碼
$Script:BashTerm = "dumb"  # 關閉 bash ANSI 色彩碼，避免 PowerShell 輸出亂碼
# SUDO_USER - 傳遞給 bash 腳本，識別實際非 root 使用者（由 WslUsername 參數決定）

# ============================================
# 日誌與輸出函式
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

function Initialize-LogDirectory {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Global:LogFile = Join-Path $LogPath "linux-tools-$timestamp.log"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    Add-Content -Path $Global:LogFile -Value $logMessage

    switch ($Level) {
        "Info"    { Write-Host $logMessage -ForegroundColor Cyan }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Error"   { Write-Host $logMessage -ForegroundColor Red }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
    }
}

function Write-Progress-Log {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )

    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    Write-Log "$Activity - $Status ($PercentComplete%)"
}

# ============================================
# 前置檢查
# ============================================

function Test-DistroReady {
    $ubuntuDistroName = "Ubuntu-$UbuntuVersion"

    Write-Log "檢查 $ubuntuDistroName 是否已安裝..."

    $distros = wsl --list --quiet 2>&1

    $found = $distros | Where-Object { $_ -match [regex]::Escape($ubuntuDistroName) }

    if (-not $found) {
        Write-Log "$ubuntuDistroName 尚未安裝，請先執行 setup-ubuntu.ps1" "Error"
        return $false
    }

    Write-Log "$ubuntuDistroName 已就緒" "Success"
    return $true
}

# ============================================
# 安裝工具
# ============================================

function Invoke-LinuxToolsInstall {
    $ubuntuDistroName = "Ubuntu-$UbuntuVersion"

    Write-Progress-Log -Activity "Linux 工具安裝" -Status "準備安裝腳本" -PercentComplete 10

    # 將 Windows 路徑轉換為 WSL 路徑（在 PowerShell 內直接轉換，不依賴 wslpath）
    # 例：D:\lab\setup-wsl-ubuntu\install-linux-tools.sh -> /mnt/d/lab/setup-wsl-ubuntu/install-linux-tools.sh
    $winPath = Join-Path $PSScriptRoot "install-linux-tools.sh"
    $driveLetter = $winPath[0].ToString().ToLower()
    $wslScriptPath = "/mnt/$driveLetter/" + $winPath.Substring(3).Replace("\", "/")
    Write-Log "腳本路徑 (WSL): $wslScriptPath"

    # 確認腳本存在
    wsl -d $ubuntuDistroName -u root -- test -f $wslScriptPath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "找不到安裝腳本: $wslScriptPath" "Error"
        return $false
    }

    # 組合傳遞給 install-linux-tools.sh 的參數
    $installArgs = ""
    if ($Proxy) {
        $installArgs += " --proxy $Proxy"
    }
    if ($SkipVerify) {
        $installArgs += " --skip-verify"
    }

    Write-Progress-Log -Activity "Linux 工具安裝" -Status "執行安裝腳本" -PercentComplete 20
    Write-Log "執行: bash install-linux-tools.sh$installArgs（SUDO_USER=$WslUsername）"

    # export 讓 SUDO_USER/TERM 對 pipe 後的 bash -s 也生效
    # （VAR=value cmd 前綴只作用於緊接的命令，不繼承至 pipe 後段）
    # 透過 sed 移除 \r 避免 Windows 換行符號造成 bash 錯誤
    # TERM=dumb 讓 bash 腳本不輸出 ANSI 色彩碼，避免 PowerShell 捕捉到亂碼
    $bashCmd = "export SUDO_USER=$WslUsername TERM=$Script:BashTerm; sed 's/\r`$//' '$wslScriptPath' | bash -s --$installArgs"
    wsl -d $ubuntuDistroName -u root -- bash -c $bashCmd 2>&1 | ForEach-Object {
        # 過濾掉殘留的 ANSI escape code 再寫入 log
        $line = [regex]::Replace("$_", '\x1b\[[0-9;]*[mKHJ]', '')
        Write-Log $line
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Linux 工具安裝完成" "Success"
        return $true
    } else {
        Write-Log "Linux 工具安裝失敗 (exit code: $LASTEXITCODE)，請查看日誌" "Warning"
        return $false
    }
}

# ============================================
# 主要執行流程
# ============================================

function Main {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    # 隱藏 Write-Progress 視覺進度條，避免殘影（]）出現在日誌輸出中
    $ProgressPreference = 'SilentlyContinue'

    # 從 .env 載入設定，參數 > .env > 後備預設值
    $dotenv = Read-DotEnv
    if (-not $UbuntuVersion) { $UbuntuVersion = if ($dotenv['UBUNTU_VERSION']) { $dotenv['UBUNTU_VERSION'] } else { '22.04' } }
    if (-not $WslUsername)   { $WslUsername   = if ($dotenv['WSL_USERNAME'])   { $dotenv['WSL_USERNAME']   } else { 'yao'   } }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Linux 開發工具安裝程式" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Initialize-LogDirectory
    Write-Log "啟動 Linux 工具安裝程式" "Success"
    Write-Log "日誌檔案: $Global:LogFile"
    if (Test-Path (Join-Path $PSScriptRoot ".env")) { Write-Log "已載入 .env 設定檔" }
    Write-Log "目標 Distro: Ubuntu-$UbuntuVersion"
    Write-Log "WSL 使用者: $WslUsername"

    try {
        Write-Progress-Log -Activity "Linux 工具安裝" -Status "前置檢查" -PercentComplete 5

        if (-not (Test-DistroReady)) {
            exit 1
        }

        if (-not (Invoke-LinuxToolsInstall)) {
            Write-Log "安裝未完全成功，請查看日誌" "Warning"
        }

        Write-Progress-Log -Activity "Linux 工具安裝" -Status "安裝完成" -PercentComplete 100

        Write-Log "========================================" "Success"
        Write-Log "Linux 工具安裝完成！" "Success"
        Write-Log "========================================" "Success"
        Write-Log "後續步驟："
        Write-Log "1. 重新登入 Ubuntu 後執行: newgrp docker（讓 docker 群組生效）"
        Write-Log "2. 驗證 Docker: docker run hello-world"
        Write-Log "3. 驗證 .NET: dotnet --list-sdks"
        Write-Log "日誌檔案位置: $Global:LogFile"
    }
    catch {
        Write-Log "========================================" "Error"
        Write-Log "安裝過程發生錯誤" "Error"
        Write-Log "錯誤訊息: $($_.Exception.Message)" "Error"
        Write-Log "========================================" "Error"
        Write-Log "請檢查日誌檔案: $Global:LogFile" "Error"
        exit 1
    }
    finally {
        Write-Progress -Activity "Linux 工具安裝" -Completed
    }
}

Main
