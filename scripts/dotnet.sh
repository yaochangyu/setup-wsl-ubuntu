#!/bin/bash

###############################################################################
# .NET SDK 安裝模組
#
# 版本策略：全部使用 dotnet-install.sh 安裝到 /usr/share/dotnet
#   避免 apt dotnet-host-X.Y vs dotnet-host 套件衝突問題
#
# 版本說明：
#   5.0  - EOL（2022-05）
#   6.0  - LTS，EOL 2024-11
#   7.0  - STS，EOL 2024-05
#   8.0  - LTS，EOL 2026-11
#   9.0  - STS，EOL 2026-05
#   10.0 - LTS，EOL 2028-11（2025-11 正式發布）
###############################################################################

install_dotnet() {
    print_header "安裝 .NET SDK"

    # -------------------------------------------------------------------------
    # 所有版本統一用 dotnet-install.sh 安裝到 /usr/share/dotnet
    # 避免 apt 的 dotnet-host-X.Y vs dotnet-host 衝突問題
    # -------------------------------------------------------------------------
    local dotnet_install_dir="/usr/share/dotnet"
    local all_versions=("5.0" "6.0" "7.0" "8.0" "9.0" "10.0")
    local installed_count=0

    info "下載 dotnet-install.sh..."
    local dotnet_install_script
    dotnet_install_script=$(curl -fsSL https://dot.net/v1/dotnet-install.sh)

    for version in "${all_versions[@]}"; do
        info "安裝 .NET ${version} SDK (dotnet-install.sh)..."
        if bash <(echo "$dotnet_install_script") \
            --channel "${version}" \
            --install-dir "${dotnet_install_dir}" \
            --no-path >> "${LOG_FILE}" 2>&1; then
            success ".NET ${version} SDK 安裝成功"
            ((installed_count++)) || true
        else
            warning ".NET ${version} SDK 安裝失敗"
        fi
    done

    # 確保 dotnet 指令在 PATH 中
    if [[ ! -f /usr/local/bin/dotnet ]] && [[ -f "${dotnet_install_dir}/dotnet" ]]; then
        ln -sf "${dotnet_install_dir}/dotnet" /usr/local/bin/dotnet
    fi

    # -------------------------------------------------------------------------
    # 驗證安裝
    # -------------------------------------------------------------------------
    if command -v dotnet &> /dev/null; then
        info "已安裝的 SDK 版本："
        dotnet --list-sdks 2>/dev/null | tee -a "${LOG_FILE}"
        success ".NET SDK 安裝完成 (${installed_count}/6 個版本)"
    else
        error ".NET SDK 安裝失敗"
        return 1
    fi

    INSTALL_STATUS["dotnet"]="success"
}

export -f install_dotnet
