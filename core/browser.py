"""
浏览器控制模块
使用 DrissionPage 控制 Chrome 浏览器
"""
import time
from pathlib import Path
from typing import Optional
from DrissionPage import ChromiumPage, ChromiumOptions
from .config import config


class Browser:
    """浏览器控制类"""

    def __init__(self):
        self.page: Optional[ChromiumPage] = None

    def _setup_user_data_dir(self):
        """确保用户数据目录存在"""
        user_data_dir = Path(config.user_data_dir)
        user_data_dir.mkdir(parents=True, exist_ok=True)

    def _create_options(self) -> ChromiumOptions:
        """创建浏览器选项"""
        co = ChromiumOptions()

        # 用户数据目录（保存登录状态）
        user_data_dir = config.user_data_dir
        if user_data_dir:
            co.set_argument(f"--user-data-dir={user_data_dir}")

        # 有头/无头模式
        co.headless(config.headless)

        # 自定义浏览器路径
        if config.browser_path:
            co.set_browser_path(config.browser_path)

        # 其他选项
        co.set_argument("--disable-blink-features=AutomationControlled")
        co.set_argument("--no-first-run")
        co.set_argument("--no-default-browser-check")
        co.set_argument("--disable-infobars")

        return co

    def start(self) -> bool:
        """启动浏览器"""
        try:
            # 确保用户数据目录存在
            self._setup_user_data_dir()

            options = self._create_options()
            self.page = ChromiumPage(options)
            print("[浏览器] 启动成功")
            return True
        except Exception as e:
            print(f"[浏览器] 启动失败: {e}")
            return False

    def quit(self):
        """关闭浏览器"""
        if self.page:
            try:
                self.page.quit()
                print("[浏览器] 已关闭")
            except Exception as e:
                print(f"[浏览器] 关闭异常: {e}")
            finally:
                self.page = None

    def goto(self, url: str, wait: float = 2) -> bool:
        """访问页面"""
        if not self.page:
            print("[浏览器] 浏览器未启动")
            return False
        try:
            self.page.get(url)
            time.sleep(wait)
            return True
        except Exception as e:
            print(f"[浏览器] 访问失败 {url}: {e}")
            return False

    def wait_for_cf(self, timeout: int = 120) -> bool:
        """
        等待 Cloudflare 5秒盾验证通过
        检测页面是否还在验证中
        """
        if not self.page:
            return False

        print("[浏览器] 检测 CF 验证...")
        start_time = time.time()

        while time.time() - start_time < timeout:
            try:
                page_text = self.page.html.lower()
            except:
                time.sleep(2)
                continue

            # CF 验证中的特征
            cf_checking = any([
                "just a moment" in page_text,
                "请稍候" in page_text,
                "checking your browser" in page_text,
                "cf-browser-verification" in page_text,
            ])

            if not cf_checking:
                print("[浏览器] CF 验证通过")
                return True

            # 尝试点击 Turnstile 验证框
            try:
                turnstile = self.page.ele("css:input[type='checkbox']", timeout=1)
                if turnstile:
                    turnstile.click()
                    print("[浏览器] 点击 Turnstile 验证框")
            except:
                pass

            time.sleep(2)

        print("[浏览器] CF 验证超时")
        return False

    def check_rate_limit(self) -> bool:
        """检测 429 限流"""
        if not self.page:
            return False
        try:
            # 检查 HTTP 状态码（如果页面显示错误）
            page_title = self.page.title.lower() if self.page.title else ""
            page_text = self.page.html.lower()

            # 只检查明确的限流标识，避免误判
            rate_limited = any([
                "rate limited" in page_text,
                "too many requests" in page_title,
                "429 too many" in page_text,
                "<h1>429</h1>" in page_text,
            ])
            if rate_limited:
                print("[浏览器] 检测到 429 限流")
            return rate_limited
        except:
            return False

    def check_cf_403(self) -> bool:
        """检测 CF 403 错误"""
        if not self.page:
            return False
        try:
            # 检测弹出对话框
            dialog = self.page.ele("css:.dialog-body", timeout=1)
            if dialog and "403" in dialog.text.lower():
                print("[浏览器] 检测到 CF 403 错误")
                return True
            # 检测页面级 403
            page_text = self.page.html.lower() if self.page.html else ""
            if "403 forbidden" in page_text or "<h1>403</h1>" in page_text:
                print("[浏览器] 检测到 CF 403 页面")
                return True
        except:
            pass
        return False

    def close_403_dialog(self) -> bool:
        """关闭 403 错误对话框"""
        try:
            # 查找并点击"确定"按钮
            ok_btn = self.page.ele("css:.dialog-footer .btn-primary", timeout=2)
            if ok_btn:
                ok_btn.click()
                print("[浏览器] 已关闭 403 对话框")
                time.sleep(1)
                return True
            # 备选：查找任何对话框的确定按钮
            ok_btn = self.page.ele("css:button.btn-primary", timeout=1)
            if ok_btn and ("确定" in ok_btn.text or "OK" in ok_btn.text.upper()):
                ok_btn.click()
                print("[浏览器] 已关闭对话框")
                time.sleep(1)
                return True
        except:
            pass
        return False

    def handle_cf_403(self, current_url: str) -> bool:
        """处理 CF 403 错误，等待验证完成"""
        try:
            # 1. 先关闭 403 对话框
            self.close_403_dialog()

            # 2. 跳转到 challenge 页面
            challenge_url = f"https://linux.do/challenge?redirect={current_url}"
            print(f"[浏览器] 跳转到验证页面...")
            self.goto(challenge_url, wait=3)

            # 3. 等待 CF 验证完成（增加超时时间）
            if not self.wait_for_cf(timeout=180):
                print("[浏览器] CF 验证超时，等待用户手动处理...")
                # 额外等待用户手动处理
                time.sleep(30)
                return self.wait_for_cf(timeout=60)

            return True
        except Exception as e:
            print(f"[浏览器] 处理 CF 403 失败: {e}")
            return False

    def is_logged_in(self) -> bool:
        """检测是否已登录"""
        if not self.page:
            return False
        try:
            # 检查是否有用户头像或用户菜单
            user_menu = self.page.ele("css:.current-user", timeout=3)
            if user_menu:
                return True

            # 检查是否有登录按钮
            login_btn = self.page.ele("css:.login-button", timeout=1)
            if login_btn:
                return False

            return False
        except:
            return False

    def get_current_user(self) -> Optional[str]:
        """获取当前登录用户名"""
        if not self.page:
            return None
        try:
            # 方法1: 从用户头像 URL 提取用户名
            # 格式: /user_avatar/linux.do/USERNAME/48/xxx.png
            avatar = self.page.ele("css:#current-user img.avatar", timeout=3)
            if avatar:
                src = avatar.attr("src")
                if src and "/user_avatar/" in src:
                    # /user_avatar/linux.do/username/48/xxx.png
                    parts = src.split("/user_avatar/")[-1].split("/")
                    if len(parts) >= 2:
                        return parts[1]  # 用户名在第二段

            # 方法2: 从页面中的 /u/ 链接提取（备选）
            user_links = self.page.eles("css:a[href*='/u/']")
            for link in user_links[:10]:
                href = link.attr("href")
                if href and "/u/" in href and "/activity/" in href:
                    # https://linux.do/u/username/activity/drafts
                    return href.split("/u/")[-1].split("/")[0]
        except:
            pass
        return None
