# config-to-env Strategy

## 目標

定義專案未來統一的設定來源、優先順序，以及 `config.example.sh` 遷移到 `.env.example` 的欄位對照規則。

## 統一原則

### 1. 唯一主要設定來源

- **使用者可編輯設定以 `.env` 為唯一主要來源**
- `.env.example` 為唯一正式範本
- `config.example.sh` 僅作為遷移過渡用途，後續應標示 deprecated，最終移除

### 2. 設定優先順序

除非個別欄位另有說明，統一採以下優先順序：

1. **CLI 參數**
2. **`.env`**
3. **現有系統設定**（只用於保留既有狀態，不作為主要輸入來源）
4. **程式內預設值**

### 3. 系統設定保留原則

- `.env` 是主要輸入來源，但**不是所有系統檔都可直接整份覆蓋**
- 對於高風險系統檔（例如 Docker 的 `/etc/docker/daemon.json`）：
  - 優先套用 `.env` 有明確宣告的欄位
  - 保留未由 `.env` 管理、且原本已存在的其他欄位
  - 不做無條件整份覆蓋

## 類型化規則

### A. 啟動參數類

適用欄位：

- `UBUNTU_VERSION`
- `WSL_USERNAME`
- `WSL_PASSWORD`
- `SKIP_VERIFY`
- `PROXY_URL`

規則：

- CLI 參數優先於 `.env`
- `.env` 優先於預設值
- 不需要回讀系統現況

### B. 安裝行為類

適用欄位：

- `UPGRADE_PACKAGES`
- `OFFLINE_MODE`
- `OFFLINE_DIR`
- `ACCEPT_EULA`
- `DEBUG`

規則：

- 由 `.env` 提供主要值
- 缺值時用腳本預設值
- 不需從現有系統狀態回填

### C. 工具版本類

適用欄位：

- `DOTNET_VERSIONS`
- `DOTNET_INSTALL_DIR`
- `NVM_VERSION`
- `PYTHON_VERSION`
- `GO_FALLBACK_VERSION`

規則：

- 以 `.env` 為主
- 缺值時使用現有腳本預設邏輯
- 不從已安裝版本反推 `.env`

### D. 系統設定類

適用欄位：

- `TIMEZONE`
- `LOCALE`
- `ADDITIONAL_LOCALES`
- `GIT_USER_NAME`
- `GIT_USER_EMAIL`

規則：

- 以 `.env` 為主
- 缺值時使用腳本預設值
- 不主動讀取現有系統設定回填，避免行為不透明

### E. Docker 設定類

適用欄位：

- `DOCKER_WINDOWS_HOST`
- `DOCKER_TCP_PORT`
- `DOCKER_REGISTRY_MIRRORS`
- `PROXY_URL`
- `NO_PROXY`

規則：

- `.env` 是主要來源
- 但套用到 `/etc/docker/daemon.json` 時，需採 **欄位級 merge**
- 若 `.env` 未指定 `DOCKER_TCP_PORT`：
  - 可保留既有 `daemon.json` 中已設定的 TCP port
  - 若系統也沒有，才落回自動偵測 / 預設值

## `config.example.sh` -> `.env.example` 欄位對照

| `config.example.sh` | `.env.example` | 遷移策略 |
|---|---|---|
| `UPGRADE_PACKAGES` | `UPGRADE_PACKAGES` | 直接對應 |
| `TIMEZONE` | `TIMEZONE` | 直接對應 |
| `LOCALE` | `LOCALE` | 直接對應 |
| `ADDITIONAL_LOCALES` | `ADDITIONAL_LOCALES` | 直接對應 |
| `GIT_USER_NAME` | `GIT_USER_NAME` | 直接對應 |
| `GIT_USER_EMAIL` | `GIT_USER_EMAIL` | 直接對應 |
| `PROXY_URL` | `PROXY_URL` | 直接對應 |
| `NO_PROXY` | `NO_PROXY` | 直接對應 |
| `DOCKER_REGISTRY_MIRRORS` | `DOCKER_REGISTRY_MIRRORS` | 直接對應 |
| `OFFLINE_MODE` | `OFFLINE_MODE` | 直接對應 |
| `OFFLINE_DIR` | `OFFLINE_DIR` | 直接對應 |
| `DOTNET_VERSIONS` | `DOTNET_VERSIONS` | 直接對應 |
| `NVM_VERSION` | `NVM_VERSION` | 直接對應 |
| `PYTHON_VERSION` | `PYTHON_VERSION` | 直接對應 |
| `GO_VERSION` | `GO_FALLBACK_VERSION` | 命名需統一，後續決定是否改腳本支援同名 |
| `ACCEPT_EULA` | `ACCEPT_EULA` | 直接對應 |
| `SKIP_VERIFY` | 無 | 可考慮補入 `.env.example`，或維持僅 CLI 參數 |
| `DEBUG` | `DEBUG` | 直接對應 |

## `.env.example` 應保留的專案主欄位

除了上表欄位，`.env.example` 應繼續保留目前已經由 PowerShell 流程使用的欄位：

- `UBUNTU_VERSION`
- `WSL_USERNAME`
- `WSL_PASSWORD`
- `DOCKER_WINDOWS_HOST`
- `DOCKER_TCP_PORT`
- `DOTNET_INSTALL_DIR`

## Docker 組態策略

### 建議管理欄位

未來由腳本明確管理的 `daemon.json` 欄位：

- `hosts`
- `registry-mirrors`
- `proxies`
- `log-driver`
- `log-opts`
- `storage-driver`

### 建議行為

1. 若 `/etc/docker/daemon.json` 不存在，建立新檔
2. 若存在：
   - 先讀取現有 JSON
   - 只更新受管理欄位
   - 保留其他未知欄位
3. 寫入前先備份
4. 寫入後驗證 JSON 格式

### 不建議行為

- 直接用 here-doc 重寫整份 `daemon.json`
- `.env` 缺值時把現有欄位清空
- 因為 Bash 腳本改以 `.env` 為主，就忽略系統既有設定

## 步驟 3 實作指引

下一步調整 `install-linux-tools.sh` 時，應採以下方向：

1. 新增 `.env` 載入流程
2. 保留 CLI 參數優先權
3. 將 `config.sh` 降級為過渡相容層或直接淘汰
4. 更新 help 與 README 說明
