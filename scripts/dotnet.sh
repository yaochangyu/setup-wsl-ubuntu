#!/bin/bash

###############################################################################
# .NET SDK 安裝模組
###############################################################################

install_dotnet() {
    print_header "安裝 .NET SDK"

    info "新增 Microsoft 套件來源..."

    # 下載並安裝 Microsoft 套件配置
    local ubuntu_version=$(lsb_release -rs)
    local packages_url="https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb"

    wget -q "${packages_url}" -O /tmp/packages-microsoft-prod.deb

    if dpkg -i /tmp/packages-microsoft-prod.deb >> "${LOG_FILE}" 2>&1; then
        success "Microsoft 套件來源已新增"
    else
        error "Microsoft 套件來源新增失敗"
        rm -f /tmp/packages-microsoft-prod.deb
        return 1
    fi

    rm -f /tmp/packages-microsoft-prod.deb

    # 更新套件列表
    info "更新套件列表..."
    apt-get update -qq >> "${LOG_FILE}" 2>&1

    # 安裝多個版本的 .NET SDK
    local dotnet_versions=("6.0" "7.0" "8.0" "9.0")
    local installed_count=0

    for version in "${dotnet_versions[@]}"; do
        info "安裝 .NET ${version} SDK..."
        if apt-get install -y "dotnet-sdk-${version}" >> "${LOG_FILE}" 2>&1; then
            success ".NET ${version} SDK 安裝成功"
            ((installed_count++)) || true
        else
            warning ".NET ${version} SDK 安裝失敗或不可用"
        fi
    done

    # 驗證安裝
    if command -v dotnet &> /dev/null; then
        success ".NET SDK 已安裝: $(dotnet --version)"
        info "已安裝的 SDK 版本："
        dotnet --list-sdks | while read line; do
            echo "  ${line}" | tee -a "${LOG_FILE}"
        done
    else
        error ".NET SDK 安裝失敗"
        return 1
    fi

    success ".NET SDK 安裝完成 (${installed_count}/${#dotnet_versions[@]} 個版本)"
    INSTALL_STATUS["dotnet"]="success"
}

export -f install_dotnet
