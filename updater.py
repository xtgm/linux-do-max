"""
自动更新模块
检测 GitHub Release 并下载更新

支持两种安装方式：
1. 源码安装（git clone）- 使用 git pull 更新
2. 预编译二进制 - 下载新版本替换
"""
import os
import sys
import platform
import subprocess
import shutil
import tempfile
import stat
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


def is_git_repo():
    """检测当前目录是否为 git 仓库"""
    try:
        # 获取脚本所在目录
        script_dir = os.path.dirname(os.path.abspath(__file__))
        result = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0 and result.stdout.strip() == "true"
    except:
        return False


def is_frozen():
    """检测是否为打包的可执行文件（PyInstaller）"""
    return getattr(sys, 'frozen', False)


def get_install_type():
    """
    获取安装类型

    Returns:
        str: "binary" (预编译二进制), "git" (git clone), "source" (其他源码)
    """
    if is_frozen():
        return "binary"
    elif is_git_repo():
        return "git"
    else:
        return "source"


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
                "install_type": get_install_type(),
            }
        else:
            if not silent:
                print("[更新] 已是最新版本")
            return None

    except Exception as e:
        if not silent:
            print(f"[更新] 检查更新异常: {e}")
        return None


def update_via_git():
    """
    通过 git pull 更新（源码安装方式）

    Returns:
        bool: 更新是否成功
    """
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))

        print("[更新] 正在通过 git pull 更新...")

        # 先 fetch
        result = subprocess.run(
            ["git", "fetch", "origin"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode != 0:
            print(f"[更新] git fetch 失败: {result.stderr}")
            return False

        # 检查是否有本地修改
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.stdout.strip():
            print("[更新] 检测到本地修改，尝试 stash...")
            subprocess.run(
                ["git", "stash"],
                cwd=script_dir,
                capture_output=True,
                timeout=10
            )

        # 执行 pull
        result = subprocess.run(
            ["git", "pull", "origin", "main"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode != 0:
            # 尝试 master 分支
            result = subprocess.run(
                ["git", "pull", "origin", "master"],
                cwd=script_dir,
                capture_output=True,
                text=True,
                timeout=120
            )

        if result.returncode == 0:
            print("[更新] ✅ 更新成功！")
            print("[更新] 请重新运行程序以使用新版本")
            return True
        else:
            print(f"[更新] git pull 失败: {result.stderr}")
            return False

    except subprocess.TimeoutExpired:
        print("[更新] 更新超时，请检查网络连接")
        return False
    except Exception as e:
        print(f"[更新] 更新异常: {e}")
        return False


def update_via_download(download_url):
    """
    通过下载替换更新（预编译二进制方式）

    Args:
        download_url: 下载链接

    Returns:
        bool: 更新是否成功
    """
    if not download_url:
        print("[更新] 未找到当前平台的下载链接")
        return False

    try:
        print(f"[更新] 正在下载新版本...")
        print(f"[更新] 下载地址: {download_url}")

        # 获取当前可执行文件路径
        if is_frozen():
            current_exe = sys.executable
        else:
            # 源码模式，不支持自动下载替换
            print("[更新] 源码安装模式不支持自动下载更新")
            print("[更新] 请手动下载或使用 git pull")
            return False

        # 下载到临时文件
        resp = requests.get(download_url, stream=True, timeout=300)
        if resp.status_code != 200:
            print(f"[更新] 下载失败: HTTP {resp.status_code}")
            return False

        # 获取文件大小
        total_size = int(resp.headers.get('content-length', 0))

        # 创建临时文件
        suffix = ".exe" if platform.system() == "Windows" else ""
        fd, temp_path = tempfile.mkstemp(suffix=suffix)

        try:
            downloaded = 0
            with os.fdopen(fd, 'wb') as f:
                for chunk in resp.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r[更新] 下载进度: {percent:.1f}%", end="", flush=True)

            print()  # 换行

            # 设置执行权限（Linux/macOS）
            if platform.system() != "Windows":
                os.chmod(temp_path, os.stat(temp_path).st_mode | stat.S_IEXEC)

            # 备份当前文件
            backup_path = current_exe + ".backup"
            if os.path.exists(backup_path):
                os.remove(backup_path)

            # Windows 下需要特殊处理（无法替换正在运行的文件）
            if platform.system() == "Windows":
                # 创建更新脚本
                update_script = current_exe + ".update.bat"
                with open(update_script, 'w') as f:
                    f.write(f'''@echo off
timeout /t 2 /nobreak >nul
move /y "{current_exe}" "{backup_path}"
move /y "{temp_path}" "{current_exe}"
del "%~f0"
echo 更新完成！请重新运行程序。
pause
''')
                print("[更新] ✅ 下载完成！")
                print("[更新] 请关闭程序后运行更新脚本完成更新")
                print(f"[更新] 更新脚本: {update_script}")
                return True
            else:
                # Linux/macOS 可以直接替换
                shutil.move(current_exe, backup_path)
                shutil.move(temp_path, current_exe)
                print("[更新] ✅ 更新成功！")
                print("[更新] 请重新运行程序以使用新版本")
                return True

        except Exception as e:
            # 清理临时文件
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise e

    except requests.exceptions.Timeout:
        print("[更新] 下载超时，请检查网络连接")
        return False
    except Exception as e:
        print(f"[更新] 下载更新异常: {e}")
        return False


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
        # 清理乱码（GitHub API 返回的中文可能有编码问题）
        notes = update_info["release_notes"][:500]
        print(notes)
        if len(update_info.get("release_notes", "")) > 500:
            print("...")

    install_type = update_info.get("install_type", "source")

    print()
    print(f"安装方式: {install_type}")

    if install_type == "git":
        print("更新方式: git pull")
    elif install_type == "binary":
        print("更新方式: 下载替换")
        if update_info.get("download_url"):
            print(f"下载地址: {update_info['download_url']}")
    else:
        print("更新方式: 手动下载")
        print(f"下载页面: {update_info.get('release_url')}")

    print()
    print("请选择操作:")
    print("  1. 自动更新（推荐）")
    print("  2. 打开下载页面")
    print("  3. 取消")
    print()

    choice = input("请选择 [1-3]: ").strip()

    if choice == "1":
        # 自动更新
        if install_type == "git":
            return update_via_git()
        elif install_type == "binary":
            return update_via_download(update_info.get("download_url"))
        else:
            print("[更新] 当前安装方式不支持自动更新")
            print("[更新] 请手动下载新版本")
            import webbrowser
            webbrowser.open(update_info.get("release_url"))
            return False
    elif choice == "2":
        import webbrowser
        webbrowser.open(update_info.get("release_url"))
        return True
    else:
        print("[更新] 已取消")
        return False


if __name__ == "__main__":
    prompt_update()
