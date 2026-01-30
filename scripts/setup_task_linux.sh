#!/bin/bash
# LinuxDO 签到 - Linux 定时任务设置
# 使用 cron 管理定时任务

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Python 路径
PYTHON_PATH=$(which python3 || which python)

# cron 任务标识
CRON_TAG="# LinuxDO-Checkin"

echo "========================================"
echo "LinuxDO 签到 - Linux 定时任务设置"
echo "========================================"
echo ""
echo "项目目录: $PROJECT_DIR"
echo "Python: $PYTHON_PATH"
echo ""

# 显示菜单
show_menu() {
    echo "请选择操作："
    echo "  1. 创建定时任务（自定义时间和次数）"
    echo "  2. 删除定时任务"
    echo "  3. 查看当前 cron 任务"
    echo "  4. 立即运行签到"
    echo "  5. 首次登录（保存登录状态）"
    echo "  6. 测试 Telegram 提醒"
    echo "  7. 查看日志"
    echo "  8. 安装 Xvfb（虚拟显示）"
    echo "  9. 退出"
    echo ""
    read -p "请输入选项 (1-9): " choice
}

# 创建定时任务
create_task() {
    echo ""
    echo "========================================"
    echo "定时任务配置"
    echo "========================================"
    echo ""

    # 创建日志目录
    mkdir -p "$PROJECT_DIR/logs"

    # 检查是否安装了 xvfb-run
    if command -v xvfb-run &> /dev/null; then
        XVFB_PREFIX="xvfb-run -a "
        echo "[信息] 检测到 Xvfb，将使用虚拟显示"
    else
        XVFB_PREFIX=""
        echo "[警告] 未检测到 Xvfb，如果运行失败请先安装（选项 8）"
    fi
    echo ""

    # 输入次数
    read -p "请输入每天执行的次数（1-4次，默认2）: " task_count
    task_count=${task_count:-2}
    if [ "$task_count" -lt 1 ]; then task_count=1; fi
    if [ "$task_count" -gt 4 ]; then task_count=4; fi

    echo ""
    echo "请输入每次执行的时间（24小时制，如 08:00）："
    echo ""

    # 删除旧任务
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null || true

    # 收集时间
    declare -a times
    for i in $(seq 1 $task_count); do
        case $i in
            1) default="08:00" ;;
            2) default="20:00" ;;
            3) default="12:00" ;;
            4) default="18:00" ;;
        esac
        read -p "第 $i 次执行时间（默认 $default）: " input_time
        times[$i]=${input_time:-$default}
    done

    # 生成 cron 任务
    REMINDER_CMD="${PYTHON_PATH} ${PROJECT_DIR}/reminder.py >> ${PROJECT_DIR}/logs/reminder.log 2>&1"
    CHECKIN_CMD="${XVFB_PREFIX}${PYTHON_PATH} ${PROJECT_DIR}/main.py >> ${PROJECT_DIR}/logs/checkin.log 2>&1"

    # 构建 cron 条目
    cron_entries=""
    for i in $(seq 1 $task_count); do
        time_str=${times[$i]}
        hour=$(echo $time_str | cut -d: -f1 | sed 's/^0//')
        minute=$(echo $time_str | cut -d: -f2 | sed 's/^0//')

        # 提醒任务
        cron_entries="$cron_entries$minute $hour * * * $REMINDER_CMD $CRON_TAG-Reminder-$i\n"

        # 签到任务（提醒后1分钟）
        checkin_minute=$((minute + 1))
        checkin_hour=$hour
        if [ $checkin_minute -ge 60 ]; then
            checkin_minute=$((checkin_minute - 60))
            checkin_hour=$((checkin_hour + 1))
        fi
        if [ $checkin_hour -ge 24 ]; then
            checkin_hour=$((checkin_hour - 24))
        fi
        cron_entries="$cron_entries$checkin_minute $checkin_hour * * * $CHECKIN_CMD $CRON_TAG-$i\n"

        printf "[成功] %s - Telegram 提醒\n" "$time_str"
        printf "[成功] %02d:%02d - 自动签到\n" "$checkin_hour" "$checkin_minute"
    done

    # 添加到 crontab
    (crontab -l 2>/dev/null || true; echo -e "$cron_entries") | crontab -

    echo ""
    echo "========================================"
    echo "[成功] 已创建 $task_count 组定时任务"
    echo "[信息] 日志文件: $PROJECT_DIR/logs/"
    echo "========================================"
    echo ""
}

# 删除定时任务
delete_task() {
    echo ""
    echo "[信息] 删除定时任务..."

    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null || true

    echo "[成功] 定时任务已删除"
    echo ""
}

# 查看 cron 任务
show_cron() {
    echo ""
    echo "[信息] 当前 cron 任务："
    echo "----------------------------------------"
    crontab -l 2>/dev/null | grep -E "(LinuxDO|linuxdo)" || echo "无 LinuxDO 相关任务"
    echo "----------------------------------------"
    echo ""
}

# 立即运行
run_now() {
    echo ""
    echo "[信息] 立即运行签到..."
    echo ""

    if command -v xvfb-run &> /dev/null; then
        cd "$PROJECT_DIR"
        xvfb-run -a "$PYTHON_PATH" main.py
    else
        cd "$PROJECT_DIR"
        "$PYTHON_PATH" main.py
    fi
    echo ""
}

# 首次登录
first_login() {
    echo ""
    echo "[信息] 首次登录模式..."
    echo "[警告] 首次登录需要图形界面，请确保有显示器或 VNC 连接"
    echo ""

    read -p "是否继续？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "[取消] 已取消"
        return
    fi

    cd "$PROJECT_DIR"
    "$PYTHON_PATH" main.py --first-login
    echo ""
}

# 测试 Telegram 提醒
test_reminder() {
    echo ""
    echo "[信息] 测试 Telegram 提醒..."
    echo ""
    cd "$PROJECT_DIR"
    "$PYTHON_PATH" reminder.py
    echo ""
}

# 查看日志
show_logs() {
    echo ""
    LOG_FILE="$PROJECT_DIR/logs/checkin.log"
    if [ -f "$LOG_FILE" ]; then
        echo "[信息] 最近 50 行日志："
        echo "----------------------------------------"
        tail -n 50 "$LOG_FILE"
        echo "----------------------------------------"
    else
        echo "[信息] 暂无日志文件"
    fi
    echo ""
}

# 安装 Xvfb
install_xvfb() {
    echo ""
    echo "[信息] 安装 Xvfb..."

    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y xvfb
    elif command -v yum &> /dev/null; then
        sudo yum install -y xorg-x11-server-Xvfb
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y xorg-x11-server-Xvfb
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm xorg-server-xvfb
    elif command -v apk &> /dev/null; then
        sudo apk add xvfb
    else
        echo "[错误] 未识别的包管理器，请手动安装 Xvfb"
        return 1
    fi

    echo ""
    echo "[成功] Xvfb 安装完成"
    echo ""
}

# 主循环
while true; do
    show_menu

    case $choice in
        1) create_task ;;
        2) delete_task ;;
        3) show_cron ;;
        4) run_now ;;
        5) first_login ;;
        6) test_reminder ;;
        7) show_logs ;;
        8) install_xvfb ;;
        9) echo "再见！"; exit 0 ;;
        *) echo "[错误] 无效选项" ;;
    esac

    read -p "按 Enter 键继续..."
    echo ""
done
