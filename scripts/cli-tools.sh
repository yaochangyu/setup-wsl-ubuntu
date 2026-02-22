#!/bin/bash

###############################################################################
# 常用 CLI 工具安裝模組
###############################################################################

install_cli_tools() {
    print_header "安裝常用 CLI 工具"

    # jq - JSON 處理
    info "安裝 jq..."
    apt-get install -y jq >> "${LOG_FILE}" 2>&1

    # yq - YAML 處理
    info "安裝 yq..."
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq

    # bat - 更好的 cat
    info "安裝 bat..."
    apt-get install -y bat >> "${LOG_FILE}" 2>&1
    if [[ -f /usr/bin/batcat ]] && [[ ! -f /usr/local/bin/bat ]]; then
        ln -s /usr/bin/batcat /usr/local/bin/bat
    fi

    # ripgrep - 更快的 grep
    info "安裝 ripgrep..."
    apt-get install -y ripgrep >> "${LOG_FILE}" 2>&1

    # fzf - 模糊搜尋
    info "安裝 fzf..."
    apt-get install -y fzf >> "${LOG_FILE}" 2>&1

    # htop - 系統監控
    info "安裝 htop..."
    apt-get install -y htop >> "${LOG_FILE}" 2>&1

    # tmux - 終端多工
    info "安裝 tmux..."
    apt-get install -y tmux >> "${LOG_FILE}" 2>&1

    # tree - 目錄樹
    info "安裝 tree..."
    apt-get install -y tree >> "${LOG_FILE}" 2>&1

    # zsh 和 oh-my-zsh
    info "安裝 zsh..."
    apt-get install -y zsh >> "${LOG_FILE}" 2>&1

    local actual_user="${SUDO_USER:-$USER}"
    if [[ "${actual_user}" != "root" ]]; then
        info "安裝 oh-my-zsh..."
        sudo -u "${actual_user}" bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' >> "${LOG_FILE}" 2>&1 || warning "oh-my-zsh 安裝失敗"
    fi

    # 驗證安裝
    local tools=("jq" "yq" "bat" "rg" "fzf" "htop" "tmux" "tree" "zsh")
    info "已安裝的工具："
    for tool in "${tools[@]}"; do
        if command -v "${tool}" &> /dev/null; then
            echo "  ✓ ${tool}" | tee -a "${LOG_FILE}"
        else
            echo "  ✗ ${tool}" | tee -a "${LOG_FILE}"
        fi
    done

    success "常用 CLI 工具安裝完成"
    INSTALL_STATUS["cli_tools"]="success"
}

export -f install_cli_tools
