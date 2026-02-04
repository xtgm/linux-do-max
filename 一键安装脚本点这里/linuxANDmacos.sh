#!/bin/bash
# ============================================================
# LinuxDO 签到 - Linux/macOS 一键安装脚本
# 使用方法: chmod +x install.sh && ./install.sh
# ============================================================

set -e

VERSION="1.4.0"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${GREEN}LinuxDO 签到一键安装脚本 v${VERSION}${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}[信息]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }

# 自动切换到项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 检测系统
detect_system() {
    print_info "检测系统环境..."

    OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$OS_TYPE" in
        linux*)
            OS_NAME="Linux"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO=$ID
                DISTRO_NAME=$PRETTY_NAME
            fi
            ;;
        darwin*)
            OS_NAME="macOS"
            DISTRO="macos"
            ;;
        *)
            OS_NAME="Unknown"
            ;;
    esac

    # 架构
    case "$ARCH" in
        x86_64|amd64) ARCH_TYPE="x64" ;;
        aarch64|arm64) ARCH_TYPE="arm64"; IS_ARM=true ;;
        armv7*|armhf) ARCH_TYPE="arm32"; IS_ARM=true ;;
        *) ARCH_TYPE="$ARCH" ;;
    esac

    # 包管理器
    if command -v apt-get &>/dev/null; then PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then PKG_MGR="yum"
    elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
    elif command -v apk &>/dev/null; then PKG_MGR="apk"
    elif command -v zypper &>/dev/null; then PKG_MGR="zypper"
    elif command -v brew &>/dev/null; then PKG_MGR="brew"
    fi

    # 图形界面
    HAS_DISPLAY=false
    [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ] && HAS_DISPLAY=true

    # 树莓派
    IS_RPI=false
    [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null && IS_RPI=true

    # ARM 设备显示
    ARM_DISPLAY="否"
    [ "$IS_ARM" = true ] && ARM_DISPLAY="是"

    # 图形界面显示
    GUI_DISPLAY="否"
    [ "$HAS_DISPLAY" = true ] && GUI_DISPLAY="有"

    echo ""
    echo "┌─────────────────────────────────────┐"
    echo "│        系统环境检测结果             │"
    echo "├─────────────────────────────────────┤"

    # 格式化输出函数（处理中文宽度问题）
    # 标签固定11字符宽度，值固定20字符宽度
    print_row() {
        local label="$1"
        local value="$2"
        # 计算值的显示宽度（中文算2，ASCII算1）
        local val_display_width=$(echo -n "$value" | awk '{
            w=0
            for(i=1;i<=length($0);i++) {
                c=substr($0,i,1)
                if(c~/[\x00-\x7f]/) w+=1
                else w+=2
            }
            print w
        }')
        # 需要补充的空格数
        local padding=$((20 - val_display_width))
        [ $padding -lt 0 ] && padding=0
        local spaces=$(printf "%${padding}s" "")
        echo "│ ${label}${value}${spaces}  │"
    }

    print_row "操作系统   " "$OS_NAME"
    print_row "架构       " "$ARCH ($ARCH_TYPE)"
    [ -n "$DISTRO" ] && print_row "发行版     " "$DISTRO"
    [ -n "$PKG_MGR" ] && print_row "包管理器   " "$PKG_MGR"
    print_row "ARM设备    " "$ARM_DISPLAY"
    print_row "图形界面   " "$GUI_DISPLAY"

    echo "└─────────────────────────────────────┘"
    echo ""
}

# 获取浏览器路径（只检测 Google Chrome，不检测 Snap Chromium）
get_browser_path() {
    # 优先检测 Google Chrome
    for p in /usr/bin/google-chrome /usr/bin/google-chrome-stable; do
        [ -x "$p" ] && echo "$p" && return 0
    done

    # macOS
    if [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
        echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        return 0
    fi

    # 尝试 which 命令（只找 google-chrome）
    for cmd in google-chrome google-chrome-stable; do
        p=$(which "$cmd" 2>/dev/null)
        [ -n "$p" ] && [ -x "$p" ] && echo "$p" && return 0
    done

    # ARM 设备：允许使用 apt 安装的 chromium（非 Snap）
    if [ "$IS_ARM" = true ]; then
        # 检查是否是 Snap 版本
        for p in /usr/bin/chromium-browser /usr/bin/chromium; do
            if [ -x "$p" ]; then
                # 检查是否是 Snap 符号链接
                if ! readlink -f "$p" 2>/dev/null | grep -q "snap"; then
                    echo "$p"
                    return 0
                fi
            fi
        done
    fi

    return 1
}

# 验证浏览器安装
verify_browser_install() {
    print_info "验证浏览器安装..."

    BROWSER_PATH=$(get_browser_path)
    if [ -z "$BROWSER_PATH" ]; then
        print_error "未检测到浏览器！"
        return 1
    fi

    print_success "检测到浏览器: $BROWSER_PATH"

    # 获取版本号
    BROWSER_VERSION=$("$BROWSER_PATH" --version 2>/dev/null | head -1)
    if [ -n "$BROWSER_VERSION" ]; then
        print_info "浏览器版本: $BROWSER_VERSION"
    fi

    return 0
}

# 测试浏览器启动（打开可见窗口）
test_browser_launch() {
    print_info "测试浏览器启动..."

    BROWSER_PATH=$(get_browser_path)
    if [ -z "$BROWSER_PATH" ]; then
        print_error "未检测到浏览器，无法测试"
        return 1
    fi

    print_info "即将打开浏览器窗口，请确认浏览器能正常显示..."
    echo ""

    # 构建启动参数（有界面模式）
    LAUNCH_ARGS="--no-sandbox --disable-dev-shm-usage --disable-gpu"
    TEST_URL="https://www.google.com"

    # 启动浏览器（后台运行）
    "$BROWSER_PATH" $LAUNCH_ARGS "$TEST_URL" &
    BROWSER_PID=$!

    echo ""
    print_info "浏览器已启动 (PID: $BROWSER_PID)"
    print_info "如果看到 Google 搜索页面，说明浏览器正常工作"
    echo ""

    read -p "浏览器是否正常显示？[Y/n]: " BROWSER_OK

    # 关闭测试浏览器
    kill $BROWSER_PID 2>/dev/null
    wait $BROWSER_PID 2>/dev/null

    if [ "$BROWSER_OK" = "n" ] || [ "$BROWSER_OK" = "N" ]; then
        print_error "浏览器启动测试失败！"
        print_info "请检查浏览器安装或图形界面配置"
        return 1
    fi

    print_success "浏览器启动测试通过！"
    return 0
}

# 安装依赖
install_deps() {
    print_info "安装系统依赖..."

    case "$PKG_MGR" in
        apt)
            sudo apt-get update
            # 先安装基础依赖
            sudo apt-get install -y python3 python3-pip python3-venv python3-dev \
                xvfb fonts-wqy-zenhei fonts-wqy-microhei \
                libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
                libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
                libxrandr2 libgbm1 libasound2 wget curl gnupg 2>/dev/null || true

            # 安装 Google Chrome（通过官方 apt 源，不使用 Snap）
            if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
                print_info "检测到 Google Chrome，跳过安装"
            else
                print_info "安装 Google Chrome（通过官方 apt 源）..."

                # 根据架构选择安装方式
                if [ "$ARCH_TYPE" = "arm64" ]; then
                    print_warning "ARM64 架构暂不支持 Google Chrome，尝试安装 Chromium..."
                    # ARM64 使用 apt 版 chromium（非 Snap）
                    sudo apt-get install -y chromium-browser 2>/dev/null || \
                    sudo apt-get install -y chromium 2>/dev/null || true
                else
                    # x64 架构：添加 Google 官方 apt 源
                    print_info "添加 Google Chrome 官方源..."

                    # 添加 Google 签名密钥
                    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg 2>/dev/null

                    # 添加 apt 源
                    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null

                    # 更新并安装
                    sudo apt-get update
                    sudo apt-get install -y google-chrome-stable

                    # 验证安装
                    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
                        print_success "Google Chrome 安装成功"
                    else
                        print_error "Google Chrome 安装失败！"
                        print_info "请手动安装："
                        print_info "  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
                        print_info "  sudo dpkg -i google-chrome-stable_current_amd64.deb"
                        print_info "  sudo apt-get install -f -y"
                    fi
                fi
            fi
            # 刷新字体缓存
            fc-cache -fv 2>/dev/null || true
            ;;
        dnf)
            sudo dnf install -y python3 python3-pip python3-virtualenv python3-devel || true
            # Fedora/RHEL: 安装 Google Chrome
            if ! command -v google-chrome &>/dev/null; then
                print_info "安装 Google Chrome..."
                sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm 2>/dev/null || \
                sudo dnf install -y chromium 2>/dev/null || true
            fi
            sudo dnf install -y xorg-x11-server-Xvfb wqy-zenhei-fonts wqy-microhei-fonts || true
            fc-cache -fv 2>/dev/null || true
            ;;
        yum)
            sudo yum install -y python3 python3-pip python3-virtualenv python3-devel || true
            # CentOS/RHEL: 安装 Google Chrome
            if ! command -v google-chrome &>/dev/null; then
                print_info "安装 Google Chrome..."
                sudo yum install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm 2>/dev/null || \
                sudo yum install -y chromium 2>/dev/null || true
            fi
            sudo yum install -y xorg-x11-server-Xvfb wqy-zenhei-fonts wqy-microhei-fonts || true
            fc-cache -fv 2>/dev/null || true
            ;;
        pacman)
            sudo pacman -Syu --noconfirm python python-pip python-virtualenv || true
            # Arch: google-chrome 在 AUR，使用 chromium
            sudo pacman -Syu --noconfirm chromium xorg-server-xvfb wqy-zenhei wqy-microhei || true
            fc-cache -fv 2>/dev/null || true
            ;;
        apk)
            # Alpine: python3-dev 包含 venv 模块
            sudo apk add python3 py3-pip python3-dev || true
            sudo apk add chromium chromium-chromedriver xvfb font-wqy-zenhei ttf-wqy-zenhei font-noto-cjk || true
            fc-cache -fv 2>/dev/null || true
            ;;
        zypper)
            sudo zypper install -y python3 python3-pip python3-virtualenv python3-devel || true
            # openSUSE: 安装 Google Chrome
            if ! command -v google-chrome &>/dev/null; then
                print_info "安装 Google Chrome..."
                sudo zypper install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm 2>/dev/null || \
                sudo zypper install -y chromium 2>/dev/null || true
            fi
            sudo zypper install -y xvfb-run google-noto-sans-cjk-fonts || true
            fc-cache -fv 2>/dev/null || true
            ;;
        brew)
            brew install python3 || true
            # macOS: 检查并安装 Chrome
            if [ ! -d "/Applications/Google Chrome.app" ]; then
                print_info "安装 Google Chrome..."
                brew install --cask google-chrome 2>/dev/null || \
                print_warning "请手动安装 Chrome: https://www.google.com/chrome/"
            fi
            ;;
        *)
            print_warning "未知包管理器，请手动安装: Python3, pip, venv, Google Chrome, Xvfb"
            ;;
    esac

    print_success "系统依赖安装完成"
}

# 验证并测试浏览器（在 Python 环境配置完成后调用）
verify_and_test_browser() {
    echo ""
    print_info "========== 浏览器验证 =========="
    echo ""

    # 验证浏览器安装
    if ! verify_browser_install; then
        print_error "未检测到 Google Chrome！"
        print_info "Snap 版 Chromium 不支持，必须安装 Google Chrome"
        echo ""
        print_info "请手动安装 Google Chrome:"
        echo "  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
        echo "  sudo dpkg -i google-chrome-stable_current_amd64.deb"
        echo "  sudo apt-get install -f -y"
        echo ""
        read -p "是否继续安装？[y/N]: " CONTINUE
        [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ] && return 1
        return 0
    fi

    # 测试浏览器启动
    echo ""
    test_browser_launch
    echo ""
    return 0
}

# Python 环境
setup_python() {
    print_info "配置 Python 环境..."

    [ ! -d "venv" ] && python3 -m venv venv

    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt

    print_success "Python 环境配置完成"
}

# 交互式配置
interactive_config() {
    print_info "配置向导..."
    echo ""

    if [ -f "config.yaml" ]; then
        echo -e "${YELLOW}检测到已有配置文件${NC}"
        read -p "是否重新配置？[y/N]: " RECONFIG
        [ "$RECONFIG" != "y" ] && [ "$RECONFIG" != "Y" ] && return
    fi

    echo ""
    echo "=== 基本配置 ==="
    read -p "Linux.do 用户名 (可选，按 Enter 跳过): " USERNAME
    [ -n "$USERNAME" ] && read -p "Linux.do 密码 (可选): " PASSWORD

    read -p "浏览帖子数量 [10]: " BROWSE_COUNT
    BROWSE_COUNT=${BROWSE_COUNT:-10}

    read -p "点赞概率 (0-1) [0.3]: " LIKE_PROB
    LIKE_PROB=${LIKE_PROB:-0.3}

    if [ "$HAS_DISPLAY" = true ]; then
        HEADLESS_DEFAULT="false"
    else
        HEADLESS_DEFAULT="true"
    fi
    read -p "无头模式 (true/false) [$HEADLESS_DEFAULT]: " HEADLESS
    HEADLESS=${HEADLESS:-$HEADLESS_DEFAULT}

    echo ""
    echo "=== Telegram 通知 (可选) ==="
    read -p "Bot Token (按 Enter 跳过): " TG_TOKEN
    [ -n "$TG_TOKEN" ] && read -p "Chat ID: " TG_CHAT_ID

    USER_DATA_DIR="$HOME/.linuxdo-browser"
    read -p "用户数据目录 [$USER_DATA_DIR]: " INPUT_DIR
    USER_DATA_DIR=${INPUT_DIR:-$USER_DATA_DIR}

    # 检测浏览器（只使用 Google Chrome，不使用 Snap Chromium）
    BROWSER_PATH=""
    for p in /usr/bin/google-chrome /usr/bin/google-chrome-stable \
             "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
        [ -x "$p" ] && BROWSER_PATH="$p" && break
    done

    # 如果没找到，尝试 which 命令（只找 google-chrome）
    if [ -z "$BROWSER_PATH" ]; then
        for cmd in google-chrome google-chrome-stable; do
            p=$(which "$cmd" 2>/dev/null)
            if [ -n "$p" ] && [ -x "$p" ]; then
                # 排除 Snap 版本
                real_path=$(readlink -f "$p" 2>/dev/null || echo "$p")
                if ! echo "$real_path" | grep -q "snap"; then
                    BROWSER_PATH="$p"
                    break
                fi
            fi
        done
    fi

    if [ -z "$BROWSER_PATH" ]; then
        print_error "未检测到 Google Chrome！"
        print_info "请确保已安装 Google Chrome"
    fi

    # Linux 系统自动添加必要的 Chrome 参数
    CHROME_ARGS=""
    IS_CONTAINER=false
    if [ -f "/.dockerenv" ] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null || \
       [ -f "/run/.containerenv" ] || systemd-detect-virt -c &>/dev/null; then
        IS_CONTAINER=true
    fi

    if [ "$OS_NAME" = "Linux" ]; then
        print_info "Linux 系统将自动添加浏览器兼容参数"
        if [ "$IS_CONTAINER" = true ]; then
            print_warning "检测到容器环境"
        fi
        CHROME_ARGS_LIST="--no-sandbox,--disable-dev-shm-usage,--disable-gpu"
    fi

    # 生成配置
    cat > config.yaml << EOF
# LinuxDO 签到配置文件
# 由一键安装脚本自动生成

username: "$USERNAME"
password: "$PASSWORD"
user_data_dir: "$USER_DATA_DIR"
headless: $HEADLESS
browser_path: "$BROWSER_PATH"
browse_count: $BROWSE_COUNT
like_probability: $LIKE_PROB
browse_interval_min: 15
browse_interval_max: 30
tg_bot_token: "$TG_TOKEN"
tg_chat_id: "$TG_CHAT_ID"

# Chrome 额外启动参数
chrome_args:
$(if [ -n "$CHROME_ARGS_LIST" ]; then
    echo "$CHROME_ARGS_LIST" | tr ',' '\n' | while read arg; do
        echo "  - \"$arg\""
    done
else
    echo "  []"
fi)
EOF

    mkdir -p "$USER_DATA_DIR"
    print_success "配置已保存: config.yaml"
}

# 设置定时任务
setup_cron() {
    read -p "是否设置定时任务？[y/N]: " SETUP
    [ "$SETUP" != "y" ] && [ "$SETUP" != "Y" ] && return

    PROJECT_DIR=$(pwd)
    PYTHON_PATH="$PROJECT_DIR/venv/bin/python"

    echo ""
    echo "选择签到时间:"
    echo "  1. 每天 8:00 和 20:00（推荐）"
    echo "  2. 每天 9:00"
    echo "  3. 自定义时间"
    read -p "请选择 [1-3]: " time_choice

    if [ "$OS_NAME" = "macOS" ]; then
        # macOS launchd
        PLIST="$HOME/Library/LaunchAgents/com.linuxdo.checkin.plist"

        case $time_choice in
            1)
                cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.linuxdo.checkin</string>
    <key>ProgramArguments</key>
    <array><string>$PYTHON_PATH</string><string>$PROJECT_DIR/main.py</string></array>
    <key>WorkingDirectory</key><string>$PROJECT_DIR</string>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
    </array>
</dict>
</plist>
EOF
                ;;
            2)
                cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.linuxdo.checkin</string>
    <key>ProgramArguments</key>
    <array><string>$PYTHON_PATH</string><string>$PROJECT_DIR/main.py</string></array>
    <key>WorkingDirectory</key><string>$PROJECT_DIR</string>
    <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
</dict>
</plist>
EOF
                ;;
            3)
                read -p "输入时间 (格式 HH:MM，如 08:00): " custom_time
                HOUR=$(echo "$custom_time" | cut -d: -f1 | sed 's/^0//')
                MINUTE=$(echo "$custom_time" | cut -d: -f2 | sed 's/^0//')
                cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.linuxdo.checkin</string>
    <key>ProgramArguments</key>
    <array><string>$PYTHON_PATH</string><string>$PROJECT_DIR/main.py</string></array>
    <key>WorkingDirectory</key><string>$PROJECT_DIR</string>
    <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>$HOUR</integer><key>Minute</key><integer>$MINUTE</integer></dict>
</dict>
</plist>
EOF
                ;;
        esac

        launchctl unload "$PLIST" 2>/dev/null || true
        launchctl load "$PLIST"
        print_success "macOS 定时任务已设置"
        echo "[提示] 查看任务: launchctl list | grep linuxdo"
        echo "[提示] 删除任务: launchctl unload $PLIST"
    else
        # Linux cron
        mkdir -p "$PROJECT_DIR/logs"

        # 移除旧的 cron 任务
        crontab -l 2>/dev/null | grep -v "linuxdo" | grep -v "LinuxDO" > /tmp/crontab.tmp || true

        # 构建 cron 命令
        if [ "$HAS_DISPLAY" = true ]; then
            DISPLAY_VAR="${DISPLAY:-:0}"
            CRON_CMD="DISPLAY=$DISPLAY_VAR $PYTHON_PATH main.py >> logs/checkin.log 2>&1"
            print_info "检测到图形界面 (DISPLAY=$DISPLAY_VAR)，将直接运行浏览器"
        else
            if command -v xvfb-run &>/dev/null; then
                CRON_CMD="xvfb-run -a $PYTHON_PATH main.py >> logs/checkin.log 2>&1"
                print_info "无图形界面，将使用 xvfb-run 运行"
            else
                CRON_CMD="$PYTHON_PATH main.py >> logs/checkin.log 2>&1"
                print_warning "未安装 xvfb-run，建议在 config.yaml 中设置 headless: true"
            fi
        fi

        case $time_choice in
            1)
                echo "# LinuxDO签到 - 08:00" >> /tmp/crontab.tmp
                echo "0 8 * * * cd $PROJECT_DIR && $CRON_CMD" >> /tmp/crontab.tmp
                echo "# LinuxDO签到 - 20:00" >> /tmp/crontab.tmp
                echo "0 20 * * * cd $PROJECT_DIR && $CRON_CMD" >> /tmp/crontab.tmp
                ;;
            2)
                echo "# LinuxDO签到 - 09:00" >> /tmp/crontab.tmp
                echo "0 9 * * * cd $PROJECT_DIR && $CRON_CMD" >> /tmp/crontab.tmp
                ;;
            3)
                read -p "输入时间 (格式 HH:MM，如 08:00): " custom_time
                HOUR=$(echo "$custom_time" | cut -d: -f1 | sed 's/^0//')
                MINUTE=$(echo "$custom_time" | cut -d: -f2 | sed 's/^0//')
                echo "# LinuxDO签到 - $custom_time" >> /tmp/crontab.tmp
                echo "$MINUTE $HOUR * * * cd $PROJECT_DIR && $CRON_CMD" >> /tmp/crontab.tmp
                ;;
        esac

        crontab /tmp/crontab.tmp
        rm /tmp/crontab.tmp
        print_success "Linux 定时任务已设置"
        echo "[提示] 查看任务: crontab -l"
        echo "[提示] 编辑任务: crontab -e"
    fi
}

# 首次登录
first_login() {
    if [ "$HAS_DISPLAY" = false ]; then
        print_warning "未检测到图形界面"
        echo ""
        echo "首次登录需要图形界面，请选择以下方式之一："
        echo ""
        echo "  方式1: VNC 远程桌面"
        echo "    sudo apt install tigervnc-standalone-server"
        echo "    vncserver :1"
        echo "    export DISPLAY=:1"
        echo ""
        echo "  方式2: SSH X11 转发"
        echo "    ssh -X user@host"
        echo "    export DISPLAY=localhost:10.0"
        echo ""
        echo "  方式3: 在其他电脑完成首次登录"
        echo "    1) 在有图形界面的电脑上运行: python main.py --first-login"
        echo "    2) 将 ~/.linuxdo-browser 目录复制到本机相同位置"
        echo "    3) 设置 headless: true 后运行签到"
        echo ""
        read -p "按 Enter 继续..."
        return
    fi

    read -p "是否现在进行首次登录？[Y/n]: " DO_LOGIN
    [ "$DO_LOGIN" = "n" ] || [ "$DO_LOGIN" = "N" ] && return

    echo ""
    print_info "启动浏览器进行首次登录..."
    echo "[提示] 请在浏览器中登录 Linux.do 账号"
    echo "[提示] 登录成功后关闭浏览器即可"
    echo ""

    source venv/bin/activate
    python main.py --first-login
}

# 编辑配置
edit_config() {
    if [ ! -f "config.yaml" ]; then
        print_warning "配置文件不存在，请先运行一键安装"
        return
    fi

    while true; do
        echo ""
        echo "当前配置:"
        grep -E "^(username|password|headless|browse_count|like_probability|tg_bot_token|tg_chat_id):" config.yaml | while read line; do
            key=$(echo "$line" | cut -d: -f1)
            val=$(echo "$line" | cut -d: -f2- | sed 's/^ *//' | sed 's/"//g')
            case $key in
                password) [ -n "$val" ] && val="********" ;;
                tg_bot_token) [ -n "$val" ] && val="${val:0:20}..." ;;
            esac
            printf "  %-20s: %s\n" "$key" "$val"
        done
        echo ""
        echo "  1. 修改用户名    5. 修改浏览数量"
        echo "  2. 修改密码      6. 修改点赞概率"
        echo "  3. 修改无头模式  7. 修改TG Token"
        echo "  4. 修改浏览器    8. 修改TG Chat ID"
        echo "  0. 返回"
        echo ""
        read -p "请选择 [0-8]: " opt

        case $opt in
            0) break ;;
            1) read -p "用户名: " val; sed -i "s/^username:.*/username: \"$val\"/" config.yaml ;;
            2) read -p "密码: " val; sed -i "s/^password:.*/password: \"$val\"/" config.yaml ;;
            3) read -p "无头模式 (true/false): " val; sed -i "s/^headless:.*/headless: $val/" config.yaml ;;
            4) read -p "浏览器路径: " val; sed -i "s|^browser_path:.*|browser_path: \"$val\"|" config.yaml ;;
            5) read -p "浏览数量: " val; sed -i "s/^browse_count:.*/browse_count: $val/" config.yaml ;;
            6) read -p "点赞概率: " val; sed -i "s/^like_probability:.*/like_probability: $val/" config.yaml ;;
            7) read -p "TG Token: " val; sed -i "s/^tg_bot_token:.*/tg_bot_token: \"$val\"/" config.yaml ;;
            8) read -p "TG Chat ID: " val; sed -i "s/^tg_chat_id:.*/tg_chat_id: \"$val\"/" config.yaml ;;
        esac
        [ "$opt" != "0" ] && print_success "配置已更新"
    done
}

# 运行签到
run_checkin() {
    source venv/bin/activate 2>/dev/null || true
    if [ "$HAS_DISPLAY" = true ]; then
        python main.py
    elif command -v xvfb-run &>/dev/null; then
        xvfb-run -a python main.py
    else
        python main.py
    fi
}

# 完成提示
print_completion() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                      安装完成！                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "后续操作:"
    echo "  1. 首次登录: ./venv/bin/python main.py --first-login"
    echo "  2. 运行签到: ./venv/bin/python main.py"
    echo "  3. 编辑配置: 运行脚本选择 4"
    echo "  4. 查看日志: tail -f logs/checkin.log"
    echo ""
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "┌─────────────────────────────────────┐"
        echo "│              主菜单                 │"
        echo "├─────────────────────────────────────┤"
        echo "│  1. 一键安装（推荐）                │"
        echo "│  2. 仅安装依赖                      │"
        echo "│  3. 仅配置 Python 环境              │"
        echo "│  4. 编辑配置文件                    │"
        echo "│  5. 设置定时任务                    │"
        echo "│  6. 首次登录                        │"
        echo "│  7. 运行签到                        │"
        echo "│  8. 查看系统信息                    │"
        echo "│  9. 检查更新                        │"
        echo "│  0. 退出                            │"
        echo "└─────────────────────────────────────┘"
        echo ""
        read -p "请选择 [0-9]: " choice

        case $choice in
            0) exit 0 ;;
            1) install_deps; setup_python; verify_and_test_browser; interactive_config; setup_cron; first_login; print_completion ;;
            2) install_deps ;;
            3) setup_python ;;
            4) edit_config ;;
            5) setup_cron ;;
            6) first_login ;;
            7) run_checkin ;;
            8) detect_system ;;
            9) manual_update ;;
            *) print_error "无效选项" ;;
        esac
    done
}

# 检查更新
check_update_on_start() {
    if [ ! -f "updater.py" ]; then
        return
    fi

    PYTHON_CMD=""
    if [ -f "venv/bin/python" ]; then
        PYTHON_CMD="venv/bin/python"
    elif command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &>/dev/null; then
        PYTHON_CMD="python"
    fi

    if [ -z "$PYTHON_CMD" ]; then
        print_info "未检测到 Python 环境，跳过更新检查"
        return
    fi

    print_info "检查更新中..."

    UPDATE_INFO=$($PYTHON_CMD -c "
from updater import check_update
from version import __version__
info = check_update(silent=True)
if info:
    print(f'CURRENT={__version__}')
    print(f'LATEST={info[\"latest_version\"]}')
else:
    print(f'CURRENT={__version__}')
    print('LATEST=NONE')
" 2>/dev/null)

    if [ $? -ne 0 ]; then
        print_warning "更新检查失败，可能缺少依赖"
        print_info "如果是首次使用，请选择 1. 一键安装"
        echo ""
        return
    fi

    CURRENT_VER=$(echo "$UPDATE_INFO" | grep "CURRENT=" | cut -d= -f2)
    LATEST_VER=$(echo "$UPDATE_INFO" | grep "LATEST=" | cut -d= -f2)

    if [ "$LATEST_VER" = "NONE" ]; then
        print_success "当前版本 v$CURRENT_VER 已是最新"
        echo ""
        return
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  发现新版本: v$LATEST_VER  (当前: v$CURRENT_VER)"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "是否现在更新？[Y/n]: " do_update
    if [ "$do_update" = "n" ] || [ "$do_update" = "N" ]; then
        print_info "跳过更新"
        echo ""
        return
    fi

    echo ""
    print_info "正在更新..."
    $PYTHON_CMD -c "from updater import prompt_update; prompt_update()"
    echo ""
    print_warning "更新完成，请重新运行此脚本"
    read -p "按 Enter 键退出..."
    exit 0
}

# 手动检查更新
manual_update() {
    PYTHON_CMD=""
    if [ -f "venv/bin/python" ]; then
        PYTHON_CMD="venv/bin/python"
    elif command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &>/dev/null; then
        PYTHON_CMD="python"
    fi

    if [ -z "$PYTHON_CMD" ]; then
        print_error "未检测到 Python 环境"
        print_info "请先运行 1. 一键安装"
        return
    fi

    $PYTHON_CMD main.py --check-update
}

# 主入口
main() {
    print_banner

    if [ ! -f "main.py" ] && [ ! -f "requirements.txt" ]; then
        print_error "请在项目目录下运行此脚本"
        exit 1
    fi

    detect_system
    check_update_on_start
    main_menu
}

main "$@"
