#!/bin/bash
# ============================================================
# LinuxDO 签到 - ARM 设备安装脚本
# 适用于: 树莓派、Orange Pi、ARM 服务器等
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() { echo -e "${BLUE}[信息]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }

# 检测系统架构
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        aarch64|arm64)
            print_success "检测到 ARM64 架构"
            IS_ARM=true
            ;;
        armv7l|armhf)
            print_warning "检测到 ARM32 架构（armv7）"
            print_warning "ARM32 支持有限，建议使用 ARM64 系统"
            IS_ARM=true
            ;;
        x86_64|amd64)
            print_info "检测到 x86_64 架构"
            IS_ARM=false
            ;;
        *)
            print_error "未知架构: $ARCH"
            exit 1
            ;;
    esac
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_info "操作系统: $PRETTY_NAME"
    else
        print_error "无法检测操作系统"
        exit 1
    fi
}

# 检测是否为树莓派
detect_raspberry_pi() {
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(cat /proc/device-tree/model)
        if [[ "$MODEL" == *"Raspberry Pi"* ]]; then
            print_success "检测到树莓派: $MODEL"
            IS_RASPBERRY_PI=true
            return
        fi
    fi
    IS_RASPBERRY_PI=false
}

# 安装系统依赖
install_dependencies() {
    print_info "安装系统依赖..."

    case $OS in
        debian|ubuntu|raspbian)
            sudo apt-get update
            sudo apt-get install -y \
                python3 \
                python3-pip \
                python3-venv \
                chromium-browser \
                chromium-chromedriver \
                xvfb \
                fonts-wqy-zenhei \
                fonts-wqy-microhei \
                libatk1.0-0 \
                libatk-bridge2.0-0 \
                libcups2 \
                libdrm2 \
                libxkbcommon0 \
                libxcomposite1 \
                libxdamage1 \
                libxfixes3 \
                libxrandr2 \
                libgbm1 \
                libasound2
            ;;
        alpine)
            sudo apk update
            sudo apk add \
                python3 \
                py3-pip \
                chromium \
                chromium-chromedriver \
                xvfb \
                font-wqy-zenhei \
                ttf-wqy-zenhei
            ;;
        arch|manjaro)
            sudo pacman -Syu --noconfirm \
                python \
                python-pip \
                chromium \
                xorg-server-xvfb \
                wqy-zenhei
            ;;
        fedora|centos|rhel)
            sudo dnf install -y \
                python3 \
                python3-pip \
                chromium \
                chromedriver \
                xorg-x11-server-Xvfb \
                wqy-zenhei-fonts
            ;;
        *)
            print_error "不支持的操作系统: $OS"
            print_info "请手动安装: Python 3.8+, Chromium, Xvfb"
            ;;
    esac

    print_success "系统依赖安装完成"
}

# 安装 Python 依赖
install_python_deps() {
    print_info "安装 Python 依赖..."

    # 创建虚拟环境（推荐）
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "创建虚拟环境: venv/"
    fi

    # 激活虚拟环境
    source venv/bin/activate

    # 升级 pip
    pip install --upgrade pip

    # 安装依赖
    pip install -r requirements.txt

    print_success "Python 依赖安装完成"
}

# 配置 Chromium 路径
configure_chromium() {
    print_info "配置 Chromium 路径..."

    # 查找 Chromium 可执行文件
    CHROMIUM_PATHS=(
        "/usr/bin/chromium-browser"
        "/usr/bin/chromium"
        "/usr/lib/chromium/chromium"
        "/snap/bin/chromium"
    )

    CHROMIUM_PATH=""
    for path in "${CHROMIUM_PATHS[@]}"; do
        if [ -x "$path" ]; then
            CHROMIUM_PATH=$path
            break
        fi
    done

    if [ -z "$CHROMIUM_PATH" ]; then
        print_error "未找到 Chromium，请手动安装"
        exit 1
    fi

    print_success "Chromium 路径: $CHROMIUM_PATH"

    # 更新配置文件
    if [ -f "config.yaml" ]; then
        # 检查是否已配置
        if grep -q "browser_path:" config.yaml; then
            sed -i "s|browser_path:.*|browser_path: \"$CHROMIUM_PATH\"|" config.yaml
        else
            echo "browser_path: \"$CHROMIUM_PATH\"" >> config.yaml
        fi
        print_success "已更新 config.yaml"
    fi
}

# 创建用户数据目录
create_user_data_dir() {
    USER_DATA_DIR="$HOME/.linuxdo-browser"
    mkdir -p "$USER_DATA_DIR"
    chmod 755 "$USER_DATA_DIR"
    print_success "用户数据目录: $USER_DATA_DIR"
}

# 测试 Chromium
test_chromium() {
    print_info "测试 Chromium..."

    # 使用 xvfb-run 测试
    if command -v xvfb-run &> /dev/null; then
        xvfb-run -a $CHROMIUM_PATH --version
        print_success "Chromium 测试通过"
    else
        $CHROMIUM_PATH --version
        print_warning "Xvfb 未安装，无头模式可能无法使用"
    fi
}

# 树莓派特殊优化
raspberry_pi_optimize() {
    if [ "$IS_RASPBERRY_PI" = true ]; then
        print_info "应用树莓派优化..."

        # 增加 GPU 内存（如果是树莓派）
        if [ -f /boot/config.txt ]; then
            if ! grep -q "gpu_mem=" /boot/config.txt; then
                print_warning "建议在 /boot/config.txt 中添加: gpu_mem=128"
            fi
        fi

        # 创建 swap（如果内存不足）
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt 2048 ]; then
            print_warning "内存较小 (${TOTAL_MEM}MB)，建议增加 swap"
            print_info "运行: sudo dphys-swapfile swapoff && sudo nano /etc/dphys-swapfile"
            print_info "设置 CONF_SWAPSIZE=2048，然后运行: sudo dphys-swapfile setup && sudo dphys-swapfile swapon"
        fi

        print_success "树莓派优化提示完成"
    fi
}

# 设置定时任务
setup_cron() {
    print_info "设置定时任务..."

    SCRIPT_DIR=$(pwd)
    PYTHON_PATH="$SCRIPT_DIR/venv/bin/python"

    # 检查是否已存在任务
    if crontab -l 2>/dev/null | grep -q "linuxdo-checkin"; then
        print_warning "已存在 LinuxDO 签到任务，跳过"
        return
    fi

    # 添加 cron 任务
    (crontab -l 2>/dev/null; echo "# LinuxDO 签到任务") | crontab -
    (crontab -l 2>/dev/null; echo "0 8 * * * cd $SCRIPT_DIR && xvfb-run -a $PYTHON_PATH reminder.py >> logs/reminder.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "1 8 * * * cd $SCRIPT_DIR && xvfb-run -a $PYTHON_PATH main.py >> logs/checkin.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 20 * * * cd $SCRIPT_DIR && xvfb-run -a $PYTHON_PATH reminder.py >> logs/reminder.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "1 20 * * * cd $SCRIPT_DIR && xvfb-run -a $PYTHON_PATH main.py >> logs/checkin.log 2>&1") | crontab -

    print_success "定时任务设置完成"
    print_info "查看任务: crontab -l | grep linuxdo"
}

# 显示菜单
show_menu() {
    echo ""
    echo "========================================"
    echo "LinuxDO 签到 - ARM 设备安装脚本"
    echo "========================================"
    echo ""
    echo "系统信息:"
    echo "  架构: $(uname -m)"
    echo "  系统: $PRETTY_NAME"
    if [ "$IS_RASPBERRY_PI" = true ]; then
        echo "  设备: $MODEL"
    fi
    echo ""
    echo "请选择操作:"
    echo "  1. 完整安装（推荐）"
    echo "  2. 仅安装系统依赖"
    echo "  3. 仅安装 Python 依赖"
    echo "  4. 配置 Chromium 路径"
    echo "  5. 测试 Chromium"
    echo "  6. 设置定时任务"
    echo "  7. 首次登录"
    echo "  8. 运行签到"
    echo "  9. 查看系统信息"
    echo "  0. 退出"
    echo ""
}

# 首次登录
first_login() {
    print_info "启动首次登录..."

    if [ -d "venv" ]; then
        source venv/bin/activate
    fi

    # 检查是否有图形界面
    if [ -z "$DISPLAY" ]; then
        print_warning "未检测到图形界面"
        echo ""
        echo "首次登录需要图形界面来手动操作浏览器登录。"
        echo ""
        echo "请选择以下方式之一："
        echo ""
        echo "  方式1: VNC 远程桌面（推荐）"
        echo "    1) 在 ARM 设备上安装 VNC: sudo apt install tigervnc-standalone-server"
        echo "    2) 启动 VNC: vncserver :1"
        echo "    3) 用 VNC 客户端连接后，在 VNC 桌面中运行本脚本"
        echo ""
        echo "  方式2: SSH X11 转发"
        echo "    1) 在本地电脑安装 X Server (Windows: VcXsrv/Xming, Mac: XQuartz)"
        echo "    2) SSH 连接时加 -X 参数: ssh -X user@arm-device"
        echo "    3) 设置 DISPLAY: export DISPLAY=localhost:10.0"
        echo "    4) 重新运行本脚本"
        echo ""
        echo "  方式3: 直接连接显示器"
        echo "    将 ARM 设备连接到显示器，在本地桌面环境中运行"
        echo ""
        echo "  方式4: 在其他电脑完成首次登录"
        echo "    1) 在有图形界面的电脑上运行首次登录"
        echo "    2) 将 ~/.linuxdo-browser 目录复制到 ARM 设备"
        echo "    3) 之后的自动签到可以在 ARM 设备上无头运行"
        echo ""
        read -p "按 Enter 返回主菜单..."
        return
    fi

    python3 main.py --first-login
}

# 运行签到
run_checkin() {
    print_info "运行签到..."

    if [ -d "venv" ]; then
        source venv/bin/activate
    fi

    if command -v xvfb-run &> /dev/null; then
        xvfb-run -a python3 main.py
    else
        python3 main.py
    fi
}

# 显示系统信息
show_system_info() {
    echo ""
    echo "========================================"
    echo "系统信息"
    echo "========================================"
    echo ""
    echo "架构: $(uname -m)"
    echo "内核: $(uname -r)"
    echo "系统: $PRETTY_NAME"
    echo ""
    echo "CPU:"
    if [ -f /proc/cpuinfo ]; then
        grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2
        echo "核心数: $(nproc)"
    fi
    echo ""
    echo "内存:"
    free -h | head -2
    echo ""
    echo "磁盘:"
    df -h / | tail -1
    echo ""
    if [ "$IS_RASPBERRY_PI" = true ]; then
        echo "树莓派信息:"
        echo "  型号: $MODEL"
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
            echo "  温度: $((TEMP/1000))°C"
        fi
    fi
    echo ""
}

# 完整安装
full_install() {
    print_info "开始完整安装..."
    echo ""

    install_dependencies
    install_python_deps
    configure_chromium
    create_user_data_dir
    test_chromium
    raspberry_pi_optimize

    echo ""
    print_success "========================================"
    print_success "安装完成！"
    print_success "========================================"
    echo ""
    print_info "下一步:"
    print_info "  1. 运行首次登录: ./scripts/setup_arm.sh 然后选择 7"
    print_info "  2. 设置定时任务: ./scripts/setup_arm.sh 然后选择 6"
    echo ""
}

# 主函数
main() {
    # 检测环境
    detect_arch
    detect_os
    detect_raspberry_pi

    # 创建日志目录
    mkdir -p logs

    # 如果有参数，直接执行
    case "$1" in
        install)
            full_install
            exit 0
            ;;
        deps)
            install_dependencies
            exit 0
            ;;
        python)
            install_python_deps
            exit 0
            ;;
        cron)
            setup_cron
            exit 0
            ;;
        login)
            first_login
            exit 0
            ;;
        run)
            run_checkin
            exit 0
            ;;
    esac

    # 交互式菜单
    while true; do
        show_menu
        read -p "请输入选项 [0-9]: " choice

        case $choice in
            1) full_install ;;
            2) install_dependencies ;;
            3) install_python_deps ;;
            4) configure_chromium ;;
            5) test_chromium ;;
            6) setup_cron ;;
            7) first_login ;;
            8) run_checkin ;;
            9) show_system_info ;;
            0)
                print_info "退出"
                exit 0
                ;;
            *)
                print_error "无效选项"
                ;;
        esac

        echo ""
        read -p "按 Enter 继续..."
    done
}

# 运行主函数
main "$@"
