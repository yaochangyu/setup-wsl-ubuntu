#!/bin/bash

###############################################################################
# VS Code Server 故障排除腳本
###############################################################################

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 修復 VS Code Server WebSocket 錯誤 1006
fix_vscode_websocket_error() {
    echo "================================"
    echo "VS Code Server 故障排除"
    echo "================================"
    echo ""

    print_info "檢查 VS Code Server 狀態..."
    
    # 檢查 VS Code Server 進程
    if pgrep -f "vscode-server" > /dev/null; then
        print_warning "發現 VS Code Server 進程正在運行"
        print_info "清理舊進程..."
        pkill -f vscode-server
        sleep 2
        print_success "進程已清理"
    else
        print_info "沒有發現運行中的 VS Code Server 進程"
    fi

    # 檢查 VS Code Server 目錄
    if [ -d "$HOME/.vscode-server" ]; then
        print_info "VS Code Server 目錄存在"
        
        # 顯示目錄大小
        size=$(du -sh "$HOME/.vscode-server" 2>/dev/null | cut -f1)
        print_info "目錄大小: $size"
        
        # 詢問是否清除快取
        echo ""
        read -p "是否清除 VS Code Server 快取？(會保留擴充套件) [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "清除快取中..."
            rm -rf "$HOME/.vscode-server/data/"* 2>/dev/null
            print_success "快取已清除"
        fi
        
        # 詢問是否完全重裝
        echo ""
        read -p "是否完全重新安裝 VS Code Server？(會移除所有擴充套件) [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_warning "這將移除所有已安裝的擴充套件"
            read -p "確定要繼續嗎？[y/N] " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "移除 VS Code Server..."
                rm -rf "$HOME/.vscode-server"
                print_success "VS Code Server 已移除，下次執行 'code .' 時會自動重新安裝"
            fi
        fi
    else
        print_info "VS Code Server 尚未安裝"
    fi

    echo ""
    echo "================================"
    echo "故障排除步驟完成"
    echo "================================"
    echo ""
    print_info "接下來的操作："
    echo "  1. 在 Windows 端完全關閉所有 VS Code 視窗"
    echo "  2. 在 WSL 中執行: code ."
    echo "  3. 如果還是失敗，請檢查 Remote-WSL 擴充套件是否已安裝並啟用"
    echo ""
}

# 顯示診斷資訊
show_diagnostic_info() {
    echo "================================"
    echo "VS Code Server 診斷資訊"
    echo "================================"
    echo ""
    
    print_info "檢查 code 命令..."
    if command -v code &> /dev/null; then
        code_path=$(which code)
        print_success "code 命令: $code_path"
        code --version 2>/dev/null || print_warning "無法取得版本資訊"
    else
        print_error "code 命令不存在"
    fi
    
    echo ""
    print_info "檢查 VS Code Server 目錄..."
    if [ -d "$HOME/.vscode-server" ]; then
        print_success "目錄存在: $HOME/.vscode-server"
        ls -lh "$HOME/.vscode-server" 2>/dev/null
    else
        print_warning "目錄不存在: $HOME/.vscode-server"
    fi
    
    echo ""
    print_info "檢查運行中的進程..."
    if pgrep -fa "vscode-server" > /dev/null; then
        pgrep -fa "vscode-server"
    else
        print_info "沒有 VS Code Server 進程"
    fi
    
    echo ""
}

# 主選單
show_menu() {
    echo "================================"
    echo "VS Code Server 工具"
    echo "================================"
    echo "1) 顯示診斷資訊"
    echo "2) 修復 WebSocket 錯誤 (錯誤 1006)"
    echo "3) 清理進程"
    echo "4) 清除快取"
    echo "5) 完全重新安裝"
    echo "0) 退出"
    echo "================================"
    read -p "請選擇操作 [0-5]: " choice
    
    case $choice in
        1)
            show_diagnostic_info
            ;;
        2)
            fix_vscode_websocket_error
            ;;
        3)
            print_info "清理 VS Code Server 進程..."
            pkill -f vscode-server
            print_success "完成"
            ;;
        4)
            print_info "清除快取..."
            rm -rf "$HOME/.vscode-server/data/"*
            print_success "完成"
            ;;
        5)
            print_warning "這將移除所有已安裝的擴充套件"
            read -p "確定要繼續嗎？[y/N] " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "移除 VS Code Server..."
                rm -rf "$HOME/.vscode-server"
                print_success "完成"
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            print_error "無效的選擇"
            ;;
    esac
}

# 執行
if [ "$1" = "--fix" ]; then
    fix_vscode_websocket_error
elif [ "$1" = "--info" ]; then
    show_diagnostic_info
else
    show_menu
fi
