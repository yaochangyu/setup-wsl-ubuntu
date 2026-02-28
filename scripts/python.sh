#!/bin/bash

###############################################################################
# Python 與 pyenv 安裝模組
###############################################################################

###############################################################################
# 環境變數（未設定時使用預設值；可由外部環境或 config.sh 覆蓋）
###############################################################################
: "${PYTHON_VERSION:=3.12}"   # pyenv 安裝的 Python 版本
# 由執行環境提供（唯讀）：
# SUDO_USER - 實際非 root 使用者（由 install-linux-tools.ps1 export 設定）

install_python() {
    print_header "安裝 Python 與 pyenv"

    info "安裝 Python 建置依賴..."

    local python_deps=(
        "make" "build-essential" "libssl-dev" "zlib1g-dev"
        "libbz2-dev" "libreadline-dev" "libsqlite3-dev" "wget"
        "curl" "llvm" "libncursesw5-dev" "xz-utils" "tk-dev"
        "libxml2-dev" "libxmlsec1-dev" "libffi-dev" "liblzma-dev"
    )

    apt-get install -y "${python_deps[@]}" >> "${LOG_FILE}" 2>&1

    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    if [[ "${actual_user}" == "root" ]]; then
        warning "不建議以 root 使用者安裝 pyenv"
        return 1
    fi

    info "安裝 pyenv..."
    if [[ -d "${user_home}/.pyenv" ]]; then
        info "pyenv 已存在，跳過安裝"
    else
        sudo -u "${actual_user}" bash -c 'curl https://pyenv.run | bash' >> "${LOG_FILE}" 2>&1

        if [[ ! -d "${user_home}/.pyenv" ]]; then
            error "pyenv 安裝失敗"
            return 1
        fi
    fi

    success "pyenv 已安裝"

    # 設定 pyenv 環境變數
    local shell_rc="${user_home}/.bashrc"

    if ! grep -q 'PYENV_ROOT' "${shell_rc}"; then
        info "設定 pyenv 環境變數..."
        sudo -u "${actual_user}" tee -a "${shell_rc}" > /dev/null <<'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF
        success "環境變數已設定"
    fi

    # 安裝指定 Python 版本
    info "安裝 Python ${PYTHON_VERSION}..."
    sudo -u "${actual_user}" bash -c "export PYENV_ROOT='${user_home}/.pyenv' && export PATH='\$PYENV_ROOT/bin:\$PATH' && eval '\$(pyenv init -)' && pyenv install ${PYTHON_VERSION} -s" >> "${LOG_FILE}" 2>&1 || warning "Python ${PYTHON_VERSION} 安裝失敗"

    sudo -u "${actual_user}" bash -c "export PYENV_ROOT='${user_home}/.pyenv' && export PATH='\$PYENV_ROOT/bin:\$PATH' && eval '\$(pyenv init -)' && pyenv global ${PYTHON_VERSION}" >> "${LOG_FILE}" 2>&1 || warning "Python 設定失敗"

    success "Python 與 pyenv 安裝完成"
    INSTALL_STATUS["python"]="success"
}

export -f install_python
