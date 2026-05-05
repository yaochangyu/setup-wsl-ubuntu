#!/bin/bash

###############################################################################
# 工具安裝驗證腳本
#
# 功能：
#   - 檢查所有已安裝的開發工具狀態
#   - 顯示分類總表（✓ 成功 / ✗ 失敗）
#   - 使用 --fix 參數自動重裝失敗的工具
#
# 使用方式：
#   ./verify.sh              # 僅檢查
#   sudo ./verify.sh --fix   # 檢查並重裝失敗項目
#
###############################################################################

set -e

###############################################################################
# 全域變數
###############################################################################

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/verify-$(date +%Y%m%d-%H%M%S).log"

# 顏色定義
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

# 檢查結果追蹤
declare -a PASSED=()
declare -a FAILED=()
declare -a FAILED_FIXABLE=()

# 參數
FIX_MODE=false

###############################################################################
# 工具函式
###############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

print_header() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}── $1 ──${COLOR_RESET}"
}

check_pass() {
    local name="$1"
    local version="$2"
    if [[ -n "${version}" ]]; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${name} (${version})"
    else
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${name}"
    fi
    PASSED+=("${name}")
    log "PASS: ${name} ${version}"
}

check_fail() {
    local name="$1"
    local fixable="${2:-}"
    echo -e "  ${COLOR_RED}✗${COLOR_RESET} ${name}"
    FAILED+=("${name}")
    if [[ -n "${fixable}" ]]; then
        FAILED_FIXABLE+=("${fixable}")
    fi
    log "FAIL: ${name}"
}

# 以使用者身分執行指令（用於 nvm/pyenv 等使用者層級工具）
run_as_user() {
    local actual_user="${SUDO_USER:-$USER}"
    if [[ "${actual_user}" == "root" ]] || [[ $EUID -ne 0 ]]; then
        bash -c "$1" 2>/dev/null
    else
        sudo -u "${actual_user}" bash -c "$1" 2>/dev/null
    fi
}

get_user_home() {
    local actual_user="${SUDO_USER:-$USER}"
    eval echo ~"${actual_user}"
}

###############################################################################
# 檢查函式
###############################################################################

check_system_tools() {
    print_header "系統工具"

    local tools=("git" "curl" "wget" "vim" "gcc" "make" "cmake" "jq" "htop" "tmux" "tree" "zsh" "unzip")
    for tool in "${tools[@]}"; do
        if command -v "${tool}" &> /dev/null; then
            check_pass "${tool}"
        else
            check_fail "${tool}" "setup_base_system"
        fi
    done
}

check_cli_tools() {
    print_header "CLI 工具"

    # fzf
    if command -v fzf &> /dev/null; then
        check_pass "fzf" "$(fzf --version 2>/dev/null | awk '{print $1}')"
    else
        check_fail "fzf" "install_fzf"
    fi

    # yq
    if command -v yq &> /dev/null; then
        check_pass "yq" "$(yq --version 2>/dev/null | awk '{print $NF}')"
    else
        check_fail "yq" "install_yq"
    fi

    # glab
    if command -v glab &> /dev/null; then
        check_pass "glab" "$(glab version 2>/dev/null | head -n1)"
    else
        check_fail "glab" "install_glab"
    fi

    # starship
    if command -v starship &> /dev/null; then
        check_pass "starship" "$(starship --version 2>/dev/null | head -n1)"
    else
        check_fail "starship" "setup_bash_env"
    fi

    # bat
    if command -v bat &> /dev/null || command -v batcat &> /dev/null; then
        check_pass "bat"
    else
        check_fail "bat" "setup_base_system"
    fi

    # ripgrep
    if command -v rg &> /dev/null; then
        check_pass "ripgrep" "$(rg --version 2>/dev/null | head -n1)"
    else
        check_fail "ripgrep" "setup_base_system"
    fi

    # eza
    if command -v eza &> /dev/null; then
        check_pass "eza" "$(eza --version 2>/dev/null | head -n1)"
    else
        check_fail "eza" "install_eza"
    fi

    # zoxide
    if command -v zoxide &> /dev/null; then
        check_pass "zoxide" "$(zoxide --version 2>/dev/null)"
    else
        local user_home
        user_home=$(get_user_home)
        if [[ -x "${user_home}/.local/bin/zoxide" ]]; then
            check_pass "zoxide"
        else
            check_fail "zoxide" "install_zoxide"
        fi
    fi

    # tldr
    if command -v tldr &> /dev/null; then
        check_pass "tldr" "$(tldr --version 2>/dev/null)"
    else
        check_fail "tldr" "install_tldr"
    fi

    # glow
    if command -v glow &> /dev/null; then
        check_pass "glow" "$(glow --version 2>/dev/null)"
    else
        check_fail "glow" "install_glow"
    fi

    # lazygit
    if command -v lazygit &> /dev/null; then
        check_pass "lazygit" "$(lazygit --version 2>/dev/null | head -n1)"
    else
        check_fail "lazygit" "install_lazygit"
    fi

    # yazi
    if command -v yazi &> /dev/null; then
        check_pass "yazi" "$(yazi --version 2>/dev/null)"
    else
        check_fail "yazi" "install_yazi"
    fi

    # chafa
    if command -v chafa &> /dev/null; then
        check_pass "chafa" "$(chafa --version 2>/dev/null | head -n1)"
    else
        check_fail "chafa" "install_chafa"
    fi
}

check_docker() {
    print_header "Docker"

    if command -v docker &> /dev/null; then
        check_pass "docker" "$(docker --version 2>/dev/null)"
    else
        check_fail "docker" "install_docker"
    fi

    if docker compose version &> /dev/null; then
        check_pass "docker compose" "$(docker compose version --short 2>/dev/null)"
    else
        check_fail "docker compose" "install_docker"
    fi
}

check_dotnet() {
    print_header ".NET SDK"

    if command -v dotnet &> /dev/null; then
        local versions
        versions=$(dotnet --list-sdks 2>/dev/null | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
        check_pass "dotnet" "${versions}"
    else
        check_fail "dotnet" "install_dotnet"
    fi
}

check_nodejs() {
    print_header "Node.js"

    local user_home
    user_home=$(get_user_home)
    local nvm_sh="${user_home}/.nvm/nvm.sh"

    # nvm
    if [[ -s "${nvm_sh}" ]]; then
        check_pass "nvm"
    else
        check_fail "nvm" "install_nodejs"
        return
    fi

    # node
    local node_ver
    node_ver=$(run_as_user "source '${nvm_sh}' && node --version")
    if [[ -n "${node_ver}" ]]; then
        check_pass "node" "${node_ver}"
    else
        check_fail "node" "install_nodejs"
    fi

    # npm
    local npm_ver
    npm_ver=$(run_as_user "source '${nvm_sh}' && npm --version")
    if [[ -n "${npm_ver}" ]]; then
        check_pass "npm" "${npm_ver}"
    else
        check_fail "npm" "install_nodejs"
    fi

    # yarn
    if run_as_user "source '${nvm_sh}' && command -v yarn" &> /dev/null; then
        local yarn_ver
        yarn_ver=$(run_as_user "source '${nvm_sh}' && yarn --version")
        check_pass "yarn" "${yarn_ver}"
    else
        check_fail "yarn" "install_nodejs"
    fi

    # pnpm
    if run_as_user "source '${nvm_sh}' && command -v pnpm" &> /dev/null; then
        local pnpm_ver
        pnpm_ver=$(run_as_user "source '${nvm_sh}' && pnpm --version")
        check_pass "pnpm" "${pnpm_ver}"
    else
        check_fail "pnpm" "install_nodejs"
    fi
}

check_ai_cli() {
    print_header "AI CLI 工具"

    local user_home
    user_home=$(get_user_home)
    local nvm_sh="${user_home}/.nvm/nvm.sh"

    # Claude Code（原生安裝器）
    if [[ -x "${user_home}/.local/bin/claude" ]]; then
        check_pass "claude"
    else
        check_fail "claude" "install_claude_code"
    fi

    # npm 全域套件
    local npm_tools=("@openai/codex:codex:install_codex_cli" "@google/gemini-cli:gemini:install_gemini_cli" "@github/copilot:copilot:install_copilot_cli")
    for entry in "${npm_tools[@]}"; do
        local pkg="${entry%%:*}"
        local rest="${entry#*:}"
        local name="${rest%%:*}"
        local fix_fn="${rest#*:}"
        if run_as_user "source '${nvm_sh}' && npm list -g '${pkg}'" &> /dev/null; then
            check_pass "${name}"
        else
            check_fail "${name}" "${fix_fn}"
        fi
    done
}

check_python() {
    print_header "Python"

    local user_home
    user_home=$(get_user_home)
    local pyenv_root="${user_home}/.pyenv"

    # pyenv
    if [[ -d "${pyenv_root}" ]]; then
        check_pass "pyenv"
    else
        check_fail "pyenv" "install_python"
        return
    fi

    # python（pyenv 需要 PYENV_ROOT 才能找到已安裝版本）
    local python_ver
    python_ver=$(PYENV_ROOT="${pyenv_root}" "${pyenv_root}/bin/pyenv" versions --bare 2>/dev/null | head -1)
    if [[ -n "${python_ver}" ]]; then
        check_pass "python" "${python_ver}"
    else
        check_fail "python" "install_python"
    fi
}

check_go() {
    print_header "Go"

    if /usr/local/go/bin/go version &> /dev/null; then
        local go_ver
        go_ver=$(/usr/local/go/bin/go version | awk '{print $3}')
        check_pass "go" "${go_ver}"
    else
        check_fail "go" "install_go"
    fi
}

check_rust() {
    print_header "Rust"

    local user_home
    user_home=$(get_user_home)

    # rustc
    local rustc_ver
    rustc_ver=$(run_as_user "source '${user_home}/.cargo/env' 2>/dev/null; rustc --version" 2>/dev/null | awk '{print $2}')
    if [[ -n "${rustc_ver}" ]]; then
        check_pass "rustc" "${rustc_ver}"
    else
        check_fail "rustc" "install_rust"
    fi

    # cargo
    if run_as_user "source '${user_home}/.cargo/env' 2>/dev/null; command -v cargo" &> /dev/null; then
        check_pass "cargo"
    else
        check_fail "cargo" "install_rust"
    fi
}

check_database() {
    print_header "資料庫工具"

    # psql
    if command -v psql &> /dev/null; then
        check_pass "psql" "$(psql --version 2>/dev/null)"
    else
        check_fail "psql" "install_database_tools"
    fi

    # sqlcmd
    if [[ -f /opt/mssql-tools18/bin/sqlcmd ]]; then
        check_pass "sqlcmd" "mssql-tools18"
    elif [[ -f /opt/mssql-tools/bin/sqlcmd ]]; then
        check_pass "sqlcmd" "mssql-tools"
    else
        check_fail "sqlcmd" "install_database_tools"
    fi
}

check_devops() {
    print_header "DevOps 工具"

    # kubectl
    if command -v kubectl &> /dev/null; then
        check_pass "kubectl" "$(kubectl version --client 2>/dev/null | grep -oP 'Client Version: \K[^ ]+')"
    else
        check_fail "kubectl" "install_devops_tools"
    fi

    # helm
    if command -v helm &> /dev/null; then
        check_pass "helm" "$(helm version --short 2>/dev/null)"
    else
        check_fail "helm" "install_devops_tools"
    fi

    # terraform
    if command -v terraform &> /dev/null; then
        check_pass "terraform" "$(terraform version 2>/dev/null | head -n1)"
    else
        check_fail "terraform" "install_devops_tools"
    fi

    # az
    if command -v az &> /dev/null; then
        check_pass "az" "$(az version -o tsv 2>/dev/null | head -n1 | awk '{print $1}')"
    else
        check_fail "az" "install_devops_tools"
    fi
}

###############################################################################
# 總表輸出
###############################################################################

print_summary() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}驗證結果${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_GREEN}通過: ${#PASSED[@]}${COLOR_RESET}"
    echo -e "  ${COLOR_RED}失敗: ${#FAILED[@]}${COLOR_RESET}"
    echo ""

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}失敗項目：${COLOR_RESET}"
        for item in "${FAILED[@]}"; do
            echo -e "  ${COLOR_RED}✗${COLOR_RESET} ${item}"
        done
        echo ""
        echo -e "${COLOR_YELLOW}使用 ${COLOR_BOLD}sudo ./verify.sh --fix${COLOR_RESET}${COLOR_YELLOW} 自動重裝失敗項目${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}所有工具皆已正確安裝！${COLOR_RESET}"
    fi

    echo ""
    echo "日誌檔案: ${LOG_FILE}"
}

###############################################################################
# --fix 重裝邏輯
###############################################################################

fix_failed() {
    if [[ ${#FAILED_FIXABLE[@]} -eq 0 ]]; then
        echo -e "${COLOR_GREEN}沒有需要修復的項目${COLOR_RESET}"
        return 0
    fi

    # 需要 root 權限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_RED}--fix 需要 root 權限，請使用: sudo $0 --fix${COLOR_RESET}"
        return 1
    fi

    # 載入模組
    echo ""
    echo -e "${COLOR_CYAN}載入安裝模組...${COLOR_RESET}"

    # 匯出主腳本的輔助函式供模組使用
    export LOG_FILE
    export DEBIAN_FRONTEND=noninteractive
    export -f log print_header check_pass check_fail

    # 定義模組需要的函式（info/success/warning/error）
    info()    { echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"; log "INFO: $*"; }
    success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; log "SUCCESS: $*"; }
    warning() { echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"; log "WARNING: $*"; }
    error()   { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"; log "ERROR: $*"; }
    debug()   { :; }
    print_separator() { echo -e "────────────────────────────────"; }

    export -f info success warning error debug print_separator

    declare -A INSTALL_STATUS
    export INSTALL_STATUS

    # source 所有模組
    for module in "${SCRIPTS_DIR}"/*.sh; do
        if [[ -f "${module}" ]]; then
            if grep -q $'\r' "${module}"; then
                source <(sed 's/\r$//' "${module}")
            else
                source "${module}"
            fi
        fi
    done

    # 去重：取得唯一的修復函式清單
    local -A unique_fns
    for fn in "${FAILED_FIXABLE[@]}"; do
        unique_fns["${fn}"]=1
    done

    echo ""
    echo -e "${COLOR_YELLOW}準備修復 ${#unique_fns[@]} 個安裝函式...${COLOR_RESET}"
    echo ""

    for fn in "${!unique_fns[@]}"; do
        if declare -f "${fn}" &> /dev/null; then
            echo -e "${COLOR_CYAN}執行 ${fn}...${COLOR_RESET}"
            "${fn}" || warning "${fn} 執行失敗"
        else
            warning "找不到函式: ${fn}"
        fi
    done

    echo ""
    echo -e "${COLOR_GREEN}修復完成，請重新執行 ./verify.sh 確認結果${COLOR_RESET}"
}

###############################################################################
# 主程式
###############################################################################

# 解析參數
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --help|-h)
            echo "使用方式:"
            echo "  ./verify.sh          # 檢查所有工具安裝狀態"
            echo "  sudo ./verify.sh --fix   # 檢查並重裝失敗項目"
            exit 0
            ;;
        *)
            echo "未知選項: $1"
            exit 1
            ;;
    esac
done

# 初始化日誌
mkdir -p "${LOG_DIR}"

echo -e "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}開發環境工具驗證${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}========================================${COLOR_RESET}"

# 執行所有檢查
check_system_tools
check_cli_tools
check_docker
check_dotnet
check_nodejs
check_ai_cli
check_python
check_go
check_rust
check_database
check_devops

# 輸出總表
print_summary

# --fix 模式
if [[ "${FIX_MODE}" == "true" ]] && [[ ${#FAILED[@]} -gt 0 ]]; then
    fix_failed
fi

# 回傳結果：有失敗則 exit 1
if [[ ${#FAILED[@]} -gt 0 ]]; then
    exit 1
fi

exit 0
