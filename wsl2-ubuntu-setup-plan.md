# WSL2 Ubuntu 24.04 LTS 開發環境設置計畫

## 專案概述

建立三個自動化腳本，用於設置完整的 WSL2 Ubuntu 24.04 LTS 開發環境，適用於 .NET、前端、全端、DevOps 等多種開發場景。

## 需求摘要

- **目標環境**：Ubuntu 24.04 LTS on WSL2
- **使用者**：yao / 123456
- **使用場景**：團隊開發（.NET、前端、全端、DevOps、基礎設施即程式碼）
- **支援功能**：離線安裝、代理設定、安裝驗證、錯誤處理

## 實作步驟

### Phase 1: Windows 腳本（WSL2 安裝）

- [x] **步驟 1：建立 PowerShell 腳本 (setup-wsl2.ps1)**
  - 目的：自動化安裝 WSL2 和 Ubuntu 24.04 LTS
  - 檔案：`setup-wsl2.ps1`
  - 功能：
    - 檢查系統需求（Windows 版本、Hyper-V 支援）
    - 啟用 WSL 和虛擬機平台功能
    - 下載並安裝 WSL2 核心更新
    - 設定 WSL2 為預設版本
    - 下載並安裝 Ubuntu 24.04 LTS
    - 建立預設使用者（yao）
    - 錯誤處理與日誌記錄
    - 顯示安裝進度

- [x] **步驟 2：建立批次檔腳本 (setup-wsl2.bat)**
  - 目的：提供批次檔方式執行 PowerShell 腳本（適合雙擊執行）
  - 檔案：`setup-wsl2.bat`
  - 功能：
    - 檢查管理員權限
    - 呼叫 PowerShell 腳本
    - 錯誤處理

### Phase 2: Linux 工具安裝腳本

- [x] **步驟 3：建立主安裝腳本 (install-linux-tools.sh)**
  - 目的：自動化安裝所有開發工具
  - 檔案：`install-linux-tools.sh`
  - 功能架構：
    - 模組化設計（每個工具一個函式）
    - 錯誤處理與日誌記錄
    - 離線安裝支援
    - 代理設定支援
    - 進度顯示
    - 安裝後驗證

- [x] **步驟 4：實作基礎設定模組**
  - 目的：設定基本系統環境
  - 功能：
    - 更新系統套件
    - 設定 APT 代理（如需要）
    - 安裝基礎工具（curl、wget、git、vim、build-essential）
    - 設定時區與語系

- [x] **步驟 5：實作 Docker Engine 安裝模組**
  - 目的：在 WSL2 內安裝 Docker
  - 功能：
    - 安裝 Docker Engine
    - 設定 Docker 服務自動啟動
    - 將使用者加入 docker 群組
    - 配置 Docker daemon（代理、鏡像加速）
    - 驗證 Docker 安裝

- [x] **步驟 6：實作 .NET SDK 安裝模組**
  - 目的：安裝多版本 .NET SDK
  - 功能：
    - 安裝 .NET 5、6、7、8、9、10 SDK
    - 設定環境變數
    - 驗證各版本安裝
  - 依賴：步驟 4

- [x] **步驟 7：實作 Node.js 與 nvm 安裝模組**
  - 目的：安裝 Node.js 版本管理工具
  - 功能：
    - 安裝 nvm
    - 透過 nvm 安裝 Node.js LTS 版本
    - 設定全域 npm 套件（yarn、pnpm 等）
    - 設定 npm 代理
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 8：實作 Python 與 pyenv 安裝模組**
  - 目的：安裝 Python 版本管理工具
  - 功能：
    - 安裝 pyenv 依賴套件
    - 安裝 pyenv
    - 透過 pyenv 安裝最新 Python 3.x
    - 設定全域 Python 版本
    - 安裝 pip、pipenv、poetry
    - 設定 pip 代理
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 9：實作 Go 安裝模組**
  - 目的：安裝 Go 語言環境
  - 功能：
    - 下載並安裝 Go 最新穩定版
    - 設定 GOPATH 和 GOROOT
    - 設定 Go 代理（GOPROXY）
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 10：實作 Rust 安裝模組**
  - 目的：安裝 Rust 開發環境
  - 功能：
    - 安裝 rustup
    - 安裝 stable 版本 Rust
    - 設定 cargo 代理
    - 安裝常用工具（cargo-edit、cargo-watch 等）
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 11：實作 VS Code Server 安裝模組**
  - 目的：安裝 VS Code Remote 支援
  - 功能：
    - 下載並安裝 VS Code Server
    - 設定自動啟動
    - 安裝常用擴充套件
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 12：實作 Vim 插件安裝模組**
  - 目的：設定 Vim 開發環境
  - 功能：
    - 安裝 vim-plug
    - 設定 .vimrc（語法高亮、自動完成等）
    - 安裝常用插件
    - 驗證設定
  - 依賴：步驟 4

- [x] **步驟 13：實作資料庫客戶端工具安裝模組**
  - 目的：安裝資料庫連接工具
  - 功能：
    - 安裝 PostgreSQL 客戶端工具
    - 安裝 MSSQL 客戶端工具（sqlcmd）
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 14：實作 DevOps 工具安裝模組**
  - 目的：安裝常用 DevOps 工具
  - 功能：
    - 安裝 kubectl
    - 安裝 helm
    - 安裝 terraform
    - 安裝 ansible
    - 安裝 az cli（Azure CLI）
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 15：實作常用 CLI 工具安裝模組**
  - 目的：安裝其他常用命令列工具
  - 功能：
    - 安裝 jq（JSON 處理）
    - 安裝 yq（YAML 處理）
    - 安裝 bat（更好的 cat）
    - 安裝 exa（更好的 ls）
    - 安裝 fzf（模糊搜尋）
    - 安裝 ripgrep（更快的 grep）
    - 安裝 htop（系統監控）
    - 安裝 tmux（終端多工）
    - 安裝 zsh 和 oh-my-zsh
    - 驗證安裝
  - 依賴：步驟 4

- [x] **步驟 16：實作整體驗證模組**
  - 目的：驗證所有工具安裝成功
  - 功能：
    - 執行所有工具的版本檢查
    - 生成安裝報告
    - 列出失敗項目
    - 提供修復建議
  - 依賴：步驟 4-15

### Phase 3: 文檔與配置

- [x] **步驟 17：建立 README.md**
  - 目的：提供使用說明文檔
  - 檔案：`README.md`
  - 內容：
    - 專案簡介
    - 系統需求
    - 安裝步驟
    - 離線安裝說明
    - 代理設定說明
    - 故障排除
    - 常見問題

- [x] **步驟 18：建立設定檔範本**
  - 目的：提供可自訂的配置選項
  - 檔案：`config.example.sh`
  - 內容：
    - 代理設定
    - 工具版本指定
    - 安裝選項開關
    - 離線安裝路徑

- [x] **步驟 19：建立離線安裝包準備腳本**
  - 目的：支援離線環境安裝
  - 檔案：`prepare-offline-packages.sh`
  - 功能：
    - 下載所有必要的安裝包
    - 打包成壓縮檔
    - 生成校驗碼
  - 依賴：步驟 3-15

- [x] **步驟 20：建立卸載腳本**
  - 目的：提供清理選項
  - 檔案：`uninstall.sh`
  - 功能：
    - 移除已安裝的工具
    - 清理配置檔
    - 恢復系統設定

## 驗收標準

- [ ] 所有腳本執行無錯誤
- [ ] 所有工具安裝後版本檢查通過
- [ ] 錯誤處理機制正常運作
- [ ] 日誌記錄完整
- [ ] 離線安裝模式可用
- [ ] 代理設定生效
- [ ] 文檔完整且清晰

## 技術架構

### 檔案結構
```
setup-wsl-ubuntu/
├── setup-wsl2.ps1              # PowerShell 安裝腳本
├── setup-wsl2.bat              # 批次檔包裝腳本
├── install-linux-tools.sh      # 主安裝腳本
├── uninstall.sh                # 卸載腳本
├── prepare-offline-packages.sh # 離線包準備腳本
├── config.example.sh           # 配置範本
├── README.md                   # 使用說明
├── wsl2-ubuntu-setup-plan.md   # 本計畫文檔
├── logs/                       # 安裝日誌目錄
├── offline-packages/           # 離線安裝包目錄
└── scripts/                    # 模組化腳本目錄
    ├── common.sh               # 共用函式
    ├── docker.sh               # Docker 安裝
    ├── dotnet.sh               # .NET SDK 安裝
    ├── nodejs.sh               # Node.js 安裝
    ├── python.sh               # Python 安裝
    ├── go.sh                   # Go 安裝
    ├── rust.sh                 # Rust 安裝
    ├── vscode.sh               # VS Code Server 安裝
    ├── vim.sh                  # Vim 配置
    ├── database.sh             # 資料庫工具安裝
    ├── devops.sh               # DevOps 工具安裝
    └── cli-tools.sh            # CLI 工具安裝
```

### 設計原則

1. **模組化**：每個工具獨立模組，方便維護和選擇性安裝
2. **錯誤處理**：每個步驟都有錯誤檢查和日誌記錄
3. **冪等性**：重複執行不會造成問題
4. **可配置**：透過配置檔自訂安裝選項
5. **驗證機制**：每個工具安裝後自動驗證

## 注意事項

1. .NET 9 和 10 的安裝需確認官方發布狀態，可能需要安裝預覽版
2. WSL2 需要 Windows 10 版本 1903 或更高，或 Windows 11
3. 某些工具可能需要重新啟動 WSL 才能生效
4. 團隊使用建議將配置檔加入版本控制，保持環境一致性
5. 離線安裝包可能會很大，需要足夠的磁碟空間

## 參考資料

- [WSL2 安裝指南](https://dotblogs.com.tw/yc421206/2021/08/15/install_wsl2_and_docker_in_windows_10)
- [Best WSL Ubuntu Setup](https://github.com/doggy8088/best-wsl-ubuntu-setup/blob/main/README.md)
- [Microsoft WSL 官方文檔](https://docs.microsoft.com/en-us/windows/wsl/)
- [Docker on WSL2](https://docs.docker.com/desktop/wsl/)
