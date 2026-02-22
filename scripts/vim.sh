#!/bin/bash

###############################################################################
# Vim 插件安裝模組
###############################################################################

install_vim_plugins() {
    print_header "安裝 Vim 插件"

    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    info "安裝 vim-plug..."

    # 安裝 vim-plug
    sudo -u "${actual_user}" bash -c 'curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' >> "${LOG_FILE}" 2>&1

    if [[ -f "${user_home}/.vim/autoload/plug.vim" ]]; then
        success "vim-plug 已安裝"
    else
        error "vim-plug 安裝失敗"
        return 1
    fi

    # 建立進階 .vimrc
    info "設定 Vim 插件配置..."
    sudo -u "${actual_user}" tee -a "${user_home}/.vimrc" > /dev/null <<'EOF'

" vim-plug 插件管理
call plug#begin('~/.vim/plugged')

" 常用插件
Plug 'preservim/nerdtree'          " 檔案樹
Plug 'vim-airline/vim-airline'     " 狀態列
Plug 'tpope/vim-fugitive'          " Git 整合

call plug#end()
EOF

    success "Vim 插件配置完成"
    INSTALL_STATUS["vim_plugins"]="success"

    info "請執行 :PlugInstall 以安裝插件"
}

export -f install_vim_plugins
