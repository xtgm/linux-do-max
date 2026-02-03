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
    """首次登录模式"""
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

    # 启动浏览器（强制有头模式）
    from DrissionPage import ChromiumPage, ChromiumOptions
    from pathlib import Path
    from core.browser import get_linux_chrome_args, find_browser_path

    # 用户数据目录
    user_data_dir = config.user_data_dir
    print(f"用户数据目录: {user_data_dir}")
    print()

    # 确保目录存在
    Path(user_data_dir).mkdir(parents=True, exist_ok=True)

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

    # 强制有头模式
    co.headless(False)

    # 基本选项
    co.set_argument("--disable-blink-features=AutomationControlled")
    co.set_argument("--no-first-run")
    co.set_argument("--no-default-browser-check")

    # Linux 系统自动添加必要参数（关键修复！）
    linux_args = get_linux_chrome_args()
    for arg in linux_args:
        co.set_argument(arg)

    # 用户自定义 Chrome 参数（如 --no-sandbox, --headless=new）
    for arg in config.chrome_args:
        co.set_argument(arg)

    print("正在启动浏览器...")
    try:
        page = ChromiumPage(co)
    except Exception as e:
        print(f"❌ 浏览器启动失败: {e}")
        print()
        print("可能的解决方案：")
        print("1. 确保已安装 Chromium 或 Chrome 浏览器")
        print("   Ubuntu/Debian: sudo apt install chromium-browser")
        print("   Fedora/RHEL:   sudo dnf install chromium")
        print("   Arch:          sudo pacman -S chromium")
        print()
        print("2. 如果仍然失败，尝试在 config.yaml 中添加：")
        print("   chrome_args:")
        print('     - "--no-sandbox"')
        print('     - "--disable-dev-shm-usage"')
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

    # 启动时检查更新（静默模式）
    if not args.no_update_check:
        try:
            from updater import check_update
            update_info = check_update(silent=True)
            if update_info:
                print(f"[提示] 发现新版本 v{update_info['latest_version']}，运行 --check-update 查看详情")
                print()
        except:
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
