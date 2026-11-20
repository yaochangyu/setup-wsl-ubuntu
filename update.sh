#!/bin/bash

###############################################################################
# 開發環境更新腳本（WSL Ubuntu 內執行）
#
# 功能：依序更新系統套件與已安裝的開發 / AI CLI 工具。
#       單一步驟失敗不會中止其餘步驟，最後會列出摘要。
#
# 更新範圍：
#   - apt 系統套件（apt-get update / upgrade / autoremove）
#   - npm 全域套件（@openai/codex、@github/copilot）
#   - Rust（rustup update）
#   - pyenv（git pull --ff-only）
#   - Claude Code（claude update）
#   - OpenCode（opencode upgrade）
#   - Antigravity（agy）、Hermes Agent：目前未提供已知的自動更新指令，略過
#
# 使用方式：
#   sudo ./update.sh               # 更新全部
#   sudo ./update.sh --skip-apt    # 跳過 apt 系統套件
#   sudo ./update.sh --apt-only    # 只更新 apt 系統套件（安裝流程使用）
#
# 安全說明：
#   - 需要 root 權限執行 apt；其餘工具以實際使用者身分執行（SUDO_USER），不以 root 執行使用者層級工具。
#   - 使用 getent 取得使用者家目錄，不以 eval 展開路徑。
###############################################################################

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/update-$(date +%Y%m%d-%H%M%S).log"

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_CYAN='\033[0;36m'

SKIP_APT=false
APT_ONLY=false
declare -a OK_STEPS=()
declare -a FAILED_STEPS=()
declare -a SKIPPED_STEPS=()

###############################################################################
# 工具函式
###############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"
    log "[INFO] $*"
}

success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
    log "[SUCCESS] $*"
}

warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
    log "[WARNING] $*"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
    log "[ERROR] $*"
}

print_header() {
    echo ""
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    log "==== $* ===="
}

usage() {
    sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# 以實際使用者身分執行指令（使用者層級工具：nvm、rustup、pyenv、claude 等）
run_as_user() {
    local cmd="$1"
    if [[ "${EUID}" -eq 0 && "${ACTUAL_USER}" != "root" ]]; then
        sudo -u "${ACTUAL_USER}" -H bash -c "${cmd}" >> "${LOG_FILE}" 2>&1
    else
        bash -c "${cmd}" >> "${LOG_FILE}" 2>&1
    fi
}

# 執行一個更新步驟：成功 / 失敗記錄在摘要中，不中止整體流程
# 用法：run_step "步驟名稱" 指令...
run_step() {
    local name="$1"
    shift
    info "更新 ${name}..."
    if "$@"; then
        success "${name} 更新完成"
        OK_STEPS+=("${name}")
    else
        warning "${name} 更新失敗（詳見日誌: ${LOG_FILE}）"
        FAILED_STEPS+=("${name}")
    fi
}

skip_step() {
    local name="$1"
    local reason="$2"
    info "略過 ${name}：${reason}"
    SKIPPED_STEPS+=("${name}")
}

###############################################################################
# 參數解析
###############################################################################

for arg in "$@"; do
    case "${arg}" in
        --skip-apt) SKIP_APT=true ;;
        --apt-only) APT_ONLY=true ;;
        -h|--help)  usage; exit 0 ;;
        *)
            error "未知參數: ${arg}"
            usage
            exit 1
            ;;
    esac
done

mkdir -p "${LOG_DIR}"

ACTUAL_USER="${SUDO_USER:-${USER}}"
USER_HOME="$(getent passwd "${ACTUAL_USER}" | cut -d: -f6)"
if [[ -z "${USER_HOME}" || ! -d "${USER_HOME}" ]]; then
    error "無法取得使用者 ${ACTUAL_USER} 的家目錄"
    exit 1
fi
readonly ACTUAL_USER USER_HOME

###############################################################################
# 各步驟
###############################################################################

update_apt() {
    if [[ "${EUID}" -ne 0 ]]; then
        error "apt 更新需要 root 權限，請使用 sudo ./update.sh"
        return 1
    fi
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >> "${LOG_FILE}" 2>&1 &&
        apt-get -y upgrade >> "${LOG_FILE}" 2>&1 &&
        apt-get -y autoremove >> "${LOG_FILE}" 2>&1
}

update_npm_globals() {
    if [[ ! -s "${USER_HOME}/.nvm/nvm.sh" ]]; then
        return 2
    fi
    run_as_user "source '${USER_HOME}/.nvm/nvm.sh' && npm update -g @openai/codex @github/copilot"
}

update_rust() {
    local rustup="${USER_HOME}/.cargo/bin/rustup"
    [[ -x "${rustup}" ]] || return 2
    run_as_user "'${rustup}' update"
}

update_pyenv() {
    [[ -d "${USER_HOME}/.pyenv/.git" ]] || return 2
    run_as_user "git -C '${USER_HOME}/.pyenv' pull --ff-only"
}

update_claude_code() {
    local claude="${USER_HOME}/.local/bin/claude"
    [[ -x "${claude}" ]] || return 2
    run_as_user "'${claude}' update"
}

update_opencode() {
    local opencode="${USER_HOME}/.opencode/bin/opencode"
    [[ -x "${opencode}" ]] || opencode="${USER_HOME}/.local/bin/opencode"
    [[ -x "${opencode}" ]] || return 2
    run_as_user "'${opencode}' upgrade"
}

# 包裝：依回傳碼區分「未安裝（略過）」與「實際失敗」
run_optional_step() {
    local name="$1"
    shift
    "$@"
    local rc=$?
    if [[ ${rc} -eq 2 ]]; then
        skip_step "${name}" "未安裝或不符合更新條件"
    elif [[ ${rc} -eq 0 ]]; then
        success "${name} 更新完成"
        OK_STEPS+=("${name}")
    else
        warning "${name} 更新失敗（詳見日誌: ${LOG_FILE}）"
        FAILED_STEPS+=("${name}")
    fi
}

###############################################################################
# 主流程
###############################################################################

print_header "開發環境更新（使用者: ${ACTUAL_USER}）"
log "update.sh 開始，使用者=${ACTUAL_USER}，家目錄=${USER_HOME}"

if [[ "${SKIP_APT}" == true ]]; then
    skip_step "apt 系統套件" "--skip-apt"
else
    run_step "apt 系統套件" update_apt
fi

if [[ "${APT_ONLY}" == true ]]; then
    skip_step "開發工具（npm、Rust、pyenv、Claude Code、OpenCode）" "--apt-only"
else
    run_optional_step "npm 全域套件（codex、copilot）" update_npm_globals
    run_optional_step "Rust（rustup）" update_rust
    run_optional_step "pyenv" update_pyenv
    run_optional_step "Claude Code" update_claude_code
    run_optional_step "OpenCode" update_opencode
    skip_step "Antigravity（agy）" "目前無已知的自動更新指令"
    skip_step "Hermes Agent" "目前無已知的自動更新指令"
fi

print_header "更新摘要"
echo -e "${COLOR_GREEN}成功（${#OK_STEPS[@]}）${COLOR_RESET}: ${OK_STEPS[*]:-無}"
echo -e "${COLOR_YELLOW}略過（${#SKIPPED_STEPS[@]}）${COLOR_RESET}: ${SKIPPED_STEPS[*]:-無}"
echo -e "${COLOR_RED}失敗（${#FAILED_STEPS[@]}）${COLOR_RESET}: ${FAILED_STEPS[*]:-無}"
echo "日誌檔案: ${LOG_FILE}"
log "update.sh 結束：成功=${#OK_STEPS[@]} 略過=${#SKIPPED_STEPS[@]} 失敗=${#FAILED_STEPS[@]}"

if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    exit 1
fi
exit 0
