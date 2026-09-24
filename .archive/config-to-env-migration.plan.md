# config-to-env-migration Plan

## 目標

將專案中的設定來源統一收斂到 `.env` / `.env.example`，逐步淘汰 `config.sh` / `config.example.sh`，並確保 PowerShell 與 Bash 腳本在設定行為、文件說明與 Docker 組態流程上保持一致。

## 實作步驟

- [x] **步驟 1：盤點所有 `config.sh`、`.env` 與 Docker 組態的使用點**
  - 目的：先建立完整遷移範圍，避免只改到入口腳本，卻漏掉模組腳本、README 或驗證流程。
  - 原因：目前 PowerShell 與 Bash 的設定來源並不一致，若未先盤點，容易造成遷移後行為分裂。
  - 盤點範圍：
    - `install-linux-tools.sh`
    - `install-linux-tools.ps1`
    - `setup-ubuntu.ps1`
    - `scripts/*.sh`
    - `README.md`
    - `verify.sh`

  - 盤點結果：
    - 詳見 `config-to-env-inventory.md`
    - 結論：PowerShell 已採 `.env`，Bash 仍依賴 `config.sh`，Docker `daemon.json` 覆蓋策略需獨立處理

- [x] **步驟 2：設計統一的設定優先順序與欄位對照表**
  - 目的：定義未來唯一設定來源、欄位命名、預設值，以及參數覆蓋規則。
  - 原因：遷移不只是搬檔案，還要先明確規範「CLI 參數、`.env`、既有系統設定、預設值」之間的優先順序，才能避免腳本各自解讀。
  - 產出內容：
    - `.env` 欄位清單
    - `config.example.sh` 對應到 `.env.example` 的映射表
    - Docker 相關設定的保留、詢問與覆蓋策略

  - 設計結果：
    - 詳見 `config-to-env-strategy.md`
    - 原則：使用者可編輯設定統一以 `.env` 為主；高風險系統檔採欄位級 merge，不做整份覆蓋

- [x] **步驟 3：調整 Bash 安裝流程，讓 `install-linux-tools.sh` 以 `.env` 為主**
  - 目的：讓 Bash 路徑與 PowerShell 路徑一致，正式以 `.env` 作為主要設定輸入來源。
  - 原因：目前 Bash 仍預設使用 `config.sh`，這是造成雙軌維護的核心來源，必須先修正入口腳本。
  - 修改範圍：
    - `install-linux-tools.sh`
    - 必要時補充共用的 `.env` 載入函式

  - 完成內容：
    - `install-linux-tools.sh` 已改為優先載入 `.env`
    - CLI 參數維持高於 `.env`
    - `config.sh` 改為過渡相容 fallback，並顯示 deprecated 警告

  - 驗證結果：
    - 已在 Ubuntu 24.04 Docker 容器中建立測試環境
    - 以 `.env` + `--skip-verify` 執行 `install-linux-tools.sh`，安裝流程可完成

  - 失敗方法紀錄：
    - 方法：直接以 root 使用者在 Docker 容器內執行安裝腳本
    - 問題：`scripts/common.sh` 中多處依賴 `SUDO_USER`，造成 `sudo -u` 使用方式錯誤而中斷
    - 調整：改為先建立測試使用者並設定 `SUDO_USER` 後再驗證，模擬實際 WSL 執行情境

- [x] **步驟 4：調整 Docker 設定套用策略，避免粗暴覆蓋 `daemon.json`**
  - 目的：在統一設定來源的同時，保護使用者既有 Docker Engine 設定。
  - 原因：Docker 組態屬於高風險設定，若遷移時直接以 `.env` 覆蓋整份 `daemon.json`，可能破壞既有 port、mirror、proxy 或其他 daemon 設定。
  - 完成內容：
    - 在 `scripts/docker.sh` 實作 Python 欄位級 merge 函式，保護未受管理之使用者自訂欄位
    - 受管理欄位包含 `log-driver`, `log-opts`, `storage-driver`, `hosts`, `registry-mirrors`, `proxies`
    - 若配置無變更則不重複寫入，若有變更則先備份既有檔案
  - 驗證重點：
    - 既有 `daemon.json` 欄位保留（已驗證自訂欄位保留）
    - WSL / Windows Docker host 行為一致
    - 冪等性測試通過

- [x] **步驟 5：更新文件與範本，標示 `config.example.sh` 為淘汰或移除**
  - 目的：讓使用者文件、設定範本與實際腳本行為一致。
  - 原因：若程式已改用 `.env`，但 README 或範本仍保留 `config.example.sh` 主流程，會讓新使用者誤用舊方式。
  - 完成內容：
    - `README.md`：更新環境設定檔章節，明確說明 `.env` 為唯一設定來源，標示 `config.example.sh` 為已淘汰過渡參考
    - `.env.example`：補充 `GO_VERSION` 與 `SKIP_VERIFY` 等完整設定欄位
    - `config.example.sh`：檔案頭部加入 `[DEPRECATED / 已淘汰]` 警示與 `.env.example` 引導說明

- [x] **步驟 6：執行安裝與驗證測試，確認遷移後行為正確**
  - 目的：確認遷移後不只語法正確，實際安裝流程也能正常運作。
  - 原因：設定來源調整會影響 Ubuntu 安裝、工具安裝、Docker 配置與驗證流程，必須至少做一次完整驗證。
  - 驗證結果：
    - 執行 `./verify.sh`：49 項工具檢查全部通過（0 項失敗）
    - 各工具版本與整合設定皆正確運作

- [x] **步驟 7：完成收尾並封存計畫檔**
  - 目的：在全部步驟完成後保留遷移紀錄，並依專案規範封存計畫。
  - 完成內容：
    - 遷移計畫各階段均已落實並驗證通過
    - 計畫檔移至 `.archive/config-to-env-migration.plan.md`
