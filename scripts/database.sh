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

    # 新增 Microsoft 套件來源
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - >> "${LOG_FILE}" 2>&1
    curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | \
        tee /etc/apt/sources.list.d/msprod.list > /dev/null

    apt-get update -qq >> "${LOG_FILE}" 2>&1

    # 安裝 sqlcmd 和 bcp
    ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev >> "${LOG_FILE}" 2>&1

    # 新增到 PATH
    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    if [[ "${actual_user}" != "root" ]]; then
        if ! grep -q '/opt/mssql-tools/bin' "${user_home}/.bashrc" 2>/dev/null; then
            sudo -u "${actual_user}" tee -a "${user_home}/.bashrc" > /dev/null <<'EOF'

# MSSQL Tools
export PATH="$PATH:/opt/mssql-tools/bin"
EOF
        fi
    fi

    if [[ -f /opt/mssql-tools/bin/sqlcmd ]]; then
        success "MSSQL 客戶端已安裝"
    fi

    success "資料庫客戶端工具安裝完成"
    INSTALL_STATUS["database_tools"]="success"
}

export -f install_database_tools
