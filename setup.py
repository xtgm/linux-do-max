#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LinuxDO 签到 - 一键安装脚本
支持: Windows / Linux / macOS / ARM

功能:
- 自动检测系统平台
- 自动安装依赖
- 交互式配置
- 设置定时任务
- 首次登录引导

使用方法:
    python setup.py
"""

import os
import sys
import platform
import subprocess
import shutil
import json
import re
from pathlib import Path
from typing import Optional, Dict, Any

# ============================================================
# 版本信息
# ============================================================
VERSION = "1.2.0"
SCRIPT_NAME = "LinuxDO 签到一键安装脚本"

# ============================================================
# 颜色输出
# ============================================================
class Colors:
    """终端颜色"""
    if sys.platform == "win32":
        # Windows 启用 ANSI 颜色
        os.system("")

    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    PURPLE = "\033[0;35m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"  # No Color

def print_banner():
    """打印横幅"""
    print()
    print(f"{Colors.CYAN}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.CYAN}║{Colors.NC}        {Colors.GREEN}{SCRIPT_NAME} v{VERSION}{Colors.NC}        {Colors.CYAN}║{Colors.NC}")
    print(f"{Colors.CYAN}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()

def print_info(msg: str):
    print(f"{Colors.BLUE}[信息]{Colors.NC} {msg}")

def print_success(msg: str):
    print(f"{Colors.GREEN}[成功]{Colors.NC} {msg}")

def print_warning(msg: str):
    print(f"{Colors.YELLOW}[警告]{Colors.NC} {msg}")

def print_error(msg: str):
    print(f"{Colors.RED}[错误]{Colors.NC} {msg}")

def print_step(msg: str):
    print(f"{Colors.PURPLE}[步骤]{Colors.NC} {msg}")

# ============================================================
# 系统检测
# ============================================================
class SystemInfo:
    """系统信息检测"""

    def __init__(self):
        self.os_type: str = ""  # windows, linux, macos
        self.os_name: str = ""
        self.os_version: str = ""
        self.arch: str = ""  # x64, arm64, arm32
        self.arch_raw: str = ""
        self.distro: str = ""  # debian, ubuntu, centos, fedora, arch, alpine
        self.distro_name: str = ""
        self.pkg_manager: str = ""  # apt, dnf, yum, pacman, apk, brew
        self.is_arm: bool = False
        self.is_raspberry_pi: bool = False
        self.is_docker: bool = False
        self.has_display: bool = False
        self.python_path: str = sys.executable
        self.browser_path: str = ""
        self.home_dir: str = str(Path.home())
        self.script_dir: str = str(Path(__file__).parent.absolute())

        self._detect()

    def _detect(self):
        """检测系统信息"""
        # 操作系统
        system = platform.system().lower()
        if system == "windows":
            self.os_type = "windows"
            self.os_name = "Windows"
            self.os_version = platform.version()
        elif system == "darwin":
            self.os_type = "macos"
            self.os_name = "macOS"
            self.os_version = platform.mac_ver()[0]
        elif system == "linux":
            self.os_type = "linux"
            self.os_name = "Linux"
            self._detect_linux_distro()
        else:
            self.os_type = "unknown"
            self.os_name = system

        # 架构
        self.arch_raw = platform.machine().lower()
        if self.arch_raw in ("x86_64", "amd64"):
            self.arch = "x64"
        elif self.arch_raw in ("aarch64", "arm64"):
            self.arch = "arm64"
            self.is_arm = True
        elif self.arch_raw.startswith("arm"):
            self.arch = "arm32"
            self.is_arm = True
        else:
            self.arch = self.arch_raw

        # 树莓派检测
        if self.os_type == "linux":
            self._detect_raspberry_pi()

        # Docker 检测
        self._detect_docker()

        # 图形界面检测
        self._detect_display()

        # 浏览器检测
        self._detect_browser()

    def _detect_linux_distro(self):
        """检测 Linux 发行版"""
        try:
            if os.path.exists("/etc/os-release"):
                with open("/etc/os-release") as f:
                    content = f.read()
                    for line in content.split("\n"):
                        if line.startswith("ID="):
                            self.distro = line.split("=")[1].strip('"').lower()
                        elif line.startswith("PRETTY_NAME="):
                            self.distro_name = line.split("=")[1].strip('"')
                        elif line.startswith("VERSION_ID="):
                            self.os_version = line.split("=")[1].strip('"')
        except:
            pass

        # 包管理器检测
        if shutil.which("apt-get"):
            self.pkg_manager = "apt"
        elif shutil.which("dnf"):
            self.pkg_manager = "dnf"
        elif shutil.which("yum"):
            self.pkg_manager = "yum"
        elif shutil.which("pacman"):
            self.pkg_manager = "pacman"
        elif shutil.which("apk"):
            self.pkg_manager = "apk"
        elif shutil.which("zypper"):
            self.pkg_manager = "zypper"

    def _detect_raspberry_pi(self):
        """检测是否为树莓派"""
        try:
            if os.path.exists("/proc/device-tree/model"):
                with open("/proc/device-tree/model") as f:
                    model = f.read()
                    if "Raspberry Pi" in model:
                        self.is_raspberry_pi = True
        except:
            pass

    def _detect_docker(self):
        """检测是否在 Docker 容器中"""
        if os.path.exists("/.dockerenv"):
            self.is_docker = True
        elif os.path.exists("/proc/1/cgroup"):
            try:
                with open("/proc/1/cgroup") as f:
                    if "docker" in f.read():
                        self.is_docker = True
            except:
                pass

    def _detect_display(self):
        """检测是否有图形界面"""
        if self.os_type == "windows":
            self.has_display = True
        elif self.os_type == "macos":
            self.has_display = True
        else:
            self.has_display = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))

    def _detect_browser(self):
        """检测浏览器路径"""
        browser_paths = []

        if self.os_type == "windows":
            browser_paths = [
                os.path.expandvars(r"%ProgramFiles%\Google\Chrome\Application\chrome.exe"),
                os.path.expandvars(r"%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"),
                os.path.expandvars(r"%LocalAppData%\Google\Chrome\Application\chrome.exe"),
            ]
        elif self.os_type == "macos":
            browser_paths = [
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                "/Applications/Chromium.app/Contents/MacOS/Chromium",
            ]
        else:  # Linux
            browser_paths = [
                "/usr/bin/chromium-browser",
                "/usr/bin/chromium",
                "/usr/lib/chromium/chromium",
                "/snap/bin/chromium",
                "/usr/bin/google-chrome",
                "/usr/bin/google-chrome-stable",
            ]

        for path in browser_paths:
            if os.path.exists(path):
                self.browser_path = path
                break

    def print_info(self):
        """打印系统信息"""
        print()
        print("┌─────────────────────────────────────────┐")
        print("│           系统环境检测结果              │")
        print("├─────────────────────────────────────────┤")
        print(f"│ {'操作系统':<12} │ {self.os_name:<21} │")
        print(f"│ {'版本':<14} │ {self.os_version[:21]:<21} │")
        print(f"│ {'架构':<14} │ {self.arch_raw} ({self.arch}){'':<10} │")
        if self.os_type == "linux":
            print(f"│ {'发行版':<12} │ {self.distro:<21} │")
            print(f"│ {'包管理器':<10} │ {self.pkg_manager:<21} │")
        print(f"│ {'ARM设备':<12} │ {'是' if self.is_arm else '否':<21} │")
        print(f"│ {'树莓派':<13} │ {'是' if self.is_raspberry_pi else '否':<21} │")
        print(f"│ {'Docker容器':<9} │ {'是' if self.is_docker else '否':<21} │")
        print(f"│ {'图形界面':<10} │ {'有' if self.has_display else '无':<21} │")
        print(f"│ {'浏览器':<13} │ {'已安装' if self.browser_path else '未安装':<21} │")
        print("└─────────────────────────────────────────┘")
        print()


# ============================================================
# 配置管理
# ============================================================
class ConfigManager:
    """配置文件管理"""

    DEFAULT_CONFIG = {
        "username": "",
        "password": "",
        "user_data_dir": "",
        "headless": False,
        "browser_path": "",
        "browse_count": 10,
        "like_probability": 0.3,
        "browse_interval_min": 3,
        "browse_interval_max": 8,
        "tg_bot_token": "",
        "tg_chat_id": "",
    }

    ENV_MAPPING = {
        "LINUXDO_USERNAME": "username",
        "LINUXDO_PASSWORD": "password",
        "USER_DATA_DIR": "user_data_dir",
        "HEADLESS": "headless",
        "BROWSER_PATH": "browser_path",
        "BROWSE_COUNT": "browse_count",
        "LIKE_PROBABILITY": "like_probability",
        "BROWSE_INTERVAL_MIN": "browse_interval_min",
        "BROWSE_INTERVAL_MAX": "browse_interval_max",
        "TG_BOT_TOKEN": "tg_bot_token",
        "TG_CHAT_ID": "tg_chat_id",
    }

    def __init__(self, config_path: str = "config.yaml"):
        self.config_path = config_path
        self.config: Dict[str, Any] = self.DEFAULT_CONFIG.copy()
        self._load()

    def _load(self):
        """加载配置文件"""
        if os.path.exists(self.config_path):
            try:
                import yaml
                with open(self.config_path, "r", encoding="utf-8") as f:
                    loaded = yaml.safe_load(f) or {}
                    self.config.update(loaded)
            except ImportError:
                # 如果没有 yaml 模块，尝试简单解析
                self._load_simple()
            except Exception as e:
                print_warning(f"加载配置文件失败: {e}")

    def _load_simple(self):
        """简单解析 YAML（不依赖 PyYAML）"""
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and ":" in line:
                        key, value = line.split(":", 1)
                        key = key.strip()
                        value = value.strip().strip('"').strip("'")
                        if key in self.config:
                            # 类型转换
                            if isinstance(self.DEFAULT_CONFIG.get(key), bool):
                                value = value.lower() in ("true", "1", "yes")
                            elif isinstance(self.DEFAULT_CONFIG.get(key), int):
                                value = int(value) if value else 0
                            elif isinstance(self.DEFAULT_CONFIG.get(key), float):
                                value = float(value) if value else 0.0
                            self.config[key] = value
        except Exception as e:
            print_warning(f"简单解析配置失败: {e}")

    def save(self):
        """保存配置文件"""
        content = f"""# ============================================================
# LinuxDO 签到配置文件
# 由一键安装脚本自动生成
# 环境变量优先级高于此配置文件
# ============================================================

# ========== 账号配置 ==========
username: "{self.config['username']}"
password: "{self.config['password']}"

# ========== 浏览器配置 ==========
user_data_dir: "{self.config['user_data_dir']}"
headless: {str(self.config['headless']).lower()}
browser_path: "{self.config['browser_path']}"

# ========== 签到配置 ==========
browse_count: {self.config['browse_count']}
like_probability: {self.config['like_probability']}
browse_interval_min: {self.config['browse_interval_min']}
browse_interval_max: {self.config['browse_interval_max']}

# ========== Telegram 通知 ==========
tg_bot_token: "{self.config['tg_bot_token']}"
tg_chat_id: "{self.config['tg_chat_id']}"
"""
        with open(self.config_path, "w", encoding="utf-8") as f:
            f.write(content)
        print_success(f"配置已保存: {self.config_path}")

    def get(self, key: str, default: Any = None) -> Any:
        """获取配置（环境变量优先）"""
        # 检查环境变量
        for env_key, config_key in self.ENV_MAPPING.items():
            if config_key == key:
                env_value = os.environ.get(env_key)
                if env_value:
                    # 类型转换
                    if isinstance(self.DEFAULT_CONFIG.get(key), bool):
                        return env_value.lower() in ("true", "1", "yes")
                    elif isinstance(self.DEFAULT_CONFIG.get(key), int):
                        return int(env_value)
                    elif isinstance(self.DEFAULT_CONFIG.get(key), float):
                        return float(env_value)
                    return env_value
        return self.config.get(key, default)

    def set(self, key: str, value: Any):
        """设置配置"""
        self.config[key] = value

    def interactive_edit(self):
        """交互式编辑配置"""
        print()
        print("┌─────────────────────────────────────────┐")
        print("│           配置编辑菜单                  │")
        print("└─────────────────────────────────────────┘")
        print()

        while True:
            print("当前配置:")
            print(f"  1. 用户名: {self.config['username'] or '(未设置)'}")
            print(f"  2. 密码: {'*' * len(self.config['password']) if self.config['password'] else '(未设置)'}")
            print(f"  3. 用户数据目录: {self.config['user_data_dir'] or '(默认)'}")
            print(f"  4. 无头模式: {self.config['headless']}")
            print(f"  5. 浏览器路径: {self.config['browser_path'] or '(自动检测)'}")
            print(f"  6. 浏览帖子数: {self.config['browse_count']}")
            print(f"  7. 点赞概率: {self.config['like_probability']}")
            print(f"  8. Telegram Token: {self.config['tg_bot_token'][:20] + '...' if self.config['tg_bot_token'] else '(未设置)'}")
            print(f"  9. Telegram Chat ID: {self.config['tg_chat_id'] or '(未设置)'}")
            print()
            print("  0. 保存并返回")
            print("  q. 不保存返回")
            print()

            choice = input("请选择要修改的项 [0-9/q]: ").strip()

            if choice == "0":
                self.save()
                break
            elif choice == "q":
                print_info("取消修改")
                break
            elif choice == "1":
                self.config["username"] = input("用户名: ").strip()
            elif choice == "2":
                self.config["password"] = input("密码: ").strip()
            elif choice == "3":
                self.config["user_data_dir"] = input("用户数据目录: ").strip()
            elif choice == "4":
                val = input("无头模式 (true/false): ").strip().lower()
                self.config["headless"] = val in ("true", "1", "yes")
            elif choice == "5":
                self.config["browser_path"] = input("浏览器路径: ").strip()
            elif choice == "6":
                try:
                    self.config["browse_count"] = int(input("浏览帖子数: ").strip())
                except:
                    print_error("请输入数字")
            elif choice == "7":
                try:
                    self.config["like_probability"] = float(input("点赞概率 (0-1): ").strip())
                except:
                    print_error("请输入数字")
            elif choice == "8":
                self.config["tg_bot_token"] = input("Telegram Bot Token: ").strip()
            elif choice == "9":
                self.config["tg_chat_id"] = input("Telegram Chat ID: ").strip()

            print()


# ============================================================
# 依赖安装器
# ============================================================
class DependencyInstaller:
    """依赖安装器"""

    def __init__(self, sys_info: SystemInfo):
        self.sys_info = sys_info

    def install_all(self):
        """安装所有依赖"""
        print_step("安装系统依赖...")

        if self.sys_info.os_type == "linux":
            self._install_linux_deps()
        elif self.sys_info.os_type == "macos":
            self._install_macos_deps()
        elif self.sys_info.os_type == "windows":
            self._check_windows_deps()

        print_success("系统依赖检查完成")

    def _install_linux_deps(self):
        """安装 Linux 依赖"""
        pkg_manager = self.sys_info.pkg_manager

        if pkg_manager == "apt":
            packages = [
                "chromium-browser", "chromium",
                "xvfb",
                "fonts-wqy-zenhei", "fonts-wqy-microhei",
                "libatk1.0-0", "libatk-bridge2.0-0", "libcups2",
                "libdrm2", "libxkbcommon0", "libxcomposite1",
                "libxdamage1", "libxfixes3", "libxrandr2",
                "libgbm1", "libasound2"
            ]
            print_info("使用 apt 安装依赖...")
            self._run_cmd("sudo apt-get update")
            for pkg in packages:
                self._run_cmd(f"sudo apt-get install -y {pkg}", ignore_error=True)

        elif pkg_manager == "dnf":
            print_info("使用 dnf 安装依赖...")
            self._run_cmd("sudo dnf install -y chromium chromedriver xorg-x11-server-Xvfb wqy-zenhei-fonts", ignore_error=True)

        elif pkg_manager == "yum":
            print_info("使用 yum 安装依赖...")
            self._run_cmd("sudo yum install -y chromium chromedriver xorg-x11-server-Xvfb wqy-zenhei-fonts", ignore_error=True)

        elif pkg_manager == "pacman":
            print_info("使用 pacman 安装依赖...")
            self._run_cmd("sudo pacman -Syu --noconfirm chromium xorg-server-xvfb wqy-zenhei", ignore_error=True)

        elif pkg_manager == "apk":
            print_info("使用 apk 安装依赖...")
            self._run_cmd("sudo apk add chromium chromium-chromedriver xvfb font-wqy-zenhei ttf-wqy-zenhei", ignore_error=True)

        else:
            print_warning(f"未知包管理器: {pkg_manager}")
            print_info("请手动安装: Chromium, Xvfb, 中文字体")

    def _install_macos_deps(self):
        """安装 macOS 依赖"""
        # 检查 Homebrew
        if not shutil.which("brew"):
            print_info("安装 Homebrew...")
            self._run_cmd('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')

        # 检查 Chrome
        if not self.sys_info.browser_path:
            print_warning("未检测到 Chrome/Chromium")
            print_info("请从 https://www.google.com/chrome/ 下载安装")

    def _check_windows_deps(self):
        """检查 Windows 依赖"""
        if not self.sys_info.browser_path:
            print_warning("未检测到 Chrome")
            print_info("请从 https://www.google.com/chrome/ 下载安装")

    def _run_cmd(self, cmd: str, ignore_error: bool = False) -> bool:
        """运行命令"""
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            if not ignore_error:
                print_error(f"命令执行失败: {e}")
            return False

    def setup_python_env(self):
        """配置 Python 环境"""
        print_step("配置 Python 环境...")

        venv_dir = os.path.join(self.sys_info.script_dir, "venv")

        # 创建虚拟环境
        if not os.path.exists(venv_dir):
            print_info("创建虚拟环境...")
            subprocess.run([sys.executable, "-m", "venv", "venv"], cwd=self.sys_info.script_dir)

        # 获取 pip 路径
        if self.sys_info.os_type == "windows":
            pip_path = os.path.join(venv_dir, "Scripts", "pip.exe")
            python_path = os.path.join(venv_dir, "Scripts", "python.exe")
        else:
            pip_path = os.path.join(venv_dir, "bin", "pip")
            python_path = os.path.join(venv_dir, "bin", "python")

        # 升级 pip
        print_info("升级 pip...")
        subprocess.run([python_path, "-m", "pip", "install", "--upgrade", "pip"], capture_output=True)

        # 安装依赖
        print_info("安装 Python 依赖...")
        requirements_path = os.path.join(self.sys_info.script_dir, "requirements.txt")
        if os.path.exists(requirements_path):
            subprocess.run([pip_path, "install", "-r", requirements_path])
        else:
            # 直接安装核心依赖
            subprocess.run([pip_path, "install", "DrissionPage>=4.0.0", "PyYAML>=6.0", "requests>=2.28.0"])

        print_success("Python 环境配置完成")
        return python_path


# ============================================================
# 定时任务管理
# ============================================================
class CronManager:
    """定时任务管理"""

    def __init__(self, sys_info: SystemInfo):
        self.sys_info = sys_info

    def setup(self):
        """设置定时任务"""
        print_step("配置定时任务...")

        confirm = input("是否设置定时任务？[y/N]: ").strip().lower()
        if confirm not in ("y", "yes"):
            print_info("跳过定时任务配置")
            return

        if self.sys_info.os_type == "windows":
            self._setup_windows_task()
        elif self.sys_info.os_type == "macos":
            self._setup_launchd()
        else:
            self._setup_cron()

    def _setup_windows_task(self):
        """设置 Windows 任务计划"""
        script_dir = self.sys_info.script_dir
        python_path = os.path.join(script_dir, "venv", "Scripts", "python.exe")
        main_script = os.path.join(script_dir, "main.py")

        # 选择时间
        print()
        print("选择签到时间:")
        print("  1. 每天 8:00 和 20:00（推荐）")
        print("  2. 每天 9:00")
        print("  3. 自定义")
        choice = input("请选择 [1-3]: ").strip()

        times = []
        if choice == "1":
            times = ["08:00", "20:00"]
        elif choice == "2":
            times = ["09:00"]
        elif choice == "3":
            t1 = input("第一个时间 (如 08:00): ").strip()
            times.append(t1)
            t2 = input("第二个时间 (直接回车跳过): ").strip()
            if t2:
                times.append(t2)
        else:
            times = ["08:00", "20:00"]

        # 创建任务
        for i, time in enumerate(times, 1):
            task_name = f"LinuxDO-Checkin-{i}"
            cmd = f'schtasks /create /tn "{task_name}" /tr "\\"{python_path}\\" \\"{main_script}\\"" /sc daily /st {time} /f'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                print_success(f"任务 {task_name} 已创建 ({time})")
            else:
                print_error(f"创建任务失败: {result.stderr}")

    def _setup_launchd(self):
        """设置 macOS launchd"""
        script_dir = self.sys_info.script_dir
        python_path = os.path.join(script_dir, "venv", "bin", "python")
        main_script = os.path.join(script_dir, "main.py")
        plist_path = os.path.expanduser("~/Library/LaunchAgents/com.linuxdo.checkin.plist")

        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.linuxdo.checkin</string>
    <key>ProgramArguments</key>
    <array>
        <string>{python_path}</string>
        <string>{main_script}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>{script_dir}</string>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>8</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>20</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>
    <key>StandardOutPath</key>
    <string>{script_dir}/logs/checkin.log</string>
    <key>StandardErrorPath</key>
    <string>{script_dir}/logs/checkin.log</string>
</dict>
</plist>
"""
        # 创建日志目录
        os.makedirs(os.path.join(script_dir, "logs"), exist_ok=True)

        # 写入 plist
        with open(plist_path, "w") as f:
            f.write(plist_content)

        # 加载任务
        subprocess.run(["launchctl", "unload", plist_path], capture_output=True)
        subprocess.run(["launchctl", "load", plist_path])

        print_success("macOS 定时任务已设置")

    def _setup_cron(self):
        """设置 Linux cron"""
        script_dir = self.sys_info.script_dir
        python_path = os.path.join(script_dir, "venv", "bin", "python")

        # 选择时间
        print()
        print("选择签到时间:")
        print("  1. 每天 8:00 和 20:00（推荐）")
        print("  2. 每天 9:00")
        print("  3. 自定义")
        choice = input("请选择 [1-3]: ").strip()

        cron_entries = []
        if choice == "1":
            cron_entries = [
                f"0 8 * * * cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1",
                f"0 20 * * * cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1",
            ]
        elif choice == "2":
            cron_entries = [
                f"0 9 * * * cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1",
            ]
        elif choice == "3":
            t1 = input("第一个时间 (cron 格式，如 0 8 * * *): ").strip()
            cron_entries.append(f"{t1} cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1")
            t2 = input("第二个时间 (直接回车跳过): ").strip()
            if t2:
                cron_entries.append(f"{t2} cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1")
        else:
            cron_entries = [
                f"0 8 * * * cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1",
                f"0 20 * * * cd {script_dir} && xvfb-run -a {python_path} main.py >> logs/checkin.log 2>&1",
            ]

        # 创建日志目录
        os.makedirs(os.path.join(script_dir, "logs"), exist_ok=True)

        # 获取现有 crontab
        try:
            result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
            existing_cron = result.stdout if result.returncode == 0 else ""
        except:
            existing_cron = ""

        # 移除旧的 LinuxDO 任务
        lines = [l for l in existing_cron.split("\n") if "linuxdo" not in l.lower() and "LinuxDO" not in l]

        # 添加新任务
        lines.append("# LinuxDO 签到任务")
        lines.extend(cron_entries)

        # 写入 crontab
        new_cron = "\n".join(lines) + "\n"
        process = subprocess.Popen(["crontab", "-"], stdin=subprocess.PIPE, text=True)
        process.communicate(input=new_cron)

        print_success("Linux 定时任务已设置")
        print_info("查看任务: crontab -l | grep -i linuxdo")


# ============================================================
# 主安装程序
# ============================================================
class Installer:
    """主安装程序"""

    def __init__(self):
        self.sys_info = SystemInfo()
        self.config = ConfigManager()
        self.dep_installer = DependencyInstaller(self.sys_info)
        self.cron_manager = CronManager(self.sys_info)

    def run(self):
        """运行安装程序"""
        print_banner()

        # 检查是否在项目目录
        if not os.path.exists("main.py") and not os.path.exists("requirements.txt"):
            print_error("请在项目目录下运行此脚本")
            print_info("cd /path/to/linuxdo-checkin && python setup.py")
            return

        # 显示系统信息
        self.sys_info.print_info()

        # 显示主菜单
        self.main_menu()

    def main_menu(self):
        """主菜单"""
        while True:
            print()
            print("┌─────────────────────────────────────────┐")
            print("│              主菜单                     │")
            print("├─────────────────────────────────────────┤")
            print("│  1. 一键安装（推荐）                    │")
            print("│  2. 仅安装依赖                          │")
            print("│  3. 仅配置 Python 环境                  │")
            print("│  4. 编辑配置文件                        │")
            print("│  5. 设置定时任务                        │")
            print("│  6. 首次登录                            │")
            print("│  7. 运行签到                            │")
            print("│  8. 查看系统信息                        │")
            print("│  0. 退出                                │")
            print("└─────────────────────────────────────────┘")
            print()

            choice = input("请选择 [0-8]: ").strip()

            if choice == "0":
                print_info("退出")
                break
            elif choice == "1":
                self.full_install()
            elif choice == "2":
                self.dep_installer.install_all()
            elif choice == "3":
                self.dep_installer.setup_python_env()
            elif choice == "4":
                self.config.interactive_edit()
            elif choice == "5":
                self.cron_manager.setup()
            elif choice == "6":
                self.first_login()
            elif choice == "7":
                self.run_checkin()
            elif choice == "8":
                self.sys_info.print_info()
            else:
                print_error("无效选项")

    def full_install(self):
        """完整安装"""
        print()
        print_step("开始一键安装...")
        print()

        # 1. 安装系统依赖
        self.dep_installer.install_all()
        print()

        # 2. 配置 Python 环境
        python_path = self.dep_installer.setup_python_env()
        print()

        # 3. 交互式配置
        self._interactive_config()
        print()

        # 4. 设置定时任务
        self.cron_manager.setup()
        print()

        # 5. 首次登录
        self.first_login()
        print()

        # 6. 完成
        self._print_completion()

    def _interactive_config(self):
        """交互式配置"""
        print_step("配置向导...")
        print()

        # 检查是否已有配置
        if os.path.exists("config.yaml"):
            print_warning("检测到已有配置文件")
            choice = input("是否重新配置？[y/N]: ").strip().lower()
            if choice not in ("y", "yes"):
                print_info("使用现有配置")
                return

        print("请输入配置信息（直接回车使用默认值）:")
        print()

        # 用户名
        username = input("Linux.do 用户名 (可选): ").strip()
        self.config.set("username", username)

        # 密码
        if username:
            password = input("Linux.do 密码 (可选): ").strip()
            self.config.set("password", password)

        # 浏览帖子数
        browse_count = input("浏览帖子数量 [10]: ").strip()
        if browse_count:
            try:
                self.config.set("browse_count", int(browse_count))
            except:
                pass

        # 点赞概率
        like_prob = input("点赞概率 (0-1) [0.3]: ").strip()
        if like_prob:
            try:
                self.config.set("like_probability", float(like_prob))
            except:
                pass

        # 无头模式
        if not self.sys_info.has_display:
            print_info("未检测到图形界面，建议使用无头模式")
            headless_default = "true"
        else:
            headless_default = "false"
        headless = input(f"无头模式 (true/false) [{headless_default}]: ").strip().lower()
        if headless:
            self.config.set("headless", headless in ("true", "1", "yes"))
        else:
            self.config.set("headless", headless_default == "true")

        # 浏览器路径
        if self.sys_info.browser_path:
            print_info(f"检测到浏览器: {self.sys_info.browser_path}")
            self.config.set("browser_path", self.sys_info.browser_path)

        # 用户数据目录
        default_user_data = os.path.join(self.sys_info.home_dir, ".linuxdo-browser")
        user_data_dir = input(f"用户数据目录 [{default_user_data}]: ").strip()
        self.config.set("user_data_dir", user_data_dir or default_user_data)

        # Telegram
        print()
        print("Telegram 通知配置（可选）:")
        tg_token = input("Bot Token (直接回车跳过): ").strip()
        if tg_token:
            self.config.set("tg_bot_token", tg_token)
            tg_chat_id = input("Chat ID: ").strip()
            self.config.set("tg_chat_id", tg_chat_id)

        # 保存配置
        self.config.save()

        # 创建用户数据目录
        user_data_path = self.config.get("user_data_dir")
        if user_data_path:
            os.makedirs(user_data_path, exist_ok=True)
            print_success(f"用户数据目录已创建: {user_data_path}")

    def first_login(self):
        """首次登录"""
        print_step("首次登录...")

        if not self.sys_info.has_display:
            print()
            print_warning("未检测到图形界面")
            print()
            print("首次登录需要图形界面来手动操作浏览器。")
            print()
            print(f"  {Colors.GREEN}方式1: VNC 远程桌面{Colors.NC}")
            print("    安装: sudo apt install tigervnc-standalone-server")
            print("    启动: vncserver :1")
            print("    然后用 VNC 客户端连接")
            print()
            print(f"  {Colors.GREEN}方式2: SSH X11 转发{Colors.NC}")
            print("    本地安装 X Server (Windows: VcXsrv, Mac: XQuartz)")
            print("    SSH 连接: ssh -X user@host")
            print("    设置: export DISPLAY=localhost:10.0")
            print()
            print(f"  {Colors.GREEN}方式3: 在其他电脑完成首次登录{Colors.NC}")
            print("    1) 在有图形界面的电脑上运行首次登录")
            print("    2) 将 ~/.linuxdo-browser 目录复制到本机")
            print("    3) 之后可以无头模式运行")
            print()
            input("按 Enter 继续...")
            return

        confirm = input("是否现在进行首次登录？[Y/n]: ").strip().lower()
        if confirm in ("n", "no"):
            print_info("跳过首次登录")
            print_info("稍后运行: python main.py --first-login")
            return

        # 运行首次登录
        self._run_main_script("--first-login")

    def run_checkin(self):
        """运行签到"""
        print_step("运行签到...")

        if not self.sys_info.has_display and not self.config.get("headless"):
            print_warning("无图形界面，尝试使用 xvfb-run...")
            self._run_with_xvfb()
        else:
            self._run_main_script()

    def _run_main_script(self, *args):
        """运行主脚本"""
        venv_python = self._get_venv_python()
        if venv_python and os.path.exists(venv_python):
            cmd = [venv_python, "main.py"] + list(args)
        else:
            cmd = [sys.executable, "main.py"] + list(args)

        subprocess.run(cmd, cwd=self.sys_info.script_dir)

    def _run_with_xvfb(self):
        """使用 xvfb-run 运行"""
        venv_python = self._get_venv_python()
        if venv_python and os.path.exists(venv_python):
            python_cmd = venv_python
        else:
            python_cmd = sys.executable

        if shutil.which("xvfb-run"):
            subprocess.run(["xvfb-run", "-a", python_cmd, "main.py"], cwd=self.sys_info.script_dir)
        else:
            print_warning("未安装 xvfb-run，尝试直接运行...")
            subprocess.run([python_cmd, "main.py"], cwd=self.sys_info.script_dir)

    def _get_venv_python(self) -> str:
        """获取虚拟环境 Python 路径"""
        if self.sys_info.os_type == "windows":
            return os.path.join(self.sys_info.script_dir, "venv", "Scripts", "python.exe")
        else:
            return os.path.join(self.sys_info.script_dir, "venv", "bin", "python")

    def _print_completion(self):
        """打印完成信息"""
        print()
        print(f"{Colors.GREEN}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
        print(f"{Colors.GREEN}║                    安装完成！                              ║{Colors.NC}")
        print(f"{Colors.GREEN}╚════════════════════════════════════════════════════════════╝{Colors.NC}")
        print()
        print("后续操作:")
        print()
        print(f"  {Colors.CYAN}1. 首次登录（如果还没完成）:{Colors.NC}")
        if self.sys_info.os_type == "windows":
            print("     .\\venv\\Scripts\\python.exe main.py --first-login")
        else:
            print("     ./venv/bin/python main.py --first-login")
        print()
        print(f"  {Colors.CYAN}2. 手动运行签到:{Colors.NC}")
        if self.sys_info.os_type == "windows":
            print("     .\\venv\\Scripts\\python.exe main.py")
        else:
            print("     ./venv/bin/python main.py")
        print()
        print(f"  {Colors.CYAN}3. 编辑配置:{Colors.NC}")
        print("     python setup.py  # 选择 4")
        print()
        print(f"  {Colors.CYAN}4. 查看日志:{Colors.NC}")
        if self.sys_info.os_type == "windows":
            print("     type logs\\checkin.log")
        else:
            print("     tail -f logs/checkin.log")
        print()

        if not self.sys_info.has_display:
            print(f"{Colors.YELLOW}提示: 当前无图形界面，首次登录请参考上述方案{Colors.NC}")
            print()

        print("项目地址: https://github.com/xtgm/linux-do-max")
        print()


# ============================================================
# 入口
# ============================================================
def main():
    """主入口"""
    try:
        installer = Installer()
        installer.run()
    except KeyboardInterrupt:
        print()
        print_info("用户取消")
    except Exception as e:
        print_error(f"发生错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
