"""
LinuxDO 自动签到工具
主入口文件

支持两种运行方式：
1. 方案A：直接运行 + Windows 任务计划
2. 方案B：青龙面板调用

使用方法：
    python main.py [--first-login] [--check-update] [--no-update-check]

参数：
    --first-login     首次登录模式，会打开有头浏览器等待手动登录
    --check-update    仅检查更新
    --no-update-check 跳过更新检查
"""
import sys
import argparse
from core.config import config
from version import __version__


def first_login():
    """首次登录模式（全平台支持）"""
    print("=" * 50)
    print("首次登录模式")
    print("=" * 50)
    print()
    print("说明：")
    print("1. 浏览器将打开 Linux.do 网站")
    print("2. 请手动完成登录（包括 CF 验证）")
    print("3. 登录成功后，按 Enter 键保存登录状态")
    print("4. 之后运行签到将自动使用保存的登录状态")
    print()

    # 导入浏览器模块
    from DrissionPage import ChromiumPage, ChromiumOptions
    from pathlib import Path
    import socket
    import time
    import subprocess
    from core.browser import (
        get_chrome_args, find_browser_path,
        is_linux, is_macos
    )

    # 用户数据目录
    user_data_dir = config.user_data_dir
    print(f"用户数据目录: {user_data_dir}")
    print()

    # 确保目录存在
    Path(user_data_dir).mkdir(parents=True, exist_ok=True)

    # 查找可用端口
    def find_free_port():
        for port in range(9222, 9322):
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.bind(('127.0.0.1', port))
                    return port
            except OSError:
                continue
        return 9222

    # 清理占用端口的进程
    def kill_port_process(port):
        if is_linux() or is_macos():
            try:
                result = subprocess.run(
                    ["lsof", "-ti", f":{port}"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0 and result.stdout.strip():
                    pids = result.stdout.strip().split('\n')
                    for pid in pids:
                        try:
                            subprocess.run(["kill", "-9", pid], timeout=5)
                        except:
                            pass
                    time.sleep(1)
            except:
                pass

    # 创建浏览器选项
    co = ChromiumOptions()

    # 设置用户数据目录（保存登录状态）
    co.set_argument(f"--user-data-dir={user_data_dir}")

    # 设置浏览器路径（优先使用配置，否则自动检测）
    browser_path = config.browser_path
    if not browser_path:
        browser_path = find_browser_path()
    if browser_path:
        co.set_browser_path(browser_path)
        print(f"浏览器路径: {browser_path}")
    else:
        print("警告: 未找到浏览器，将使用系统默认")

    # 强制有头模式
    co.headless(False)

    # 获取跨平台 Chrome 参数
    chrome_args = get_chrome_args()
    for arg in chrome_args:
        co.set_argument(arg)

    # Linux/macOS: 设置远程调试端口
    port = 9222
    if is_linux() or is_macos():
        kill_port_process(9222)
        port = find_free_port()
        co.set_argument(f"--remote-debugging-port={port}")
        co.set_local_port(port)
        print(f"调试端口: {port}")

    # 用户自定义 Chrome 参数
    for arg in config.chrome_args:
        co.set_argument(arg)

    print()
    print("正在启动浏览器...")

    # 带重试的启动（只重试1次）
    page = None
    for attempt in range(2):
        try:
            page = ChromiumPage(co)
            print("[浏览器] 启动成功")
            break
        except Exception as e:
            print(f"[浏览器] 启动失败 (尝试 {attempt + 1}/2): {e}")
            if attempt < 1:
                time.sleep(2)
                if is_linux() or is_macos():
                    port = find_free_port()
                    co.set_argument(f"--remote-debugging-port={port}")
                    co.set_local_port(port)

    if not page:
        print()
        print("❌ 浏览器启动失败")
        print()
        print("可能的解决方案：")
        print("1. 确保已安装 Google Chrome 浏览器")
        print("   Ubuntu/Debian: 运行一键安装脚本自动安装")
        print("   Fedora/RHEL:   sudo dnf install https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm")
        print("   macOS:         brew install --cask google-chrome")
        print()
        print("2. 如果仍然失败，尝试在 config.yaml 中添加：")
        print("   chrome_args:")
        print('     - "--no-sandbox"')
        print('     - "--disable-dev-shm-usage"')
        print('     - "--disable-gpu"')
        print()
        return

    page.get("https://linux.do")

    print()
    print("浏览器已打开，请完成登录...")
    print()

    input("登录完成后，按 Enter 键保存并退出...")

    # 检查是否登录成功
    username = None
    try:
        user_menu = page.ele("css:.current-user", timeout=3)
        if user_menu:
            user_link = page.ele("css:.current-user a", timeout=3)
            if user_link:
                href = user_link.attr("href")
                if href and "/u/" in href:
                    username = href.split("/u/")[-1].split("/")[0]
    except Exception as e:
        print(f"⚠️ 检测登录状态时出错: {e}")

    # 无论检测结果如何，都提示用户数据目录已保存
    print()
    if username:
        print(f"✅ 登录成功！用户名: {username}")
    else:
        print("⚠️ 未能自动检测到登录状态")
        print("   如果你已经登录，登录状态仍会被保存")

    print(f"✅ 用户数据目录: {user_data_dir}")

    try:
        page.quit()
    except:
        pass
    print("\n浏览器已关闭")


def is_interactive():
    """检测是否为交互模式（有终端输入）"""
    import sys
    import os

    # 检查是否有 TTY
    if hasattr(sys.stdin, 'isatty') and sys.stdin.isatty():
        return True

    # Windows 任务计划、cron 等非交互环境
    # 检查常见的非交互环境变量
    if os.environ.get('TERM') is None and os.environ.get('SSH_TTY') is None:
        # 可能是定时任务
        pass

    return False


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="LinuxDO 自动签到工具")
    parser.add_argument(
        "--first-login",
        action="store_true",
        help="首次登录模式，打开浏览器等待手动登录"
    )
    parser.add_argument(
        "--check-update",
        action="store_true",
        help="仅检查更新"
    )
    parser.add_argument(
        "--no-update-check",
        action="store_true",
        help="跳过更新检查"
    )
    args = parser.parse_args()

    # 显示版本
    print(f"LinuxDO 签到工具 v{__version__}")
    print()

    # 仅检查更新
    if args.check_update:
        from updater import prompt_update
        prompt_update()
        return 0

    # 启动时检查更新（仅交互模式）
    # 定时任务等非交互环境跳过更新检查，避免阻塞
    if not args.no_update_check and is_interactive():
        try:
            from updater import check_update, prompt_update
            update_info = check_update(silent=True)
            if update_info:
                print(f"[更新] 发现新版本 v{update_info['latest_version']}")
                print()
                choice = input("是否现在更新？[Y/n]: ").strip().lower()
                if choice != 'n':
                    prompt_update()
                    # 更新后退出，让用户重新运行
                    print()
                    print("[提示] 请重新运行程序以使用新版本")
                    return 0
                print()
        except Exception as e:
            # 更新检测失败不影响正常使用
            pass

    if args.first_login:
        first_login()
        return 0

    # 正常签到模式 - 创建新实例避免状态累积
    from core.checkin import Checkin
    checkin = Checkin()
    success = checkin.run()
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
