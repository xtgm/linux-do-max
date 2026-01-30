"""
Linux.do 签到提醒脚本
定时发送 Telegram 提醒
"""
import requests
from datetime import datetime
import sys
sys.path.insert(0, r'E:\linuxdo-checkin')
from core.config import config


def send_reminder():
    """发送签到提醒"""
    if not config.tg_bot_token or not config.tg_chat_id:
        print("[提醒] Telegram 未配置")
        return False

    # 获取当前时间
    now = datetime.now()
    time_str = now.strftime("%H:%M")

    message = f"""⏰ Linux.do 签到提醒

现在是北京时间 {time_str}
该去论坛逛逛了！

🔗 https://linux.do

💡 自动签到将在 1 分钟后执行"""

    try:
        url = f"https://api.telegram.org/bot{config.tg_bot_token}/sendMessage"
        data = {
            "chat_id": config.tg_chat_id,
            "text": message,
            "parse_mode": "HTML"
        }
        resp = requests.post(url, json=data, timeout=30)
        if resp.status_code == 200:
            print("[提醒] Telegram 发送成功")
            return True
        else:
            print(f"[提醒] Telegram 发送失败: {resp.text}")
            return False
    except Exception as e:
        print(f"[提醒] 发送异常: {e}")
        return False


if __name__ == "__main__":
    send_reminder()
