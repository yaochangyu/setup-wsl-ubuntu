#!/bin/bash

###############################################################################
# WSL2 Ubuntu 開發環境自動安裝腳本
#
# 功能：
#   - 安裝開發工具（Docker、.NET、Node.js、Python、Go、Rust 等）
#   - 支援離線安裝
#   - 支援代理設定
#   - 完整的日誌記錄
#   - 安裝後驗證
#
# 使用方式：
#   sudo ./install-linux-tools.sh [選項]
#
# 選項：
#   --offline          使用離線安裝模式
#   --proxy <url>      設定代理伺服器
#   --config <file>    使用自訂配置檔
#   --skip-verify      跳過安裝驗證
#   --help             顯示說明
#
###############################################################################

set -e  # 遇到錯誤立即退出
# set -x  # 取消註解以啟用除錯模式

###############################################################################
# 全域變數
###############################################################################

# 腳本資訊
# 優先使用外部傳入的 SCRIPT_DIR（bash -s 管道執行時 BASH_SOURCE[0] 為空）
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# 目錄設定
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
readonly OFFLINE_DIR="${SCRIPT_DIR}/offline-packages"
readonly CONFIG_DIR="${SCRIPT_DIR}"

# 日誌設定
readonly LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# 顏色定義
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

###############################################################################
# 環境變數（未設定時使用預設值；可由外部環境或 config.sh 覆蓋）
###############################################################################
: "${DEBUG:=false}"                      # 啟用除錯輸出（export DEBUG=true）
export DEBIAN_FRONTEND=noninteractive    # 禁用 dpkg/apt 互動式提示

# 安裝選項（預設值）
OFFLINE_MODE=false
PROXY_URL=""
CONFIG_FILE="${CONFIG_DIR}/config.sh"
SKIP_VERIFY=false

# 安裝狀態追蹤
declare -A INSTALL_STATUS
TOTAL_STEPS=0
CURRENT_STEP=0

###############################################################################
# 工具函式
###############################################################################

# 初始化日誌目錄
init_log_dir() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
    fi
}

# 日誌函式
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

# 輸出函式（同時輸出到控制台和日誌）
print_log() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"

    echo -e "${color}[${level}]${COLOR_RESET} ${message}"
    log "${level}" "${message}"
}

info() {
    print_log "INFO" "${COLOR_CYAN}" "$@"
}

success() {
    print_log "SUCCESS" "${COLOR_GREEN}" "$@"
}

warning() {
    print_log "WARNING" "${COLOR_YELLOW}" "$@"
}

error() {
    print_log "ERROR" "${COLOR_RED}" "$@"
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        print_log "DEBUG" "${COLOR_BLUE}" "$@"
    fi
}

# 進度顯示
show_progress() {
    local current=$1
    local total=$2
    local message=$3

    # 非終端機環境（如 PowerShell 管道）直接輸出純文字
    if [[ ! -t 1 ]]; then
        echo "[進度 ${current}/${total}] ${message}"
        return
    fi

    local percent=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((bar_length * current / total))

    printf "\r["
    printf "%${filled_length}s" | tr ' ' '='
    printf "%$((bar_length - filled_length))s" | tr ' ' '-'
    printf "] %3d%% - %s" "$percent" "$message"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# 更新步驟進度
update_progress() {
    ((CURRENT_STEP++)) || true
    show_progress "${CURRENT_STEP}" "${TOTAL_STEPS}" "$1"
}

# 標題顯示
print_header() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$1${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}"
    echo ""
}

# 分隔線
print_separator() {
    echo -e "${COLOR_BLUE}----------------------------------------${COLOR_RESET}"
}

# 錯誤處理
handle_error() {
    local line_number=$1
    local error_code=$2

    error "腳本執行失敗於第 ${line_number} 行，錯誤代碼: ${error_code}"
    error "請檢查日誌檔案: ${LOG_FILE}"

    exit "${error_code}"
}

trap 'handle_error ${LINENO} $?' ERR

# 檢查是否為 root 使用者
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此腳本需要 root 權限執行"
        error "請使用: sudo $0"
        exit 1
    fi
}

# 檢查作業系統
check_os() {
    info "檢查作業系統..."

    if [[ ! -f /etc/os-release ]]; then
        error "無法識別作業系統"
        exit 1
    fi

    source /etc/os-release

    info "作業系統: ${NAME} ${VERSION}"
    log "INFO" "OS ID: ${ID}, Version ID: ${VERSION_ID}"

    # 檢查是否為 Ubuntu
    if [[ "${ID}" != "ubuntu" ]]; then
        warning "此腳本主要針對 Ubuntu 設計，在其他發行版上可能無法正常運作"
            read -p "是否要繼續？ (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "使用者取消安裝"
                exit 0
        fi
    fi

    success "作業系統檢查通過"
}

# 檢查網路連線
check_network() {
    if [[ "${OFFLINE_MODE}" == "true" ]]; then
        info "離線模式：跳過網路檢查"
        return 0
    fi

    info "檢查網路連線..."

    if ping -c 1 8.8.8.8 &> /dev/null; then
        success "網路連線正常"
        return 0
    else
        warning "無法連接到網際網路"
        warning "某些功能可能無法使用"
        return 1
    fi
}

# 檢查磁碟空間
check_disk_space() {
    info "檢查磁碟空間..."

    local required_space=10485760  # 10GB in KB
    local available_space=$(df / | awk 'NR==2 {print $4}')

    info "可用空間: $((available_space / 1024 / 1024)) GB"

    if [[ $available_space -lt $required_space ]]; then
        warning "磁碟空間不足 10GB，建議清理磁碟空間"
    else
        success "磁碟空間充足"
    fi
}

# 載入配置檔
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        info "載入配置檔: ${CONFIG_FILE}"
        source "${CONFIG_FILE}"
        success "配置檔載入完成"
    else
        warning "找不到配置檔: ${CONFIG_FILE}"
        warning "使用預設設定"
    fi
}

# 設定代理
setup_proxy() {
    if [[ -n "${PROXY_URL}" ]]; then
        info "設定代理: ${PROXY_URL}"

        export http_proxy="${PROXY_URL}"
        export https_proxy="${PROXY_URL}"
        export HTTP_PROXY="${PROXY_URL}"
        export HTTPS_PROXY="${PROXY_URL}"

        # 設定 APT 代理
        if [[ ! -d /etc/apt/apt.conf.d ]]; then
            mkdir -p /etc/apt/apt.conf.d
        fi

        cat > /etc/apt/apt.conf.d/95proxy <<EOF
Acquire::http::Proxy "${PROXY_URL}";
Acquire::https::Proxy "${PROXY_URL}";
EOF

        success "代理設定完成"
    fi
}

# 修復 dpkg 中斷的套件（非互動式）
repair_dpkg() {
    info "修復中斷的 dpkg 套件..."
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a >> "${LOG_FILE}" 2>&1 || true
    apt-get install -f -y >> "${LOG_FILE}" 2>&1 || true
}

# 更新系統套件
update_system() {
    info "更新系統套件列表..."

    local tmpout
    tmpout=$(mktemp)
    if ! apt-get update -qq > "$tmpout" 2>&1; then
        cat "$tmpout" >> "${LOG_FILE}"
        # 顯示錯誤行，但若只有第三方來源失敗則繼續（不中止）
        local errors
        errors=$(grep -E "^E:" "$tmpout" || true)
        if [[ -n "$errors" ]]; then
            warning "apt-get update 部分失敗，請確認以下來源設定："
            echo "$errors"
            rm -f "$tmpout"
            return 1
        fi
    fi
    cat "$tmpout" >> "${LOG_FILE}"
    rm -f "$tmpout"

    success "系統套件列表已更新"
}

# apt-get install 包裝：輸出寫入日誌，失敗時將錯誤行印到 stdout
apt_install() {
    local tmpout
    tmpout=$(mktemp)
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" > "$tmpout" 2>&1
    local rc=$?
    cat "$tmpout" >> "${LOG_FILE}"
    if [[ $rc -ne 0 ]]; then
        grep -E "^E:|^W:|[Ee]rror|[Ff]ailed" "$tmpout" || tail -5 "$tmpout"
    fi
    rm -f "$tmpout"
    return $rc
}

# 安裝基礎套件
install_base_packages() {
    info "安裝基礎套件..."

    local packages=(
        "build-essential"
        "curl"
        "wget"
        "git"
        "vim"
        "unzip"
        "tar"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "software-properties-common"
        "apt-transport-https"
    )

    apt_install "${packages[@]}"

    success "基礎套件安裝完成"
}

###############################################################################
# 模組載入函式
###############################################################################

# 載入安裝模組
load_modules() {
    info "載入安裝模組..."

    if [[ ! -d "${SCRIPTS_DIR}" ]]; then
        warning "找不到模組目錄: ${SCRIPTS_DIR}"
        warning "將使用內建安裝函式"
        return 1
    fi

    local module_count=0

    for module in "${SCRIPTS_DIR}"/*.sh; do
        if [[ -f "${module}" ]]; then
            source "${module}"
            ((module_count++)) || true
            debug "載入模組: $(basename "${module}")"
        fi
    done

    if [[ $module_count -gt 0 ]]; then
        success "已載入 ${module_count} 個模組"
    else
        warning "沒有找到任何模組"
    fi
}

###############################################################################
# 驗證函式
###############################################################################

# 驗證安裝
verify_installation() {
    if [[ "${SKIP_VERIFY}" == "true" ]]; then
        info "跳過安裝驗證"
        return 0
    fi

    print_header "驗證安裝"

    local failed_count=0

    # 驗證 Docker
    if [[ "${INSTALL_STATUS[docker]}" == "success" ]]; then
        if command -v docker &> /dev/null; then
            success "Docker: $(docker --version)"
        else
            error "Docker 驗證失敗"
            ((failed_count++)) || true
        fi
    fi

    # 驗證 .NET
    if [[ "${INSTALL_STATUS[dotnet]}" == "success" ]]; then
        if command -v dotnet &> /dev/null; then
            success ".NET: $(dotnet --version)"
        else
            error ".NET 驗證失敗"
            ((failed_count++)) || true
        fi
    fi

    if [[ $failed_count -eq 0 ]]; then
        success "所有工具驗證通過"
        return 0
    else
        warning "有 ${failed_count} 個工具驗證失敗"
        return 1
    fi
}

###############################################################################
# 主要流程
###############################################################################

# 顯示說明
show_help() {
    cat << EOF
使用方式: sudo ${SCRIPT_NAME} [選項]

WSL2 Ubuntu 開發環境自動安裝腳本 v${SCRIPT_VERSION}

選項:
    --offline          使用離線安裝模式
    --proxy <url>      設定代理伺服器 (例如: http://proxy.example.com:8080)
    --config <file>    使用自訂配置檔 (預設: config.sh)
    --skip-verify      跳過安裝驗證
    --help             顯示此說明訊息

範例:
    sudo ${SCRIPT_NAME}
    sudo ${SCRIPT_NAME} --proxy http://proxy.example.com:8080
    sudo ${SCRIPT_NAME} --offline --config my-config.sh

EOF
}

# 解析命令列參數
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --offline)
                OFFLINE_MODE=true
                shift
                ;;
            --proxy)
                PROXY_URL="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "未知選項: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主程式
main() {
    # 初始化
    init_log_dir

    # 顯示標題（非終端機環境不清除畫面）
    [[ -t 1 ]] && clear
    print_header "WSL2 Ubuntu 開發環境安裝程式 v${SCRIPT_VERSION}"

    info "日誌檔案: ${LOG_FILE}"
    echo ""

    # 系統檢查
    check_root
    check_os
    check_network
    check_disk_space

    print_separator

    # 載入配置
    load_config
    setup_proxy

    # 修復中斷的套件，再更新系統
    repair_dpkg
    update_system
    install_base_packages

    # 載入模組
    load_modules

    print_separator

    # 計算總步驟數
    TOTAL_STEPS=12
    CURRENT_STEP=0

    # 安裝工具
    update_progress "設定基礎系統..."
    if declare -f setup_base_system &> /dev/null; then
        setup_base_system
    fi

    update_progress "安裝 CLI 工具..."
    if declare -f install_cli_tools &> /dev/null; then
        install_cli_tools
    fi
    
    update_progress "安裝 Docker..."
    if declare -f install_docker &> /dev/null; then
        install_docker
    fi

    update_progress "安裝 .NET SDK..."
    if declare -f install_dotnet &> /dev/null; then
        install_dotnet
    fi

    update_progress "安裝 Node.js..."
    if declare -f install_nodejs &> /dev/null; then
        install_nodejs
    fi

    update_progress "安裝 Python..."
    if declare -f install_python &> /dev/null; then
        install_python
    fi

    update_progress "安裝 Go..."
    if declare -f install_go &> /dev/null; then
        install_go
    fi

    update_progress "安裝 Rust..."
    if declare -f install_rust &> /dev/null; then
        install_rust
    fi

    update_progress "設定 VS Code Server..."
    if declare -f install_vscode_server &> /dev/null; then
        install_vscode_server
    fi

    update_progress "安裝 Vim 插件..."
    if declare -f install_vim_plugins &> /dev/null; then
        install_vim_plugins
    fi

    update_progress "安裝資料庫工具..."
    if declare -f install_database_tools &> /dev/null; then
        install_database_tools
    fi

    update_progress "安裝 DevOps 工具..."
    if declare -f install_devops_tools &> /dev/null; then
        install_devops_tools
    fi

    print_separator

    # 驗證安裝
    verify_installation

    # 完成
    print_header "安裝完成！"

    success "所有工具已成功安裝"
    info "日誌檔案: ${LOG_FILE}"
    echo ""
    info "後續步驟："
    info "  1. 重新登入或執行: newgrp docker"
    info "  2. 驗證 Docker: docker run hello-world"
    info "  3. 驗證 .NET: dotnet --list-sdks"
    echo ""
}

###############################################################################
# 程式進入點
###############################################################################

parse_args "$@"
main

exit 0
