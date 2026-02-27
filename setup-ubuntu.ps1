<#
.SYNOPSIS
    安裝並設定 WSL Ubuntu（不需要管理員權限）

.DESCRIPTION
    此腳本會執行以下操作：
    1. 安裝指定版本的 Ubuntu
    2. 建立預設使用者
    3. 驗證安裝結果

.PARAMETER UbuntuVersion
    Ubuntu 版本，預設為 22.04

.PARAMETER WslUsername
    WSL 使用者名稱，預設為 yao

.PARAMETER WslPassword
    WSL 使用者密碼，預設為 123456

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\setup-ubuntu.ps1

.EXAMPLE
    .\setup-ubuntu.ps1 -UbuntuVersion 24.04 -WslUsername myuser

.NOTES
    執行前請確認已完成 setup-wsl2-features.ps1（需要管理員）
    完成後請執行 install-linux-tools.ps1 安裝開發工具
#>

[CmdletBinding()]
param(
    [string]$UbuntuVersion = "",   # 優先順序：參數 > .env UBUNTU_VERSION > "22.04"
    [string]$WslUsername   = "",   # 優先順序：參數 > .env WSL_USERNAME   > "yao"
    [string]$WslPassword   = "",   # 優先順序：參數 > .env WSL_PASSWORD   > "changeme"
    [string]$Proxy         = "",
    [switch]$SkipVerify,
    [string]$LogPath       = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"
$Global:LogFile = ""

# ============================================
# 環境變數設定
# ============================================
$env:WSL_UTF8 = 1   # 強制 wsl.exe 以 UTF-8 輸出，避免 wsl --list 亂碼

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
    $Global:LogFile = Join-Path $LogPath "ubuntu-setup-$timestamp.log"
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
# Ubuntu 安裝函式
# ============================================

function Install-Ubuntu {
    Write-Log "安裝 Ubuntu $UbuntuVersion LTS..."
    Write-Progress-Log -Activity "Ubuntu 安裝" -Status "安裝 Ubuntu $UbuntuVersion" -PercentComplete 20

    $ubuntuDistroName = "Ubuntu-$UbuntuVersion"

    try {
        # 檢查是否已安裝目標版本
        $existingTarget = wsl --list --quiet 2>&1 |
            Where-Object { $_ -match [regex]::Escape($ubuntuDistroName) }
        if ($existingTarget) {
            Write-Log "$ubuntuDistroName 已安裝，跳過安裝步驟" "Success"
            return $true
        }

        # 檢查是否有其他 Ubuntu 版本，僅記錄 log 不中斷
        $existingDistros = wsl --list --quiet 2>&1 |
            Where-Object { $_ -match "Ubuntu" }
        if ($existingDistros) {
            Write-Log "檢測到已安裝的其他 Ubuntu 發行版，繼續安裝 $ubuntuDistroName..." "Warning"
        }

        # 步驟 1: 下載並註冊 distro（--no-launch 避免互動式提示）
        Write-Log "正在下載 $ubuntuDistroName..."
        $installCmd = "wsl --install -d $ubuntuDistroName --no-launch"
        Write-Log "執行命令: $installCmd"
        Invoke-Expression $installCmd 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -ne 0) {
            Write-Log "wsl --install 失敗" "Error"
            Write-Log "請嘗試手動執行: wsl --install -d $ubuntuDistroName" "Warning"
            return $false
        }

        # 用 ubuntu exe 初始化 distro（--root 避免互動式 OOBE）
        # 此步驟會把 Registry DefaultUid 設為 0（root），之後由 Set-UbuntuDefaultUser 改寫
        $ubuntuExe = "ubuntu$(($UbuntuVersion).Replace('.',''))"
        Write-Log "初始化 $ubuntuDistroName（使用 $ubuntuExe install --root）..."
        & $ubuntuExe install --root 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "$ubuntuDistroName 安裝並初始化完成" "Success"
            return $true
        } else {
            Write-Log "$ubuntuExe install --root 失敗 (exit code: $LASTEXITCODE)" "Error"
            return $false
        }
    }
    catch {
        Write-Log "安裝 Ubuntu 失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-UbuntuDefaultUser {
    Write-Log "設定 Ubuntu 預設使用者..."
    Write-Progress-Log -Activity "Ubuntu 安裝" -Status "設定預設使用者" -PercentComplete 70

    $ubuntuDistroName = "Ubuntu-$UbuntuVersion"

    try {
        # 檢查 distro 是否已註冊
        $distros = wsl --list --quiet 2>&1
        $ubuntuRegistered = $distros | Where-Object { $_ -match [regex]::Escape($ubuntuDistroName) }

        if (-not $ubuntuRegistered) {
            Write-Log "$ubuntuDistroName 尚未註冊，無法設定使用者" "Warning"
            return $false
        }

        # 建立使用者，透過 -c 傳入 bash（比 stdin pipe 更穩定）
        Write-Log "正在建立使用者 $WslUsername..."

        $createCmd = "if ! id -u $WslUsername > /dev/null 2>&1; then " +
                     "useradd -m -s /bin/bash $WslUsername && " +
                     "echo '${WslUsername}:${WslPassword}' | chpasswd && " +
                     "usermod -aG sudo $WslUsername && " +
                     "echo '$WslUsername ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/$WslUsername && " +
                     "chmod 0440 /etc/sudoers.d/$WslUsername && " +
                     "echo 'User created'; " +
                     "else echo 'User already exists'; fi"

        wsl -d $ubuntuDistroName -u root -- bash -c $createCmd 2>&1 | ForEach-Object { Write-Log $_ }

        # 寫入 wsl.conf 設定預設使用者
        wsl -d $ubuntuDistroName -u root -- bash -c "printf '[user]\ndefault=$WslUsername\n' > /etc/wsl.conf" 2>&1 | Out-Null
        Write-Log "/etc/wsl.conf 設定完成，預設使用者為 $WslUsername" "Success"

        # 終止 distro，讓 wsl.conf 在下次啟動時生效
        wsl --terminate $ubuntuDistroName 2>&1 | Out-Null

        return $true
    }
    catch {
        Write-Log "設定預設使用者時發生錯誤: $($_.Exception.Message)" "Warning"
        Write-Log "請手動啟動 Ubuntu 並完成初始設定" "Warning"
        return $true
    }
}

function Test-Installation {
    Write-Log "驗證 WSL2 Ubuntu 安裝..."
    Write-Progress-Log -Activity "Ubuntu 安裝" -Status "驗證安裝" -PercentComplete 90

    $ubuntuDistroName = "Ubuntu-$UbuntuVersion"

    try {
        Write-Log "WSL 版本資訊："
        wsl --version 2>&1 | ForEach-Object { Write-Log $_ }

        Write-Log "`n已安裝的 Linux 發行版："
        wsl --list --verbose 2>&1 | ForEach-Object { Write-Log $_ }

        Write-Log "`n測試 WSL 連接..."
        $testResult = wsl -d $ubuntuDistroName -e echo "WSL2 Ubuntu $UbuntuVersion 運作正常" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log $testResult "Success"
            Write-Log "WSL2 Ubuntu 安裝驗證成功！" "Success"
            return $true
        } else {
            Write-Log "WSL2 連接測試失敗" "Error"
            return $false
        }
    }
    catch {
        Write-Log "驗證過程發生錯誤: $($_.Exception.Message)" "Error"
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
    if (-not $UbuntuVersion) { $UbuntuVersion = if ($dotenv['UBUNTU_VERSION']) { $dotenv['UBUNTU_VERSION'] } else { '22.04'    } }
    if (-not $WslUsername)   { $WslUsername   = if ($dotenv['WSL_USERNAME'])   { $dotenv['WSL_USERNAME']   } else { 'yao'      } }
    if (-not $WslPassword)   { $WslPassword   = if ($dotenv['WSL_PASSWORD'])   { $dotenv['WSL_PASSWORD']   } else { 'changeme' } }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Ubuntu $UbuntuVersion LTS 安裝程式" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Initialize-LogDirectory
    Write-Log "啟動 Ubuntu 安裝程式" "Success"
    Write-Log "日誌檔案: $Global:LogFile"
    if (Test-Path (Join-Path $PSScriptRoot ".env")) { Write-Log "已載入 .env 設定檔" }
    Write-Log "Ubuntu 版本: $UbuntuVersion"
    Write-Log "WSL 使用者: $WslUsername"

    try {
        Write-Progress-Log -Activity "Ubuntu 安裝" -Status "開始安裝" -PercentComplete 5

        if (-not (Install-Ubuntu)) {
            throw "安裝 Ubuntu 失敗"
        }

        Set-UbuntuDefaultUser | Out-Null

        if (-not (Test-Installation)) {
            Write-Log "部分功能驗證失敗，請檢查日誌" "Warning"
        }

        Write-Progress-Log -Activity "Ubuntu 安裝" -Status "安裝完成" -PercentComplete 100

        Write-Log "`n========================================" "Success"
        Write-Log "Ubuntu $UbuntuVersion 安裝完成！" "Success"
        Write-Log "========================================" "Success"
        Write-Log "`n使用者帳號資訊："
        Write-Log "  使用者名稱: $WslUsername"
        Write-Log "  密碼: $WslPassword"
        Write-Log "`n日誌檔案位置: $Global:LogFile"

        # 安裝開發工具
        Write-Log "`n========================================" "Info"
        Write-Log "開始安裝開發工具..." "Info"
        Write-Log "========================================" "Info"

        $installToolsScript = Join-Path $PSScriptRoot "install-linux-tools.ps1"
        if (Test-Path $installToolsScript) {
            $installArgs = @{
                UbuntuVersion = $UbuntuVersion
                WslUsername   = $WslUsername
                LogPath       = $LogPath
            }
            if ($Proxy)      { $installArgs["Proxy"]      = $Proxy }
            if ($SkipVerify) { $installArgs["SkipVerify"] = $true  }

            & $installToolsScript @installArgs
        } else {
            Write-Log "找不到 install-linux-tools.ps1，請手動執行：.\install-linux-tools.ps1" "Warning"
        }
    }
    catch {
        Write-Log "`n========================================" "Error"
        Write-Log "安裝過程發生錯誤" "Error"
        Write-Log "錯誤訊息: $($_.Exception.Message)" "Error"
        Write-Log "========================================" "Error"
        Write-Log "`n請檢查日誌檔案: $Global:LogFile" "Error"
        exit 1
    }
    finally {
        Write-Progress -Activity "Ubuntu 安裝" -Completed
    }
}

Main
