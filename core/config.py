"""
配置管理模块
支持环境变量（青龙面板）和 config.yaml（本地运行）
"""
import os
from pathlib import Path
from typing import Optional
import yaml


class Config:
    """配置类，优先读取环境变量，其次读取 config.yaml"""

    def __init__(self, config_path: Optional[str] = None):
        self._config = {}
        self._load_yaml(config_path)

    def _load_yaml(self, config_path: Optional[str] = None):
        """加载 yaml 配置文件"""
        if config_path is None:
            config_path = Path(__file__).parent.parent / "config.yaml"

        if Path(config_path).exists():
            with open(config_path, "r", encoding="utf-8") as f:
                self._config = yaml.safe_load(f) or {}

    def get(self, key: str, default=None, allow_empty: bool = False):
        """
        获取配置值
        优先级：环境变量 > config.yaml > 默认值

        参数:
            key: 配置键名
            default: 默认值
            allow_empty: 是否允许空字符串作为有效值
        """
        # 环境变量名：大写，点号转下划线
        env_key = key.upper().replace(".", "_")
        env_value = os.environ.get(env_key)
        if env_value is not None and (env_value != "" or allow_empty):
            return env_value

        # 从 yaml 中获取（支持点号分隔的嵌套键）
        keys = key.split(".")
        value = self._config
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
            else:
                value = None
                break

        # 空字符串处理
        if value is None:
            return default
        if value == "" and not allow_empty:
            return default
        return value

    # 账号配置（使用 LINUXDO_ 前缀避免与系统变量冲突）
    @property
    def username(self) -> str:
        # 优先使用 LINUXDO_USERNAME，避免与系统 USERNAME 冲突
        value = os.environ.get("LINUXDO_USERNAME")
        if value:
            return value
        # 只从 yaml 读取，不使用 get 方法（避免读取系统 USERNAME）
        yaml_value = self._config.get("username", "")
        return yaml_value if yaml_value else ""

    @property
    def password(self) -> str:
        value = os.environ.get("LINUXDO_PASSWORD")
        if value:
            return value
        yaml_value = self._config.get("password", "")
        return yaml_value if yaml_value else ""

    @property
    def cookie(self) -> str:
        """Cookie 字符串（备选登录方式）"""
        return self.get("cookie", "", allow_empty=True) or ""

    # 浏览器配置
    @property
    def user_data_dir(self) -> str:
        """用户数据目录，保存登录状态"""
        default_dir = str(Path.home() / ".linuxdo-browser")
        return self.get("user_data_dir", default_dir) or default_dir

    @property
    def headless(self) -> bool:
        """是否无头模式（默认 False，有头模式）"""
        value = self.get("headless", False)
        if isinstance(value, bool):
            return value
        return str(value).lower() in ("true", "1", "yes")

    @property
    def browser_path(self) -> str:
        """浏览器路径（可选）"""
        return self.get("browser_path", "", allow_empty=True) or ""

    # 签到配置
    @property
    def browse_count(self) -> int:
        """浏览帖子数量"""
        value = self.get("browse_count", 10)
        try:
            return int(value)
        except (ValueError, TypeError):
            return 10

    @property
    def like_probability(self) -> float:
        """点赞概率 0-1"""
        value = self.get("like_probability", 0.3)
        try:
            return float(value)
        except (ValueError, TypeError):
            return 0.3

    @property
    def browse_interval(self) -> tuple:
        """浏览间隔（秒），返回 (最小, 最大)"""
        try:
            min_val = int(self.get("browse_interval_min", 3))
        except (ValueError, TypeError):
            min_val = 3
        try:
            max_val = int(self.get("browse_interval_max", 8))
        except (ValueError, TypeError):
            max_val = 8
        return (min_val, max_val)

    # Telegram 配置（允许空字符串）
    @property
    def tg_bot_token(self) -> str:
        return self.get("tg_bot_token", "", allow_empty=True) or ""

    @property
    def tg_chat_id(self) -> str:
        return self.get("tg_chat_id", "", allow_empty=True) or ""

    @property
    def tg_enabled(self) -> bool:
        """是否启用 Telegram 通知"""
        return bool(self.tg_bot_token and self.tg_chat_id)


# 全局配置实例
config = Config()
