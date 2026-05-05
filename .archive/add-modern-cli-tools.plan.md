# 新增現代 CLI 工具安裝計畫

## 背景

將以下現代 CLI 工具整合到現有的 `install-linux-tools.sh` 安裝腳本：

| 工具 | 用途 | 備註 |
|------|------|------|
| [Eza](https://github.com/eza-community/eza) | ls 替代品 | 支援 icon、git 狀態 |
| Bat | cat 替代品 | **已安裝**（`batcat` via apt + symlink） |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | cd 替代品 | 智慧目錄跳轉 |
| [TLDR (tlrc)](https://github.com/tldr-pages/tlrc) | man 替代品 | Rust 客戶端 |
| [Glow](https://github.com/charmbracelet/glow) | Markdown 閱讀器 | Charmbracelet 出品 |
| [LazyGit](https://github.com/jesseduffield/lazygit) | Git TUI | 終端 Git 介面 |
| [Yazi](https://github.com/sxyazi/yazi) | 檔案瀏覽器 | 終端檔案管理 |
| [Chafa](https://github.com/hpjansson/chafa) | 終端圖片瀏覽 | 支援多種圖片格式 |

> **Bat 說明**：已在 `setup_base_tools()` 透過 apt 安裝 `bat`（Ubuntu 套件名 `batcat`），並由 `setup_bat_symlink()` 建立 `/usr/local/bin/bat` 符號連結，無需重複處理。

---

## 安裝策略

| 工具 | 安裝方式 | 原因 |
|------|----------|------|
| Eza | GitHub Releases 二進位 | apt 版本較舊 |
| Zoxide | 官方安裝腳本 | 跨平台最簡便 |
| TLDR (tlrc) | GitHub Releases 二進位 | Rust 客戶端最新版 |
| Glow | GitHub Releases 二進位 | 官方提供 Linux amd64/arm64 |
| LazyGit | GitHub Releases 二進位 | 官方提供 Linux 版本 |
| Yazi | GitHub Releases 二進位 | 官方提供 Linux amd64/arm64 |
| Chafa | apt | Ubuntu 官方套件庫即可 |

---

## 實作步驟

- [x] **步驟 1：新增 `install_eza()` 函式到 `scripts/common.sh`**
  - 從 GitHub Releases 下載對應架構（amd64/arm64）的最新版二進位
  - 安裝至 `/usr/local/bin/eza`
  - 加入跳過檢查（已安裝則略過）

- [x] **步驟 2：新增 `install_zoxide()` 函式到 `scripts/common.sh`**
  - 使用官方 install.sh 安裝至使用者目錄
  - 在 `setup_bash_env()` 之後於 `~/.bashrc` 加入 `eval "$(zoxide init bash)"`（避免重複寫入）

- [x] **步驟 3：新增 `install_tldr()` 函式到 `scripts/common.sh`**
  - 從 GitHub Releases 下載 `tlrc` 二進位（套件名 `tldr`）
  - 安裝至 `/usr/local/bin/tldr`

- [x] **步驟 4：新增 `install_glow()` 函式到 `scripts/common.sh`**
  - 從 GitHub Releases 下載對應架構的 `.tar.gz`
  - 安裝至 `/usr/local/bin/glow`

- [x] **步驟 5：新增 `install_lazygit()` 函式到 `scripts/common.sh`**
  - 從 GitHub Releases 下載對應架構的 `.tar.gz`
  - 安裝至 `/usr/local/bin/lazygit`

- [x] **步驟 6：新增 `install_yazi()` 函式到 `scripts/common.sh`**
  - 從 GitHub Releases 下載對應架構的 `.zip`
  - 安裝 `yazi`、`ya` 至 `/usr/local/bin/`

- [x] **步驟 7：新增 `install_chafa()` 函式到 `scripts/common.sh`**
  - 透過 apt 安裝 `chafa`

- [x] **步驟 8：新增 `setup_modern_cli_aliases()` 函式到 `scripts/common.sh`**
  - 在使用者 `~/.bashrc` 寫入替代指令的 alias（避免重複寫入）
  - 涵蓋以下替代關係：

  | alias | 替代 | 工具 |
  |-------|------|------|
  | `ls` → `eza` | `ls` | Eza |
  | `ll` → `eza -l --icons` | — | Eza 長格式 |
  | `la` → `eza -la --icons` | — | Eza 含隱藏檔 |
  | `lt` → `eza --tree --icons` | — | Eza 樹狀 |
  | `cat` → `bat` | `cat` | Bat |
  | `cd` → `z` | `cd` | Zoxide（`z` 指令） |
  | `man` → `tldr` | `man` | TLDR |

  > **注意**：`cd` 本身不覆蓋，改用 `z` 指令（zoxide 慣例）；`man` alias 僅作為快捷，原 `man` 仍保留。

- [x] **步驟 9：整合到 `install_cli_tools()` 函式**
  - 在 `scripts/common.sh` 的 `install_cli_tools()` 中呼叫上述所有新函式
  - 最後呼叫 `setup_modern_cli_aliases()`（確保工具已安裝後才設定 alias）
  - 更新驗證清單，加入新工具的 `✓/✗` 檢查

- [x] **步驟 10：更新 `verify.sh` 的 `check_cli_tools()` 函式**
  - 加入 eza、zoxide、tldr、glow、lazygit、yazi、chafa 的驗證項目
  - 每項設定對應的 `fixable` 函式名稱

- [x] **步驟 11：更新 `tree.md`（若有新增檔案）**
  - 本次僅修改既有檔案（`scripts/common.sh`、`verify.sh`），無新增檔案

---

## 影響範圍

- `scripts/common.sh`：新增 8 個函式（7 安裝 + 1 alias 設定），更新 `install_cli_tools()`
- `verify.sh`：更新 `check_cli_tools()`，加入 7 項驗證
- `~/.bashrc`（執行時）：寫入 alias 與 shell integration（zoxide、fzf 已有）
