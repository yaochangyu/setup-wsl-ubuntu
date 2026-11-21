#!/bin/bash

###############################################################################
# 額外工具模組（依使用者選擇納入）
#
# 包含：
#   - 雲端與版本控制：gh、awscli、google-cloud-sdk（gcloud）
#   - 一般開發：uv、vifm、gcx、dbx-cli
#   - Python 爬蟲（uv tool 隔離安裝）：Scrapling、crawl4ai、browser-use
#   - npm 全域 AI / 瀏覽器工具：agent-browser、@googleworkspace/cli、notebooklm-cli、
#     open-browser-use、chrome-devtools-mcp、@jackwener/opencli、@hackmd/hackmd-cli、uipro-cli
#
# 需要人工操作（登入、設定 token、API key）的工具，安裝後會統一列出提醒。
###############################################################################

# 安裝後需要手動完成的步驟（於 install_extra_tools 結尾統一輸出）
declare -a POST_INSTALL_NOTES=()

add_post_install_note() {
    POST_INSTALL_NOTES+=("$1")
}

# 以實際使用者身分執行 uv tool 安裝（uv 會把工具放在 ~/.local/bin）
# 用法：uv_tool_install "套件名稱" ["安裝後要執行的指令"]
uv_tool_install() {
    local pkg="$1"
    local post_cmd="${2:-}"
    local actual_user="${SUDO_USER:-$USER}"

    info "以 uv tool 安裝 ${pkg}（隔離虛擬環境）..."

    local cmd="export PATH=\"\$HOME/.local/bin:\$PATH\"; uv tool install '${pkg}'"
    if [[ -n "${post_cmd}" ]]; then
        cmd="${cmd} && ${post_cmd}"
    fi

    if sudo -u "${actual_user}" -H bash -c "${cmd}" >> "${LOG_FILE}" 2>&1; then
        success "${pkg} 安裝完成"
        return 0
    fi
    warning "${pkg} 安裝失敗（詳見日誌: ${LOG_FILE}）"
    return 1
}

###############################################################################
# 雲端與版本控制
###############################################################################

install_gh() {
    if command -v gh &> /dev/null; then
        info "gh 已安裝，跳過"
        return 0
    fi

    info "安裝 GitHub CLI（gh）..."
    if apt_install gh; then
        success "gh 安裝完成"
        add_post_install_note "gh：請執行 gh auth login 完成 GitHub 登入"
    else
        warning "gh 安裝失敗"
        return 1
    fi
}

install_awscli() {
    if command -v aws &> /dev/null; then
        info "AWS CLI 已安裝，跳過"
        return 0
    fi

    info "安裝 AWS CLI v2（官方安裝包）..."
    apt_install unzip >> "${LOG_FILE}" 2>&1 || true

    local arch
    arch="$(uname -m)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o "${tmp_dir}/awscliv2.zip" >> "${LOG_FILE}" 2>&1 \
        && unzip -q "${tmp_dir}/awscliv2.zip" -d "${tmp_dir}" >> "${LOG_FILE}" 2>&1 \
        && "${tmp_dir}/aws/install" >> "${LOG_FILE}" 2>&1; then
        success "AWS CLI 安裝完成"
        add_post_install_note "awscli：請執行 aws configure 設定 AWS 存取金鑰與預設區域"
    else
        warning "AWS CLI 安裝失敗（詳見日誌: ${LOG_FILE}）"
    fi
    rm -rf "${tmp_dir}"
}

install_gcloud() {
    if command -v gcloud &> /dev/null; then
        info "gcloud 已安裝，跳過"
        return 0
    fi

    info "安裝 Google Cloud CLI（官方 apt 來源）..."
    local keyring="/usr/share/keyrings/cloud.google.gpg"

    if ! curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --batch --no-tty --yes --dearmor -o "${keyring}" >> "${LOG_FILE}" 2>&1; then
        warning "Google Cloud 金鑰下載失敗"
        return 1
    fi

    echo "deb [signed-by=${keyring}] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list
    apt-get update >> "${LOG_FILE}" 2>&1 || true

    if apt_install google-cloud-cli; then
        success "Google Cloud CLI 安裝完成"
        add_post_install_note "google-cloud-sdk：請執行 gcloud init 完成登入並選擇預設專案"
    else
        warning "Google Cloud CLI 安裝失敗"
        return 1
    fi
}

###############################################################################
# 一般開發工具
###############################################################################

install_uv() {
    local actual_user="${SUDO_USER:-$USER}"
    local user_home
    user_home="$(getent passwd "${actual_user}" | cut -d: -f6)"

    if command -v uv &> /dev/null || [[ -x "${user_home}/.local/bin/uv" ]]; then
        info "uv 已安裝，跳過"
        return 0
    fi

    native_cli_install "uv" "https://astral.sh/uv/install.sh" "uv" || return 1
}

install_vifm() {
    if command -v vifm &> /dev/null; then
        info "vifm 已安裝，跳過"
        return 0
    fi

    info "安裝 vifm..."
    if apt_install vifm; then
        success "vifm 安裝完成"
    else
        warning "vifm 安裝失敗"
        return 1
    fi
}

install_gcx() {
    native_cli_install "gcx（Grafana CLI）" "https://raw.githubusercontent.com/grafana/gcx/main/scripts/install.sh" "gcx" || return 1
    add_post_install_note "gcx：請依 gcx --help 設定 Grafana 連線"
}

install_dbx_cli() {
    npm_global_install "@dbx-app/cli" "dbx" || return 1
    add_post_install_note "dbx：請依 dbx --help 設定資料庫連線"
}

###############################################################################
# Python 爬蟲與瀏覽器自動化（uv tool 隔離安裝）
###############################################################################

install_scrapling() {
    uv_tool_install "scrapling[fetchers]" "scrapling install" || return 1
    add_post_install_note "Scrapling：已下載瀏覽器元件（scrapling install）；如需 MCP 伺服器，另執行 uv tool install 'scrapling[ai]'"
}

install_crawl4ai() {
    uv_tool_install "crawl4ai" "crawl4ai-setup" || return 1
    add_post_install_note "crawl4ai：已執行 crawl4ai-setup；使用前請依 crawl4ai 說明設定 LLM 相關金鑰（若有需要）"
}

install_browser_use() {
    uv_tool_install "browser-use" || return 1
    add_post_install_note "browser-use：需設定所選 LLM 的 API key（依 browser-use 說明）"
}

###############################################################################
# npm 全域 AI 與瀏覽器工具
###############################################################################

install_agent_browser() {
    npm_global_install "agent-browser" "agent-browser" || return 1
    add_post_install_note "agent-browser：首次使用前請依 agent-browser --help 完成設定"
}

install_gws() {
    npm_global_install "@googleworkspace/cli" "gws" || return 1
    add_post_install_note "gws（Google Workspace CLI）：首次使用需以 Google 帳號登入，依 gws 說明執行"
}

install_nlm_cli() {
    npm_global_install "notebooklm-cli" "nlm-cli" || return 1
    add_post_install_note "nlm-cli（NotebookLM）：需以 Google 帳號登入，依 nlm-cli 說明完成"
}

install_open_browser_use() {
    npm_global_install "open-browser-use" "obu" || return 1
    add_post_install_note "open-browser-use（obu）：依 open-browser-use 說明完成瀏覽器相關設定"
}

install_chrome_devtools_mcp() {
    npm_global_install "chrome-devtools-mcp" "chrome-devtools-mcp" || return 1
    add_post_install_note "chrome-devtools-mcp：為 MCP 伺服器，需在 AI 代理的 MCP 設定中加入指令 chrome-devtools-mcp"
}

install_opencli() {
    npm_global_install "@jackwener/opencli" "opencli" || return 1
    add_post_install_note "opencli：依 opencli --help 完成設定"
}

install_hackmd_cli() {
    npm_global_install "@hackmd/hackmd-cli" "hackmd-cli" || return 1
    add_post_install_note "hackmd-cli：需要 HackMD API token，依 hackmd-cli 說明設定"
}

install_uipro_cli() {
    npm_global_install "uipro-cli" "uipro" || return 1
    add_post_install_note "uipro：依 uipro --help 完成設定"
}

###############################################################################
# 主流程
###############################################################################

install_extra_tools() {
    info "========================================"
    info "安裝額外工具（依選擇納入）"
    info "========================================"

    # uv 需先安裝，後續 Python 工具才能使用
    want uv && install_uv || true

    want gh && install_gh || true
    want awscli && install_awscli || true
    want gcloud && install_gcloud || true
    want vifm && install_vifm || true
    want gcx && install_gcx || true
    want dbx && install_dbx_cli || true

    want scrapling && install_scrapling || true
    want crawl4ai && install_crawl4ai || true
    want browser-use && install_browser_use || true

    want agent-browser && install_agent_browser || true
    want gws && install_gws || true
    want nlm && install_nlm_cli || true
    want open-browser-use && install_open_browser_use || true
    want chrome-devtools-mcp && install_chrome_devtools_mcp || true
    want opencli && install_opencli || true
    want hackmd && install_hackmd_cli || true
    want uipro && install_uipro_cli || true

    if [[ ${#POST_INSTALL_NOTES[@]} -gt 0 ]]; then
        echo "" | tee -a "${LOG_FILE}"
        warning "以下工具安裝後仍需手動完成設定："
        local note
        for note in "${POST_INSTALL_NOTES[@]}"; do
            echo "  - ${note}" | tee -a "${LOG_FILE}"
        done
    fi

    success "額外工具安裝流程完成"
}
