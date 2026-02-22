#!/bin/bash

###############################################################################
# 離線安裝包準備腳本
#
# 功能：下載所有必要的安裝包以供離線環境使用
#
###############################################################################

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OFFLINE_DIR="${SCRIPT_DIR}/offline-packages"
readonly LOG_FILE="${SCRIPT_DIR}/logs/prepare-offline-$(date +%Y%m%d-%H%M%S).log"

# 建立目錄
mkdir -p "${OFFLINE_DIR}"
mkdir -p "$(dirname "${LOG_FILE}")"

echo "========================================
echo "準備離線安裝包"
echo "========================================"
echo ""
echo "目標目錄: ${OFFLINE_DIR}"
echo "日誌檔案: ${LOG_FILE}"
echo ""

# 檢查 root 權限
if [[ $EUID -ne 0 ]]; then
    echo "此腳本需要 root 權限"
    echo "請使用: sudo $0"
    exit 1
fi

# 下載 Docker GPG 金鑰
echo "下載 Docker GPG 金鑰..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o "${OFFLINE_DIR}/docker.gpg"

# 下載 APT 套件
echo "下載 APT 套件..."
cd "${OFFLINE_DIR}"

apt-get update >> "${LOG_FILE}" 2>&1

# 建立套件列表
packages=(
    "docker-ce"
    "docker-ce-cli"
    "containerd.io"
    "docker-buildx-plugin"
    "docker-compose-plugin"
    "postgresql-client"
    "jq"
    "bat"
    "ripgrep"
    "fzf"
    "htop"
    "tmux"
    "tree"
    "zsh"
)

for package in "${packages[@]}"; do
    echo "下載 ${package}..."
    apt-get download "${package}" >> "${LOG_FILE}" 2>&1 || echo "  警告: ${package} 下載失敗"
done

# 建立校驗碼
echo ""
echo "建立校驗碼..."
sha256sum *.deb > checksums.txt 2>/dev/null || true
sha256sum *.gpg >> checksums.txt 2>/dev/null || true

# 顯示摘要
echo ""
echo "========================================"
echo "離線安裝包準備完成"
echo "========================================"
echo ""
echo "檔案數量: $(ls -1 "${OFFLINE_DIR}" | wc -l)"
echo "總大小: $(du -sh "${OFFLINE_DIR}" | cut -f1)"
echo ""
echo "請將 offline-packages/ 目錄複製到離線環境"
echo ""
