#!/bin/bash
# LinuxDO 签到 - macOS 定时任务设置
# 使用 launchd 管理定时任务

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PLIST_DIR="$HOME/Library/LaunchAgents"

# Python 路径
PYTHON_PATH=$(which python3 || which python)

echo "========================================"
echo "LinuxDO 签到 - macOS 定时任务设置"
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
    echo "  3. 查看任务状态"
    echo "  4. 立即运行签到"
    echo "  5. 首次登录（保存登录状态）"
    echo "  6. 测试 Telegram 提醒"
    echo "  7. 查看日志"
    echo "  8. 退出"
    echo ""
    read -p "请输入选项 (1-8): " choice
}

# 创建 plist 文件
create_plist() {
    local name=$1
    local script=$2
    local hour=$3
    local minute=$4
    local plist_path="$PLIST_DIR/${name}.plist"

    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${name}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${PYTHON_PATH}</string>
        <string>${PROJECT_DIR}/${script}</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${PROJECT_DIR}</string>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${hour}</integer>
        <key>Minute</key>
        <integer>${minute}</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>${PROJECT_DIR}/logs/${script%.py}.log</string>

    <key>StandardErrorPath</key>
    <string>${PROJECT_DIR}/logs/${script%.py}.error.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
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

    # 创建 LaunchAgents 目录
    mkdir -p "$PLIST_DIR"

    # 输入次数
    read -p "请输入每天执行的次数（1-4次，默认2）: " task_count
    task_count=${task_count:-2}
    if [ "$task_count" -lt 1 ]; then task_count=1; fi
    if [ "$task_count" -gt 4 ]; then task_count=4; fi

    echo ""
    echo "请输入每次执行的时间（24小时制，如 08:00）："
    echo ""

    # 卸载并删除旧任务
    for i in 1 2 3 4; do
        for type in reminder checkin; do
            plist_name="com.linuxdo.${type}.${i}"
            if [ -f "$PLIST_DIR/${plist_name}.plist" ]; then
                launchctl unload "$PLIST_DIR/${plist_name}.plist" 2>/dev/null || true
                rm -f "$PLIST_DIR/${plist_name}.plist"
            fi
        done
    done
    # 删除旧版本
    for old_plist in "com.linuxdo.checkin" "com.linuxdo.reminder.am" "com.linuxdo.checkin.am" "com.linuxdo.reminder.pm" "com.linuxdo.checkin.pm"; do
        if [ -f "$PLIST_DIR/${old_plist}.plist" ]; then
            launchctl unload "$PLIST_DIR/${old_plist}.plist" 2>/dev/null || true
            rm -f "$PLIST_DIR/${old_plist}.plist"
        fi
    done

    # 收集时间并创建任务
    for i in $(seq 1 $task_count); do
        case $i in
            1) default="08:00" ;;
            2) default="20:00" ;;
            3) default="12:00" ;;
            4) default="18:00" ;;
        esac
        read -p "第 $i 次执行时间（默认 $default）: " input_time
        time_str=${input_time:-$default}

        hour=$(echo $time_str | cut -d: -f1 | sed 's/^0//')
        minute=$(echo $time_str | cut -d: -f2 | sed 's/^0//')

        # 创建提醒任务
        create_plist "com.linuxdo.reminder.$i" "reminder.py" "$hour" "$minute"
        launchctl load "$PLIST_DIR/com.linuxdo.reminder.$i.plist"
        echo "[成功] $time_str - Telegram 提醒"

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

        create_plist "com.linuxdo.checkin.$i" "main.py" "$checkin_hour" "$checkin_minute"
        launchctl load "$PLIST_DIR/com.linuxdo.checkin.$i.plist"
        printf "[成功] %02d:%02d - 自动签到\n" "$checkin_hour" "$checkin_minute"
    done

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

    for i in 1 2 3 4; do
        for type in reminder checkin; do
            plist_name="com.linuxdo.${type}.${i}"
            if [ -f "$PLIST_DIR/${plist_name}.plist" ]; then
                launchctl unload "$PLIST_DIR/${plist_name}.plist" 2>/dev/null || true
                rm -f "$PLIST_DIR/${plist_name}.plist"
            fi
        done
    done

    # 删除旧版本
    for old_plist in "com.linuxdo.checkin" "com.linuxdo.reminder.am" "com.linuxdo.checkin.am" "com.linuxdo.reminder.pm" "com.linuxdo.checkin.pm"; do
        if [ -f "$PLIST_DIR/${old_plist}.plist" ]; then
            launchctl unload "$PLIST_DIR/${old_plist}.plist" 2>/dev/null || true
            rm -f "$PLIST_DIR/${old_plist}.plist"
        fi
    done

    echo "[成功] 定时任务已删除"
    echo ""
}

# 查看任务状态
show_status() {
    echo ""
    echo "[信息] 任务状态："
    echo "----------------------------------------"
    launchctl list | grep -E "linuxdo" || echo "无 LinuxDO 相关任务"
    echo "----------------------------------------"
    echo ""
}

# 立即运行
run_now() {
    echo ""
    echo "[信息] 立即运行签到..."
    echo ""
    cd "$PROJECT_DIR"
    "$PYTHON_PATH" main.py
    echo ""
}

# 首次登录
first_login() {
    echo ""
    echo "[信息] 首次登录模式..."
    echo ""
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
    LOG_FILE="$PROJECT_DIR/logs/main.log"
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

# 主循环
while true; do
    show_menu

    case $choice in
        1) create_task ;;
        2) delete_task ;;
        3) show_status ;;
        4) run_now ;;
        5) first_login ;;
        6) test_reminder ;;
        7) show_logs ;;
        8) echo "再见！"; exit 0 ;;
        *) echo "[错误] 无效选项" ;;
    esac

    read -p "按 Enter 键继续..."
    echo ""
done
