#!/bin/bash

###############################################################################
# Vim 插件安裝模組
###############################################################################

install_vim_plugins() {
    print_header "安裝 Vim 插件"

    local actual_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~${actual_user})

    # vim-plug 已安裝則跳過
    if [[ -f "${user_home}/.vim/autoload/plug.vim" ]]; then
        info "vim-plug 已安裝，跳過"
    else
        info "安裝 vim-plug..."
        sudo -u "${actual_user}" bash -c 'curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' >> "${LOG_FILE}" 2>&1

        if [[ ! -f "${user_home}/.vim/autoload/plug.vim" ]]; then
            error "vim-plug 安裝失敗"
            return 1
        fi
        success "vim-plug 已安裝"
    fi

    # .vimrc 插件配置（已存在則跳過，避免重複寫入）
    if grep -q "plug#begin" "${user_home}/.vimrc" 2>/dev/null; then
        info "Vim 插件配置已存在，跳過"
    else
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
    fi

    success "Vim 插件配置完成"
    INSTALL_STATUS["vim_plugins"]="success"

    info "請執行 :PlugInstall 以安裝插件"
}

export -f install_vim_plugins
