"""
签到核心逻辑模块
"""
import time
import random
import re
import json
from typing import Optional, Dict, List
from .browser import Browser
from .config import config
from .notify import Notifier


class Checkin:
    """签到类"""

    SITE_URL = "https://linux.do"
    CONNECT_URL = "https://connect.linux.do"

    def __init__(self):
        self.username: Optional[str] = None
        self.level: int = 0
        self.progress: Optional[Dict] = None
        self.stats = {
            'browse_count': 0,
            'read_comments': 0,
            'like_count': 0,
        }
        # 限流状态
        self._rate_limited_until: float = 0
        # 浏览器实例（每次运行创建新的）
        self._browser: Optional[Browser] = None
        # 通知实例
        self._notifier: Optional[Notifier] = None

    @property
    def browser(self) -> Browser:
        """获取浏览器实例"""
        if self._browser is None:
            self._browser = Browser()
        return self._browser

    @property
    def notifier(self) -> Notifier:
        """获取通知实例"""
        if self._notifier is None:
            self._notifier = Notifier()
        return self._notifier

    def is_rate_limited(self) -> bool:
        """检查是否在限流期内"""
        if time.time() < self._rate_limited_until:
            remaining = int(self._rate_limited_until - time.time())
            print(f"[签到] 限流中，剩余 {remaining} 秒")
            return True
        return False

    def set_rate_limited(self, duration: int = 1800):
        """设置限流状态（默认30分钟）"""
        self._rate_limited_until = time.time() + duration
        print(f"[签到] 设置限流 {duration} 秒")

    def run(self) -> bool:
        """执行签到流程"""
        print("=" * 50)
        print("[签到] 开始执行 Linux.do 签到")
        print("=" * 50)

        try:
            # 1. 启动浏览器
            if not self.browser.start():
                return self._finish(False)

            # 2. 访问首页
            print("[签到] 访问 Linux.do 首页...")
            if not self.browser.goto(self.SITE_URL):
                return self._finish(False)

            # 3. 等待 CF 验证
            if not self.browser.wait_for_cf():
                print("[签到] CF 验证失败")
                return self._finish(False)

            # 4. 检查登录状态
            if not self._check_login():
                return self._finish(False)

            # 5. 获取用户信息
            self._get_user_info()

            # 6. 浏览帖子
            self._browse_posts()

            # 7. 获取升级进度
            self._get_progress()

            # 8. 完成
            return self._finish(True)

        except Exception as e:
            print(f"[签到] 执行异常: {e}")
            import traceback
            traceback.print_exc()
            return self._finish(False)

    def _finish(self, success: bool) -> bool:
        """完成签到，发送通知"""
        print("=" * 50)
        if success:
            print("[签到] 签到完成")
        else:
            print("[签到] 签到失败")
        print("=" * 50)

        # 发送通知
        self.notifier.send_checkin_result(
            success=success,
            username=self.username or "未知",
            stats=self.stats,
            level=self.level,
            progress=self.progress
        )

        # 关闭浏览器
        self.browser.quit()

        return success

    def _check_login(self) -> bool:
        """检查登录状态"""
        print("[签到] 检查登录状态...")

        if self.browser.is_logged_in():
            self.username = self.browser.get_current_user()
            print(f"[签到] 已登录: {self.username}")
            return True

        # 未登录，尝试使用用户名密码登录
        if config.username and config.password:
            return self._login_with_password()

        # 未登录且无凭据
        print("[签到] 未登录，请先运行 --first-login 进行首次登录")
        return False

    def _login_with_password(self) -> bool:
        """使用用户名密码登录"""
        print("[签到] 尝试使用用户名密码登录...")

        try:
            # 点击登录按钮
            login_btn = self.browser.page.ele("css:.login-button", timeout=5)
            if login_btn:
                login_btn.click()
                time.sleep(2)

            # 输入用户名
            username_input = self.browser.page.ele("css:#login-account-name", timeout=5)
            if username_input:
                username_input.clear()
                username_input.input(config.username)

            # 输入密码
            password_input = self.browser.page.ele("css:#login-account-password", timeout=5)
            if password_input:
                password_input.clear()
                password_input.input(config.password)

            # 点击登录
            submit_btn = self.browser.page.ele("css:#login-button", timeout=5)
            if submit_btn:
                submit_btn.click()
                time.sleep(3)

            # 检查是否登录成功
            if self.browser.is_logged_in():
                self.username = self.browser.get_current_user()
                print(f"[签到] 登录成功: {self.username}")
                return True
            else:
                print("[签到] 登录失败")
                return False

        except Exception as e:
            print(f"[签到] 登录异常: {e}")
            return False

    def _get_user_info(self):
        """获取用户信息（等级等）- 从 connect.linux.do 获取"""
        print("[签到] 获取用户信息...")

        try:
            # 直接从 connect.linux.do 获取等级（更可靠）
            self.browser.goto(self.CONNECT_URL, wait=3)

            # 等待 CF 验证
            if not self.browser.wait_for_cf(timeout=60):
                print("[签到] Connect 页面 CF 验证失败")
                return

            # 从页面 HTML 解析等级
            # 格式: "你好，用户名 (username) 2级用户"
            html = self.browser.page.html
            match = re.search(r'(\d+)级用户', html)
            if match:
                self.level = int(match.group(1))
                print(f"[签到] 用户等级: {self.level}")
            else:
                print("[签到] 未能解析用户等级")

            # 同时解析升级进度（避免重复访问）
            self.progress = self._parse_progress_from_html(html)
            if self.progress:
                print(f"[签到] 获取到升级进度: {len(self.progress)} 项")

        except Exception as e:
            print(f"[签到] 获取用户信息异常: {e}")

    def _browse_posts(self):
        """浏览帖子"""
        print(f"[签到] 开始浏览帖子，目标: {config.browse_count} 篇")

        # 从多个页面获取帖子（热门 + 最新）
        posts = self._get_posts_from_multiple_pages()
        if not posts:
            print("[签到] 未获取到帖子列表")
            return

        # 随机打乱顺序
        random.shuffle(posts)
        print(f"[签到] 获取到 {len(posts)} 个帖子（已随机排序）")

        # 浏览帖子
        browse_count = min(config.browse_count, len(posts))
        for i, post_url in enumerate(posts[:browse_count]):
            if self.is_rate_limited():
                print("[签到] 限流中，停止浏览")
                break

            print(f"[签到] 浏览帖子 {i + 1}/{browse_count}: {post_url}")

            if not self.browser.goto(post_url, wait=2):
                continue

            # 检查 CF 403
            if self.browser.check_cf_403():
                self.browser.handle_cf_403(post_url)
                continue

            # 检查限流
            if self.browser.check_rate_limit():
                self.set_rate_limited()
                break

            # 滑动浏览帖子（模拟真实阅读）
            self._scroll_post()

            # 统计浏览
            self.stats['browse_count'] += 1

            # 统计评论数
            comments = self._count_comments()
            self.stats['read_comments'] += comments

            # 随机点赞
            if random.random() < config.like_probability:
                if self._like_post():
                    self.stats['like_count'] += 1

            # 随机等待
            min_wait, max_wait = config.browse_interval
            wait_time = random.uniform(min_wait, max_wait)
            time.sleep(wait_time)

        print(f"[签到] 浏览完成，共浏览 {self.stats['browse_count']} 篇")

    def _get_posts_from_multiple_pages(self) -> List[str]:
        """从多个页面获取帖子（热门 + 最新），随机混合"""
        all_posts = []

        # 要访问的页面列表（热门优先）
        pages = [
            (f"{self.SITE_URL}/top", "热门(Top)"),
            (f"{self.SITE_URL}/hot", "热门(Hot)"),
            (f"{self.SITE_URL}/latest", "最新(Latest)"),
        ]

        for url, name in pages:
            print(f"[签到] 获取 {name} 帖子...")
            if not self.browser.goto(url, wait=3):
                continue

            # 检查限流
            if self.browser.check_rate_limit():
                self.set_rate_limited()
                break

            # 获取帖子列表
            posts = self._get_post_list()
            if posts:
                print(f"[签到] {name}: {len(posts)} 篇")
                all_posts.extend(posts)

        # 去重（保持顺序）
        seen = set()
        unique_posts = []
        for post in all_posts:
            if post not in seen:
                seen.add(post)
                unique_posts.append(post)

        return unique_posts

    def _get_post_list(self) -> List[str]:
        """获取帖子列表"""
        posts = []
        try:
            # 从列表区域获取帖子链接（使用正确的选择器）
            topic_links = self.browser.page.eles("css:.topic-list-item a.title")
            for link in topic_links:
                href = link.attr("href")
                if href:
                    if href.startswith("/"):
                        href = f"{self.SITE_URL}{href}"
                    if "/t/" in href:
                        posts.append(href)

            # 去重
            posts = list(dict.fromkeys(posts))

        except Exception as e:
            print(f"[签到] 获取帖子列表异常: {e}")

        return posts

    def _scroll_post(self):
        """滑动浏览帖子到底部，模拟真实阅读"""
        try:
            if not self.browser.page:
                return

            # 获取页面高度
            page_height = self.browser.page.run_js("return document.body.scrollHeight")
            viewport_height = self.browser.page.run_js("return window.innerHeight")

            if not page_height or not viewport_height:
                return

            # 分段滑动到底部
            current_pos = 0
            scroll_step = viewport_height * 0.7  # 每次滑动 70% 视口高度

            while current_pos < page_height:
                current_pos += scroll_step
                self.browser.page.run_js(f"window.scrollTo(0, {int(current_pos)})")
                # 随机等待 0.5-1.5 秒，模拟阅读
                time.sleep(random.uniform(0.5, 1.5))

                # 更新页面高度（帖子可能有懒加载）
                new_height = self.browser.page.run_js("return document.body.scrollHeight")
                if new_height and new_height > page_height:
                    page_height = new_height

            # 确保滑动到最底部
            self.browser.page.run_js("window.scrollTo(0, document.body.scrollHeight)")
            time.sleep(random.uniform(0.5, 1.0))

        except Exception as e:
            # 滑动失败不影响主流程
            pass

    def _count_comments(self) -> int:
        """统计当前帖子的评论数"""
        try:
            posts = self.browser.page.eles("css:.topic-post")
            return len(posts) - 1 if posts else 0  # 减去主帖
        except:
            return 0

    def _like_post(self) -> bool:
        """点赞帖子"""
        try:
            # 查找点赞按钮（尝试多个选择器）
            selectors = [
                "css:.discourse-reactions-reaction-button",
                "css:button.like",
                "css:.actions button.like",
            ]

            for selector in selectors:
                try:
                    like_btn = self.browser.page.ele(selector, timeout=1)
                    if like_btn:
                        like_btn.click()
                        print("[签到] 点赞成功")
                        time.sleep(1)
                        return True
                except:
                    continue

        except Exception as e:
            print(f"[签到] 点赞失败: {e}")
        return False

    def _get_progress(self):
        """获取升级进度（已在 _get_user_info 中获取）"""
        # 如果已经有进度数据，跳过
        if self.progress:
            return

        if self.level < 1:
            print("[签到] 等级未知，跳过获取进度")
            return

        print("[签到] 获取升级进度...")

        try:
            # 访问 connect.linux.do
            self.browser.goto(self.CONNECT_URL, wait=3)

            # 等待 CF 验证
            self.browser.wait_for_cf(timeout=60)

            # 解析进度信息
            html = self.browser.page.html
            self.progress = self._parse_progress_from_html(html)

            if self.progress:
                print(f"[签到] 获取到升级进度: {len(self.progress)} 项")
            else:
                print("[签到] 未获取到升级进度")

        except Exception as e:
            print(f"[签到] 获取进度异常: {e}")

    def _parse_progress_from_html(self, html: str) -> Optional[Dict]:
        """从 HTML 解析升级进度表格"""
        progress = {}

        try:
            # 解析表格行，格式:
            # <td>访问次数</td>
            # <td class="text-red-500">14% (14 / 100 天数)</td>
            # <td>50%</td>

            # 定义要解析的项目（key, 页面标签名）
            items = [
                ('visit_days', '访问次数'),
                ('replies', '回复的话题'),
                ('topics_viewed', '浏览的话题'),
                ('posts_read', '已读帖子'),
                ('likes_given', '点赞'),
                ('likes_received', '获赞'),
            ]

            for key, label in items:
                # 匹配表格行: <td>标签</td> <td class="...">当前值</td> <td>要求值</td>
                # 注意：标签可能有额外文字如"（所有时间）"，我们只匹配精确的标签
                pattern = rf'<td[^>]*>\s*{re.escape(label)}\s*</td>\s*<td[^>]*class="(text-(?:red|green)-500)"[^>]*>\s*([^<]+?)\s*</td>\s*<td[^>]*>\s*([^<]+?)\s*</td>'
                match = re.search(pattern, html)
                if match:
                    status_class = match.group(1)
                    current_text = match.group(2).strip()
                    required_text = match.group(3).strip()

                    # 解析当前值和要求值
                    current = self._parse_progress_value(current_text)
                    required = self._parse_required_value(required_text, label)

                    progress[key] = {
                        'current': current,
                        'required': required,
                        'completed': 'green' in status_class,
                        'current_text': current_text,
                        'required_text': required_text,
                    }

        except Exception as e:
            print(f"[签到] 解析进度异常: {e}")

        return progress if progress else None

    def _parse_progress_value(self, text: str) -> int:
        """解析当前进度值"""
        # 格式1: 14% (14 / 100 天数) -> 取括号内第一个数字 14
        match = re.search(r'\((\d+)\s*/', text)
        if match:
            return int(match.group(1))

        # 格式2: ≥ 22 -> 22
        match = re.search(r'[≥>=]\s*(\d+)', text)
        if match:
            return int(match.group(1))

        # 格式3: 纯数字 7170 -> 7170
        match = re.search(r'^(\d+)$', text.strip())
        if match:
            return int(match.group(1))

        # 格式4: 其他包含数字的情况
        match = re.search(r'(\d+)', text)
        if match:
            return int(match.group(1))

        return 0

    def _parse_required_value(self, text: str, label: str) -> int:
        """解析要求值"""
        # 格式1: 50% -> 对于访问次数，50% of 100天 = 50天
        if '%' in text:
            match = re.search(r'(\d+)%', text)
            if match:
                percent = int(match.group(1))
                # 访问次数的要求是百分比，基数是100天
                if '访问' in label:
                    return percent  # 50% -> 50天
                return percent

        # 格式2: 最多 5 个 -> 5
        match = re.search(r'最多\s*(\d+)', text)
        if match:
            return int(match.group(1))

        # 格式3: 纯数字 20000 -> 20000
        match = re.search(r'(\d+)', text)
        if match:
            return int(match.group(1))

        return 0
