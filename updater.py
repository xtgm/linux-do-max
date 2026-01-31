"""
自动更新模块
检测 GitHub Release 并下载更新
"""
import os
import sys
import platform
import requests
from version import __version__, GITHUB_API, GITHUB_REPO


def get_platform_suffix():
    """获取当前平台的文件后缀"""
    system = platform.system()
    machine = platform.machine().lower()

    if system == "Windows":
        return "windows-x64.exe"
    elif system == "Darwin":  # macOS
        if "arm" in machine:
            return "macos-arm64"
        return "macos-x64"
    elif system == "Linux":
        if "arm" in machine or "aarch" in machine:
            return "linux-arm64"
        return "linux-x64"
    return None


def check_update(silent=False):
    """
    检查更新

    Args:
        silent: 静默模式，不打印信息

    Returns:
        dict: 包含更新信息，如果无更新返回 None
    """
    try:
        if not silent:
            print(f"[更新] 当前版本: v{__version__}")
            print("[更新] 检查更新中...")

        resp = requests.get(GITHUB_API, timeout=10)
        if resp.status_code != 200:
            if not silent:
                print("[更新] 检查更新失败")
            return None

        data = resp.json()
        latest_version = data.get("tag_name", "").lstrip("v")

        if not latest_version:
            return None

        # 比较版本号
        current_parts = [int(x) for x in __version__.split(".")]
        latest_parts = [int(x) for x in latest_version.split(".")]

        if latest_parts > current_parts:
            if not silent:
                print(f"[更新] 发现新版本: v{latest_version}")

            # 获取对应平台的下载链接
            suffix = get_platform_suffix()
            download_url = None

            for asset in data.get("assets", []):
                if suffix and suffix in asset.get("name", ""):
                    download_url = asset.get("browser_download_url")
                    break

            return {
                "current_version": __version__,
                "latest_version": latest_version,
                "download_url": download_url,
                "release_url": data.get("html_url"),
                "release_notes": data.get("body", ""),
            }
        else:
            if not silent:
                print("[更新] 已是最新版本")
            return None

    except Exception as e:
        if not silent:
            print(f"[更新] 检查更新异常: {e}")
        return None


def prompt_update():
    """提示用户更新"""
    update_info = check_update()

    if not update_info:
        return False

    print()
    print("=" * 50)
    print(f"发现新版本: v{update_info['latest_version']}")
    print("=" * 50)

    if update_info.get("release_notes"):
        print("\n更新内容:")
        print(update_info["release_notes"][:500])
        if len(update_info.get("release_notes", "")) > 500:
            print("...")

    print(f"\n下载地址: {update_info.get('release_url')}")

    if update_info.get("download_url"):
        print(f"直接下载: {update_info['download_url']}")

    print()
    choice = input("是否打开下载页面？(y/n): ").strip().lower()

    if choice == "y":
        import webbrowser
        webbrowser.open(update_info.get("release_url"))
        return True

    return False


if __name__ == "__main__":
    prompt_update()
