@echo off
REM ============================================
REM WSL2 與 Ubuntu 自動安裝批次檔
REM 此批次檔會以管理員權限執行 PowerShell 腳本
REM ============================================

setlocal EnableDelayedExpansion

REM 設定控制台編碼為 UTF-8
chcp 65001 >nul

REM 顯示標題
title WSL2 安裝程式
cls
echo ========================================
echo WSL2 與 Ubuntu 自動安裝程式
echo ========================================
echo.

REM ============================================
REM 檢查管理員權限
REM ============================================

echo [檢查] 正在檢查管理員權限...

net session >nul 2>&1
if %errorLevel% == 0 (
    echo [成功] 已取得管理員權限
    echo.
    goto :RunScript
) else (
    echo [警告] 此程式需要管理員權限執行
    echo.
    echo 正在嘗試以管理員權限重新啟動...
    echo.

    REM 嘗試以管理員權限重新啟動
    powershell -Command "Start-Process '%~f0' -Verb RunAs"

    if %errorLevel% == 0 (
        echo [資訊] 已在新視窗中以管理員權限啟動
        echo [資訊] 您可以關閉此視窗
        timeout /t 3 >nul
        exit /b 0
    ) else (
        echo [錯誤] 無法取得管理員權限
        echo.
        echo 請手動以管理員身分執行此批次檔：
        echo   1. 右鍵點擊此批次檔
        echo   2. 選擇「以系統管理員身分執行」
        echo.
        goto :Error
    )
)

REM ============================================
REM 執行 PowerShell 腳本
REM ============================================

:RunScript

REM 取得批次檔所在目錄
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%setup-wsl2.ps1"

REM 檢查 PowerShell 腳本是否存在
echo [檢查] 正在檢查 PowerShell 腳本...

if not exist "%PS_SCRIPT%" (
    echo [錯誤] 找不到 PowerShell 腳本：%PS_SCRIPT%
    echo.
    echo 請確認以下檔案存在：
    echo   - setup-wsl2.ps1
    echo.
    goto :Error
)

echo [成功] PowerShell 腳本檢查通過
echo.

REM 檢查 PowerShell 版本
echo [檢查] 正在檢查 PowerShell 版本...

powershell -Command "$PSVersionTable.PSVersion.Major" >nul 2>&1
if %errorLevel% neq 0 (
    echo [錯誤] 無法執行 PowerShell
    echo.
    echo 請確認系統已安裝 PowerShell
    goto :Error
)

for /f "delims=" %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major"') do set PS_VERSION=%%i

if !PS_VERSION! LSS 5 (
    echo [警告] PowerShell 版本過舊 ^(目前版本: !PS_VERSION!^)
    echo [警告] 建議使用 PowerShell 5.0 或更高版本
    echo.
) else (
    echo [成功] PowerShell 版本檢查通過 ^(版本: !PS_VERSION!^)
    echo.
)

REM 詢問是否繼續
echo ========================================
echo 準備開始安裝 WSL2 與 Ubuntu
echo ========================================
echo.
echo 此程式將會：
echo   1. 檢查系統需求
echo   2. 啟用 WSL 和虛擬機平台功能
echo   3. 安裝 WSL2 核心更新
echo   4. 安裝 Ubuntu 22.04 LTS
echo   5. 設定預設使用者 ^(yao^)
echo.
echo 注意事項：
echo   - 需要網路連線
echo   - 可能需要重新啟動電腦
echo   - 整個過程可能需要 10-30 分鐘
echo.

set /p "CONFIRM=是否要繼續？ (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo.
    echo [資訊] 使用者取消安裝
    goto :End
)

echo.
echo ========================================
echo 開始執行安裝程式
echo ========================================
echo.

REM 執行 PowerShell 腳本
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS_SCRIPT%'"

REM 檢查執行結果
if %errorLevel% == 0 (
    echo.
    echo ========================================
    echo [成功] 安裝完成！
    echo ========================================
    echo.
    goto :End
) else (
    echo.
    echo ========================================
    echo [錯誤] 安裝過程發生錯誤
    echo ========================================
    echo.
    echo 錯誤代碼: %errorLevel%
    echo.
    echo 請檢查日誌檔案：
    echo   %SCRIPT_DIR%logs\
    echo.
    goto :Error
)

REM ============================================
REM 錯誤處理
REM ============================================

:Error
echo.
echo [資訊] 程式執行失敗
echo.
echo 故障排除建議：
echo   1. 確認以管理員身分執行
echo   2. 確認網路連線正常
echo   3. 檢查 Windows 版本是否支援 WSL2
echo   4. 檢查日誌檔案以了解詳細錯誤
echo.
echo 日誌檔案位置：
echo   %SCRIPT_DIR%logs\
echo.
pause
exit /b 1

REM ============================================
REM 正常結束
REM ============================================

:End
echo.
echo [資訊] 按任意鍵結束程式...
pause >nul
exit /b 0
