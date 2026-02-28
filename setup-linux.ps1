<#
.SYNOPSIS
    安裝並設定 WSL Linux 發行版（不需要管理員權限）

.DESCRIPTION
    此腳本會執行以下操作：
    1. 顯示可用的 WSL 發行版選單
    2. 安裝指定的發行版
    3. 建立預設使用者
    4. 驗證安裝結果

.PARAMETER DistroName
    WSL 發行版完整名稱（例如: Ubuntu-24.04、Debian），優先順序：參數 > .env DISTRO_NAME > 互動選單

.PARAMETER UbuntuVersion
    Ubuntu 版本號（例如: 24.04），會自動轉換為 Ubuntu-24.04，供向下相容使用

.PARAMETER WslUsername
    WSL 使用者名稱，預設為 yao

.PARAMETER WslPassword
    WSL 使用者密碼，預設為 changeme

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\setup-linux.ps1

.EXAMPLE
    .\setup-linux.ps1 -DistroName Ubuntu-24.04 -WslUsername myuser

.EXAMPLE
    .\setup-linux.ps1 -UbuntuVersion 24.04

.NOTES
    執行前請確認已完成 setup-wsl2-features.ps1（需要管理員）
    完成後請執行 install-linux-tools.ps1 安裝開發工具
#>

[CmdletBinding()]
param(
    [string]$DistroName    = "",   # 優先順序：參數 > .env DISTRO_NAME > 互動選單
    [string]$UbuntuVersion = "",   # 向下相容：24.04 → Ubuntu-24.04
    [string]$WslUsername   = "",   # 優先順序：參數 > .env WSL_USERNAME > "yao"
    [string]$WslPassword   = "",   # 優先順序：參數 > .env WSL_PASSWORD > "changeme"
    [string]$Proxy         = "",
    [switch]$SkipVerify,
    [string]$LogPath       = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"
$Global:LogFile    = ""

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
# 發行版選單
# ============================================

function Select-WslDistro {
    Write-Host "取得可用的 WSL 發行版..." -ForegroundColor Cyan

    $allLines    = wsl --list --online 2>&1
    $headerFound = $false
    $distros     = @()

    foreach ($line in $allLines) {
        # 找到標題列（NAME ... FRIENDLY NAME）後開始解析
        if ($line -match '^NAME\s+FRIENDLY') {
            $headerFound = $true
            continue
        }
        if ($headerFound -and $line.Trim() -ne '') {
            # 名稱與顯示名稱之間至少有兩個空白
            if ($line -match '^(\S+)\s{2,}(.+)$') {
                $distros += [PSCustomObject]@{
                    Name         = $Matches[1].Trim()
                    FriendlyName = $Matches[2].Trim()
                }
            }
        }
    }

    # 無法取得線上清單時使用後備清單
    if (-not $distros) {
        Write-Host "（無法取得線上清單，使用內建清單）" -ForegroundColor Yellow
        $distros = @(
            [PSCustomObject]@{ Name = "Ubuntu-24.04"; FriendlyName = "Ubuntu 24.04 LTS" },
            [PSCustomObject]@{ Name = "Ubuntu-20.04"; FriendlyName = "Ubuntu 20.04 LTS" },
            [PSCustomObject]@{ Name = "Debian";        FriendlyName = "Debian GNU/Linux" }
        )
    }

    Write-Host ""
    Write-Host "請選擇要安裝的 WSL 發行版：" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $distros.Count; $i++) {
        $d = $distros[$i]
        Write-Host "  $($i + 1)) $($d.FriendlyName)  [$($d.Name)]" -ForegroundColor White
    }
    Write-Host ""

    do {
        $choice = Read-Host "請輸入選項 [1-$($distros.Count)]"
        $idx    = [int]$choice - 1
    } while ($choice -notmatch '^\d+$' -or $idx -lt 0 -or $idx -ge $distros.Count)

    return $distros[$idx].Name
}

# ============================================
# 安裝函式
# ============================================

function Install-Distro {
    Write-Log "安裝 $Script:DistroName..."
    Write-Progress-Log -Activity "WSL 安裝" -Status "安裝 $Script:DistroName" -PercentComplete 20

    try {
        # 檢查是否已安裝目標發行版
        $existingTarget = wsl --list --quiet 2>&1 |
            Where-Object { $_ -match [regex]::Escape($Script:DistroName) }
        if ($existingTarget) {
            Write-Log "$Script:DistroName 已安裝，跳過安裝步驟" "Success"
            return $true
        }

        # 步驟 1: 下載並註冊 distro（--no-launch 避免互動式提示）
        Write-Log "正在下載 $Script:DistroName..."
        $installCmd = "wsl --install -d $Script:DistroName --no-launch"
        Write-Log "執行命令: $installCmd"
        Invoke-Expression $installCmd 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -ne 0) {
            Write-Log "wsl --install 失敗" "Error"
            Write-Log "請嘗試手動執行: wsl --install -d $Script:DistroName" "Warning"
            return $false
        }

        # Ubuntu 發行版：用 ubuntu exe 初始化（--root 避免互動式 OOBE）
        # 此步驟會把 Registry DefaultUid 設為 0（root），之後由 Set-DefaultUser 改寫
        if ($Script:DistroName -match '^Ubuntu-(\d+\.\d+)$') {
            $ubuntuExe = "ubuntu$($Matches[1].Replace('.',''))"
            Write-Log "初始化 $Script:DistroName（使用 $ubuntuExe install --root）..."
            & $ubuntuExe install --root 2>&1 | ForEach-Object { Write-Log $_ }

            if ($LASTEXITCODE -ne 0) {
                Write-Log "$ubuntuExe install --root 失敗 (exit code: $LASTEXITCODE)" "Error"
                return $false
            }
        }

        Write-Log "$Script:DistroName 安裝並初始化完成" "Success"
        return $true
    }
    catch {
        Write-Log "安裝 $Script:DistroName 失敗: $($_.Exception.Message)" "Error"
        return $false
    }
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

        wsl -d $Script:DistroName -u root -- bash -c $createCmd 2>&1 | ForEach-Object { Write-Log $_ }

        # 寫入 wsl.conf 設定預設使用者
        wsl -d $Script:DistroName -u root -- bash -c "printf '[user]\ndefault=$WslUsername\n' > /etc/wsl.conf" 2>&1 | Out-Null
        Write-Log "/etc/wsl.conf 設定完成，預設使用者為 $WslUsername" "Success"

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

# ============================================
# 主要執行流程
# ============================================

function Main {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    # 隱藏 Write-Progress 視覺進度條，避免殘影（]）出現在日誌輸出中
    $ProgressPreference = 'SilentlyContinue'

    # 從 .env 載入設定，優先順序：參數 > .env > 選單/後備預設值
    $dotenv = Read-DotEnv
    if (-not $DistroName)  { $DistroName  = $dotenv['DISTRO_NAME'] }
    if (-not $WslUsername) { $WslUsername = if ($dotenv['WSL_USERNAME']) { $dotenv['WSL_USERNAME'] } else { 'yao'      } }
    if (-not $WslPassword) { $WslPassword = if ($dotenv['WSL_PASSWORD']) { $dotenv['WSL_PASSWORD'] } else { 'changeme' } }

    # 正規化發行版名稱（.env UBUNTU_VERSION 不在此處套用，僅供 install-linux-tools.ps1 獨立執行使用）：
    # - $DistroName 已設定（來自參數或 .env DISTRO_NAME）→ 直接使用，跳過選單
    # - $UbuntuVersion 以命令列參數傳入（例如: 24.04）→ 轉換為 Ubuntu-24.04，跳過選單（向下相容）
    # - 兩者皆未設定 → 顯示互動選單
    if ($DistroName) {
        $Script:DistroName = $DistroName
    } elseif ($UbuntuVersion -match '^\d+\.\d+$') {
        $Script:DistroName = "Ubuntu-$UbuntuVersion"
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "WSL Linux 發行版安裝程式" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # 發行版未指定時顯示互動選單
    if (-not $Script:DistroName) {
        $Script:DistroName = Select-WslDistro
        Write-Host ""
    }

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
        Write-Log "  密碼: $WslPassword"
        Write-Log "日誌檔案位置: $Global:LogFile"

        # 安裝開發工具
        Write-Log "========================================" "Info"
        Write-Log "開始安裝開發工具..." "Info"
        Write-Log "========================================" "Info"

        $installToolsScript = Join-Path $PSScriptRoot "install-linux-tools.ps1"
        if (Test-Path $installToolsScript) {
            $installArgs = @{
                DistroName  = $Script:DistroName
                WslUsername = $WslUsername
                LogPath     = $LogPath
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
