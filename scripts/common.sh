#!/bin/bash

###############################################################################
# 基礎設定模組
#
# 功能：
#   - 系統套件更新
#   - APT 代理設定
#   - 基礎工具安裝
#   - 時區與語系設定
#   - 系統優化設定
#
###############################################################################

# 更新系統套件
setup_system_update() {
    info "更新系統套件..."

    # 備份現有的 sources.list
    if [[ -f /etc/apt/sources.list ]]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.backup-$(date +%Y%m%d-%H%M%S)
        debug "已備份 sources.list"
    fi

    # 更新套件列表
    info "執行 apt-get update..."
    if apt-get update >> "${LOG_FILE}" 2>&1; then
        success "套件列表更新成功"
    else
        warning "套件列表更新失敗，嘗試修復..."
        apt-get update --fix-missing >> "${LOG_FILE}" 2>&1 || true
    fi

    # 升級已安裝的套件（可選）
    if [[ "${UPGRADE_PACKAGES:-false}" == "true" ]]; then
        info "升級已安裝的套件..."
        apt-get upgrade -y >> "${LOG_FILE}" 2>&1
        success "套件升級完成"
    fi
}

# 設定 APT 代理
setup_apt_proxy() {
    if [[ -z "${PROXY_URL}" ]]; then
        debug "未設定代理，跳過 APT 代理設定"
        return 0
    fi

    info "設定 APT 代理..."

    local apt_conf_dir="/etc/apt/apt.conf.d"
    local proxy_conf="${apt_conf_dir}/95proxy"

    # 確保目錄存在
    if [[ ! -d "${apt_conf_dir}" ]]; then
        mkdir -p "${apt_conf_dir}"
    fi

    # 寫入代理設定
    cat > "${proxy_conf}" <<EOF
# APT 代理設定
# 由 install-linux-tools.sh 自動生成於 $(date)

Acquire::http::Proxy "${PROXY_URL}";
Acquire::https::Proxy "${PROXY_URL}";

# 超時設定
Acquire::http::Timeout "300";
Acquire::https::Timeout "300";
Acquire::ftp::Timeout "300";

# 重試設定
Acquire::Retries "3";
EOF

    success "APT 代理設定完成: ${PROXY_URL}"
    debug "代理設定檔: ${proxy_conf}"
}

# 安裝基礎工具
setup_base_tools() {
    info "安裝基礎開發工具..."

    # 定義基礎套件清單
    local base_packages=(
        # 編譯工具
        "build-essential"
        "gcc"
        "g++"
        "make"
        "cmake"

        # 網路工具
        "curl"
        "wget"
        "net-tools"
        "iputils-ping"
        "dnsutils"

        # 版本控制
        "git"
        "git-lfs"

        # 編輯器
        "vim"
        "nano"

        # 壓縮工具
        "unzip"
        "zip"
        "tar"
        "gzip"
        "bzip2"
        "xz-utils"

        # SSL/TLS
        "ca-certificates"
        "gnupg"
        "gnupg2"

        # 系統工具
        "lsb-release"
        "software-properties-common"
        "apt-transport-https"
        "sudo"

        # 開發依賴
        "pkg-config"
        "autoconf"
        "automake"
        "libtool"

        # 其他工具
        "tree"
        "less"
        "man-db"
        "bash-completion"
    )

    info "準備安裝 ${#base_packages[@]} 個基礎套件..."

    # 安裝套件
    for package in "${base_packages[@]}"; do
        debug "安裝 ${package}..."
    done

    if apt-get install -y "${base_packages[@]}" >> "${LOG_FILE}" 2>&1; then
        success "基礎工具安裝完成"
    else
        warning "部分基礎工具安裝失敗，請檢查日誌"
    fi

    # 驗證重要工具
    local critical_tools=("git" "curl" "wget" "vim" "gcc" "make")
    local failed=0

    for tool in "${critical_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            error "${tool} 未正確安裝"
            ((failed++)) || true
        fi
    done

    if [[ $failed -eq 0 ]]; then
        success "所有關鍵工具驗證通過"
    else
        error "有 ${failed} 個關鍵工具安裝失敗"
        return 1
    fi
}

# 設定時區
setup_timezone() {
    local timezone="${TIMEZONE:-Asia/Taipei}"

    info "設定時區為: ${timezone}"

    # 檢查時區是否有效
    if [[ ! -f "/usr/share/zoneinfo/${timezone}" ]]; then
        warning "時區 ${timezone} 不存在，使用預設時區"
        return 1
    fi

    # 設定時區
    if timedatectl set-timezone "${timezone}" 2>> "${LOG_FILE}"; then
        success "時區設定完成: ${timezone}"
    else
        # WSL 環境可能不支援 timedatectl，使用替代方案
        warning "timedatectl 不可用，使用替代方案..."

        ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
        echo "${timezone}" > /etc/timezone

        success "時區設定完成 (使用替代方案): ${timezone}"
    fi

    # 顯示當前時間
    info "當前時間: $(date)"
}

# 設定語系
setup_locale() {
    local locale="${LOCALE:-en_US.UTF-8}"
    local additional_locales="${ADDITIONAL_LOCALES:-zh_TW.UTF-8}"

    info "設定系統語系..."

    # 安裝 locales 套件
    if ! dpkg -l | grep -q "^ii  locales"; then
        apt-get install -y locales >> "${LOG_FILE}" 2>&1
    fi

    # 取消註解需要的語系
    info "啟用語系: ${locale}"
    sed -i "s/^# *${locale}/${locale}/" /etc/locale.gen

    # 啟用額外的語系
    if [[ -n "${additional_locales}" ]]; then
        IFS=',' read -ra LOCALES <<< "${additional_locales}"
        for loc in "${LOCALES[@]}"; do
            loc=$(echo "${loc}" | xargs)  # 移除空白
            if [[ -n "${loc}" ]]; then
                info "啟用額外語系: ${loc}"
                sed -i "s/^# *${loc}/${loc}/" /etc/locale.gen
            fi
        done
    fi

    # 生成語系
    info "生成語系檔案..."
    if locale-gen >> "${LOG_FILE}" 2>&1; then
        success "語系生成完成"
    else
        warning "語系生成失敗"
        return 1
    fi

    # 設定預設語系
    info "設定預設語系: ${locale}"
    update-locale LANG="${locale}" >> "${LOG_FILE}" 2>&1

    # 更新環境變數
    export LANG="${locale}"
    export LANGUAGE="${locale}"
    export LC_ALL="${locale}"

    success "語系設定完成: ${locale}"

    # 顯示當前語系設定
    debug "當前語系設定:"
    locale >> "${LOG_FILE}" 2>&1
}

# 設定 Git 全域配置
setup_git_config() {
    local git_user_name="${GIT_USER_NAME:-}"
    local git_user_email="${GIT_USER_EMAIL:-}"
    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    if [[ -z "${git_user_name}" ]] && [[ -z "${git_user_email}" ]]; then
        debug "未設定 Git 使用者資訊，跳過 Git 設定"
        return 0
    fi

    info "設定 Git 全域配置..."

    # 以實際使用者身分執行 Git 設定
    if [[ -n "${git_user_name}" ]]; then
        sudo -u "${actual_user}" git config --global user.name "${git_user_name}"
        info "Git 使用者名稱: ${git_user_name}"
    fi

    if [[ -n "${git_user_email}" ]]; then
        sudo -u "${actual_user}" git config --global user.email "${git_user_email}"
        info "Git 使用者信箱: ${git_user_email}"
    fi

    # 設定其他 Git 偏好
    sudo -u "${actual_user}" git config --global core.editor "vim"
    sudo -u "${actual_user}" git config --global init.defaultBranch "main"
    sudo -u "${actual_user}" git config --global pull.rebase false

    success "Git 全域配置完成"
}

# 設定 Vim 基本配置
setup_vim_basic() {
    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})
    local vimrc="${user_home}/.vimrc"

    info "設定 Vim 基本配置..."

    # 建立基本的 .vimrc
    sudo -u "${actual_user}" tee "${vimrc}" > /dev/null <<'EOF'
" Vim 基本配置
" 由 install-linux-tools.sh 自動生成

" 基本設定
set nocompatible              " 不相容 vi 模式
set number                    " 顯示行號
set relativenumber            " 顯示相對行號
set cursorline                " 高亮當前行
set ruler                     " 顯示游標位置
set showcmd                   " 顯示命令

" 縮排設定
set autoindent                " 自動縮排
set smartindent               " 智慧縮排
set tabstop=4                 " Tab 寬度
set shiftwidth=4              " 縮排寬度
set expandtab                 " 使用空格代替 Tab
set softtabstop=4             " 軟 Tab 寬度

" 搜尋設定
set hlsearch                  " 高亮搜尋結果
set incsearch                 " 即時搜尋
set ignorecase                " 搜尋時忽略大小寫
set smartcase                 " 智慧大小寫搜尋

" 編輯設定
set backspace=indent,eol,start " 退格鍵行為
set encoding=utf-8            " 編碼設定
set fileencoding=utf-8        " 檔案編碼
set mouse=a                   " 啟用滑鼠

" 視覺設定
syntax on                     " 語法高亮
set background=dark           " 深色背景
set wildmenu                  " 命令列補全
set showmatch                 " 顯示配對括號

" 效能設定
set lazyredraw                " 延遲重繪
set ttyfast                   " 快速終端

" 備份設定
set nobackup                  " 不建立備份
set noswapfile                " 不建立 swap 檔案
set nowritebackup             " 寫入時不備份
EOF

    success "Vim 基本配置完成"
    debug "配置檔案: ${vimrc}"
}

# 清理 APT 快取
cleanup_apt_cache() {
    info "清理 APT 快取..."

    apt-get autoclean >> "${LOG_FILE}" 2>&1
    apt-get autoremove -y >> "${LOG_FILE}" 2>&1

    success "APT 快取清理完成"
}

# 顯示系統資訊
show_system_info() {
    info "系統資訊："

    echo "  作業系統: $(lsb_release -d | cut -f2)" | tee -a "${LOG_FILE}"
    echo "  核心版本: $(uname -r)" | tee -a "${LOG_FILE}"
    echo "  架構: $(uname -m)" | tee -a "${LOG_FILE}"
    echo "  主機名稱: $(hostname)" | tee -a "${LOG_FILE}"

    if command -v free &> /dev/null; then
        local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
        echo "  記憶體: ${mem_total}" | tee -a "${LOG_FILE}"
    fi

    if command -v df &> /dev/null; then
        local disk_avail=$(df -h / | awk 'NR==2 {print $4}')
        echo "  可用磁碟空間: ${disk_avail}" | tee -a "${LOG_FILE}"
    fi
}

# 設定系統優化
setup_system_optimization() {
    info "設定系統優化..."

    # 增加檔案描述符限制
    if [[ -f /etc/security/limits.conf ]]; then
        if ! grep -q "nofile" /etc/security/limits.conf; then
            cat >> /etc/security/limits.conf <<EOF

# 增加檔案描述符限制
* soft nofile 65536
* hard nofile 65536
EOF
            success "已增加檔案描述符限制"
        fi
    fi

    # 設定 sysctl 優化（WSL 可能不支援）
    if command -v sysctl &> /dev/null; then
        # 嘗試設定，但不強制成功
        sysctl -w fs.file-max=2097152 >> "${LOG_FILE}" 2>&1 || true
        debug "已嘗試設定 sysctl 參數"
    fi

    success "系統優化設定完成"
}

# 主要基礎設定函式
setup_base_system() {
    print_header "基礎系統設定"

    # 顯示系統資訊
    show_system_info
    print_separator

    # 設定 APT 代理
    setup_apt_proxy

    # 更新系統
    setup_system_update

    # 安裝基礎工具
    setup_base_tools

    # 設定時區
    setup_timezone

    # 設定語系
    setup_locale

    # 設定 Git
    setup_git_config

    # 設定 Vim
    setup_vim_basic

    # 系統優化
    setup_system_optimization

    # 清理快取
    cleanup_apt_cache

    success "基礎系統設定完成"
    INSTALL_STATUS["base_system"]="success"
}

# 匯出函式供主腳本使用
export -f setup_system_update
export -f setup_apt_proxy
export -f setup_base_tools
export -f setup_timezone
export -f setup_locale
export -f setup_git_config
export -f setup_vim_basic
export -f cleanup_apt_cache
export -f show_system_info
export -f setup_system_optimization
export -f setup_base_system
