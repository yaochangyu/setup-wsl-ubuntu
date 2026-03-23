#!/bin/bash

###############################################################################
# 資料庫客戶端工具安裝模組
###############################################################################

###############################################################################
# 環境變數（未設定時使用預設值；可由外部環境或 config.sh 覆蓋）
###############################################################################
: "${ACCEPT_EULA:=Y}"   # 接受 MSSQL 工具授權條款 (Y/N)
# 由執行環境提供（唯讀）：
# SUDO_USER - 實際非 root 使用者（由 install-linux-tools.ps1 export 設定）

install_database_tools() {
    print_header "安裝資料庫客戶端工具"

    # PostgreSQL 客戶端
    if command -v psql &> /dev/null; then
        info "PostgreSQL 客戶端已安裝，跳過"
    else
        info "安裝 PostgreSQL 客戶端..."
        apt-get install -y postgresql-client >> "${LOG_FILE}" 2>&1
    fi
    command -v psql &> /dev/null && success "PostgreSQL 客戶端: $(psql --version)"

    # MSSQL 客戶端
    local mssql_pkg="mssql-tools18"
    local mssql_bin="/opt/mssql-tools18/bin"

    if [[ -f "${mssql_bin}/sqlcmd" ]]; then
        info "MSSQL 客戶端已安裝，跳過"
    else
        info "安裝 MSSQL 客戶端工具..."

        # 新增 Microsoft APT 來源（使用 signed-by 方式，相容 Ubuntu 24.04+）
        local ms_keyring="/etc/apt/keyrings/microsoft.gpg"
        if [[ ! -f "${ms_keyring}" ]]; then
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
                gpg --batch --no-tty --yes --dearmor -o "${ms_keyring}" >> "${LOG_FILE}" 2>&1
            chmod a+r "${ms_keyring}"
        fi

        local ms_list="/etc/apt/sources.list.d/microsoft-prod.list"
        if [[ ! -f "${ms_list}" ]]; then
            local ubuntu_version
            ubuntu_version=$(lsb_release -rs)
            echo "deb [arch=$(dpkg --print-architecture) signed-by=${ms_keyring}] https://packages.microsoft.com/ubuntu/${ubuntu_version}/prod $(lsb_release -cs) main" \
                | tee "${ms_list}" > /dev/null
        fi

        # 移除舊的重複來源與過時金鑰
        rm -f /etc/apt/sources.list.d/msprod.list
        rm -f /etc/apt/trusted.gpg.d/microsoft.gpg

        apt-get update -qq >> "${LOG_FILE}" 2>&1

        # Ubuntu 22.04+ 使用 mssql-tools18，路徑為 /opt/mssql-tools18/bin
        if ! ACCEPT_EULA=Y apt-get install -y "${mssql_pkg}" unixodbc-dev >> "${LOG_FILE}" 2>&1; then
            warning "mssql-tools18 安裝失敗，嘗試舊版 mssql-tools..."
            mssql_pkg="mssql-tools"
            mssql_bin="/opt/mssql-tools/bin"
            ACCEPT_EULA=Y apt-get install -y "${mssql_pkg}" unixodbc-dev >> "${LOG_FILE}" 2>&1 || \
                warning "MSSQL 客戶端安裝失敗"
        fi
    fi

    # 新增到 PATH
    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    if [[ "${actual_user}" != "root" ]]; then
        if ! grep -q "${mssql_bin}" "${user_home}/.bashrc" 2>/dev/null; then
            sudo -u "${actual_user}" tee -a "${user_home}/.bashrc" > /dev/null <<EOF

# MSSQL Tools
export PATH="\$PATH:${mssql_bin}"
EOF
        fi
    fi

    if [[ -f "${mssql_bin}/sqlcmd" ]]; then
        success "MSSQL 客戶端已安裝: ${mssql_bin}/sqlcmd"
    fi

    success "資料庫客戶端工具安裝完成"
    INSTALL_STATUS["database_tools"]="success"
}

export -f install_database_tools
