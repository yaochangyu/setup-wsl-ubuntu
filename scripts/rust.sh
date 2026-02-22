#!/bin/bash

###############################################################################
# Rust 安裝模組
###############################################################################

install_rust() {
    print_header "安裝 Rust"

    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    if [[ "${actual_user}" == "root" ]]; then
        warning "不建議以 root 使用者安裝 Rust"
        return 1
    fi

    info "安裝 Rust..."

    # 使用 rustup 安裝
    sudo -u "${actual_user}" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' >> "${LOG_FILE}" 2>&1

    if [[ ! -d "${user_home}/.cargo" ]]; then
        error "Rust 安裝失敗"
        return 1
    fi

    success "Rust 已安裝"

    # 驗證安裝
    if sudo -u "${actual_user}" bash -c "source ${user_home}/.cargo/env && rustc --version" >> "${LOG_FILE}" 2>&1; then
        local rust_version=$(sudo -u "${actual_user}" bash -c "source ${user_home}/.cargo/env && rustc --version")
        success "Rust 版本: ${rust_version}"
    fi

    success "Rust 安裝完成"
    INSTALL_STATUS["rust"]="success"
}

export -f install_rust
