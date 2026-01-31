: << 'BATCH_SCRIPT'
@echo off
goto :windows
BATCH_SCRIPT

#!/bin/bash
# ============================================================
# LinuxDO 签到 - 一键安装脚本 (Polyglot)
# 此脚本在 Windows 上作为 .cmd 运行，在 Linux/macOS 上作为 bash 运行
#
# 使用方法:
#   Windows: 双击 install.cmd 或在命令行运行 install.cmd
#   Linux/macOS: chmod +x install.cmd && ./install.cmd
# ============================================================

set -e

VERSION="1.2.0"

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
    elif command -v brew &>/dev/null; then PKG_MGR="brew"
    fi

    # 图形界面
    HAS_DISPLAY=false
    [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ] && HAS_DISPLAY=true

    # 树莓派
    IS_RPI=false
    [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null && IS_RPI=true

    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│           系统环境检测结果              │"
    echo "├─────────────────────────────────────────┤"
    printf "│ %-12s │ %-24s │\n" "操作系统" "$OS_NAME"
    printf "│ %-12s │ %-24s │\n" "架构" "$ARCH ($ARCH_TYPE)"
    [ -n "$DISTRO" ] && printf "│ %-12s │ %-24s │\n" "发行版" "$DISTRO"
    [ -n "$PKG_MGR" ] && printf "│ %-12s │ %-24s │\n" "包管理器" "$PKG_MGR"
    printf "│ %-12s │ %-24s │\n" "ARM设备" "$([ "$IS_ARM" = true ] && echo '是' || echo '否')"
    printf "│ %-12s │ %-24s │\n" "图形界面" "$([ "$HAS_DISPLAY" = true ] && echo '有' || echo '无')"
    echo "└─────────────────────────────────────────┘"
    echo ""
}

# 安装依赖
install_deps() {
    print_info "安装系统依赖..."

    case "$PKG_MGR" in
        apt)
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-venv \
                chromium-browser xvfb fonts-wqy-zenhei \
                libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
                libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
                libxrandr2 libgbm1 libasound2 2>/dev/null || \
            sudo apt-get install -y python3 python3-pip python3-venv \
                chromium xvfb fonts-wqy-zenhei 2>/dev/null || true
            ;;
        dnf)
            sudo dnf install -y python3 python3-pip chromium chromedriver \
                xorg-x11-server-Xvfb wqy-zenhei-fonts || true
            ;;
        yum)
            sudo yum install -y python3 python3-pip chromium chromedriver \
                xorg-x11-server-Xvfb wqy-zenhei-fonts || true
            ;;
        pacman)
            sudo pacman -Syu --noconfirm python python-pip chromium \
                xorg-server-xvfb wqy-zenhei || true
            ;;
        apk)
            sudo apk add python3 py3-pip chromium chromium-chromedriver \
                xvfb font-wqy-zenhei ttf-wqy-zenhei || true
            ;;
        brew)
            brew install python3 || true
            [ ! -d "/Applications/Google Chrome.app" ] && \
                print_warning "请手动安装 Chrome: https://www.google.com/chrome/"
            ;;
        *)
            print_warning "未知包管理器，请手动安装: Python3, Chromium, Xvfb"
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

    read -p "Linux.do 用户名 (可选): " USERNAME
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
    echo "Telegram 通知配置（可选）:"
    read -p "Bot Token (直接回车跳过): " TG_TOKEN
    [ -n "$TG_TOKEN" ] && read -p "Chat ID: " TG_CHAT_ID

    USER_DATA_DIR="$HOME/.linuxdo-browser"
    read -p "用户数据目录 [$USER_DATA_DIR]: " INPUT_DIR
    USER_DATA_DIR=${INPUT_DIR:-$USER_DATA_DIR}

    # 检测浏览器
    BROWSER_PATH=""
    for p in /usr/bin/chromium-browser /usr/bin/chromium /usr/bin/google-chrome; do
        [ -x "$p" ] && BROWSER_PATH="$p" && break
    done

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
browse_interval_min: 3
browse_interval_max: 8
tg_bot_token: "$TG_TOKEN"
tg_chat_id: "$TG_CHAT_ID"
EOF

    mkdir -p "$USER_DATA_DIR"
    print_success "配置已保存: config.yaml"
}

# 设置定时任务
setup_cron() {
    read -p "是否设置定时任务？[y/N]: " SETUP
    [ "$SETUP" != "y" ] && [ "$SETUP" != "Y" ] && return

    SCRIPT_DIR=$(pwd)
    PYTHON_PATH="$SCRIPT_DIR/venv/bin/python"

    if [ "$OS_NAME" = "macOS" ]; then
        # macOS launchd
        PLIST="$HOME/Library/LaunchAgents/com.linuxdo.checkin.plist"
        cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.linuxdo.checkin</string>
    <key>ProgramArguments</key>
    <array><string>$PYTHON_PATH</string><string>$SCRIPT_DIR/main.py</string></array>
    <key>WorkingDirectory</key><string>$SCRIPT_DIR</string>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
    </array>
</dict>
</plist>
EOF
        launchctl unload "$PLIST" 2>/dev/null || true
        launchctl load "$PLIST"
        print_success "macOS 定时任务已设置"
    else
        # Linux cron
        mkdir -p "$SCRIPT_DIR/logs"
        CRON_CMD="0 8,20 * * * cd $SCRIPT_DIR && xvfb-run -a $PYTHON_PATH main.py >> logs/checkin.log 2>&1"
        (crontab -l 2>/dev/null | grep -v "linuxdo"; echo "# LinuxDO签到"; echo "$CRON_CMD") | crontab -
        print_success "Linux 定时任务已设置"
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
        echo ""
        echo "  方式2: SSH X11 转发"
        echo "    ssh -X user@host"
        echo "    export DISPLAY=localhost:10.0"
        echo ""
        echo "  方式3: 在其他电脑完成首次登录"
        echo "    1) 在有图形界面的电脑上运行首次登录"
        echo "    2) 将 ~/.linuxdo-browser 目录复制到本机"
        echo ""
        read -p "按 Enter 继续..."
        return
    fi

    read -p "是否现在进行首次登录？[Y/n]: " DO_LOGIN
    [ "$DO_LOGIN" = "n" ] || [ "$DO_LOGIN" = "N" ] && return

    source venv/bin/activate
    python main.py --first-login
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "┌─────────────────────────────────────────┐"
        echo "│              主菜单                     │"
        echo "├─────────────────────────────────────────┤"
        echo "│  1. 一键安装（推荐）                    │"
        echo "│  2. 仅安装依赖                          │"
        echo "│  3. 仅配置 Python 环境                  │"
        echo "│  4. 编辑配置文件                        │"
        echo "│  5. 设置定时任务                        │"
        echo "│  6. 首次登录                            │"
        echo "│  7. 运行签到                            │"
        echo "│  8. 查看系统信息                        │"
        echo "│  0. 退出                                │"
        echo "└─────────────────────────────────────────┘"
        echo ""
        read -p "请选择 [0-8]: " choice

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
            *) print_error "无效选项" ;;
        esac
    done
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
        print_success "配置已更新"
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
    echo "  3. 编辑配置: ./install.cmd 选择 4"
    echo "  4. 查看日志: tail -f logs/checkin.log"
    echo ""
}

# 主入口
main() {
    print_banner

    if [ ! -f "main.py" ] && [ ! -f "requirements.txt" ]; then
        print_error "请在项目目录下运行此脚本"
        exit 1
    fi

    detect_system
    main_menu
}

main "$@"
exit 0

:windows
@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

set "VERSION=1.2.0"

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║     LinuxDO 签到一键安装脚本 v%VERSION%     ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

:: 检测系统
echo [信息] 检测系统环境...
echo.
echo ┌─────────────────────────────────────────┐
echo │           系统环境检测结果              │
echo ├─────────────────────────────────────────┤

for /f "tokens=2 delims==" %%a in ('wmic os get caption /value') do set "OS_NAME=%%a"
for /f "tokens=2 delims==" %%a in ('wmic os get osarchitecture /value') do set "ARCH=%%a"

echo │ 操作系统     │ Windows                   │
echo │ 架构         │ %ARCH%                    │

:: 检测 Python
set "PYTHON_OK=0"
where python >nul 2>&1 && set "PYTHON_OK=1"
if %PYTHON_OK%==1 (
    echo │ Python       │ 已安装                    │
) else (
    echo │ Python       │ 未安装                    │
)

:: 检测 Chrome
set "CHROME_PATH="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME_PATH=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME_PATH=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME_PATH=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if defined CHROME_PATH (
    echo │ Chrome       │ 已安装                    │
) else (
    echo │ Chrome       │ 未安装                    │
)
echo └─────────────────────────────────────────┘
echo.

:: 检查依赖
if %PYTHON_OK%==0 (
    echo [错误] 未检测到 Python
    echo [信息] 请从 https://www.python.org/downloads/ 下载安装
    echo [信息] 安装时请勾选 "Add Python to PATH"
    pause
    exit /b 1
)

if not defined CHROME_PATH (
    echo [警告] 未检测到 Chrome
    echo [信息] 请从 https://www.google.com/chrome/ 下载安装
)

:: 检查项目文件
if not exist "main.py" (
    if not exist "requirements.txt" (
        echo [错误] 请在项目目录下运行此脚本
        pause
        exit /b 1
    )
)

:menu
echo.
echo ┌─────────────────────────────────────────┐
echo │              主菜单                     │
echo ├─────────────────────────────────────────┤
echo │  1. 一键安装（推荐）                    │
echo │  2. 仅配置 Python 环境                  │
echo │  3. 编辑配置文件                        │
echo │  4. 设置定时任务                        │
echo │  5. 首次登录                            │
echo │  6. 运行签到                            │
echo │  0. 退出                                │
echo └─────────────────────────────────────────┘
echo.
set /p choice="请选择 [0-6]: "

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto :full_install
if "%choice%"=="2" goto :setup_python
if "%choice%"=="3" goto :edit_config
if "%choice%"=="4" goto :setup_task
if "%choice%"=="5" goto :first_login
if "%choice%"=="6" goto :run_checkin
echo [错误] 无效选项
goto :menu

:full_install
call :setup_python
call :interactive_config
call :setup_task
call :first_login
call :print_completion
goto :menu

:setup_python
echo [信息] 配置 Python 环境...
if not exist "venv" (
    echo [信息] 创建虚拟环境...
    python -m venv venv
)
echo [信息] 升级 pip...
venv\Scripts\python.exe -m pip install --upgrade pip >nul 2>&1
echo [信息] 安装依赖...
venv\Scripts\pip.exe install -r requirements.txt
echo [成功] Python 环境配置完成
goto :eof

:interactive_config
echo [信息] 配置向导...
echo.

if exist "config.yaml" (
    echo [警告] 检测到已有配置文件
    set /p reconfig="是否重新配置？[y/N]: "
    if /i not "!reconfig!"=="y" goto :eof
)

set /p USERNAME="Linux.do 用户名 (可选): "
if defined USERNAME set /p PASSWORD="Linux.do 密码 (可选): "

set /p BROWSE_COUNT="浏览帖子数量 [10]: "
if not defined BROWSE_COUNT set "BROWSE_COUNT=10"

set /p LIKE_PROB="点赞概率 (0-1) [0.3]: "
if not defined LIKE_PROB set "LIKE_PROB=0.3"

set /p HEADLESS="无头模式 (true/false) [false]: "
if not defined HEADLESS set "HEADLESS=false"

echo.
echo Telegram 通知配置（可选）:
set /p TG_TOKEN="Bot Token (直接回车跳过): "
if defined TG_TOKEN set /p TG_CHAT_ID="Chat ID: "

set "USER_DATA_DIR=%USERPROFILE%\.linuxdo-browser"

:: 生成配置文件
(
echo # LinuxDO 签到配置文件
echo.
echo username: "%USERNAME%"
echo password: "%PASSWORD%"
echo user_data_dir: "%USER_DATA_DIR:\=/%"
echo headless: %HEADLESS%
echo browser_path: "%CHROME_PATH:\=/%"
echo browse_count: %BROWSE_COUNT%
echo like_probability: %LIKE_PROB%
echo browse_interval_min: 3
echo browse_interval_max: 8
echo tg_bot_token: "%TG_TOKEN%"
echo tg_chat_id: "%TG_CHAT_ID%"
) > config.yaml

if not exist "%USER_DATA_DIR%" mkdir "%USER_DATA_DIR%"
echo [成功] 配置已保存: config.yaml
goto :eof

:edit_config
if not exist "config.yaml" (
    echo [警告] 配置文件不存在，请先运行一键安装
    goto :menu
)
echo [信息] 打开配置文件...
notepad config.yaml
goto :menu

:setup_task
set /p setup="是否设置定时任务？[y/N]: "
if /i not "%setup%"=="y" goto :eof

set "SCRIPT_DIR=%CD%"
set "PYTHON_PATH=%SCRIPT_DIR%\venv\Scripts\python.exe"
set "MAIN_SCRIPT=%SCRIPT_DIR%\main.py"

echo.
echo 选择签到时间:
echo   1. 每天 8:00 和 20:00（推荐）
echo   2. 每天 9:00
echo   3. 自定义
set /p time_choice="请选择 [1-3]: "

if "%time_choice%"=="1" (
    schtasks /create /tn "LinuxDO-Checkin-1" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st 08:00 /f >nul
    schtasks /create /tn "LinuxDO-Checkin-2" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st 20:00 /f >nul
    echo [成功] 定时任务已设置 (08:00, 20:00^)
) else if "%time_choice%"=="2" (
    schtasks /create /tn "LinuxDO-Checkin-1" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st 09:00 /f >nul
    echo [成功] 定时任务已设置 (09:00^)
) else (
    set /p custom_time="输入时间 (如 08:00): "
    schtasks /create /tn "LinuxDO-Checkin-1" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st !custom_time! /f >nul
    echo [成功] 定时任务已设置 (!custom_time!^)
)
goto :eof

:first_login
set /p do_login="是否现在进行首次登录？[Y/n]: "
if /i "%do_login%"=="n" goto :eof
venv\Scripts\python.exe main.py --first-login
goto :eof

:run_checkin
venv\Scripts\python.exe main.py
goto :eof

:print_completion
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                    安装完成！                              ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo 后续操作:
echo   1. 首次登录: venv\Scripts\python.exe main.py --first-login
echo   2. 运行签到: venv\Scripts\python.exe main.py
echo   3. 编辑配置: install.cmd 选择 3
echo   4. 查看任务: schtasks /query /tn LinuxDO-Checkin-1
echo.
goto :eof
