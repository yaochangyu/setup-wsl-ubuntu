#!/bin/bash

###############################################################################
# 卸載腳本
#
# 警告：此腳本會移除所有已安裝的開發工具
#
###############################################################################

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/uninstall-$(date +%Y%m%d-%H%M%S).log"

# 顏色定義
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RESET='\033[0m'

# 初始化日誌
mkdir -p "${LOG_DIR}"

# 警告訊息
echo -e "${COLOR_RED}========================================${COLOR_RESET}"
echo -e "${COLOR_RED}警告：卸載開發工具${COLOR_RESET}"
echo -e "${COLOR_RED}========================================${COLOR_RESET}"
echo ""
echo "此操作將移除以下工具："
echo "  - Docker Engine"
echo "  - .NET SDK"
echo "  - Node.js (nvm)"
echo "  - Python (pyenv)"
echo "  - Go"
echo "  - Rust"
echo "  - DevOps 工具 (kubectl, helm, terraform, az)"
echo "  - CLI 工具"
echo ""
echo -e "${COLOR_YELLOW}此操作無法復原！${COLOR_RESET}"
echo ""

read -p "確定要繼續嗎？ (輸入 YES 繼續): " confirm

if [[ "${confirm}" != "YES" ]]; then
    echo "已取消卸載"
    exit 0
fi

echo ""
echo "開始卸載..."
echo ""

# 檢查 root 權限
if [[ $EUID -ne 0 ]]; then
    echo "此腳本需要 root 權限"
    echo "請使用: sudo $0"
    exit 1
fi

# 移除 Docker
echo "移除 Docker..."
apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "${LOG_FILE}" 2>&1 || true
apt-get purge -y docker-ce docker-ce-cli containerd.io >> "${LOG_FILE}" 2>&1 || true
rm -rf /var/lib/docker
rm -rf /etc/docker
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg

# 移除 .NET
echo "移除 .NET SDK..."
apt-get remove -y 'dotnet-*' >> "${LOG_FILE}" 2>&1 || true
apt-get remove -y 'aspnetcore-*' >> "${LOG_FILE}" 2>&1 || true
rm -f /etc/apt/sources.list.d/microsoft-prod.list

# 移除 nvm 和 Node.js
echo "移除 Node.js 和 nvm..."
local actual_user="${SUDO_USER:-$USER}"
if [[ "${actual_user}" != "root" ]]; then
    local user_home=$(eval echo ~${actual_user})
    rm -rf "${user_home}/.nvm"
    sed -i '/NVM_DIR/d' "${user_home}/.bashrc" 2>/dev/null || true
fi

# 移除 pyenv 和 Python
echo "移除 Python 和 pyenv..."
if [[ "${actual_user}" != "root" ]]; then
    rm -rf "${user_home}/.pyenv"
    sed -i '/PYENV_ROOT/d' "${user_home}/.bashrc" 2>/dev/null || true
fi

# 移除 Go
echo "移除 Go..."
rm -rf /usr/local/go

# 移除 Rust
echo "移除 Rust..."
if [[ "${actual_user}" != "root" ]]; then
    rm -rf "${user_home}/.cargo"
    rm -rf "${user_home}/.rustup"
fi

# 移除 DevOps 工具
echo "移除 DevOps 工具..."
rm -f /usr/local/bin/kubectl
rm -f /usr/local/bin/helm
apt-get remove -y terraform >> "${LOG_FILE}" 2>&1 || true
apt-get remove -y azure-cli >> "${LOG_FILE}" 2>&1 || true

# 移除 CLI 工具
echo "移除 CLI 工具..."
apt-get remove -y jq bat ripgrep fzf htop tmux tree zsh >> "${LOG_FILE}" 2>&1 || true
rm -f /usr/local/bin/yq
rm -f /usr/local/bin/bat

# 移除資料庫工具
echo "移除資料庫工具..."
apt-get remove -y postgresql-client mssql-tools unixodbc-dev >> "${LOG_FILE}" 2>&1 || true

# 清理
echo "清理系統..."
apt-get autoremove -y >> "${LOG_FILE}" 2>&1
apt-get autoclean >> "${LOG_FILE}" 2>&1

echo ""
echo "========================================
echo "卸載完成"
echo "========================================"
echo ""
echo "日誌檔案: ${LOG_FILE}"
echo ""
