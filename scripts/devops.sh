#!/bin/bash

###############################################################################
# DevOps 工具安裝模組
###############################################################################

install_devops_tools() {
    print_header "安裝 DevOps 工具"

    # kubectl
    info "安裝 kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >> "${LOG_FILE}" 2>&1
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl

    if command -v kubectl &> /dev/null; then
        success "kubectl: $(kubectl version --client --short 2>/dev/null | head -n1)"
    fi

    # Helm
    info "安裝 Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >> "${LOG_FILE}" 2>&1

    if command -v helm &> /dev/null; then
        success "Helm: $(helm version --short)"
    fi

    # Terraform
    info "安裝 Terraform..."
    rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.gpg
    curl -fsSL https://apt.releases.hashicorp.com/gpg -o /tmp/hashicorp.gpg
    gpg --batch --no-tty --dearmor --output /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.gpg
    rm -f /tmp/hashicorp.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/hashicorp.list
    apt-get update -qq >> "${LOG_FILE}" 2>&1
    apt-get install -y terraform >> "${LOG_FILE}" 2>&1

    if command -v terraform &> /dev/null; then
        success "Terraform: $(terraform version | head -n1)"
    fi

    # Azure CLI
    info "安裝 Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash >> "${LOG_FILE}" 2>&1

    if command -v az &> /dev/null; then
        success "Azure CLI: $(az version -o tsv | head -n1)"
    fi

    success "DevOps 工具安裝完成"
    INSTALL_STATUS["devops_tools"]="success"
}

export -f install_devops_tools
