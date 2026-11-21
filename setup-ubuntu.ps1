<#
.SYNOPSIS
    安裝並設定 WSL Ubuntu（不需要管理員權限）

.DESCRIPTION
    此腳本會執行以下操作：
    1. 安裝指定的 Ubuntu 發行版
    2. 建立預設使用者
    3. 驗證安裝結果

.PARAMETER UbuntuVersion
    Ubuntu 版本號（例如: 24.04、22.04）
    不指定時安裝最新 LTS（distro name = Ubuntu）
    優先順序：手動指定 > .env UBUNTU_VERSION > 空值（Ubuntu 最新 LTS）

.PARAMETER WslUsername
    WSL 使用者名稱。未指定且 .env 未設定時，會在執行時互動輸入（無預設值）

.PARAMETER WslPassword
    WSL 使用者密碼。未指定且 .env 未設定時，會在執行時互動輸入（需輸入兩次確認，至少 8 個字元）

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\setup-ubuntu.ps1

.EXAMPLE
    .\setup-ubuntu.ps1 -UbuntuVersion 22.04 -WslUsername myuser

.NOTES
    執行前請確認已完成 setup-wsl2-features.ps1（需要管理員）
    安裝 Ubuntu 完成後，若同目錄存在 install-linux-tools.ps1，會自動接續安裝開發工具
    如需單獨重跑開發工具安裝，可手動執行 install-linux-tools.ps1
#>

[CmdletBinding()]
param(
    [string]$UbuntuVersion = "",   # 優先順序：參數 > .env UBUNTU_VERSION > 空值（安裝 Ubuntu 最新 LTS）
    [string]$WslUsername   = "",   # 優先順序：參數 > .env WSL_USERNAME > 互動輸入（無預設值）
    [string]$WslPassword   = "",   # 優先順序：參數 > .env WSL_PASSWORD > 互動輸入（無預設值）
    [string]$Proxy         = "",
    [switch]$SkipVerify,
    [switch]$SkipUpdate,   # 略過安裝前的 WSL 與發行版更新（wsl --update + apt upgrade）
    [string]$LogPath       = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # 關閉 Write-Progress 視覺元件以防終端排版偏斜與殘影
$Global:LogFile    = ""

# ============================================
# 環境變數設定
# ============================================
$env:WSL_UTF8 = 1   # 強制 wsl.exe 以 UTF-8 輸出，避免 wsl --list 亂碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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

    $cleanMessage = if ($null -ne $Message) { $Message.Trim() } else { "" }
    if ([string]::IsNullOrWhiteSpace($cleanMessage)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $cleanMessage"

    Add-Content -Path $Global:LogFile -Value $logMessage -Encoding utf8

    switch ($Level) {
        "Info"    { Write-Host "`r$logMessage" -ForegroundColor Cyan }
        "Warning" { Write-Host "`r$logMessage" -ForegroundColor Yellow }
        "Error"   { Write-Host "`r$logMessage" -ForegroundColor Red }
        "Success" { Write-Host "`r$logMessage" -ForegroundColor Green }
    }
}

function Write-Progress-Log {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )

    Write-Log "$Activity - $Status ($PercentComplete%)"
}

# ============================================
# 安裝函式
# ============================================

function Install-Distro {
    Write-Log "安裝 $Script:DistroName..."
    Write-Progress-Log -Activity "WSL 安裝" -Status "安裝 $Script:DistroName" -PercentComplete 20

    try {
        # 檢查 WSL 是否已安裝就緒
        $oldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & wsl.exe --status 2>$null | Out-Null
        $wslStatusExit = $LASTEXITCODE
        $ErrorActionPreference = $oldEap

        if ($wslStatusExit -ne 0) {
            Write-Log "WSL 核心/套件尚未安裝或未就緒！" "Error"
            Write-Log "請先以「系統管理員身分」執行 .\setup-wsl2-features.ps1，或直接執行 .\setup-wsl2.ps1" "Warning"
            return $false
        }

        # 檢查是否已安裝目標發行版
        $oldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $existingTarget = & wsl.exe --list --quiet 2>$null |
            Where-Object { $_ -match [regex]::Escape($Script:DistroName) }
        $ErrorActionPreference = $oldEap

        if ($existingTarget) {
            Write-Log "$Script:DistroName 已安裝，跳過安裝步驟" "Success"
            return $true
        }

        # 步驟 1: 下載並註冊 distro（--no-launch 避免互動式提示）
        Write-Log "正在下載 $Script:DistroName..."
        Write-Log "執行命令: wsl --install -d $Script:DistroName --no-launch"
        $oldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & wsl.exe --install -d $Script:DistroName --no-launch 2>&1 | ForEach-Object { Write-Log $_ }
        $installExit = $LASTEXITCODE
        $ErrorActionPreference = $oldEap

        if ($installExit -ne 0) {
            Write-Log "wsl --install 失敗" "Error"
            Write-Log "請嘗試手動執行: wsl --install -d $Script:DistroName" "Warning"
            return $false
        }

        $registered = $false
        for ($attempt = 1; $attempt -le 15; $attempt++) {
            $oldEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $registered = & wsl.exe --list --quiet 2>$null |
                Where-Object { $_ -match [regex]::Escape($Script:DistroName) }
            $ErrorActionPreference = $oldEap

            if ($registered) {
                break
            }

            Write-Log "等待 $Script:DistroName 完成註冊... ($attempt/15)"
            Start-Sleep -Seconds 2
        }

        if (-not $registered) {
            Write-Log "$Script:DistroName 安裝後未出現在 wsl --list 中，無法繼續初始化" "Error"
            return $false
        }

        # 不依賴 App Execution Alias（ubuntu2404.exe）：它可能不會出現，改用 wsl -d ... -u root 觸發首次初始化。
        Write-Log "初始化 $Script:DistroName（使用 wsl -d $Script:DistroName -u root -- /bin/sh -lc true）..."
        & wsl -d $Script:DistroName -u root -- /bin/sh -lc "true" 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -ne 0) {
            Write-Log "wsl 初始化 $Script:DistroName 失敗 (exit code: $LASTEXITCODE)" "Error"
            return $false
        }

        Write-Log "$Script:DistroName 安裝並初始化完成" "Success"
        return $true
    }
    catch {
        Write-Log "安裝 $Script:DistroName 失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-WslConfig {
    Write-Log "寫入 /etc/wsl.conf..."

    $wslConfLines = @(
        "[boot]",
        "systemd=true",
        "",
        "[user]",
        "default=$WslUsername",
        "",
        "[interop]",
        "enabled=true",
        "appendWindowsPath=true"
    )
    $wslConfContent = $wslConfLines -join "\n"
    wsl -d $Script:DistroName -u root -- bash -c "printf '$wslConfContent\n' > /etc/wsl.conf" 2>&1 | Out-Null
    Write-Log "/etc/wsl.conf 設定完成（systemd=true, 預設使用者為 $WslUsername, interop=true）" "Success"
}

function Set-DefaultUser {
    Write-Log "設定預設使用者..."
    Write-Progress-Log -Activity "WSL 安裝" -Status "設定預設使用者" -PercentComplete 70

    try {
        # 檢查 distro 是否已註冊
        $distros    = wsl --list --quiet 2>&1
        $registered = $distros | Where-Object { $_ -match [regex]::Escape($Script:DistroName) }

        if (-not $registered) {
            Write-Log "$Script:DistroName 尚未註冊，無法設定使用者" "Warning"
            return $false
        }

        # 使用者名稱會被拼進 shell 指令，先驗證格式避免注入
        if ($WslUsername -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
            Write-Log "WSL 使用者名稱格式不合法（僅允許小寫字母、數字、_ 與 -）: $WslUsername" "Error"
            return $false
        }

        # 建立使用者（不含密碼）。密碼改由 stdin 交給 chpasswd，不出現在命令列或日誌中。
        Write-Log "正在建立使用者 $WslUsername..."

        $createCmd = "if ! id -u $WslUsername > /dev/null 2>&1; then " +
                     "useradd -m -s /bin/bash $WslUsername && " +
                     "usermod -aG sudo $WslUsername && " +
                     "echo '$WslUsername ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/$WslUsername && " +
                     "chmod 0440 /etc/sudoers.d/$WslUsername && " +
                     "echo 'User created'; " +
                     "else echo 'User already exists'; fi"

        $createOut = wsl -d $Script:DistroName -u root -- bash -c $createCmd 2>&1
        $createOut | ForEach-Object { Write-Log $_ }

        if ($createOut -match 'User created') {
            "${WslUsername}:${WslPassword}" | wsl -d $Script:DistroName -u root -- chpasswd 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Log "設定使用者密碼失敗" "Error"
                return $false
            }
        }

        Set-WslConfig

        # 終止 distro，讓 wsl.conf 在下次啟動時生效
        wsl --terminate $Script:DistroName 2>&1 | Out-Null

        return $true
    }
    catch {
        Write-Log "設定預設使用者時發生錯誤: $($_.Exception.Message)" "Warning"
        Write-Log "請手動啟動發行版並完成初始設定" "Warning"
        return $true
    }
}

function Test-Installation {
    Write-Log "驗證 WSL2 $Script:DistroName 安裝..."
    Write-Progress-Log -Activity "WSL 安裝" -Status "驗證安裝" -PercentComplete 90

    try {
        Write-Log "WSL 版本資訊："
        wsl --version 2>&1 | ForEach-Object { Write-Log $_ }

        Write-Log "已安裝的 Linux 發行版："
        wsl --list --verbose 2>&1 | ForEach-Object { Write-Log $_ }

        Write-Log "測試 WSL 連接..."
        $testResult = wsl -d $Script:DistroName -e echo "$Script:DistroName 運作正常" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log $testResult "Success"
            Write-Log "WSL2 $Script:DistroName 安裝驗證成功！" "Success"
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

function Read-WslCredentials {
    # 互動輸入 WSL 使用者名稱與密碼；非互動環境（例如輸入被重新導向）直接報錯，不使用預設值
    if ([Console]::IsInputRedirected) {
        throw "未提供 WSL 使用者名稱或密碼，且目前無法互動輸入。請使用 -WslUsername / -WslPassword 參數，或在 .env 設定 WSL_USERNAME / WSL_PASSWORD"
    }

    Write-Host "`r請設定 WSL 使用者帳號（將建立為 Ubuntu 的預設使用者）" -ForegroundColor Cyan

    $user = ""
    while ($true) {
        $user = (Read-Host "`r使用者名稱（小寫英文字母開頭，可含數字、_、-，最長 32 字元）").Trim()
        if ($user -match '^[a-z_][a-z0-9_-]{0,31}$') { break }
        Write-Host "`r使用者名稱格式不合法，請重新輸入" -ForegroundColor Yellow
    }

    $password = ""
    while ($true) {
        $secure1 = Read-Host "`r密碼（至少 8 個字元）" -AsSecureString
        $secure2 = Read-Host "`r再輸入一次確認" -AsSecureString
        $candidate = [System.Net.NetworkCredential]::new("", $secure1).Password
        $confirm   = [System.Net.NetworkCredential]::new("", $secure2).Password

        if ($candidate.Length -lt 8) {
            Write-Host "`r密碼至少需要 8 個字元，請重新輸入" -ForegroundColor Yellow
            continue
        }
        if ($candidate -cne $confirm) {
            Write-Host "`r兩次輸入的密碼不一致，請重新輸入" -ForegroundColor Yellow
            continue
        }
        $password = $candidate
        break
    }

    return @{ User = $user; Password = $password }
}

function Update-Distro {
    # 只更新 Ubuntu 內的 apt 套件（update.sh --apt-only）；失敗只記錄警告，不中止安裝流程
    Write-Log "更新 Ubuntu 系統套件（apt update / upgrade）..." "Info"

    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        # 不傳遞任何路徑：把 update.sh 內容經 stdin 交給 WSL 內的 bash 執行（避免依賴 /mnt 掛載位置）
        $updateScriptText = (Get-Content -Raw -Path (Join-Path $PSScriptRoot "update.sh")) -replace "`r", ""

        # 以 root 執行，SUDO_USER 指定 WSL 使用者
        $updateScriptText | & wsl.exe -d $Script:DistroName -u root -- env "SUDO_USER=$WslUsername" bash -s -- --apt-only 2>&1 | ForEach-Object { Write-Log $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Log "apt 更新有失敗項目（詳見日誌），繼續安裝" "Warning"
        } else {
            Write-Log "Ubuntu 系統套件更新完成" "Success"
        }
    }
    catch {
        Write-Log "更新過程發生錯誤，已略過並繼續安裝: $($_.Exception.Message)" "Warning"
    }
    finally {
        $ErrorActionPreference = $oldEap
    }
}

# ============================================
# 主要執行流程
# ============================================

function Main {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    # 隱藏 Write-Progress 視覺進度條，避免殘影（]）出現在日誌輸出中
    $ProgressPreference = 'SilentlyContinue'

    # 從 .env 載入設定，優先順序：參數 > .env > 後備預設值
    $dotenv = Read-DotEnv
    if (-not $WslUsername) { $WslUsername = $dotenv['WSL_USERNAME'] }
    if (-not $WslPassword) { $WslPassword = $dotenv['WSL_PASSWORD'] }
    if (-not $WslUsername -or -not $WslPassword) {
        # 參數與 .env 都沒有提供時，互動輸入帳號與密碼（不使用預設值）
        $cred = Read-WslCredentials
        if (-not $WslUsername) { $WslUsername = $cred.User }
        if (-not $WslPassword) { $WslPassword = $cred.Password }
    }

    $resolvedVersion   = if ($UbuntuVersion) { $UbuntuVersion } elseif ($dotenv['UBUNTU_VERSION']) { $dotenv['UBUNTU_VERSION'] } else { "24.04" }
    $Script:DistroName = if ($resolvedVersion) { "Ubuntu-$resolvedVersion" } else { "Ubuntu" }

    # banner 也需要 `r 強制回到行首，否則游標若殘留在上一個指令的欄位，會造成階梯狀偏移
    Write-Host "`r========================================" -ForegroundColor Cyan
    Write-Host "`rWSL Ubuntu 安裝程式" -ForegroundColor Cyan
    Write-Host "`r========================================" -ForegroundColor Cyan

    Initialize-LogDirectory
    Write-Log "啟動 WSL 安裝程式" "Success"
    Write-Log "日誌檔案: $Global:LogFile"
    if (Test-Path (Join-Path $PSScriptRoot ".env")) { Write-Log "已載入 .env 設定檔" }
    Write-Log "發行版: $Script:DistroName"
    Write-Log "WSL 使用者: $WslUsername"

    try {
        Write-Progress-Log -Activity "WSL 安裝" -Status "開始安裝" -PercentComplete 5

        if (-not (Install-Distro)) {
            throw "安裝 $Script:DistroName 失敗"
        }

        Set-DefaultUser | Out-Null

        if (-not (Test-Installation)) {
            Write-Log "部分功能驗證失敗，請檢查日誌" "Warning"
        }

        Write-Progress-Log -Activity "WSL 安裝" -Status "安裝完成" -PercentComplete 100

        Write-Log "========================================" "Success"
        Write-Log "$Script:DistroName 安裝完成！" "Success"
        Write-Log "========================================" "Success"
        Write-Log "使用者帳號資訊："
        Write-Log "  使用者名稱: $WslUsername"
        # 密碼不寫入日誌
        Write-Log "  密碼: 已設定（未記錄於日誌）"
        Write-Log "日誌檔案位置: $Global:LogFile"

        # 安裝前先更新：WSL 本體與發行版套件，讓後續開發工具以最新狀態安裝
        if (-not $SkipUpdate) {
            Update-Distro
        } else {
            Write-Log "略過安裝前更新（-SkipUpdate）" "Info"
        }

        # 安裝開發工具
        Write-Log "========================================" "Info"
        Write-Log "開始安裝開發工具..." "Info"
        Write-Log "========================================" "Info"

        $installToolsScript = Join-Path $PSScriptRoot "install-linux-tools.ps1"
        if (Test-Path $installToolsScript) {
            $installArgs = @{
                UbuntuVersion = $resolvedVersion
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
        Write-Log "========================================" "Error"
        Write-Log "安裝過程發生錯誤" "Error"
        Write-Log "錯誤訊息: $($_.Exception.Message)" "Error"
        Write-Log "========================================" "Error"
        Write-Log "請檢查日誌檔案: $Global:LogFile" "Error"
        exit 1
    }
    finally {
        Write-Progress -Activity "WSL 安裝" -Completed
    }
}

Main
