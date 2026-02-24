#!/bin/bash

###############################################################################
# 資料庫客戶端工具安裝模組
###############################################################################

install_database_tools() {
    print_header "安裝資料庫客戶端工具"

    # PostgreSQL 客戶端
    info "安裝 PostgreSQL 客戶端..."
    apt-get install -y postgresql-client >> "${LOG_FILE}" 2>&1

    if command -v psql &> /dev/null; then
        success "PostgreSQL 客戶端: $(psql --version)"
    fi

    # MSSQL 客戶端
    info "安裝 MSSQL 客戶端工具..."

    # 若 microsoft-prod.list 已由 dotnet 模組建立，直接複用，否則手動新增
    if [[ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]]; then
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
            gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg >> "${LOG_FILE}" 2>&1
        curl -fsSL "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list" \
            -o /etc/apt/sources.list.d/microsoft-prod.list >> "${LOG_FILE}" 2>&1
    fi

    # 移除舊的重複來源（msprod.list）
    rm -f /etc/apt/sources.list.d/msprod.list

    apt-get update -qq >> "${LOG_FILE}" 2>&1

    # Ubuntu 22.04+ 使用 mssql-tools18，路徑為 /opt/mssql-tools18/bin
    local mssql_pkg="mssql-tools18"
    local mssql_bin="/opt/mssql-tools18/bin"
    if ! ACCEPT_EULA=Y apt-get install -y "${mssql_pkg}" unixodbc-dev >> "${LOG_FILE}" 2>&1; then
        warning "mssql-tools18 安裝失敗，嘗試舊版 mssql-tools..."
        mssql_pkg="mssql-tools"
        mssql_bin="/opt/mssql-tools/bin"
        ACCEPT_EULA=Y apt-get install -y "${mssql_pkg}" unixodbc-dev >> "${LOG_FILE}" 2>&1 || \
            warning "MSSQL 客戶端安裝失敗"
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
