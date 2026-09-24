# config-to-env Inventory

## 盤點目標

整理目前專案中 `config.sh`、`.env` 與 Docker 組態的實際使用點，作為後續設定來源收斂與 Docker 組態策略調整的依據。

## 盤點結果摘要

### 1. 設定來源現況

- **PowerShell 流程已以 `.env` 為主**
  - `setup-ubuntu.ps1` 會讀取 `.env`，並以「參數 > `.env` > 後備預設值」決定 `UBUNTU_VERSION`、`WSL_USERNAME`、`WSL_PASSWORD`。
  - `install-linux-tools.ps1` 會讀取 `.env`，並以「參數 > `.env` > 後備預設值」決定 `UBUNTU_VERSION`、`WSL_USERNAME`、`DOCKER_TCP_PORT`。

- **Bash 流程仍以 `config.sh` 為主**
  - `install-linux-tools.sh` 預設從 `config.sh` 載入設定。
  - 各 shell 模組的環境變數說明，也都還寫著「可由外部環境或 `config.sh` 覆蓋」。

- **文件已偏向 `.env`，但 repo 仍保留 `config.example.sh`**
  - README 的使用說明與安裝入口偏向 `.env`。
  - 專案樹與範例檔仍同時保留 `.env.example` 與 `config.example.sh`，形成雙軌。

### 2. Docker 組態現況

- Docker 安裝與 daemon 設定主要在 `scripts/docker.sh`。
- Docker 相關參數目前由環境變數注入：
  - `DOCKER_WINDOWS_HOST`
  - `DOCKER_TCP_PORT`
  - `DOCKER_REGISTRY_MIRRORS`
  - `PROXY_URL`
  - `NO_PROXY`
- `configure_docker_daemon()` 目前會重寫 `/etc/docker/daemon.json`，僅保留少數欄位與現有 TCP port 偵測結果，仍有覆蓋既有使用者設定的風險。

## 詳細盤點

### A. 入口腳本

#### `setup-ubuntu.ps1`

- 讀取 `.env`：`Read-DotEnv()`
- 目前使用的 `.env` 欄位：
  - `UBUNTU_VERSION`
  - `WSL_USERNAME`
  - `WSL_PASSWORD`
- 優先順序已明確寫在程式中：參數 > `.env` > 後備預設值

#### `install-linux-tools.ps1`

- 讀取 `.env`：`Read-DotEnv()`
- 目前使用的 `.env` 欄位：
  - `UBUNTU_VERSION`
  - `WSL_USERNAME`
  - `DOCKER_TCP_PORT`
- 附加行為：
  - 若 `.env` 沒指定 `DOCKER_TCP_PORT`，會先讀取 WSL 既有 Docker 設定，再自動找可用 port。
  - 執行 Bash 安裝腳本時，會透過 `export` 傳入 `SUDO_USER`、`SCRIPT_DIR`、`DOCKER_TCP_PORT`。

#### `install-linux-tools.sh`

- 預設設定檔：`CONFIG_FILE="${CONFIG_DIR}/config.sh"`
- 由 `load_config()` 直接 `source "${CONFIG_FILE}"`
- CLI 參數仍保留 `--config <file>`
- `--proxy` 會直接覆蓋 `PROXY_URL`
- 目前尚未支援讀取 `.env`

### B. Shell 模組

以下模組的檔頭註解仍以「環境變數可由外部環境或 `config.sh` 覆蓋」為前提：

- `scripts/common.sh`
- `scripts/database.sh`
- `scripts/docker.sh`
- `scripts/dotnet.sh`
- `scripts/go.sh`
- `scripts/nodejs.sh`
- `scripts/python.sh`

其中與本次遷移直接相關的主要欄位如下。

#### `scripts/common.sh`

- 依賴環境變數：
  - `UPGRADE_PACKAGES`
  - `PROXY_URL`
  - `TIMEZONE`
  - `LOCALE`
  - `ADDITIONAL_LOCALES`
  - `GIT_USER_NAME`
  - `GIT_USER_EMAIL`
- 功能影響：
  - APT proxy 設定
  - 系統更新
  - 時區與語系
  - Git 全域使用者設定

#### `scripts/docker.sh`

- 依賴環境變數：
  - `OFFLINE_MODE`
  - `OFFLINE_DIR`
  - `DOCKER_REGISTRY_MIRRORS`
  - `PROXY_URL`
  - `NO_PROXY`
  - `DOCKER_WINDOWS_HOST`
  - `DOCKER_TCP_PORT`
- 風險點：
  - `configure_docker_daemon()` 直接輸出新的 JSON 內容到 `/etc/docker/daemon.json`
  - 雖有備份與既有 TCP port 偵測，但沒有 merge 現有 JSON 欄位

### C. 驗證與文件

#### `verify.sh`

- 目前**沒有**讀取 `.env` 或 `config.sh`
- 只負責檢查工具是否存在與版本
- `check_docker()` 僅驗證：
  - `docker`
  - `docker compose`
- 結論：`verify.sh` 不需遷移設定來源，但後續若要驗證 Docker host / port / proxy / mirrors，可能需要擴充檢查項目

#### `README.md`

- 使用說明偏向 `.env`
- 提供 `.env.example -> .env` 的操作方式
- 仍在專案結構中列出 `config.example.sh`
- 結論：文件與 Bash 腳本的實際行為尚未一致

### D. 範例檔

#### `.env.example`

- 已涵蓋大部分安裝所需欄位：
  - WSL 發行版與帳密
  - 系統設定
  - Git 設定
  - 代理設定
  - Docker 設定
  - 離線設定
  - 語言版本設定
  - 資料庫授權設定

#### `config.example.sh`

- 與 `.env.example` 有大量重疊欄位
- 目前仍作為 Bash 預設設定範本
- 與 `.env.example` 相比：
  - 缺少 WSL 帳密欄位
  - Docker 欄位較少
  - 版本欄位覆蓋範圍較窄

## 初步結論

1. **設定來源已經事實上分裂**
   - PowerShell：`.env`
   - Bash：`config.sh`

2. **`.env.example` 已具備成為唯一主設定範本的條件**
   - 欄位比較完整
   - 已被 README 與 PowerShell 流程採用

3. **Bash 入口腳本是遷移的主要切入點**
   - 只要 `install-linux-tools.sh` 改為以 `.env` 為主，整體雙軌問題就會大幅縮小

4. **Docker 組態要另外處理，不宜只做設定來源替換**
   - 因為目前最大風險不只是從哪裡讀值，而是 `daemon.json` 的覆蓋策略

## 建議下一步

- 進入步驟 2，先定義：
  - 統一設定優先順序
  - `.env` 欄位對照表
  - Docker daemon 的保留 / merge / 覆蓋規則
