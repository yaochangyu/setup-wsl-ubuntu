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
#   --config <file>    使用舊版配置檔（過渡相容）
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
readonly CONFIG_DIR="${SCRIPT_DIR}"
readonly DEFAULT_ENV_FILE="${CONFIG_DIR}/.env"
readonly DEFAULT_CONFIG_FILE="${CONFIG_DIR}/config.sh"

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
# 環境變數（未設定時使用預設值；可由外部環境或 .env 覆蓋）
###############################################################################
: "${DEBUG:=false}"                      # 啟用除錯輸出（export DEBUG=true）
export DEBIAN_FRONTEND=noninteractive    # 禁用 dpkg/apt 互動式提示

# 安裝選項（預設值）
OFFLINE_MODE=false
OFFLINE_DIR="${SCRIPT_DIR}/offline-packages"
PROXY_URL=""
ENV_FILE="${DEFAULT_ENV_FILE}"
CONFIG_FILE="${DEFAULT_CONFIG_FILE}"
SKIP_VERIFY=false
LEGACY_CONFIG_ENABLED=false

# CLI 參數覆蓋追蹤（維持 CLI > .env > fallback）
declare -A CLI_OVERRIDE=()

# 安裝狀態追蹤
declare -A INSTALL_STATUS
TOTAL_STEPS=0
CURRENT_STEP=0

# --only 選取的工具或群組（空陣列 = 完整安裝）
declare -a ONLY_TOOLS=()

# 工具 → 所屬群組（--only 使用）。群組名稱本身也可指定，代表該群組全部工具。
declare -A TOOL_GROUP=(
    [claude]=ai [codex]=ai [antigravity]=ai [copilot]=ai [opencode]=ai [hermes]=ai
    [uv]=extra [gh]=extra [awscli]=extra [gcloud]=extra [vifm]=extra [gcx]=extra [dbx]=extra
    [scrapling]=extra [crawl4ai]=extra [browser-use]=extra
    [agent-browser]=extra [gws]=extra [nlm]=extra [open-browser-use]=extra
    [chrome-devtools-mcp]=extra [opencli]=extra [hackmd]=extra [uipro]=extra
    [cli-tools]=cli-tools [docker]=docker [dotnet]=dotnet [nodejs]=nodejs
    [python]=python [go]=go [rust]=rust [vscode-server]=vscode-server
    [vim]=vim [database]=database [devops]=devops [homebrew]=homebrew
)

# 工具本身或其所屬群組是否被選取（未指定 --only 時一律 true）
want() {
    [[ ${#ONLY_TOOLS[@]} -eq 0 ]] && return 0
    local sel group="${TOOL_GROUP[$1]:-}"
    for sel in "${ONLY_TOOLS[@]}"; do
        [[ "${sel}" == "$1" || "${sel}" == "${group}" ]] && return 0
    done
    return 1
}

# 群組內是否有任一工具被選取（用於決定是否呼叫整個群組函式）
group_active() {
    [[ ${#ONLY_TOOLS[@]} -eq 0 ]] && return 0
    local sel
    for sel in "${ONLY_TOOLS[@]}"; do
        [[ "${sel}" == "$1" || "${TOOL_GROUP[${sel}]:-}" == "$1" ]] && return 0
    done
    return 1
}

# 驗證 --only 的名稱是否都存在
validate_only_tools() {
    local sel valid name
    for sel in "${ONLY_TOOLS[@]}"; do
        valid=false
        for name in "${!TOOL_GROUP[@]}"; do
            if [[ "${sel}" == "${name}" || "${sel}" == "${TOOL_GROUP[${name}]}" ]]; then
                valid=true
                break
            fi
        done
        if [[ "${valid}" != "true" ]]; then
            # 此時日誌目錄尚未初始化，直接輸出到 stderr
            echo "[ERROR] 未知的工具或群組: ${sel}（可用名稱請見 --help）" >&2
            exit 1
        fi
    done
}

###############################################################################
# 工具函式
###############################################################################

# 初始化日誌目錄
init_log_dir() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
    fi
}

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "${value}"
}

set_env_var() {
    local key="$1"
    local value="$2"

    if [[ -n "${CLI_OVERRIDE[${key}]:-}" ]]; then
        debug "略過 ${key}：已由 CLI 參數指定"
        return 0
    fi

    value=$(trim_whitespace "${value}")

    if [[ "${value}" =~ ^".*"$ ]] || [[ "${value}" =~ ^'.*'$ ]]; then
        value="${value:1:${#value}-2}"
    fi

    printf -v "${key}" '%s' "${value}"
    export "${key}"
}

load_env_file() {
    local env_file="$1"
    local loaded=0

    if [[ ! -f "${env_file}" ]]; then
        return 1
    fi

    info "載入 .env 設定檔: ${env_file}"

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%$'\r'}"

        [[ -z "$(trim_whitespace "${line}")" ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue

        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            set_env_var "${key}" "${value}"
            loaded=1
        else
            warning ".env 存在無法解析的設定，已略過: ${line}"
        fi
    done < "${env_file}"

    if [[ "${OFFLINE_MODE}" == "true" ]] && [[ -z "${OFFLINE_DIR}" ]]; then
        OFFLINE_DIR="${SCRIPT_DIR}/offline-packages"
    fi

    success ".env 設定檔載入完成"
    return 0
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

# 使用者中止（Ctrl+C / 終端關閉）：整支腳本立即結束，不繼續安裝下一個工具。
# 注意：bash 會等前景指令（例如原生安裝器）結束後才執行 trap，因此中止會在該指令結束時生效。
on_user_abort() {
    error "使用者中止安裝（收到中斷訊號）"
    error "已安裝的項目保留，可重新執行腳本或用 verify.sh --fix 接續"
    exit 130
}

trap on_user_abort INT TERM HUP

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

# 載入設定（以 .env 為主，config.sh 為過渡相容）
load_configuration() {
    local env_loaded=false

    if load_env_file "${ENV_FILE}"; then
        env_loaded=true
    else
        warning "找不到 .env 設定檔: ${ENV_FILE}"
    fi

    if [[ "${LEGACY_CONFIG_ENABLED}" == "true" ]]; then
        if [[ "${env_loaded}" == "true" ]]; then
            warning "已偵測 .env，忽略舊版配置檔: ${CONFIG_FILE}"
            warning "請改用 .env 作為主要設定來源"
        elif [[ -f "${CONFIG_FILE}" ]]; then
            warning "載入舊版配置檔: ${CONFIG_FILE}"
            warning "config.sh 已進入過渡相容模式，請儘快遷移到 .env"
            source "${CONFIG_FILE}"
            success "舊版配置檔載入完成"
        else
            warning "找不到舊版配置檔: ${CONFIG_FILE}"
            warning "使用預設設定"
        fi
    elif [[ "${env_loaded}" == "false" ]] && [[ -f "${DEFAULT_CONFIG_FILE}" ]]; then
        warning "未找到 .env，改用舊版配置檔: ${DEFAULT_CONFIG_FILE}"
        warning "config.sh 已進入過渡相容模式，請儘快遷移到 .env"
        source "${DEFAULT_CONFIG_FILE}"
        success "舊版配置檔載入完成"
    elif [[ "${env_loaded}" == "false" ]]; then
        warning "未找到可用設定檔，使用預設設定"
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
        "pinentry-qt"
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
source_module() {
    local module_path="$1"

    if grep -q $'\r' "${module_path}"; then
        debug "偵測到 CRLF，載入前轉為 LF: $(basename "${module_path}")"
        # 透過 process substitution 正規化換行，避免 source CRLF 檔案失敗
        source <(sed 's/\r$//' "${module_path}")
    else
        source "${module_path}"
    fi
}

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
            source_module "${module}"
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

# 驗證安裝（呼叫 verify.sh）
verify_installation() {
    if [[ "${SKIP_VERIFY}" == "true" ]]; then
        info "跳過安裝驗證"
        return 0
    fi

    local verify_script="${SCRIPT_DIR}/verify.sh"
    if [[ -x "${verify_script}" ]]; then
        info "執行安裝驗證..."
        bash "${verify_script}" || true
    else
        warning "找不到驗證腳本: ${verify_script}"
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
    --config <file>    使用舊版配置檔（過渡相容，預設: config.sh）
    --skip-verify      跳過安裝驗證
    --only <名稱,...>  只安裝指定的工具或群組（逗號分隔；指定時自動跳過完整驗證）
    --help             顯示此說明訊息

--only 可用名稱:
    群組（安裝該群組全部工具）:
        ai, extra
    AI CLI（屬於 ai）:
        claude, codex, antigravity, copilot, opencode, hermes
    額外工具（屬於 extra）:
        uv, gh, awscli, gcloud, vifm, gcx, dbx, scrapling, crawl4ai, browser-use,
        agent-browser, gws, nlm, open-browser-use, chrome-devtools-mcp, opencli, hackmd, uipro
    獨立群組:
        cli-tools, docker, dotnet, nodejs, python, go, rust, vscode-server, vim, database, devops, homebrew
    注意: scrapling、crawl4ai、browser-use 依賴 uv，需一併指定 uv

範例:
    sudo ${SCRIPT_NAME}
    sudo ${SCRIPT_NAME} --proxy http://proxy.example.com:8080
    sudo ${SCRIPT_NAME} --offline
    sudo ${SCRIPT_NAME} --config my-config.sh
    sudo ${SCRIPT_NAME} --only gh
    sudo ${SCRIPT_NAME} --only claude,codex
    sudo ${SCRIPT_NAME} --only uv,scrapling

EOF
}

# 解析命令列參數
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --offline)
                OFFLINE_MODE=true
                CLI_OVERRIDE[OFFLINE_MODE]=true
                shift
                ;;
            --proxy)
                PROXY_URL="$2"
                CLI_OVERRIDE[PROXY_URL]=true
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                LEGACY_CONFIG_ENABLED=true
                shift 2
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                CLI_OVERRIDE[SKIP_VERIFY]=true
                shift
                ;;
            --only)
                if [[ -z "${2:-}" ]]; then
                    echo "[ERROR] --only 需要指定工具名稱，例如 --only gh,claude" >&2
                    exit 1
                fi
                IFS=',' read -ra _only_items <<< "$2"
                ONLY_TOOLS+=("${_only_items[@]}")
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                error "未知選項: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ ${#ONLY_TOOLS[@]} -gt 0 ]]; then
        validate_only_tools
        # 指定 --only 時只安裝部分工具，完整驗證會對未安裝的工具報錯，因此略過
        SKIP_VERIFY=true
    fi
}

# 一律執行的閘門（基礎系統設定）
always() { return 0; }

# 安裝步驟表：閘門 | 閘門參數 | 進度文字 | 安裝函式
# 閘門：always（一律執行）、want（工具或群組被選取）、group_active（群組內有被選取的工具）
declare -a GROUP_STEPS=(
    "always|-|設定基礎系統...|setup_base_system"
    "want|cli-tools|安裝 CLI 工具...|install_cli_tools"
    "want|docker|安裝 Docker...|install_docker"
    "want|dotnet|安裝 .NET SDK...|install_dotnet"
    "want|nodejs|安裝 Node.js...|install_nodejs"
    "group_active|ai|安裝 AI CLI 工具...|install_ai_cli_tools"
    "group_active|extra|安裝額外工具...|install_extra_tools"
    "want|python|安裝 Python...|install_python"
    "want|go|安裝 Go...|install_go"
    "want|rust|安裝 Rust...|install_rust"
    "want|vscode-server|設定 VS Code Server...|install_vscode_server"
    "want|vim|安裝 Vim 插件...|install_vim_plugins"
    "want|database|安裝資料庫工具...|install_database_tools"
    "want|devops|安裝 DevOps 工具...|install_devops_tools"
    "want|homebrew|安裝 Homebrew...|install_homebrew"
)

# 依步驟表執行：先算出實際要執行的步驟數（進度分母），再依序執行並只對執行中的步驟顯示進度
run_group_steps() {
    local entry gate arg label fn
    local -a active=()
    for entry in "${GROUP_STEPS[@]}"; do
        IFS='|' read -r gate arg label fn <<< "${entry}"
        if "${gate}" "${arg}" && declare -f "${fn}" &> /dev/null; then
            active+=("${entry}")
        fi
    done

    TOTAL_STEPS=${#active[@]}
    CURRENT_STEP=0

    for entry in "${active[@]}"; do
        IFS='|' read -r gate arg label fn <<< "${entry}"
        update_progress "${label}"
        "${fn}"
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
    check_network || true
    check_disk_space

    print_separator

    # 載入設定
    load_configuration
    setup_proxy

    # 修復中斷的套件，再更新系統
    repair_dpkg
    update_system
    install_base_packages

    # 載入模組
    load_modules

    print_separator

    # 計算總步驟數
    run_group_steps

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
    info "  2. 若有失敗項目，執行: sudo ./verify.sh --fix"
    echo ""
}

###############################################################################
# 程式進入點
###############################################################################

parse_args "$@"
main

exit 0
