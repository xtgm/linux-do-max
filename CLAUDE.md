# LinuxDO 签到工具 - Claude 开发记录

## 项目信息

- **项目路径**: `E:\linuxdo-checkin`
- **GitHub**: https://github.com/xtgm/linux-do-max
- **当前版本**: v0.3.2
- **技术栈**: Python + DrissionPage + Chrome

## 核心文件结构

```
linuxdo-checkin/
├── core/
│   ├── browser.py      # 浏览器控制，Chrome 启动参数在此应用
│   ├── checkin.py      # 签到核心逻辑
│   ├── config.py       # 配置管理，支持 YAML + 环境变量
│   └── notify.py       # Telegram 通知
├── main.py             # 主入口，--first-login 首次登录
├── version.py          # 版本号管理
├── config.yaml         # 用户配置文件
├── 一键安装脚本点这里/
│   ├── install.py      # Python 跨平台安装脚本
│   └── linuxANDmacos.sh # Bash 安装脚本
└── README.md           # 项目文档
```

## 重要配置项

### chrome_args (v0.3.2+)

用于传递额外的 Chrome 启动参数，解决 LXC/Docker 容器中浏览器无法启动的问题。

**配置文件格式**:
```yaml
chrome_args:
  - "--no-sandbox"
  - "--headless=new"
  - "--disable-gpu"
```

**环境变量格式**:
```bash
CHROME_ARGS="--no-sandbox,--disable-gpu"  # 逗号分隔
```

**代码位置**:
- 配置读取: `core/config.py` 的 `chrome_args` 属性
- 参数应用: `core/browser.py` 的 `_create_options()` 方法
- 首次登录: `main.py` 的 `first_login()` 函数

## 容器环境检测

安装脚本会自动检测容器环境：

**检测方法** (`install.py`):
1. `/.dockerenv` 文件存在 → Docker
2. `/proc/1/cgroup` 包含 "docker" → Docker
3. `/proc/1/cgroup` 包含 "lxc" → LXC
4. `/run/.containerenv` 存在 → Podman
5. `systemd-detect-virt -c` 返回容器类型

**检测方法** (`linuxANDmacos.sh`):
```bash
if [ -f "/.dockerenv" ] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null || \
   [ -f "/run/.containerenv" ] || systemd-detect-virt -c &>/dev/null; then
    CHROME_ARGS="--no-sandbox"
fi
```

## 版本发布流程

1. 修改 `version.py` 中的版本号
2. 更新 `README.md` 的更新日志
3. 提交更改
4. 删除旧标签（如需覆盖）: `git tag -d vX.X.X && git push origin :refs/tags/vX.X.X`
5. 创建新标签: `git tag vX.X.X -m "描述"`
6. 推送: `git push origin main && git push origin vX.X.X`

## 常见问题解决

### LXC 容器浏览器启动失败

**错误**: `浏览器连接失败。地址: 127.0.0.1:9222`

**解决**: 添加 `--no-sandbox` 到 `chrome_args`

### 用户反馈版本号不对

**现象**: 下载了新版本但显示旧版本号

**原因**: 可能下载了错误的文件或缓存问题

**排查**:
```bash
file ./linuxdo-checkin  # 检查文件类型
./linuxdo-checkin --version  # 检查版本
```

## 更新历史

### v0.3.2 (2026-02-02)
- 新增 `chrome_args` 配置项
- 新增 LXC/Docker 容器环境检测
- 容器环境自动添加 `--no-sandbox`
- 更新文档和安装脚本
