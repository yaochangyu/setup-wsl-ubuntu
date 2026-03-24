# WSL2 Linux 開發環境自動設置

一鍵安裝 WSL2 + Linux 發行版完整開發環境，支援 Ubuntu，適用於 .NET、前端、全端、DevOps 等多種開發場景。

## 功能特色

✅ **自動化安裝** - PowerShell 和 Bash 腳本全自動安裝
✅ **模組化設計** - 每個工具獨立模組，易於維護
✅ **冪等執行** - 已安裝的工具自動跳過，配置步驟每次更新
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

### 推薦流程

一般情況下，只要照下面兩步執行即可：

1. 先用 `setup-wsl2-features.ps1` 啟用 WSL2 功能
2. 再用 `setup-ubuntu.ps1` 安裝 Ubuntu，並自動接續安裝開發工具

只有在開發工具安裝中斷，或你想單獨重跑工具安裝時，才需要另外執行 `install-linux-tools.ps1` 或 `install-linux-tools.sh`。

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
.\setup-ubuntu.ps1
```

預設安裝 Ubuntu 24.04，帳號為 `yao / changeme`。

`setup-ubuntu.ps1` 完成 Ubuntu 安裝後，若同目錄存在 `install-linux-tools.ps1`，會自動接續安裝開發工具，因此多數情況不需要再手動執行下一步。

如需直接指定：

```powershell
# 指定版本號（安裝 Ubuntu-24.04）
.\setup-ubuntu.ps1 -UbuntuVersion 24.04 -WslUsername myuser -WslPassword mypassword

# 不指定版本：安裝最新 LTS（distro name = Ubuntu）
.\setup-ubuntu.ps1

# 或透過 .env 檔案設定（詳見「環境設定檔」章節）
```

### 步驟 3：單獨執行或重跑開發工具安裝（可選）

適用情境：

- 前一次工具安裝中斷
- 只想重跑開發工具安裝，不重裝 Ubuntu
- 想直接從 WSL 內執行 Linux 安裝腳本

#### 方法 A：使用 PowerShell

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

### AI CLI 工具
- ✅ **Claude Code** - Anthropic CLI（原生安裝器）
- ✅ **Codex CLI** - OpenAI CLI
- ✅ **Gemini CLI** - Google CLI
- ✅ **GitHub Copilot CLI** - GitHub AI 助手

### CLI 工具
- ✅ jq, yq - JSON/YAML 處理
- ✅ bat - 增強的 cat
- ✅ ripgrep - 快速搜尋
- ✅ fzf - 模糊搜尋
- ✅ glab - GitLab CLI
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
# 預設安裝 Ubuntu 24.04
.\setup-ubuntu.ps1

# 直接指定版本
.\setup-ubuntu.ps1 -UbuntuVersion 24.04
```

### 使用代理

```powershell
# 推薦：從頭執行 Ubuntu 安裝，並在完成後自動接續安裝開發工具
.\setup-ubuntu.ps1 -Proxy http://proxy.example.com:8080

# 僅重跑開發工具安裝
.\install-linux-tools.ps1 -Proxy http://proxy.example.com:8080
```

```bash
# WSL 內
sudo ./install-linux-tools.sh --proxy http://proxy.example.com:8080
```

## 命令列選項

### setup-ubuntu.ps1

```
參數:
  -UbuntuVersion <版號>   Ubuntu 版本號（例: 24.04、22.04）
                          不指定則安裝最新 LTS（distro name = Ubuntu）
  -WslUsername <名稱>     WSL 使用者名稱（預設: yao）
  -WslPassword <密碼>     WSL 使用者密碼（預設: changeme）
  -Proxy <url>            設定代理伺服器
  -SkipVerify             跳過安裝驗證
```

### install-linux-tools.ps1

```
參數:
  -UbuntuVersion <版號>   Ubuntu 版本號（例: 24.04、22.04）
                          優先順序：參數 > .env UBUNTU_VERSION > 24.04
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

## 版本控制

各工具版本可透過環境變數指定，未設定時自動取得最新版本：

| 環境變數 | 預設值 | 說明 |
|---------|--------|------|
| `DOTNET_VERSIONS` | `5.0 6.0 7.0 8.0 9.0 10.0` | .NET SDK 版本（空白分隔） |
| `NVM_VERSION` | 自動取得最新版 | nvm 版本（例: `v0.40.4`） |
| `PYTHON_VERSION` | `3.12` | pyenv 安裝的 Python 版本 |
| `GO_VERSION` | 自動取得最新版 | Go 版本（例: `1.26.1`） |

```bash
# 範例：指定特定版本
sudo GO_VERSION=1.23.0 PYTHON_VERSION=3.11 ./install-linux-tools.sh
```

## 日誌與除錯

### 日誌位置

- **發行版安裝日誌**: `logs/ubuntu-setup-YYYYMMDD-HHMMSS.log`
- **Linux 工具日誌（PS1）**: `logs/linux-tools-YYYYMMDD-HHMMSS.log`
- **Linux 工具日誌（sh）**: `logs/install-YYYYMMDD-HHMMSS.log`
- **驗證日誌**: `logs/verify-YYYYMMDD-HHMMSS.log`
- **卸載日誌**: `logs/uninstall-YYYYMMDD-HHMMSS.log`

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

### WSL interop 問題

**問題：** 執行 Windows 程式（如 `code .`）出現 `Exec format error`
**解決：** `/etc/wsl.conf` 缺少 `[interop]` 設定，手動加入後重啟 WSL：
```bash
sudo tee -a /etc/wsl.conf <<'EOF'

[interop]
enabled=true
appendWindowsPath=true
EOF
```
```powershell
# Windows PowerShell
wsl --shutdown
wsl
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

使用內建的驗證腳本，一次檢查所有工具安裝狀態：

```bash
# 檢查所有工具
./verify.sh

# 檢查並自動重裝失敗項目
sudo ./verify.sh --fix
```

輸出範例：

```
── 系統工具 ──
  ✓ git
  ✓ curl
  ...

── AI CLI 工具 ──
  ✓ claude
  ✓ codex
  ✓ gemini
  ✓ copilot

========================================
驗證結果
========================================

  通過: 42
  失敗: 0

所有工具皆已正確安裝！
```

## 檔案結構

```
setup-wsl-ubuntu/
├── setup-wsl2-features.ps1     # 步驟 1：啟用 WSL2 Windows 功能（需管理員）
├── setup-ubuntu.ps1            # 步驟 2：安裝 Ubuntu + 建立使用者，完成後自動接續安裝工具
├── install-linux-tools.ps1     # 開發工具安裝入口（可由 setup-ubuntu 自動呼叫，也可手動重跑）
├── install-linux-tools.sh      # 步驟 3：在 Linux 內執行的開發工具安裝腳本
├── verify.sh                   # 工具安裝驗證（支援 --fix 自動重裝）
├── uninstall.sh                # 卸載所有已安裝的開發工具
├── config.example.sh           # 配置檔範例
├── .env.example                # 環境設定範本（複製為 .env 後填入實際值）
├── README.md                   # 本文檔
├── tree.md                     # 專案結構
├── logs/                       # 安裝日誌
└── scripts/                    # 模組化腳本
    ├── common.sh               # 基礎系統、Bash 環境、CLI 工具、AI CLI 工具
    ├── docker.sh               # Docker 安裝
    ├── dotnet.sh               # .NET SDK 安裝
    ├── nodejs.sh               # Node.js + nvm 安裝
    ├── python.sh               # Python + pyenv 安裝
    ├── go.sh                   # Go 安裝
    ├── rust.sh                 # Rust 安裝
    ├── vscode.sh               # VS Code Server
    ├── vscode-troubleshoot.sh  # VS Code Server 故障排除
    ├── vim.sh                  # Vim 配置
    ├── database.sh             # 資料庫工具（psql, sqlcmd）
    └── devops.sh               # DevOps 工具（kubectl, helm, terraform, az）
```

## 常見問題 (FAQ)

### Q: 需要多少時間完成安裝？
A: 視網路速度而定，通常 15-30 分鐘。

### Q: 可以選擇性安裝某些工具嗎？
A: 可以，請修改 `install-linux-tools.sh` 中需要的模組。

### Q: 支援哪些 Linux 發行版？
A: 支援 Ubuntu（預設安裝 Ubuntu 24.04）。開發工具安裝腳本以 Ubuntu/Debian 系為主。

### Q: 重複執行腳本會怎樣？
A: 安全，腳本設計為冪等執行。已安裝的工具會自動跳過，但配置步驟（如 Docker daemon 設定、daemon.json、使用者群組、npm 全域套件）每次都會重新套用，確保設定是最新的。

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

**最後更新：** 2026-03-24
