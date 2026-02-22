#Requires -RunAsAdministrator

<#
.SYNOPSIS
    自動化安裝 WSL2 和 Ubuntu 24.04 LTS

.DESCRIPTION
    此腳本會自動執行以下操作：
    1. 檢查系統需求
    2. 啟用 WSL 和虛擬機平台功能
    3. 下載並安裝 WSL2 核心更新
    4. 設定 WSL2 為預設版本
    5. 安裝 Ubuntu 24.04 LTS
    6. 設定預設使用者

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\setup_wsl2.ps1

.NOTES
    需要管理員權限執行
    需要 Windows 10 版本 1903 或更高，或 Windows 11
#>

[CmdletBinding()]
param(
    [string]$LogPath = "$PSScriptRoot\logs"
)

# ============================================
# 全域變數設定
# ============================================
$ErrorActionPreference = "Stop"
$Global:LogFile = ""
$Global:InstallSuccess = $true

# 使用者設定
$WslUsername = "yao"
$WslPassword = "123456"
# $UbuntuVersion = "24.04"
$UbuntuVersion = "22.04"

# ============================================
# 日誌與輸出函式
# ============================================

function Initialize-LogDirectory {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Global:LogFile = Join-Path $LogPath "wsl2-setup-$timestamp.log"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # 寫入日誌檔
    Add-Content -Path $Global:LogFile -Value $logMessage

    # 根據級別設定顏色輸出到控制台
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
# 系統檢查函式
# ============================================

function Test-WindowsVersion {
    Write-Log "檢查 Windows 版本..."

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $version = [System.Version]$os.Version
    $buildNumber = $os.BuildNumber

    Write-Log "作業系統: $($os.Caption)"
    Write-Log "版本: $($os.Version)"
    Write-Log "組建編號: $buildNumber"

    # Windows 10 需要 Build 18362 或更高（版本 1903）
    # Windows 11 都支援
    if ($buildNumber -lt 18362) {
        Write-Log "不支援的 Windows 版本。需要 Windows 10 Build 18362 (版本 1903) 或更高版本。" "Error"
        return $false
    }

    Write-Log "Windows 版本檢查通過" "Success"
    return $true
}

function Test-VirtualizationEnabled {
    Write-Log "檢查虛擬化支援..."

    try {
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        $vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

        # 檢查 CPU 虛擬化是否啟用
        $processor = Get-CimInstance -ClassName Win32_Processor
        if ($processor.VirtualizationFirmwareEnabled -eq $false) {
            Write-Log "警告：BIOS/UEFI 中的虛擬化功能未啟用。請在 BIOS 中啟用 Intel VT-x 或 AMD-V。" "Warning"
        } else {
            Write-Log "CPU 虛擬化已啟用" "Success"
        }

        return $true
    }
    catch {
        Write-Log "無法檢查虛擬化狀態: $($_.Exception.Message)" "Warning"
        return $true  # 繼續執行，讓後續步驟處理
    }
}

function Test-DiskSpace {
    Write-Log "檢查磁碟空間..."

    $systemDrive = $env:SystemDrive
    $disk = Get-PSDrive -Name $systemDrive.Trim(':')
    $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)

    Write-Log "系統磁碟 ($systemDrive) 可用空間: $freeSpaceGB GB"

    # 建議至少 20GB 可用空間
    if ($freeSpaceGB -lt 20) {
        Write-Log "警告：磁碟空間不足 20GB，建議清理磁碟空間。" "Warning"
    }

    return $true
}

# ============================================
# WSL 安裝函式
# ============================================

function Enable-WSLFeature {
    Write-Log "啟用 WSL 功能..."
    Write-Progress-Log -Activity "WSL2 安裝" -Status "啟用 WSL 功能" -PercentComplete 20

    try {
        $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

        if ($wsl.State -ne "Enabled") {
            Write-Log "正在啟用 WSL 功能..."
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -WarningAction SilentlyContinue | Out-Null
            Write-Log "WSL 功能已啟用" "Success"
        } else {
            Write-Log "WSL 功能已經啟用" "Success"
        }

        return $true
    }
    catch {
        Write-Log "啟用 WSL 功能失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Enable-VirtualMachinePlatform {
    Write-Log "啟用虛擬機器平台功能..."
    Write-Progress-Log -Activity "WSL2 安裝" -Status "啟用虛擬機器平台" -PercentComplete 30

    try {
        $vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

        if ($vmPlatform.State -ne "Enabled") {
            Write-Log "正在啟用虛擬機器平台..."
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -WarningAction SilentlyContinue | Out-Null
            Write-Log "虛擬機器平台已啟用" "Success"
        } else {
            Write-Log "虛擬機器平台已經啟用" "Success"
        }

        return $true
    }
    catch {
        Write-Log "啟用虛擬機器平台失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Install-WSL2Kernel {
    Write-Log "安裝 WSL2 Linux 核心更新..."
    Write-Progress-Log -Activity "WSL2 安裝" -Status "下載並安裝 WSL2 核心" -PercentComplete 40

    try {
        # 檢查是否已安裝
        $wslVersion = wsl --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 核心已安裝" "Success"
            return $true
        }

        # 使用 wsl --update 安裝最新核心
        Write-Log "正在更新 WSL2 核心..."
        wsl --update 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 核心更新完成" "Success"
            return $true
        } else {
            Write-Log "WSL2 核心更新失敗，嘗試手動下載..." "Warning"

            # 備用方案：手動下載
            $kernelUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
            $kernelInstaller = Join-Path $env:TEMP "wsl_update_x64.msi"

            Write-Log "下載 WSL2 核心更新檔案..."
            Invoke-WebRequest -Uri $kernelUrl -OutFile $kernelInstaller -UseBasicParsing

            Write-Log "安裝 WSL2 核心..."
            Start-Process msiexec.exe -ArgumentList "/i `"$kernelInstaller`" /quiet /norestart" -Wait

            Remove-Item $kernelInstaller -Force
            Write-Log "WSL2 核心安裝完成" "Success"
            return $true
        }
    }
    catch {
        Write-Log "安裝 WSL2 核心失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-WSL2AsDefault {
    Write-Log "設定 WSL2 為預設版本..."
    Write-Progress-Log -Activity "WSL2 安裝" -Status "設定 WSL2 為預設版本" -PercentComplete 50

    try {
        wsl --set-default-version 2 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 已設為預設版本" "Success"
            return $true
        } else {
            Write-Log "設定 WSL2 預設版本失敗" "Error"
            return $false
        }
    }
    catch {
        Write-Log "設定 WSL2 失敗: $($_.Exception.Message)" "Error"
        return $false
    }
}

# ============================================
# Ubuntu 安裝函式
# ============================================

function Install-Ubuntu {
    Write-Log "安裝 Ubuntu $UbuntuVersion LTS..."
    Write-Progress-Log -Activity "WSL2 安裝" -Status "安裝 Ubuntu $UbuntuVersion" -PercentComplete 60

    try {
        # 檢查是否已安裝
        $existingDistros = wsl --list --quiet 2>&1 | Where-Object { $_ -match "Ubuntu" }
        if ($existingDistros) {
            Write-Log "檢測到已安裝的 Ubuntu 發行版：" "Warning"
            wsl --list --verbose | ForEach-Object { Write-Log $_ }

            $response = Read-Host "是否要繼續安裝新的 Ubuntu $UbuntuVersion？ (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Log "使用者取消安裝" "Warning"
                return $true
            }
        }

        # 使用 wsl --install 安裝 Ubuntu
        Write-Log "正在安裝 Ubuntu-$UbuntuVersion..."

        # 嘗試使用 wsl --install
        $installCmd = "wsl --install -d Ubuntu-$UbuntuVersion"
        Write-Log "執行命令: $installCmd"

        Invoke-Expression $installCmd 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Ubuntu $UbuntuVersion 安裝命令執行完成" "Success"
            return $true
        } else {
            Write-Log "使用 wsl --install 失敗，嘗試從 Microsoft Store 安裝..." "Warning"

            # 備用方案：使用 Microsoft Store
            Write-Log "請從 Microsoft Store 手動安裝 Ubuntu $UbuntuVersion" "Warning"
            Write-Log "或使用命令: wsl --install -d Ubuntu-$UbuntuVersion" "Warning"

            # 開啟 Microsoft Store
            Start-Process "ms-windows-store://pdp/?ProductId=9NZ3KLHXDJP5"

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
    Write-Progress-Log -Activity "WSL2 安裝" -Status "設定預設使用者" -PercentComplete 80

    try {
        # 等待 Ubuntu 完成初始化
        Write-Log "等待 Ubuntu 初始化..."
        Start-Sleep -Seconds 5

        # 檢查 Ubuntu 是否已安裝
        $distros = wsl --list --verbose 2>&1
        $ubuntuInstalled = $distros | Select-String -Pattern "Ubuntu.*Running|Ubuntu.*Stopped"

        if (-not $ubuntuInstalled) {
            Write-Log "Ubuntu 尚未完成安裝，請手動完成初始設定" "Warning"
            Write-Log "請執行 'ubuntu2404' 或從開始功能表啟動 Ubuntu 24.04" "Warning"
            Write-Log "首次啟動時，請設定使用者名稱為: $WslUsername" "Warning"
            Write-Log "密碼為: $WslPassword" "Warning"
            return $true
        }

        # 嘗試設定預設使用者
        Write-Log "正在設定預設使用者為 $WslUsername..."

        # 建立使用者設定指令
        $createUserCmd = @"
if ! id -u $WslUsername > /dev/null 2>&1; then
    useradd -m -s /bin/bash $WslUsername
    echo '$WslUsername`:$WslPassword' | chpasswd
    usermod -aG sudo $WslUsername
    echo '$WslUsername ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/$WslUsername
    chmod 0440 /etc/sudoers.d/$WslUsername
fi
"@

        # 執行建立使用者的命令
        $createUserCmd | wsl -d Ubuntu-$UbuntuVersion -u root bash 2>&1 | ForEach-Object { Write-Log $_ }

        # 設定預設使用者
        ubuntu2404 config --default-user $WslUsername 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "預設使用者設定完成" "Success"
            return $true
        } else {
            Write-Log "自動設定預設使用者失敗，請手動設定" "Warning"
            return $true
        }
    }
    catch {
        Write-Log "設定預設使用者時發生錯誤: $($_.Exception.Message)" "Warning"
        Write-Log "請手動啟動 Ubuntu 並完成初始設定" "Warning"
        return $true
    }
}

# ============================================
# 驗證函式
# ============================================

function Test-Installation {
    Write-Log "驗證 WSL2 安裝..."
    Write-Progress-Log -Activity "WSL2 安裝" -Status "驗證安裝" -PercentComplete 90

    try {
        # 檢查 WSL 版本
        Write-Log "WSL 版本資訊："
        wsl --version 2>&1 | ForEach-Object { Write-Log $_ }

        # 列出已安裝的發行版
        Write-Log "`n已安裝的 Linux 發行版："
        wsl --list --verbose 2>&1 | ForEach-Object { Write-Log $_ }

        # 測試 WSL 連接
        Write-Log "`n測試 WSL 連接..."
        $testResult = wsl -d Ubuntu-$UbuntuVersion -e echo "WSL2 Ubuntu $UbuntuVersion 運作正常" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log $testResult "Success"
            Write-Log "WSL2 安裝驗證成功！" "Success"
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
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "WSL2 與 Ubuntu $UbuntuVersion LTS 自動安裝程式" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # 初始化日誌
    Initialize-LogDirectory
    Write-Log "安裝程式啟動" "Success"
    Write-Log "日誌檔案: $Global:LogFile"

    try {
        # 階段 1: 系統檢查
        Write-Progress-Log -Activity "WSL2 安裝" -Status "檢查系統需求" -PercentComplete 5

        if (-not (Test-WindowsVersion)) {
            throw "Windows 版本不符合需求"
        }

        Test-VirtualizationEnabled | Out-Null
        Test-DiskSpace | Out-Null

        # 階段 2: 啟用 WSL 功能
        Write-Progress-Log -Activity "WSL2 安裝" -Status "啟用 WSL 功能" -PercentComplete 10

        if (-not (Enable-WSLFeature)) {
            throw "啟用 WSL 功能失敗"
        }

        if (-not (Enable-VirtualMachinePlatform)) {
            throw "啟用虛擬機器平台失敗"
        }

        # 階段 3: 安裝 WSL2 核心
        if (-not (Install-WSL2Kernel)) {
            throw "安裝 WSL2 核心失敗"
        }

        if (-not (Set-WSL2AsDefault)) {
            throw "設定 WSL2 預設版本失敗"
        }

        # 階段 4: 安裝 Ubuntu
        if (-not (Install-Ubuntu)) {
            throw "安裝 Ubuntu 失敗"
        }

        # 階段 5: 設定預設使用者
        Set-UbuntuDefaultUser | Out-Null

        # 階段 6: 驗證安裝
        if (-not (Test-Installation)) {
            Write-Log "部分功能驗證失敗，請檢查日誌" "Warning"
        }

        # 完成
        Write-Progress-Log -Activity "WSL2 安裝" -Status "安裝完成" -PercentComplete 100

        Write-Log "`n========================================" "Success"
        Write-Log "WSL2 與 Ubuntu $UbuntuVersion 安裝完成！" "Success"
        Write-Log "========================================" "Success"
        Write-Log "`n後續步驟："
        Write-Log "1. 可能需要重新啟動電腦以完成安裝"
        Write-Log "2. 啟動 Ubuntu：在開始功能表搜尋 'Ubuntu 24.04' 或執行 'wsl' 命令"
        Write-Log "3. 執行 Linux 工具安裝腳本：cd /mnt/d/lab/setup-wsl-ubuntu && ./install-linux-tools.sh"
        Write-Log "`n使用者帳號資訊："
        Write-Log "  使用者名稱: $WslUsername"
        Write-Log "  密碼: $WslPassword"
        Write-Log "`n日誌檔案位置: $Global:LogFile"

        # 詢問是否重新啟動
        Write-Host "`n" -NoNewline
        $restart = Read-Host "是否現在重新啟動電腦？ (y/N)"
        if ($restart -eq 'y' -or $restart -eq 'Y') {
            Write-Log "準備重新啟動電腦..."
            Restart-Computer -Force
        }
    }
    catch {
        $Global:InstallSuccess = $false
        Write-Log "`n========================================" "Error"
        Write-Log "安裝過程發生錯誤" "Error"
        Write-Log "錯誤訊息: $($_.Exception.Message)" "Error"
        Write-Log "========================================" "Error"
        Write-Log "`n請檢查日誌檔案: $Global:LogFile" "Error"
        exit 1
    }
    finally {
        Write-Progress -Activity "WSL2 安裝" -Completed
    }
}

# ============================================
# 執行主程式
# ============================================

# 檢查管理員權限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "此腳本需要管理員權限執行" -ForegroundColor Red
    Write-Host "請以系統管理員身分執行 PowerShell，然後重新執行此腳本" -ForegroundColor Yellow
    exit 1
}

# 執行主程式
Main
