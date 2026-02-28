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

###############################################################################
# 環境變數（未設定時使用預設值；可由外部環境或 config.sh 覆蓋）
###############################################################################
: "${UPGRADE_PACKAGES:=false}"          # 是否升級已安裝套件 (true/false)
: "${PROXY_URL:=}"                      # 代理伺服器 URL（選填）
: "${TIMEZONE:=Asia/Taipei}"           # 系統時區
: "${LOCALE:=en_US.UTF-8}"            # 系統預設語系
: "${ADDITIONAL_LOCALES:=zh_TW.UTF-8}" # 額外語系（逗號分隔）
: "${GIT_USER_NAME:=}"                  # Git 全域使用者名稱（選填）
: "${GIT_USER_EMAIL:=}"                 # Git 全域使用者信箱（選填）
# 由執行環境提供（唯讀）：
# SUDO_USER - 實際非 root 使用者（由 install-linux-tools.ps1 export 設定）

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
        "less"
        "man-db"
        "bash-completion"

        # CLI 工具
        "jq"           # JSON 處理
        "bat"          # 更好的 cat
        "ripgrep"      # 更快的 grep
        "fzf"          # 模糊搜尋
        "htop"         # 系統監控
        "tmux"         # 終端多工
        "tree"         # 目錄樹
        "zsh"          # Shell
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

# 設定 Bash 使用者環境
setup_bash_env() {
    info "設定 Bash 使用者環境..."

    local actual_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(eval echo ~"${actual_user}")

    # ~/.profile 設定（避免重複寫入）
    if ! grep -q 'WINDOWS_USERNAME' "${user_home}/.profile" 2>/dev/null; then
        info "設定 ~/.profile..."
        sudo -u "${actual_user}" tee -a "${user_home}/.profile" > /dev/null <<'EOF'

# WSL: 取得 Windows 使用者名稱（僅在 Windows interop 啟用時）
if [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    export WINDOWS_USERNAME=$(powershell.exe -NoProfile -NonInteractive -Command '$env:UserName' 2>/dev/null | tr -d '\r\n')
fi

# jq 暗色背景終端機色彩配置
export JQ_COLORS="33:93:93:96:92:97:1;97:4;97"

export EDITOR=vim
export GPG_TTY=$(tty)
EOF
    fi

    # ~/.bashrc 設定（避免重複寫入）
    if ! grep -q 'no_empty_cmd_completion' "${user_home}/.bashrc" 2>/dev/null; then
        info "設定 ~/.bashrc..."
        sudo -u "${actual_user}" tee -a "${user_home}/.bashrc" > /dev/null <<'EOF'

# Bash 補全設定
shopt -u direxpand
shopt -s no_empty_cmd_completion
EOF
    fi

    # SSH 設定
    info "設定 SSH..."
    local ssh_dir="${user_home}/.ssh"
    local ssh_key="${ssh_dir}/id_rsa"

    sudo -u "${actual_user}" mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    sudo -u "${actual_user}" touch "${ssh_dir}/authorized_keys"
    chmod 600 "${ssh_dir}/authorized_keys"

    if [[ ! -f "${ssh_key}" ]]; then
        info "產生 SSH 金鑰 (RSA 4096)..."
        sudo -u "${actual_user}" ssh-keygen -t rsa -b 4096 -f "${ssh_key}" -N "" >> "${LOG_FILE}" 2>&1
        success "SSH 金鑰已產生: ${ssh_key}"
        info "請將公鑰加入 GitHub: $(cat "${ssh_key}.pub")"
    else
        debug "SSH 金鑰已存在，跳過: ${ssh_key}"
    fi

    # 建立工作目錄
    info "建立工作目錄 ~/projects..."
    sudo -u "${actual_user}" mkdir -p "${user_home}/projects"

    # Starship - 華麗的 Bash 提示符號
    info "安裝 Starship 提示符號..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y >> "${LOG_FILE}" 2>&1 || warning "Starship 安裝失敗"

    if command -v starship &> /dev/null; then
        info "套用 Starship catppuccin-powerline 主題..."
        sudo -u "${actual_user}" bash -c '
            mkdir -p ~/.config
            starship preset catppuccin-powerline -o ~/.config/starship.toml
            sed -i '"'"'/^\[line_break\]/,/^\[/ s/disabled = true/disabled = false/'"'"' ~/.config/starship.toml
        ' >> "${LOG_FILE}" 2>&1 || warning "Starship 主題套用失敗"

        info "將 Starship 加入 ~/.bashrc..."
        if ! grep -q 'starship init bash' "${user_home}/.bashrc" 2>/dev/null; then
            echo 'eval "$(starship init bash)"' >> "${user_home}/.bashrc"
        fi
    fi

    success "Bash 使用者環境設定完成"
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

# 安裝 better-rm（更安全的 rm 替代方案，刪除前移至垃圾桶）
install_better_rm() {
    info "安裝 better-rm..."

    local actual_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(eval echo ~"${actual_user}")

    sudo -u "${actual_user}" bash -c \
        'curl -sSL https://raw.githubusercontent.com/doggy8088/better-rm/main/install.sh | bash' \
        >> "${LOG_FILE}" 2>&1 || warning "better-rm 安裝失敗"

    # 驗證安裝（better-rm 會覆蓋 rm，版本資訊中會顯示 better-rm）
    if sudo -u "${actual_user}" bash -c 'source ~/.bashrc && rm --version 2>&1' | grep -qi "better-rm" 2>/dev/null; then
        success "better-rm 安裝完成"
    else
        warning "better-rm 驗證失敗，請重新登入後手動確認: rm --version"
    fi
}

# 安裝 yq（YAML 處理，從 GitHub 下載）
install_yq() {
    info "安裝 yq..."
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
}

# 設定 bat 符號連結（Ubuntu 套件名為 batcat）
setup_bat_symlink() {
    if [[ -f /usr/bin/batcat ]] && [[ ! -f /usr/local/bin/bat ]]; then
        ln -s /usr/bin/batcat /usr/local/bin/bat
    fi
}

# 安裝 oh-my-zsh
install_oh_my_zsh() {
    local actual_user="${SUDO_USER:-$USER}"

    if [[ "${actual_user}" == "root" ]]; then
        warning "以 root 執行，跳過 oh-my-zsh 安裝"
        return 0
    fi

    info "安裝 oh-my-zsh..."
    sudo -u "${actual_user}" bash -c \
        'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' \
        >> "${LOG_FILE}" 2>&1 || warning "oh-my-zsh 安裝失敗"
}

# 安裝常用 CLI 工具
install_cli_tools() {
    print_header "安裝常用 CLI 工具"

    install_yq
    setup_bat_symlink
    install_oh_my_zsh
    install_better_rm

    # 驗證安裝
    local tools=("yq" "starship")
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

    # 設定 Bash 使用者環境
    setup_bash_env

    # 系統優化
    setup_system_optimization

    # 清理快取
    cleanup_apt_cache

    success "基礎系統設定完成"
    INSTALL_STATUS["base_system"]="success"
}

# 允許單獨執行（source 時跳過）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 補充日誌與輸出函式（未由主腳本 source 時的後備定義）
    if ! declare -f info > /dev/null 2>&1; then
        COLOR_RESET="\033[0m"
        COLOR_GREEN="\033[32m"; COLOR_CYAN="\033[36m"
        COLOR_YELLOW="\033[33m"; COLOR_RED="\033[31m"
        COLOR_BLUE="\033[34m";  COLOR_BOLD="\033[1m"

        LOG_FILE="${LOG_FILE:-/tmp/common-$(date +%Y%m%d-%H%M%S).log}"

        log()             { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${*:2}" >> "${LOG_FILE}"; }
        print_log()       { local lvl=$1 clr=$2; shift 2; echo -e "${clr}[${lvl}]${COLOR_RESET} $*"; log "${lvl}" "$*"; }
        info()            { print_log "INFO"    "${COLOR_CYAN}"   "$@"; }
        success()         { print_log "SUCCESS" "${COLOR_GREEN}"  "$@"; }
        warning()         { print_log "WARNING" "${COLOR_YELLOW}" "$@"; }
        error()           { print_log "ERROR"   "${COLOR_RED}"    "$@"; }
        debug()           { [[ "${DEBUG:-false}" == "true" ]] && print_log "DEBUG" "${COLOR_BLUE}" "$@" || true; }
        print_header()    { echo -e "\n${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}\n${COLOR_BOLD}${COLOR_CYAN}$1${COLOR_RESET}\n${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}\n"; }
        print_separator() { echo -e "${COLOR_BLUE}----------------------------------------${COLOR_RESET}"; }
    fi

    declare -A INSTALL_STATUS 2>/dev/null || true

    setup_base_system "$@"
    install_cli_tools
    exit $?
fi

# 匯出函式供主腳本使用
export -f setup_system_update
export -f setup_apt_proxy
export -f setup_base_tools
export -f setup_timezone
export -f setup_locale
export -f setup_git_config
export -f setup_vim_basic
export -f setup_bash_env
export -f cleanup_apt_cache
export -f show_system_info
export -f setup_system_optimization
export -f setup_base_system
export -f install_yq
export -f setup_bat_symlink
export -f install_oh_my_zsh
export -f install_better_rm
export -f install_cli_tools
