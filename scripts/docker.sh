#!/bin/bash

###############################################################################
# Docker Engine 安裝模組
#
# 功能：
#   - 安裝 Docker Engine
#   - 安裝 Docker Compose
#   - 設定 Docker 服務
#   - 配置 Docker daemon
#   - 使用者群組設定
#   - 代理與鏡像加速設定
#   - Docker 驗證
#
###############################################################################

# 移除舊版本 Docker
remove_old_docker() {
    info "檢查並移除舊版本 Docker..."

    local old_packages=(
        "docker"
        "docker-engine"
        "docker.io"
        "containerd"
        "runc"
    )

    local removed=0

    for package in "${old_packages[@]}"; do
        if dpkg -l | grep -q "^ii  ${package}"; then
            info "移除舊套件: ${package}"
            apt-get remove -y "${package}" >> "${LOG_FILE}" 2>&1
            ((removed++)) || true
        fi
    done

    if [[ $removed -gt 0 ]]; then
        success "已移除 ${removed} 個舊版本套件"
    else
        debug "未發現舊版本 Docker"
    fi
}

# 安裝 Docker 依賴套件
install_docker_dependencies() {
    info "安裝 Docker 依賴套件..."

    local dependencies=(
        "ca-certificates"
        "curl"
        "gnupg"
        "lsb-release"
    )

    if apt-get install -y "${dependencies[@]}" >> "${LOG_FILE}" 2>&1; then
        success "Docker 依賴套件安裝完成"
    else
        error "Docker 依賴套件安裝失敗"
        return 1
    fi
}

# 新增 Docker 官方 GPG 金鑰
add_docker_gpg_key() {
    info "新增 Docker 官方 GPG 金鑰..."

    # 建立 keyrings 目錄
    local keyrings_dir="/etc/apt/keyrings"
    if [[ ! -d "${keyrings_dir}" ]]; then
        install -m 0755 -d "${keyrings_dir}"
    fi

    local gpg_key="${keyrings_dir}/docker.gpg"

    # 下載並安裝 GPG 金鑰
    if [[ "${OFFLINE_MODE}" == "true" ]] && [[ -f "${OFFLINE_DIR}/docker.gpg" ]]; then
        info "使用離線 GPG 金鑰..."
        cp "${OFFLINE_DIR}/docker.gpg" "${gpg_key}"
    else
        info "下載 Docker GPG 金鑰..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            gpg --batch --no-tty --yes --dearmor -o "${gpg_key}" 2>> "${LOG_FILE}"
    fi

    if [[ -f "${gpg_key}" ]]; then
        chmod a+r "${gpg_key}"
        success "Docker GPG 金鑰已新增"
    else
        error "Docker GPG 金鑰新增失敗"
        return 1
    fi
}

# 新增 Docker 套件來源
add_docker_repository() {
    info "新增 Docker 套件來源..."

    local arch=$(dpkg --print-architecture)
    local codename=$(lsb_release -cs)
    local repo_file="/etc/apt/sources.list.d/docker.list"

    # 建立套件來源檔案
    echo \
        "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        ${codename} stable" | tee "${repo_file}" > /dev/null

    if [[ -f "${repo_file}" ]]; then
        success "Docker 套件來源已新增"
        debug "套件來源: ${repo_file}"
    else
        error "Docker 套件來源新增失敗"
        return 1
    fi

    # 更新套件列表
    info "更新套件列表..."
    apt-get update -qq >> "${LOG_FILE}" 2>&1
}

# 安裝 Docker Engine
install_docker_engine() {
    info "安裝 Docker Engine..."

    local docker_packages=(
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
        "docker-buildx-plugin"
        "docker-compose-plugin"
    )

    info "準備安裝以下套件:"
    for pkg in "${docker_packages[@]}"; do
        echo "  - ${pkg}" | tee -a "${LOG_FILE}"
    done

    if apt-get install -y "${docker_packages[@]}" >> "${LOG_FILE}" 2>&1; then
        success "Docker Engine 安裝完成"
    else
        error "Docker Engine 安裝失敗"
        return 1
    fi

    # 驗證安裝
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        success "Docker 版本: ${docker_version}"
    else
        error "Docker 命令未找到"
        return 1
    fi
}

# 設定 Docker 服務
setup_docker_service() {
    info "設定 Docker 服務..."

    # WSL 環境處理
    if grep -qi microsoft /proc/version; then
        warning "偵測到 WSL 環境"

        # 檢查 systemd 是否可用
        if command -v systemctl &> /dev/null && systemctl is-system-running &> /dev/null; then
            info "systemd 可用，啟用 Docker 服務..."

            systemctl enable docker >> "${LOG_FILE}" 2>&1 || warning "無法啟用 Docker 服務（可能需要 systemd）"
            systemctl start docker >> "${LOG_FILE}" 2>&1 || warning "無法啟動 Docker 服務"

            if systemctl is-active docker &> /dev/null; then
                success "Docker 服務已啟動"
            else
                warning "Docker 服務未啟動，WSL 環境中可能需要手動啟動"
                info "手動啟動指令: sudo service docker start"
            fi
        else
            warning "systemd 不可用，使用傳統 service 命令..."

            # 使用傳統的 service 命令
            service docker start >> "${LOG_FILE}" 2>&1 || warning "無法啟動 Docker 服務"

            if service docker status &> /dev/null; then
                success "Docker 服務已啟動（使用 service）"
            else
                warning "Docker 服務狀態不明"
                info "請嘗試手動啟動: sudo service docker start"
            fi
        fi
    else
        # 非 WSL 環境，正常使用 systemd
        systemctl enable docker >> "${LOG_FILE}" 2>&1
        systemctl start docker >> "${LOG_FILE}" 2>&1

        if systemctl is-active docker &> /dev/null; then
            success "Docker 服務已啟動"
        else
            error "Docker 服務啟動失敗"
            return 1
        fi
    fi
}

# 設定使用者群組
setup_docker_user_group() {
    info "設定 Docker 使用者群組..."

    local actual_user="${SUDO_USER:-$USER}"

    if [[ -z "${actual_user}" ]] || [[ "${actual_user}" == "root" ]]; then
        warning "未偵測到非 root 使用者，跳過群組設定"
        return 0
    fi

    # 檢查 docker 群組是否存在
    if ! getent group docker &> /dev/null; then
        info "建立 docker 群組..."
        groupadd docker
    fi

    # 將使用者加入 docker 群組
    if id -nG "${actual_user}" | grep -qw docker; then
        debug "使用者 ${actual_user} 已在 docker 群組中"
    else
        info "將使用者 ${actual_user} 加入 docker 群組..."
        usermod -aG docker "${actual_user}"
        success "使用者 ${actual_user} 已加入 docker 群組"

        warning "請重新登入或執行以下命令以套用群組變更:"
        echo "  newgrp docker" | tee -a "${LOG_FILE}"
    fi
}

# 配置 Docker daemon
configure_docker_daemon() {
    info "配置 Docker daemon..."

    local daemon_config="/etc/docker/daemon.json"
    local config_dir="/etc/docker"

    # 確保配置目錄存在
    if [[ ! -d "${config_dir}" ]]; then
        mkdir -p "${config_dir}"
    fi

    # 備份現有配置
    if [[ -f "${daemon_config}" ]]; then
        cp "${daemon_config}" "${daemon_config}.backup-$(date +%Y%m%d-%H%M%S)"
        debug "已備份現有的 daemon.json"
    fi

    # 建立配置內容
    local config_content='{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"'

    # 新增鏡像加速（如果設定）
    if [[ -n "${DOCKER_REGISTRY_MIRRORS:-}" ]]; then
        config_content+=',
  "registry-mirrors": ['
        IFS=',' read -ra MIRRORS <<< "${DOCKER_REGISTRY_MIRRORS}"
        local first=true
        for mirror in "${MIRRORS[@]}"; do
            mirror=$(echo "${mirror}" | xargs)  # 移除空白
            if [[ -n "${mirror}" ]]; then
                if [[ "${first}" == "true" ]]; then
                    first=false
                else
                    config_content+=','
                fi
                config_content+="
    \"${mirror}\""
            fi
        done
        config_content+='
  ]'
    fi

    # 新增代理設定（如果設定）
    if [[ -n "${PROXY_URL:-}" ]]; then
        config_content+=',
  "proxies": {
    "http-proxy": "'"${PROXY_URL}"'",
    "https-proxy": "'"${PROXY_URL}"'"'

        if [[ -n "${NO_PROXY:-}" ]]; then
            config_content+=',
    "no-proxy": "'"${NO_PROXY}"'"'
        fi

        config_content+='
  }'
    fi

    # 結束 JSON
    config_content+='
}'

    # 寫入配置檔案
    echo "${config_content}" > "${daemon_config}"

    if [[ -f "${daemon_config}" ]]; then
        success "Docker daemon 配置完成"
        debug "配置檔案: ${daemon_config}"

        # 驗證 JSON 格式
        if command -v jq &> /dev/null; then
            if jq empty "${daemon_config}" 2>> "${LOG_FILE}"; then
                debug "daemon.json 格式驗證通過"
            else
                warning "daemon.json 格式可能有誤"
            fi
        fi
    else
        error "Docker daemon 配置失敗"
        return 1
    fi
}

# 重新載入 Docker daemon
reload_docker_daemon() {
    info "重新載入 Docker daemon..."

    if grep -qi microsoft /proc/version; then
        # WSL 環境
        if command -v systemctl &> /dev/null && systemctl is-system-running &> /dev/null; then
            systemctl daemon-reload >> "${LOG_FILE}" 2>&1 || true
            systemctl restart docker >> "${LOG_FILE}" 2>&1 || warning "無法重新啟動 Docker"
        else
            service docker restart >> "${LOG_FILE}" 2>&1 || warning "無法重新啟動 Docker"
        fi
    else
        # 非 WSL 環境
        systemctl daemon-reload >> "${LOG_FILE}" 2>&1
        systemctl restart docker >> "${LOG_FILE}" 2>&1
    fi

    # 等待 Docker 服務就緒
    sleep 2

    success "Docker daemon 已重新載入"
}

# 驗證 Docker 安裝
verify_docker_installation() {
    info "驗證 Docker 安裝..."

    local failed=0

    # 檢查 Docker 命令
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        success "Docker: ${docker_version}"
    else
        error "Docker 命令未找到"
        ((failed++)) || true
    fi

    # 檢查 Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        success "Docker Compose: ${compose_version}"
    else
        warning "Docker Compose 未找到或無法執行"
    fi

    # 測試 Docker 運作
    info "執行 Docker 測試..."
    if timeout 30 docker run --rm hello-world >> "${LOG_FILE}" 2>&1; then
        success "Docker 運作測試通過"
    else
        warning "Docker 運作測試失敗"
        warning "這可能是正常的，某些環境需要重新登入才能使用 Docker"
        ((failed++)) || true
    fi

    # 檢查 Docker 服務狀態
    if grep -qi microsoft /proc/version; then
        if command -v systemctl &> /dev/null && systemctl is-system-running &> /dev/null; then
            if systemctl is-active docker &> /dev/null; then
                success "Docker 服務運作中"
            else
                warning "Docker 服務未運作"
            fi
        else
            if service docker status &> /dev/null 2>&1; then
                success "Docker 服務運作中"
            else
                warning "Docker 服務狀態不明"
            fi
        fi
    else
        if systemctl is-active docker &> /dev/null; then
            success "Docker 服務運作中"
        else
            error "Docker 服務未運作"
            ((failed++)) || true
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        success "Docker 安裝驗證通過"
        return 0
    else
        warning "Docker 驗證有 ${failed} 項失敗"
        return 1
    fi
}

# 顯示 Docker 資訊
show_docker_info() {
    info "Docker 系統資訊："

    if docker info >> "${LOG_FILE}" 2>&1; then
        echo "  Docker 根目錄: $(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo 'N/A')" | tee -a "${LOG_FILE}"
        echo "  儲存驅動: $(docker info --format '{{.Driver}}' 2>/dev/null || echo 'N/A')" | tee -a "${LOG_FILE}"
        echo "  映像數量: $(docker info --format '{{.Images}}' 2>/dev/null || echo '0')" | tee -a "${LOG_FILE}"
        echo "  容器數量: $(docker info --format '{{.Containers}}' 2>/dev/null || echo '0')" | tee -a "${LOG_FILE}"
    else
        warning "無法取得 Docker 資訊"
    fi
}

# 主要 Docker 安裝函式
install_docker() {
    print_header "安裝 Docker Engine"

    # 移除舊版本
    remove_old_docker

    # 安裝依賴
    install_docker_dependencies

    # 新增 GPG 金鑰
    add_docker_gpg_key

    # 新增套件來源
    add_docker_repository

    # 安裝 Docker Engine
    install_docker_engine

    # 配置 Docker daemon
    configure_docker_daemon

    # 設定 Docker 服務
    setup_docker_service

    # 設定使用者群組
    setup_docker_user_group

    # 重新載入 daemon
    reload_docker_daemon

    print_separator

    # 驗證安裝
    verify_docker_installation

    # 顯示 Docker 資訊
    show_docker_info

    success "Docker 安裝完成"
    INSTALL_STATUS["docker"]="success"

    print_separator
    info "Docker 使用提示："
    echo "  - 執行測試: docker run hello-world" | tee -a "${LOG_FILE}"
    echo "  - 檢查版本: docker --version" | tee -a "${LOG_FILE}"
    echo "  - 系統資訊: docker info" | tee -a "${LOG_FILE}"
    echo "  - 映像列表: docker images" | tee -a "${LOG_FILE}"
    echo "  - 容器列表: docker ps -a" | tee -a "${LOG_FILE}"

    local actual_user="${SUDO_USER:-$USER}"
    if [[ -n "${actual_user}" ]] && [[ "${actual_user}" != "root" ]]; then
        echo "" | tee -a "${LOG_FILE}"
        echo "  注意: 請重新登入或執行 'newgrp docker' 以套用群組變更" | tee -a "${LOG_FILE}"
    fi
}

# 匯出函式供主腳本使用
export -f remove_old_docker
export -f install_docker_dependencies
export -f add_docker_gpg_key
export -f add_docker_repository
export -f install_docker_engine
export -f setup_docker_service
export -f setup_docker_user_group
export -f configure_docker_daemon
export -f reload_docker_daemon
export -f verify_docker_installation
export -f show_docker_info
export -f install_docker
