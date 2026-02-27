# WSL2 Linux 開發環境自動設置

一鍵安裝 WSL2 + Linux 發行版完整開發環境，支援 Ubuntu、Debian、Kali Linux 等多種發行版，適用於 .NET、前端、全端、DevOps 等多種開發場景。

## 功能特色

✅ **自動化安裝** - PowerShell 和 Bash 腳本全自動安裝
✅ **發行版選單** - 互動式選單，支援所有 `wsl --list --online` 的發行版
✅ **模組化設計** - 每個工具獨立模組，易於維護
✅ **完整日誌** - 詳細的安裝日誌與錯誤追蹤
✅ **代理設定** - 支援企業環境代理配置
✅ **自動驗證** - 安裝後自動驗證所有工具

## 系統需求

### Windows 環境
- Windows 10 版本 1903 或更高（Build 18362+）
- Windows 11（所有版本）
- 至少 10GB 可用磁碟空間
- 網路連線

### 硬體需求
- 支援虛擬化的 CPU（Intel VT-x 或 AMD-V）
- 建議 8GB 以上記憶體

## 快速開始

### 步驟 1：啟用 WSL2 功能（需要管理員）

以**系統管理員身分**開啟 PowerShell，執行：

```powershell
cd D:\lab\setup-wsl-ubuntu
.\setup-wsl2-features.ps1
```

> 完成後可能需要**重新啟動電腦**。

### 步驟 2：安裝 Linux 發行版

重新啟動後，開啟 PowerShell（不需要管理員），執行：

```powershell
cd D:\lab\setup-wsl-ubuntu
.\setup-linux.ps1
```

未指定發行版時會顯示互動式選單，列出所有可用的 WSL 發行版供選擇。預設安裝 Ubuntu 24.04，帳號為 `yao / changeme`。

如需直接指定：

```powershell
# 指定發行版完整名稱（建議）
.\setup-linux.ps1 -DistroName Ubuntu-24.04 -WslUsername myuser -WslPassword mypassword

# 或透過 .env 檔案設定（詳見「環境設定檔」章節）
```

### 步驟 3：安裝開發工具

#### 方法 A：使用 PowerShell（建議）

```powershell
.\install-linux-tools.ps1
```

#### 方法 B：在 WSL 內直接執行

開啟 Linux（從開始功能表或執行 `wsl`），然後執行：

```bash
cd /mnt/d/lab/setup-wsl-ubuntu
sudo ./install-linux-tools.sh
```

## 環境設定檔

敏感資訊（帳號、密碼）建議透過 `.env` 檔案管理，避免直接寫在命令列：

```bash
cp .env.example .env
```

編輯 `.env`：

```ini
# 指定發行版（可選，未設定則顯示互動選單）
DISTRO_NAME=Ubuntu-24.04

# WSL 使用者帳號
WSL_USERNAME=your_username
WSL_PASSWORD=your_password
```

> `.env` 已加入 `.gitignore`，不會被納入版控。

## 已安裝的工具

### 基礎工具
- ✅ build-essential, gcc, g++, make, cmake
- ✅ curl, wget, git, vim, nano
- ✅ 壓縮工具（zip, tar, gzip 等）

### 開發環境
- ✅ **Docker Engine** - 容器化平台
- ✅ **.NET SDK** - 5.0, 6.0, 7.0, 8.0, 9.0, 10.0
- ✅ **Node.js** - LTS 版本 + nvm
- ✅ **Python** - 3.12 + pyenv
- ✅ **Go** - 最新穩定版（動態抓取）
- ✅ **Rust** - 最新穩定版

### 資料庫工具
- ✅ PostgreSQL 客戶端
- ✅ MSSQL 客戶端 (sqlcmd)

### DevOps 工具
- ✅ kubectl - Kubernetes CLI
- ✅ Helm - Kubernetes 套件管理
- ✅ Terraform - 基礎設施即程式碼
- ✅ Azure CLI - Azure 命令列工具

### CLI 工具
- ✅ jq, yq - JSON/YAML 處理
- ✅ bat - 增強的 cat
- ✅ ripgrep - 快速搜尋
- ✅ fzf - 模糊搜尋
- ✅ htop - 系統監控
- ✅ tmux - 終端多工
- ✅ zsh + oh-my-zsh - 強化 Shell
- ✅ Starship - 華麗的 Bash 提示符號（catppuccin-powerline 主題）
- ✅ better-rm - 更安全的 rm（刪除前移至垃圾桶）

### 使用者環境
- ✅ ~/.profile - WINDOWS_USERNAME、JQ_COLORS、EDITOR、GPG_TTY
- ✅ ~/.bashrc - Bash 補全設定、Starship 初始化
- ✅ SSH 金鑰（RSA 4096）自動產生
- ✅ ~/projects 工作目錄建立

## 進階使用

### 選擇發行版

```powershell
# 互動式選單（未指定時自動顯示）
.\setup-linux.ps1

# 直接指定發行版
.\setup-linux.ps1 -DistroName Debian
.\setup-linux.ps1 -DistroName kali-linux
.\setup-linux.ps1 -DistroName Ubuntu-24.04
```

### 使用代理

```powershell
# PowerShell
.\install-linux-tools.ps1 -Proxy http://proxy.example.com:8080
```

```bash
# WSL 內
sudo ./install-linux-tools.sh --proxy http://proxy.example.com:8080
```

## 命令列選項

### setup-linux.ps1

```
參數:
  -DistroName <名稱>      WSL 發行版完整名稱（預設: 互動選單）
                          例: Ubuntu-24.04、Debian、kali-linux
  -WslUsername <名稱>     WSL 使用者名稱（預設: yao）
  -WslPassword <密碼>     WSL 使用者密碼（預設: changeme）
  -Proxy <url>            設定代理伺服器
  -SkipVerify             跳過安裝驗證
```

### install-linux-tools.ps1

```
參數:
  -DistroName <名稱>      WSL 發行版完整名稱（預設: Ubuntu-24.04）
                          例: Ubuntu-24.04、Debian、kali-linux
  -WslUsername <名稱>     WSL 使用者名稱（預設: yao）
  -Proxy <url>            設定代理伺服器
  -SkipVerify             跳過安裝驗證
```

### install-linux-tools.sh

```
選項:
  --proxy <url>      設定代理伺服器
  --skip-verify      跳過安裝驗證
  --help             顯示說明訊息
```

## 日誌與除錯

### 日誌位置

- **發行版安裝日誌**: `logs/ubuntu-setup-YYYYMMDD-HHMMSS.log`
- **Linux 工具日誌（PS1）**: `logs/linux-tools-YYYYMMDD-HHMMSS.log`
- **Linux 工具日誌（sh）**: `logs/install-YYYYMMDD-HHMMSS.log`

### 查看日誌

```bash
# 查看最新日誌
tail -f logs/install-*.log

# 搜尋錯誤訊息
grep -i error logs/install-*.log
```

## 故障排除

### WSL2 安裝問題

**問題：** 虛擬化未啟用
**解決：** 在 BIOS/UEFI 中啟用 Intel VT-x 或 AMD-V

**問題：** Windows 版本過舊
**解決：** 更新 Windows 到 1903 或更高版本

**問題：** 無法啟動 WSL
**解決：** 執行 `wsl --update` 更新 WSL 核心

### Docker 問題

**問題：** Docker 命令無權限
**解決：**
```bash
# 重新登入或執行
newgrp docker

# 或重新啟動 WSL
wsl --shutdown
wsl
```

**問題：** Docker 服務未啟動
**解決：**
```bash
sudo service docker start
```

### 其他問題

**問題：** 套件下載失敗
**解決：** 檢查網路連線或使用代理設定

**問題：** 磁碟空間不足
**解決：** 清理不需要的檔案或擴充磁碟空間

## 卸載

如需移除已安裝的工具：

```bash
sudo ./uninstall.sh
```

**警告：** 此操作會移除所有已安裝的開發工具，請謹慎使用。

## 驗證安裝

### 檢查 Docker

```bash
docker --version
docker run hello-world
```

### 檢查 .NET

```bash
dotnet --version
dotnet --list-sdks
```

### 檢查 Node.js

```bash
node --version
npm --version
```

### 檢查 Python

```bash
python --version
pip --version
```

## 檔案結構

```
setup-wsl-ubuntu/
├── setup-wsl2-features.ps1     # 步驟 1：啟用 WSL2 Windows 功能（需管理員）
├── setup-linux.ps1            # 步驟 2：安裝 Linux 發行版 + 建立使用者
├── install-linux-tools.ps1     # 步驟 3：從 Windows 呼叫開發工具安裝（PS1 包裝）
├── install-linux-tools.sh      # 步驟 3：在 Linux 內執行的開發工具安裝腳本
├── .env.example                # 環境設定範本（複製為 .env 後填入實際值）
├── README.md                   # 本文檔
├── logs/                       # 安裝日誌
└── scripts/                    # 模組化腳本
    ├── common.sh               # 基礎系統、Bash 環境、CLI 工具
    ├── docker.sh               # Docker 安裝
    ├── dotnet.sh               # .NET SDK 安裝
    ├── nodejs.sh               # Node.js 安裝
    ├── python.sh               # Python 安裝
    ├── go.sh                   # Go 安裝
    ├── rust.sh                 # Rust 安裝
    ├── vscode.sh               # VS Code Server
    ├── vim.sh                  # Vim 配置
    ├── database.sh             # 資料庫工具
    └── devops.sh               # DevOps 工具
```

## 常見問題 (FAQ)

### Q: 需要多少時間完成安裝？
A: 視網路速度而定，通常 15-30 分鐘。

### Q: 可以選擇性安裝某些工具嗎？
A: 可以，請修改 `install-linux-tools.sh` 中需要的模組。

### Q: 支援哪些 Linux 發行版？
A: 支援所有 `wsl --list --online` 列出的發行版（Ubuntu、Debian、Kali Linux、openSUSE 等）。開發工具安裝腳本以 Ubuntu/Debian 系為主，其他發行版可能需要調整。

### Q: 如何更新已安裝的工具？
A: 大部分工具可以使用各自的更新命令（如 `apt update`、`nvm install`）。

### Q: 可以在實體 Linux 上使用嗎？
A: 可以，`install-linux-tools.sh` 可在任何 Ubuntu/Debian 系統上執行。

## 貢獻

歡迎提交 Issue 或 Pull Request！

## 授權

MIT License

## 參考資料

- [WSL 官方文檔](https://docs.microsoft.com/zh-tw/windows/wsl/)
- [Docker 官方文檔](https://docs.docker.com/)
- [.NET 官方文檔](https://docs.microsoft.com/zh-tw/dotnet/)

## 作者

開發環境自動化專案

---

**最後更新：** 2026-02-27
