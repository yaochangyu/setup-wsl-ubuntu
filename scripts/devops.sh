#!/bin/bash

###############################################################################
# DevOps 工具安裝模組
###############################################################################

install_devops_tools() {
    print_header "安裝 DevOps 工具"

    # kubectl
    if command -v kubectl &> /dev/null; then
        info "kubectl 已安裝，跳過"
    else
        info "安裝 kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >> "${LOG_FILE}" 2>&1
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm -f kubectl
    fi
    command -v kubectl &> /dev/null && success "kubectl: $(kubectl version --client --short 2>/dev/null | head -n1)"

    # Helm
    if command -v helm &> /dev/null; then
        info "Helm 已安裝，跳過"
    else
        info "安裝 Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >> "${LOG_FILE}" 2>&1
    fi
    command -v helm &> /dev/null && success "Helm: $(helm version --short)"

    # Terraform
    if command -v terraform &> /dev/null; then
        info "Terraform 已安裝，跳過"
    else
        info "安裝 Terraform..."
        rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.gpg
        curl -fsSL https://apt.releases.hashicorp.com/gpg -o /tmp/hashicorp.gpg
        gpg --batch --no-tty --dearmor --output /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.gpg
        rm -f /tmp/hashicorp.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
            tee /etc/apt/sources.list.d/hashicorp.list
        apt-get update -qq >> "${LOG_FILE}" 2>&1
        apt-get install -y terraform >> "${LOG_FILE}" 2>&1
    fi
    command -v terraform &> /dev/null && success "Terraform: $(terraform version | head -n1)"

    # Azure CLI
    if command -v az &> /dev/null; then
        info "Azure CLI 已安裝，跳過"
    else
        info "安裝 Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash >> "${LOG_FILE}" 2>&1
    fi
    command -v az &> /dev/null && success "Azure CLI: $(az version -o tsv | head -n1)"

    success "DevOps 工具安裝完成"
    INSTALL_STATUS["devops_tools"]="success"
}

export -f install_devops_tools
