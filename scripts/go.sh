#!/bin/bash

###############################################################################
# Go 安裝模組
###############################################################################

###############################################################################
# 環境變數
###############################################################################
# 由執行環境提供（唯讀）：
# SUDO_USER - 實際非 root 使用者（由 install-linux-tools.ps1 export 設定）

install_go() {
    print_header "安裝 Go"

    # 從官方 API 取得最新穩定版本號（例如: 1.24.1）
    info "取得 Go 最新穩定版本..."
    local go_version
    go_version=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1 | sed 's/^go//')
    if [[ -z "${go_version}" ]]; then
        warning "無法取得最新版本，使用後備版本 1.24.1"
        go_version="1.24.1"
    fi
    info "目標版本: Go ${go_version}"

    local go_url="https://go.dev/dl/go${go_version}.linux-amd64.tar.gz"
    local go_tar="/tmp/go${go_version}.linux-amd64.tar.gz"

    info "下載 Go ${go_version}..."

    if wget -q "${go_url}" -O "${go_tar}"; then
        success "Go 下載完成"
    else
        error "Go 下載失敗"
        return 1
    fi

    # 移除舊版本
    if [[ -d /usr/local/go ]]; then
        info "移除舊版本 Go..."
        rm -rf /usr/local/go
    fi

    # 解壓縮
    info "安裝 Go..."
    tar -C /usr/local -xzf "${go_tar}"
    rm -f "${go_tar}"

    # 設定環境變數
    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})
    local profile="${user_home}/.profile"

    if [[ "${actual_user}" != "root" ]]; then
        if ! grep -q '/usr/local/go/bin' "${profile}" 2>/dev/null; then
            info "設定 Go 環境變數..."
            sudo -u "${actual_user}" tee -a "${profile}" > /dev/null <<'EOF'

# Go configuration
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF
            success "環境變數已設定"
        fi
    fi

    # 驗證安裝
    if /usr/local/go/bin/go version &> /dev/null; then
        success "Go 已安裝: $(/usr/local/go/bin/go version)"
    else
        error "Go 安裝驗證失敗"
        return 1
    fi

    success "Go 安裝完成"
    INSTALL_STATUS["go"]="success"
}

export -f install_go
