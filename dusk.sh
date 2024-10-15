#!/bin/bash

# ===========================
# 自定义样式变量
# ===========================
# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 文本样式
BOLD='\033[1m'
UNDERLINE='\033[4m'

# 图标定义
INFO_ICON="ℹ️"
SUCCESS_ICON="✅"
WARNING_ICON="⚠️"
ERROR_ICON="❌"

# ===========================
# 信息显示函数
# ===========================

# 显示一般信息
log_info() {
    echo -e "${CYAN}${INFO_ICON} $1${NC}"
}

# 显示成功信息
log_success() {
    echo -e "${GREEN}${SUCCESS_ICON} $1${NC}"
}

# 显示警告信息
log_warning() {
    echo -e "${YELLOW}${WARNING_ICON} $1${NC}"
}

# 显示错误信息
log_error() {
    echo -e "${RED}${ERROR_ICON} $1${NC}"
}

# ===========================
# 脚本保存路径
# ===========================
SCRIPT_PATH="$HOME/Dusk.sh"

# ===========================
# 确保脚本以 root 权限运行
# ===========================
if [ "$(id -u)" -ne "0" ]; then
  log_error "请以 root 用户或使用 sudo 运行此脚本"
  exit 1
fi

# ===========================
# 启动节点函数
# ===========================
function start_node() {
    log_info "正在启动节点..."

    # 更新系统并安装必要的软件包
    log_info "更新系统并安装必要的软件包..."
    if ! sudo apt update && sudo apt upgrade -y && sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libclang-dev -y; then
        log_error "安装软件包失败。"
        exit 1
    fi

    # 下载并运行 node-installer.sh
    log_info "下载并运行 node-installer.sh..."
    if ! curl --proto '=https' --tlsv1.2 -sSfL https://github.com/dusk-network/node-installer/releases/download/v0.3.3/node-installer.sh | sudo sh; then
        log_error "下载或运行 node-installer.sh 失败。"
        exit 1
    fi

    # 运行 ruskreset 命令
    log_info "运行 ruskreset..."
    if ! ruskreset; then
        log_error "运行 ruskreset 失败。"
        exit 1
    fi

    # 安装 Rust 和 Cargo
    log_info "检查是否已安装 Rust 和 Cargo..."
    if ! command -v rustc &> /dev/null; then
        log_warning "未检测到 Rust，正在安装 Rust 和 Cargo..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        log_success "Rust 和 Cargo 已安装，跳过安装。"
    fi

    # 克隆 rusk 仓库
    if [ -d "rusk" ]; then
        log_warning "rusk 目录已存在，正在删除..."
        rm -rf rusk
    fi

    log_info "克隆 rusk 仓库..."
    if ! git clone https://github.com/dusk-network/rusk.git; then
        log_error "克隆 rusk 仓库失败。"
        exit 1
    fi

    # 进入 rusk-wallet 目录并安装
    cd rusk/rusk-wallet || { log_error "进入 rusk-wallet 目录失败。"; exit 1; }
    if ! make install; then
        log_error "安装 rusk-wallet 失败。"
        exit 1
    fi

    # 初始化钱包
    log_success "初始化钱包..."
    rusk-wallet

    # 导出共识密钥
    log_info "导出共识密钥..."
    rusk-wallet export -d /opt/dusk/conf -n consensus.keys

    # 设置共识密钥密码
    log_info "设置共识密钥密码..."
    sh /opt/dusk/bin/setup_consensus_pwd.sh

    # 启动 rusk 服务
    log_success "启动 rusk 服务..."
    if ! service rusk start; then
        log_error "启动 rusk 服务失败。"
        exit 1
    fi
    log_success "rusk 服务已成功启动。"

    # 返回主菜单
    read -p "$(log_info "按任意键返回主菜单...")"
}

# ===========================
# 质押 Dusk 函数
# ===========================
function stake_dusk() {
    read -p "$(log_info "请输入质押金额（默认最低 1000 Dusk）: ")" amt
    amt=${amt:-1000}  # 如果用户没有输入，则使用默认值 1000

    if ! rusk-wallet moonlight-stake --amt "$amt"; then
        log_error "质押 Dusk 失败。"
        exit 1
    fi
    log_success "成功质押 $amt Dusk。"

    # 返回主菜单
    read -p "$(log_info "按任意键返回主菜单...")"
}

# ===========================
# 检查质押信息函数
# ===========================
function check_stake_info() {
    log_info "检查质押信息..."
    if ! rusk-wallet stake-info; then
        log_error "检查质押信息失败。"
        exit 1
    fi
    # 返回主菜单
    read -p "$(log_info "按任意键返回主菜单...")"
}

# ===========================
# 查看日志函数
# ===========================
function view_logs() {
    log_info "查看 rusk 日志..."
    tail -F /var/log/rusk.log -n 50

    # 返回主菜单
    read -p "$(log_info "按任意键返回主菜单...")"
}

# ===========================
# 查看区块高度函数
# ===========================
function view_block_height() {
    log_info "查看区块高度..."
    if ! ruskquery block-height; then
        log_error "查看区块高度失败。"
    fi
    # 返回主菜单
    read -p "$(log_info "按任意键返回主菜单...")"
}

# ===========================
# 主菜单函数
# ===========================
function main_menu() {
    while true; do
        clear
        echo -e "${BOLD}${BLUE}欢迎使用 Dusk 节点管理脚本${NC}"
        echo -e "${BOLD}${BLUE}==============================================${NC}"
        log_info "请选择要执行的操作:"
        echo "1. 启动节点"
        echo "2. 查看区块高度"
        echo "3. 质押 Dusk"
        echo "4. 查看日志"
        echo "5. 检查质押信息"
        echo "6. 退出"

        read -p "$(log_info "请输入选项: ")" choice
        case $choice in
            1)
                start_node
                ;;
            2)
                view_block_height
                ;;
            3)
                stake_dusk
                ;;
            4)
                view_logs
                ;;
            5)
                check_stake_info
                ;;
            6)
                log_success "退出脚本..."
                exit 0
                ;;
            *)
                log_error "无效选项，请重试。"
                ;;
        esac
        read -p "$(log_info "按任意键继续...")"
    done
}

# ===========================
# 调用主菜单函数
# ===========================
main_menu
