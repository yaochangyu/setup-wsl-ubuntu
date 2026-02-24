#!/bin/bash

###############################################################################
# .NET SDK 安裝模組
#
# 版本策略：
#   apt 安裝  : 6.0, 7.0, 8.0, 9.0  （Microsoft Ubuntu 22.04 repo 提供）
#   dotnet-install.sh : 5.0 (EOL), 10.0 (Preview，視可用性）
###############################################################################

install_dotnet() {
    print_header "安裝 .NET SDK"

    # -------------------------------------------------------------------------
    # 確認 Microsoft 套件來源已設定（22.04）
    # -------------------------------------------------------------------------
    info "新增 Microsoft 套件來源 (Ubuntu 22.04)..."
    local ubuntu_version
    ubuntu_version=$(lsb_release -rs)
    rm -f /tmp/packages-microsoft-prod.deb
    wget -q "https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb" \
        -O /tmp/packages-microsoft-prod.deb
    dpkg -i --force-confdef --force-confnew /tmp/packages-microsoft-prod.deb >> "${LOG_FILE}" 2>&1 && \
        success "Microsoft 套件來源已新增" || \
        warning "Microsoft 套件來源新增失敗，繼續使用現有來源"
    rm -f /tmp/packages-microsoft-prod.deb
    apt-get update -qq >> "${LOG_FILE}" 2>&1

    # 搜尋可用的 .NET SDK 套件
    info "可用的 .NET SDK 套件（apt）："
    apt-cache search dotnet-sdk 2>/dev/null | grep -v source-built | grep -v dbg | sort | tee -a "${LOG_FILE}"

    # -------------------------------------------------------------------------
    # 所有版本統一用 dotnet-install.sh 安裝到 /usr/share/dotnet
    # 避免 apt 的 dotnet-host-X.Y vs dotnet-host 衝突問題
    # -------------------------------------------------------------------------
    local dotnet_install_dir="/usr/share/dotnet"
    local all_versions=("5.0" "6.0" "7.0" "8.0" "9.0" "10.0")
    local installed_count=0

    info "下載 dotnet-install.sh..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh

    for version in "${all_versions[@]}"; do
        info "安裝 .NET ${version} SDK (dotnet-install.sh)..."
        if /tmp/dotnet-install.sh \
            --channel "${version}" \
            --install-dir "${dotnet_install_dir}" \
            --no-path >> "${LOG_FILE}" 2>&1; then
            success ".NET ${version} SDK 安裝成功"
            ((installed_count++)) || true
        else
            warning ".NET ${version} SDK 安裝失敗（可能尚未發布）"
        fi
    done

    rm -f /tmp/dotnet-install.sh

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
