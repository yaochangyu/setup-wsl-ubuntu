#!/bin/bash

###############################################################################
# Node.js 與 nvm 安裝模組
###############################################################################

###############################################################################
# 環境變數（未設定時使用預設值；可由外部環境或 config.sh 覆蓋）
###############################################################################
: "${NVM_VERSION:=v0.39.7}"   # nvm 版本
# 由執行環境提供（唯讀）：
# SUDO_USER - 實際非 root 使用者（由 install-linux-tools.ps1 export 設定）

install_nodejs() {
    print_header "安裝 Node.js 與 nvm"

    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    if [[ "${actual_user}" == "root" ]]; then
        warning "不建議以 root 使用者安裝 nvm"
        return 1
    fi

    info "下載並安裝 nvm..."

    # 安裝 nvm
    sudo -u "${actual_user}" bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash" >> "${LOG_FILE}" 2>&1

    if [[ ! -d "${user_home}/.nvm" ]]; then
        error "nvm 安裝失敗"
        return 1
    fi

    success "nvm 已安裝"

    # 載入 nvm
    export NVM_DIR="${user_home}/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    info "安裝 Node.js LTS 版本..."
    sudo -u "${actual_user}" bash -c "source ${user_home}/.nvm/nvm.sh && nvm install --lts" >> "${LOG_FILE}" 2>&1
    sudo -u "${actual_user}" bash -c "source ${user_home}/.nvm/nvm.sh && nvm use --lts" >> "${LOG_FILE}" 2>&1

    # 安裝常用全域套件
    info "安裝常用 npm 全域套件..."
    sudo -u "${actual_user}" bash -c "source ${user_home}/.nvm/nvm.sh && npm install -g yarn pnpm" >> "${LOG_FILE}" 2>&1 || warning "全域套件安裝失敗"

    success "Node.js 與 nvm 安裝完成"
    INSTALL_STATUS["nodejs"]="success"

    info "Node.js 版本："
    sudo -u "${actual_user}" bash -c "source ${user_home}/.nvm/nvm.sh && node --version" 2>/dev/null | tee -a "${LOG_FILE}" || echo "  請重新登入後使用"
}

export -f install_nodejs
