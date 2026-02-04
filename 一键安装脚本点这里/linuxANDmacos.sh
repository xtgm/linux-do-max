#!/bin/bash
# ============================================================
# LinuxDO 签到 - Linux/macOS 一键安装脚本
# 使用方法: chmod +x install.sh && ./install.sh
# ============================================================

set -e

VERSION="1.3.0"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}     ${GREEN}LinuxDO 签到一键安装脚本 v${VERSION}${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
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

    echo ""
    echo "┌──────────────────────────────────────────┐"
    echo "│            系统环境检测结果              │"
    echo "├──────────────────────────────────────────┤"
    printf "│ 操作系统     │ %-22s │\n" "$OS_NAME"
    printf "│ 架构         │ %-22s │\n" "$ARCH ($ARCH_TYPE)"
    [ -n "$DISTRO" ] && printf "│ 发行版       │ %-22s │\n" "$DISTRO"
    [ -n "$PKG_MGR" ] && printf "│ 包管理器     │ %-22s │\n" "$PKG_MGR"
    printf "│ ARM设备      │ %-22s │\n" "$([ "$IS_ARM" = true ] && echo '是' || echo '否')"
    printf "│ 图形界面     │ %-22s │\n" "$([ "$HAS_DISPLAY" = true ] && echo '有' || echo '无')"
    echo "└──────────────────────────────────────────┘"
    echo ""
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
                libxrandr2 libgbm1 libasound2 wget curl 2>/dev/null || true

            # 检查是否已有浏览器
            if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
                print_info "检测到 Google Chrome，跳过浏览器安装"
            elif command -v chromium &>/dev/null && ! command -v snap &>/dev/null; then
                print_info "检测到 Chromium（非 Snap），跳过浏览器安装"
            else
                # Ubuntu 22.04+ 的 chromium-browser 是 Snap 包，需要访问 snap store
                # 优先安装 Google Chrome（deb 包，无需 snap store）
                print_info "安装 Google Chrome..."
                TEMP_DEB="/tmp/google-chrome.deb"
                if wget -q -O "$TEMP_DEB" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" 2>/dev/null; then
                    sudo dpkg -i "$TEMP_DEB" 2>/dev/null || true
                    sudo apt-get install -f -y 2>/dev/null || true
                    rm -f "$TEMP_DEB"
                    print_success "Google Chrome 安装完成"
                else
                    # 下载失败，尝试安装 chromium（可能触发 Snap）
                    print_warning "Google Chrome 下载失败，尝试安装 Chromium..."
                    sudo apt-get install -y chromium-browser 2>/dev/null || \
                    sudo apt-get install -y chromium 2>/dev/null || true
                fi
            fi
            # 刷新字体缓存
            fc-cache -fv 2>/dev/null || true
            ;;
        dnf)
            sudo dnf install -y python3 python3-pip python3-virtualenv python3-devel || true
            sudo dnf install -y chromium chromedriver xorg-x11-server-Xvfb wqy-zenhei-fonts wqy-microhei-fonts || true
            fc-cache -fv 2>/dev/null || true
            ;;
        yum)
            sudo yum install -y python3 python3-pip python3-virtualenv python3-devel || true
            sudo yum install -y chromium chromedriver xorg-x11-server-Xvfb wqy-zenhei-fonts wqy-microhei-fonts || true
            fc-cache -fv 2>/dev/null || true
            ;;
        pacman)
            sudo pacman -Syu --noconfirm python python-pip python-virtualenv || true
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
            sudo zypper install -y chromium xvfb-run google-noto-sans-cjk-fonts || true
            fc-cache -fv 2>/dev/null || true
            ;;
        brew)
            brew install python3 || true
            [ ! -d "/Applications/Google Chrome.app" ] && \
                print_warning "请手动安装 Chrome: https://www.google.com/chrome/"
            ;;
        *)
            print_warning "未知包管理器，请手动安装: Python3, pip, venv, Chromium, Xvfb"
            ;;
    esac

    print_success "系统依赖安装完成"
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

    # 检测浏览器
    BROWSER_PATH=""
    for p in /usr/bin/chromium-browser /usr/bin/chromium /usr/lib/chromium/chromium \
             /usr/lib/chromium-browser/chromium-browser /snap/bin/chromium \
             /usr/bin/google-chrome /usr/bin/google-chrome-stable \
             "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
        [ -x "$p" ] && BROWSER_PATH="$p" && break
    done

    # 如果没找到，尝试 which 命令
    if [ -z "$BROWSER_PATH" ]; then
        for cmd in chromium-browser chromium google-chrome google-chrome-stable; do
            p=$(which "$cmd" 2>/dev/null)
            [ -n "$p" ] && [ -x "$p" ] && BROWSER_PATH="$p" && break
        done
    fi

    # Linux 系统自动添加必要的 Chrome 参数
    CHROME_ARGS=""
    IS_CONTAINER=false
    if [ -f "/.dockerenv" ] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null || \
       [ -f "/run/.containerenv" ] || systemd-detect-virt -c &>/dev/null; then
        IS_CONTAINER=true
    fi

    if [ "$OS_NAME" = "Linux" ]; then
        # Linux 系统通常需要这些参数才能正常启动浏览器
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
# Linux 系统自动添加 --no-sandbox 等参数
# 通常不需要手动修改
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
        # 有图形界面：设置 DISPLAY 环境变量
        # 无图形界面：使用 xvfb-run
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
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    安装完成！                              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "后续操作:"
    echo "  1. 首次登录: ./venv/bin/python main.py --first-login"
    echo "  2. 运行签到: ./venv/bin/python main.py"
    echo "  3. 编辑配置: ./install.sh 选择 4"
    echo "  4. 查看日志: tail -f logs/checkin.log"
    echo ""
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "┌──────────────────────────────────────────┐"
        echo "│                主菜单                    │"
        echo "├──────────────────────────────────────────┤"
        echo "│  1. 一键安装（推荐）                     │"
        echo "│  2. 仅安装依赖                           │"
        echo "│  3. 仅配置 Python 环境                   │"
        echo "│  4. 编辑配置文件                         │"
        echo "│  5. 设置定时任务                         │"
        echo "│  6. 首次登录                             │"
        echo "│  7. 运行签到                             │"
        echo "│  8. 查看系统信息                         │"
        echo "│  9. 检查更新                             │"
        echo "│  0. 退出                                 │"
        echo "└──────────────────────────────────────────┘"
        echo ""
        read -p "请选择 [0-9]: " choice

        case $choice in
            0) exit 0 ;;
            1) install_deps; setup_python; interactive_config; setup_cron; first_login; print_completion ;;
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
    # 检查 updater.py 是否存在
    if [ ! -f "updater.py" ]; then
        return
    fi

    # 确定使用哪个 Python：优先 venv，否则系统 Python
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

    # 获取当前版本和最新版本
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
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  发现新版本: v$LATEST_VER  (当前: v$CURRENT_VER)"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
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
    # 确定使用哪个 Python
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

    # 启动时检查更新
    check_update_on_start

    main_menu
}

main "$@"
