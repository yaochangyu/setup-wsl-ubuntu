#!/bin/bash

###############################################################################
# VS Code Server 安裝模組
###############################################################################

install_vscode_server() {
    print_header "設定 VS Code Remote 支援"

    info "VS Code Server 會在首次透過 Remote-SSH 連接時自動安裝"

    # 安裝必要的依賴
    info "安裝 VS Code Server 依賴..."
    apt-get install -y wget ca-certificates >> "${LOG_FILE}" 2>&1

    success "VS Code Remote 環境準備完成"
    INSTALL_STATUS["vscode"]="success"

    info "使用方式："
    echo "  1. 在 Windows 上安裝 VS Code" | tee -a "${LOG_FILE}"
    echo "  2. 安裝 Remote - WSL 擴充套件" | tee -a "${LOG_FILE}"
    echo "  3. 在 WSL 中執行: code ." | tee -a "${LOG_FILE}"
}

export -f install_vscode_server
