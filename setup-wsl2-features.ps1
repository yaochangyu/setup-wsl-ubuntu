#Requires -RunAsAdministrator

<#
.SYNOPSIS
    啟用 WSL2 所需的 Windows 功能（需要管理員權限）

.DESCRIPTION
    此腳本會執行以下操作：
    1. 檢查 Windows 版本與系統需求
    2. 啟用 WSL Windows 功能
    3. 啟用虛擬機器平台（Hyper-V 相關）
    4. 安裝/更新 WSL2 Linux 核心
    5. 設定 WSL2 為預設版本

.PARAMETER LogPath
    日誌檔案路徑，預設為腳本目錄下的 logs 資料夾

.EXAMPLE
    .\setup-wsl2-features.ps1

.NOTES
    需要管理員權限執行
    完成後執行 setup-linux.ps1 安裝 Linux 發行版（不需管理員）
#>

[CmdletBinding()]
param(
    [string]$LogPath = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"
$Global:LogFile = ""

# ============================================
# 日誌與輸出函式
# ============================================

function Initialize-LogDirectory {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Global:LogFile = Join-Path $LogPath "wsl2-features-$timestamp.log"
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
# 系統檢查函式
# ============================================

function Test-WindowsVersion {
    Write-Log "檢查 Windows 版本..."

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $buildNumber = $os.BuildNumber

    Write-Log "作業系統: $($os.Caption)"
    Write-Log "版本: $($os.Version)"
    Write-Log "組建編號: $buildNumber"

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
        return $true
    }
}

function Test-DiskSpace {
    Write-Log "檢查磁碟空間..."

    $systemDrive = $env:SystemDrive
    $disk = Get-PSDrive -Name $systemDrive.Trim(':')
    $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)

    Write-Log "系統磁碟 ($systemDrive) 可用空間: $freeSpaceGB GB"

    if ($freeSpaceGB -lt 20) {
        Write-Log "警告：磁碟空間不足 20GB，建議清理磁碟空間。" "Warning"
    }

    return $true
}

# ============================================
# WSL 功能啟用函式
# ============================================

function Enable-WSLFeature {
    Write-Log "啟用 WSL 功能..."
    Write-Progress-Log -Activity "WSL2 功能啟用" -Status "啟用 WSL 功能" -PercentComplete 30

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
    Write-Progress-Log -Activity "WSL2 功能啟用" -Status "啟用虛擬機器平台" -PercentComplete 55

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
    Write-Progress-Log -Activity "WSL2 功能啟用" -Status "下載並安裝 WSL2 核心" -PercentComplete 75

    try {
        $wslVersion = wsl --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 核心已安裝" "Success"
            return $true
        }

        Write-Log "正在更新 WSL2 核心..."
        wsl --update 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 核心更新完成" "Success"
            return $true
        } else {
            Write-Log "WSL2 核心更新失敗，嘗試手動下載..." "Warning"

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
    Write-Progress-Log -Activity "WSL2 功能啟用" -Status "設定 WSL2 為預設版本" -PercentComplete 90

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
# 主要執行流程
# ============================================

function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "WSL2 Windows 功能啟用程式（需要管理員）" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Initialize-LogDirectory
    Write-Log "啟動 WSL2 功能啟用程式" "Success"
    Write-Log "日誌檔案: $Global:LogFile"

    try {
        Write-Progress-Log -Activity "WSL2 功能啟用" -Status "檢查系統需求" -PercentComplete 10

        if (-not (Test-WindowsVersion)) {
            throw "Windows 版本不符合需求"
        }

        Test-VirtualizationEnabled | Out-Null
        Test-DiskSpace | Out-Null

        if (-not (Enable-WSLFeature)) {
            throw "啟用 WSL 功能失敗"
        }

        if (-not (Enable-VirtualMachinePlatform)) {
            throw "啟用虛擬機器平台失敗"
        }

        if (-not (Install-WSL2Kernel)) {
            throw "安裝 WSL2 核心失敗"
        }

        if (-not (Set-WSL2AsDefault)) {
            throw "設定 WSL2 預設版本失敗"
        }

        Write-Progress-Log -Activity "WSL2 功能啟用" -Status "完成" -PercentComplete 100

        Write-Log "`n========================================" "Success"
        Write-Log "WSL2 Windows 功能啟用完成！" "Success"
        Write-Log "========================================" "Success"
        Write-Log "`n後續步驟："
        Write-Log "1. 可能需要重新啟動電腦以完成功能啟用"
        Write-Log "2. 重新啟動後，執行 setup-linux.ps1 安裝 Linux 發行版（不需管理員）"
        Write-Log "`n日誌檔案位置: $Global:LogFile"
    }
    catch {
        Write-Log "`n========================================" "Error"
        Write-Log "功能啟用過程發生錯誤" "Error"
        Write-Log "錯誤訊息: $($_.Exception.Message)" "Error"
        Write-Log "========================================" "Error"
        Write-Log "`n請檢查日誌檔案: $Global:LogFile" "Error"
        exit 1
    }
    finally {
        Write-Progress -Activity "WSL2 功能啟用" -Completed
    }
}

Main
