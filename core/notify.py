"""
通知模块
支持 Telegram 通知
"""
import requests
from typing import Optional, Dict
from .config import config


class TelegramNotify:
    """Telegram 通知"""

    def __init__(self, bot_token: str = "", chat_id: str = ""):
        self.bot_token = bot_token or config.tg_bot_token
        self.chat_id = chat_id or config.tg_chat_id

    @property
    def api_base(self) -> str:
        return f"https://api.telegram.org/bot{self.bot_token}"

    @property
    def enabled(self) -> bool:
        return bool(self.bot_token and self.chat_id)

    def send(self, message: str) -> bool:
        """发送消息"""
        if not self.enabled:
            print("[通知] Telegram 未配置，跳过通知")
            return False

        try:
            url = f"{self.api_base}/sendMessage"
            data = {
                "chat_id": self.chat_id,
                "text": message,
                "parse_mode": "HTML"
            }
            resp = requests.post(url, json=data, timeout=30)
            if resp.status_code == 200:
                print("[通知] Telegram 发送成功")
                return True
            else:
                print(f"[通知] Telegram 发送失败: {resp.text}")
                return False
        except Exception as e:
            print(f"[通知] Telegram 发送异常: {e}")
            return False


class Notifier:
    """统一通知管理"""

    def __init__(self):
        self._telegram: Optional[TelegramNotify] = None

    @property
    def telegram(self) -> TelegramNotify:
        """延迟创建 Telegram 通知实例"""
        if self._telegram is None:
            self._telegram = TelegramNotify()
        return self._telegram

    def send_checkin_result(
        self,
        success: bool,
        username: str,
        stats: Dict,
        level: int,
        progress: Optional[Dict] = None
    ):
        """
        发送签到结果通知

        参数:
            success: 是否成功
            username: 用户名
            stats: 执行统计 {
                'browse_count': 浏览数,
                'read_comments': 阅读评论数,
                'like_count': 点赞数,
                'post_count': 发帖数,
                'comment_count': 评论数
            }
            level: 当前等级
            progress: 升级进度（2级+才有）
        """

        status = "✅ LINUX DO 签到成功" if success else "❌ LINUX DO 签到失败"

        # 执行统计
        browse_count = stats.get('browse_count', 0)
        read_comments = stats.get('read_comments', 0)
        like_count = stats.get('like_count', 0)

        msg_lines = [
            status,
            f"👤 {username}",
            "",
            "📊 执行统计",
            f"├ 📖 浏览：{browse_count} 篇",
            f"├ 💬 阅读评论：{read_comments} 条",
            f"└ 👍 点赞：{like_count} 次",
            "",
            f"🏆 当前等级：{level} 级",
        ]

        # 升级进度
        if progress:
            next_level = level + 1
            msg_lines.append("")
            msg_lines.append(f"📈 升级进度 ({level}→{next_level} 级)")

            # 统计完成项
            completed = 0
            total = 0

            # 进度项配置（key, 显示名称, 单位）
            progress_items = [
                ('visit_days', '访问天数', '天'),
                ('likes_given', '点赞', '次'),
                ('likes_received', '获赞', '次'),
                ('replies', '回复的话题', '个'),
                ('topics_viewed', '浏览的话题', '个'),
                ('posts_read', '已读帖子', '篇'),
            ]

            for key, label, unit in progress_items:
                if key in progress:
                    item = progress[key]
                    current = item.get('current', 0)
                    required = item.get('required', 0)
                    is_completed = item.get('completed', False)
                    total += 1

                    if is_completed:
                        icon = "✅"
                        completed += 1
                        msg_lines.append(f"├ {icon} {label}：{current}{unit}/{required}{unit}")
                    else:
                        icon = "⏳"
                        diff = required - current
                        msg_lines.append(f"├ {icon} {label}：{current}{unit}/{required}{unit} (差{diff}{unit})")

            # 完成度
            if total > 0:
                percentage = int(completed / total * 100)
                # 进度条
                filled = completed
                empty = total - completed
                progress_bar = "🟩" * filled + "⬜" * empty

                msg_lines.append("")
                msg_lines.append(f"🎯 完成度 {percentage}%")
                msg_lines.append(progress_bar)
                msg_lines.append(f"已完成 {completed}/{total} 项")

        elif level == 1:
            msg_lines.append("")
            msg_lines.append("📈 升级进度 (1→2 级)")
            msg_lines.append("⏳ 1级用户需要访问 connect.linux.do 查看进度")

        message = "\n".join(msg_lines)

        # 发送通知
        self.telegram.send(message)

        return message
