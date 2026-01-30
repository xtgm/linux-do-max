# LinuxDO 自动签到工具

> 自动浏览 Linux.do 论坛帖子，模拟真实用户行为，帮助完成每日活跃任务。

## 目录

- [工作原理](#工作原理)
- [签到流程](#签到流程)
- [功能特性](#功能特性)
- [支持平台](#支持平台)
- [快速开始](#快速开始)
- [方案详解](#方案详解)
  - [方案A：Windows 任务计划](#方案awindows-任务计划)
  - [方案B：macOS launchd](#方案bmacos-launchd)
  - [方案C：Linux cron](#方案clinux-cron)
  - [方案D：Docker 部署](#方案ddocker-部署)
  - [方案E：青龙面板](#方案e青龙面板)
- [配置说明](#配置说明)
- [Telegram 通知](#telegram-通知)
- [常见问题](#常见问题)
- [故障排除](#故障排除)

---

## 工作原理

本工具使用 **DrissionPage** 控制 Chrome 浏览器，模拟真实用户浏览论坛的行为：

```
┌─────────────────────────────────────────────────────────────┐
│                      签到工具工作流程                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 启动浏览器 ──→ 2. 访问 linux.do ──→ 3. 等待 CF 验证      │
│         │                                      │            │
│         ↓                                      ↓            │
│  复用登录状态 ←── 用户数据目录 ←── 首次登录时保存            │
│         │                                                   │
│         ↓                                                   │
│  4. 检查登录 ──→ 5. 获取用户信息 ──→ 6. 浏览帖子             │
│                        │                    │               │
│                        ↓                    ↓               │
│                   等级、进度          滑动、点赞、统计        │
│                        │                    │               │
│                        └────────┬───────────┘               │
│                                 ↓                           │
│                    7. 发送 Telegram 通知                     │
│                                 │                           │
│                                 ↓                           │
│                         8. 关闭浏览器                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 核心机制

| 机制 | 说明 |
|------|------|
| **用户数据目录** | 首次登录后，浏览器的 Cookie、登录状态保存在本地目录，后续运行自动复用 |
| **有头模式** | 默认使用有头浏览器（非无头），CF 验证通过率更高 |
| **随机行为** | 随机选择帖子、随机等待时间、随机点赞，模拟真实用户 |
| **限流保护** | 检测到 429 错误自动暂停 30 分钟，避免被封禁 |

---

## 签到流程

每次执行签到，工具会按以下步骤运行：

### 步骤 1：启动浏览器
- 读取配置文件 `config.yaml`
- 创建/复用用户数据目录
- 启动 Chrome 浏览器

### 步骤 2：访问首页
- 打开 https://linux.do
- 等待页面加载完成

### 步骤 3：CF 验证
- 检测 Cloudflare 5秒盾
- 自动等待验证完成（最长 120 秒）
- 如有 Turnstile 验证框，自动点击

### 步骤 4：检查登录
- 检测页面是否已登录
- 已登录：继续执行
- 未登录：尝试用户名密码登录（如已配置）

### 步骤 5：获取用户信息
- 访问 https://connect.linux.do
- 解析用户等级（1级、2级、3级...）
- 解析升级进度（访问天数、点赞、获赞等）

### 步骤 6：浏览帖子
```
获取帖子列表
    │
    ├── 访问 /top（热门帖子）
    ├── 访问 /hot（热门帖子）
    └── 访问 /latest（最新帖子）
    │
    ↓
合并去重（约 80-100 篇）
    │
    ↓
随机打乱顺序
    │
    ↓
选取前 10 篇浏览
    │
    ↓
对每篇帖子：
    ├── 打开帖子页面
    ├── 滑动到底部（模拟阅读）
    ├── 统计评论数
    ├── 30% 概率点赞
    └── 随机等待 3-8 秒
```

### 步骤 7：发送通知
- 汇总执行统计（浏览数、评论数、点赞数）
- 发送 Telegram 通知（如已配置）

### 步骤 8：关闭浏览器
- 保存浏览器状态
- 关闭浏览器进程

---

## 功能特性

| 功能 | 说明 | 状态 |
|------|------|------|
| 首次登录 | `--first-login` 打开有头浏览器，手动登录后保存状态 | ✅ |
| 自动浏览 | 从热门+最新页面获取帖子，随机选择浏览 | ✅ |
| 滑动阅读 | 模拟真实阅读，分段滑动到页面底部 | ✅ |
| 随机点赞 | 30% 概率点赞（可配置） | ✅ |
| 等级识别 | 自动获取用户等级 | ✅ |
| 升级进度 | 2级+ 显示详细进度，1级提示查看 connect 页面 | ✅ |
| CF 5秒盾 | 自动等待 + Turnstile 点击 | ✅ |
| 429 限流 | 检测并暂停 30 分钟 | ✅ |
| CF 403 | 跳转 /challenge 页面处理 | ✅ |
| Telegram | 签到结果推送 | ✅ |

---

## 支持平台

| 平台 | 定时任务方式 | 脚本 | 难度 |
|------|-------------|------|------|
| **Windows** | 任务计划程序 | `scripts/setup_task.bat` | ⭐ 简单 |
| **macOS** | launchd | `scripts/setup_task.sh` | ⭐⭐ 中等 |
| **Linux** | cron | `scripts/setup_task_linux.sh` | ⭐⭐ 中等 |
| **Docker** | docker-compose | `docker-compose.yml` | ⭐⭐⭐ 较难 |
| **青龙面板** | 内置调度 | `ql_main.py` | ⭐⭐⭐ 较难 |

**推荐选择：**
- 个人电脑：Windows / macOS 方案
- 服务器：Linux / Docker 方案
- 已有青龙面板：青龙方案

---

## 快速开始

### 第一步：下载项目

```bash
git clone https://github.com/你的用户名/linuxdo-checkin.git
cd linuxdo-checkin
```

### 第二步：安装依赖

```bash
pip install -r requirements.txt
```

依赖列表：
- `DrissionPage>=4.0.0` - 浏览器自动化
- `PyYAML>=6.0` - 配置文件解析
- `requests>=2.28.0` - HTTP 请求（Telegram 通知）

### 第三步：首次登录（重要！）

```bash
python main.py --first-login
```

**操作步骤：**
1. 浏览器自动打开 linux.do
2. 等待 CF 5秒盾验证通过
3. 手动点击「登录」按钮
4. 输入用户名和密码
5. 完成登录后，回到命令行按 **Enter** 键
6. 登录状态已保存，后续运行无需再登录

### 第四步：配置 Telegram 通知（可选）

编辑 `config.yaml`：

```yaml
tg_bot_token: "你的Bot Token"
tg_chat_id: "你的Chat ID"
```

### 第五步：运行签到

```bash
python main.py
```

### 第六步：设置定时任务

根据你的平台，选择对应的方案（见下方详解）。

---

## 方案详解

### 方案A：Windows 任务计划

**适用场景：** Windows 个人电脑，希望每天自动执行签到

**前置条件：**
- Windows 10/11
- 已安装 Python 3.8+
- 已安装 Chrome 浏览器
- 已完成首次登录

#### 操作步骤

**步骤 1：打开设置脚本**

双击运行 `scripts/setup_task.bat`

**步骤 2：选择操作**

```
========================================
LinuxDO 签到 - Windows 定时任务设置
========================================

请选择操作：
  1. 创建定时任务（自定义时间和次数）
  2. 删除定时任务
  3. 查看定时任务
  4. 立即运行签到
  5. 首次登录（保存登录状态）
  6. 测试 Telegram 提醒
  7. 退出
```

**步骤 3：创建定时任务（选择 1）**

```
请输入每天执行的次数（1-4次）：
次数: 2

请输入每次执行的时间（24小时制，如 08:00）：

第 1 次执行时间（如 08:00）: 08:00
[成功] 08:00 - Telegram 提醒
[成功] 08:01 - 自动签到

第 2 次执行时间（如 20:00）: 20:00
[成功] 20:00 - Telegram 提醒
[成功] 20:01 - 自动签到

========================================
[成功] 已创建 2 组定时任务
========================================
```

#### 任务说明

| 任务名称 | 执行时间 | 功能 |
|----------|----------|------|
| LinuxDO-Reminder-1 | 08:00 | 发送 Telegram 提醒 |
| LinuxDO-Checkin-1 | 08:01 | 执行签到 |
| LinuxDO-Reminder-2 | 20:00 | 发送 Telegram 提醒 |
| LinuxDO-Checkin-2 | 20:01 | 执行签到 |

#### 注意事项

1. **电脑需要开机** - 任务计划在电脑关机时不会执行
2. **不要锁屏** - 有头浏览器需要桌面环境
3. **查看任务** - 打开「任务计划程序」可查看和管理任务
4. **日志位置** - 无独立日志，输出在命令行窗口

#### 手动管理任务

```powershell
# 查看任务
schtasks /query /fo table | findstr LinuxDO

# 删除单个任务
schtasks /delete /tn "LinuxDO-Checkin-1" /f

# 立即运行任务
schtasks /run /tn "LinuxDO-Checkin-1"
```

---

### 方案B：macOS launchd

**适用场景：** macOS 个人电脑，希望每天自动执行签到

**前置条件：**
- macOS 10.15+
- 已安装 Python 3.8+
- 已安装 Chrome 浏览器
- 已完成首次登录

#### 操作步骤

**步骤 1：赋予执行权限**

```bash
chmod +x scripts/setup_task.sh
```

**步骤 2：运行设置脚本**

```bash
./scripts/setup_task.sh
```

**步骤 3：选择操作**

```
========================================
LinuxDO 签到 - macOS 定时任务设置
========================================

项目目录: /Users/你的用户名/linuxdo-checkin
Python: /usr/local/bin/python3

请选择操作：
  1. 创建定时任务（自定义时间和次数）
  2. 删除定时任务
  3. 查看任务状态
  4. 立即运行签到
  5. 首次登录（保存登录状态）
  6. 测试 Telegram 提醒
  7. 查看日志
  8. 退出
```

**步骤 4：创建定时任务（选择 1）**

按提示输入执行次数和时间。

#### 任务文件位置

```
~/Library/LaunchAgents/
├── com.linuxdo.reminder.1.plist
├── com.linuxdo.checkin.1.plist
├── com.linuxdo.reminder.2.plist
└── com.linuxdo.checkin.2.plist
```

#### 日志位置

```
项目目录/logs/
├── main.log          # 签到日志
├── main.error.log    # 错误日志
├── reminder.log      # 提醒日志
└── reminder.error.log
```

#### 注意事项

1. **电脑需要开机** - 休眠状态不会执行
2. **允许后台运行** - 系统偏好设置 → 电池 → 取消「电池供电时使显示器进入睡眠」
3. **查看任务状态** - `launchctl list | grep linuxdo`

#### 手动管理任务

```bash
# 查看任务状态
launchctl list | grep linuxdo

# 卸载任务
launchctl unload ~/Library/LaunchAgents/com.linuxdo.checkin.1.plist

# 加载任务
launchctl load ~/Library/LaunchAgents/com.linuxdo.checkin.1.plist

# 立即运行
launchctl start com.linuxdo.checkin.1
```

---

### 方案C：Linux cron

**适用场景：** Linux 服务器或桌面，希望每天自动执行签到

**前置条件：**
- Linux（Debian/Ubuntu/CentOS/Arch/Alpine）
- 已安装 Python 3.8+
- 已安装 Chrome/Chromium 浏览器
- 已安装 Xvfb（虚拟显示）
- 已完成首次登录

#### 操作步骤

**步骤 1：安装 Xvfb**

```bash
# Debian/Ubuntu
sudo apt-get install xvfb

# CentOS/RHEL
sudo yum install xorg-x11-server-Xvfb

# Arch
sudo pacman -S xorg-server-xvfb

# Alpine
sudo apk add xvfb
```

或使用脚本自动安装（选项 8）。

**步骤 2：首次登录（需要图形界面）**

```bash
# 方式1：本地桌面环境
python main.py --first-login

# 方式2：VNC 远程桌面
# 先安装 VNC Server，通过 VNC 客户端连接后运行
```

**步骤 3：赋予执行权限**

```bash
chmod +x scripts/setup_task_linux.sh
```

**步骤 4：运行设置脚本**

```bash
./scripts/setup_task_linux.sh
```

**步骤 5：创建定时任务（选择 1）**

按提示输入执行次数和时间。

#### cron 任务格式

```
# 提醒任务
0 8 * * * /usr/bin/python3 /path/to/reminder.py >> /path/to/logs/reminder.log 2>&1 # LinuxDO-Checkin-Reminder-1

# 签到任务（使用 xvfb-run）
1 8 * * * xvfb-run -a /usr/bin/python3 /path/to/main.py >> /path/to/logs/checkin.log 2>&1 # LinuxDO-Checkin-1
```

#### 日志位置

```
项目目录/logs/
├── checkin.log    # 签到日志
└── reminder.log   # 提醒日志
```

#### 注意事项

1. **必须安装 Xvfb** - 无头服务器需要虚拟显示
2. **首次登录需要图形界面** - 使用 VNC 或本地桌面
3. **检查 Python 路径** - 确保 cron 能找到 Python

#### 手动管理任务

```bash
# 查看 cron 任务
crontab -l | grep -i linuxdo

# 编辑 cron 任务
crontab -e

# 删除所有 LinuxDO 任务
crontab -l | grep -v "LinuxDO" | crontab -

# 手动运行（带虚拟显示）
xvfb-run -a python3 main.py
```

---

### 方案D：Docker 部署

**适用场景：** 服务器部署，希望隔离环境、方便迁移

**前置条件：**
- 已安装 Docker 和 Docker Compose
- 有图形界面支持（首次登录需要）

#### 操作步骤

**步骤 1：构建镜像**

```bash
docker-compose build
```

**步骤 2：首次登录**

```bash
# 方式1：X11 转发（Linux 桌面）
xhost +local:docker
docker-compose run --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix linuxdo-checkin python main.py --first-login

# 方式2：VNC（服务器）
# 需要额外配置 VNC 服务
```

**步骤 3：配置环境变量**

编辑 `docker-compose.yml`：

```yaml
services:
  linuxdo-checkin:
    environment:
      - TG_BOT_TOKEN=你的Token
      - TG_CHAT_ID=你的ChatID
      - BROWSE_COUNT=10
      - LIKE_PROBABILITY=0.3
      - HEADLESS=false
```

**步骤 4：运行签到**

```bash
# 单次运行
docker-compose run --rm linuxdo-checkin python main.py

# 后台运行（配合定时任务）
docker-compose up -d
```

**步骤 5：配置定时执行**

**方式1：使用 ofelia（推荐）**

取消 `docker-compose.yml` 中 ofelia 服务的注释：

```yaml
ofelia:
  image: mcuadros/ofelia:latest
  depends_on:
    - linuxdo-checkin
  command: daemon --docker
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
  labels:
    ofelia.job-run.checkin-am.schedule: "0 0 8 * * *"
    ofelia.job-run.checkin-am.container: "linuxdo-checkin"
    ofelia.job-run.checkin-pm.schedule: "0 0 20 * * *"
    ofelia.job-run.checkin-pm.container: "linuxdo-checkin"
```

**方式2：使用宿主机 cron**

```bash
crontab -e

# 添加以下内容
0 8 * * * docker-compose -f /path/to/docker-compose.yml run --rm linuxdo-checkin python main.py
0 20 * * * docker-compose -f /path/to/docker-compose.yml run --rm linuxdo-checkin python main.py
```

#### 数据持久化

| 目录 | 说明 |
|------|------|
| `./data/browser` | 浏览器用户数据（登录状态） |
| `./logs` | 运行日志 |

#### 注意事项

1. **首次登录是难点** - 需要图形界面支持
2. **数据持久化** - 确保 volumes 配置正确
3. **时区设置** - 容器内时区可能与宿主机不同

---

### 方案E：青龙面板

**适用场景：** 已有青龙面板，希望统一管理定时任务

**前置条件：**
- 已部署青龙面板
- 青龙面板所在服务器已安装 Xvfb
- 有图形界面支持（首次登录需要）

#### 操作步骤

**步骤 1：上传文件**

将项目文件上传到青龙面板的脚本目录：

```
/ql/scripts/linuxdo-checkin/
├── core/
│   ├── __init__.py
│   ├── browser.py
│   ├── checkin.py
│   ├── config.py
│   └── notify.py
├── main.py
├── ql_main.py
├── config.yaml
└── requirements.txt
```

**步骤 2：安装依赖**

在青龙面板的「依赖管理」→「Python」中添加：

```
DrissionPage
PyYAML
requests
```

**步骤 3：安装 Xvfb**

SSH 登录青龙面板所在服务器：

```bash
# Debian/Ubuntu
apt-get update && apt-get install -y xvfb

# Alpine（青龙官方镜像）
apk add xvfb
```

**步骤 4：配置环境变量**

在青龙面板的「环境变量」中添加：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| TG_BOT_TOKEN | 你的Token | Telegram Bot Token |
| TG_CHAT_ID | 你的ChatID | Telegram Chat ID |
| USER_DATA_DIR | /ql/data/linuxdo-browser | 用户数据目录 |
| HEADLESS | false | 有头模式 |

**步骤 5：首次登录**

```bash
# SSH 登录服务器，进入青龙容器
docker exec -it qinglong bash

# 运行首次登录（需要 VNC 或 X11 转发）
cd /ql/scripts/linuxdo-checkin
python3 main.py --first-login
```

**步骤 6：添加定时任务**

在青龙面板的「定时任务」中添加：

| 字段 | 值 |
|------|-----|
| 名称 | LinuxDO签到 |
| 命令 | `xvfb-run -a python3 /ql/scripts/linuxdo-checkin/ql_main.py` |
| 定时规则 | `0 8,20 * * *` |

#### 注意事项

1. **必须安装 Xvfb** - 青龙容器内需要虚拟显示
2. **首次登录是难点** - 需要 VNC 或 X11 转发
3. **用户数据目录** - 确保路径在容器内可写
4. **依赖安装** - 确保 DrissionPage 安装成功

---

## 配置说明

### 配置文件 config.yaml

```yaml
# ========== 账号配置 ==========
# 用户名（可选，首次登录后会保存登录状态）
username: ""
# 密码（可选）
password: ""

# ========== 浏览器配置 ==========
# 用户数据目录（保存登录状态）
# 默认: ~/.linuxdo-browser/
# Windows 示例: C:\Users\你的用户名\.linuxdo-browser
# Linux/macOS 示例: /home/你的用户名/.linuxdo-browser
user_data_dir: ""

# 是否无头模式（默认 false，有头模式）
# 有头模式 CF 验证通过率更高
headless: false

# 浏览器路径（可选，留空使用系统默认）
# Windows 示例: C:\Program Files\Google\Chrome\Application\chrome.exe
# macOS 示例: /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
# Linux 示例: /usr/bin/google-chrome
browser_path: ""

# ========== 签到配置 ==========
# 浏览帖子数量（默认 10）
browse_count: 10

# 点赞概率（0-1，0.3 表示 30%）
like_probability: 0.3

# 浏览间隔（秒）
browse_interval_min: 3
browse_interval_max: 8

# ========== Telegram 通知 ==========
# Bot Token（从 @BotFather 获取）
tg_bot_token: ""

# Chat ID（从 @userinfobot 获取）
tg_chat_id: ""
```

### 配置项说明

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| username | 字符串 | 空 | Linux.do 用户名（可选） |
| password | 字符串 | 空 | Linux.do 密码（可选） |
| user_data_dir | 字符串 | ~/.linuxdo-browser | 浏览器用户数据目录 |
| headless | 布尔 | false | 是否无头模式 |
| browser_path | 字符串 | 空 | 浏览器可执行文件路径 |
| browse_count | 整数 | 10 | 每次浏览帖子数量 |
| like_probability | 浮点 | 0.3 | 点赞概率（0-1） |
| browse_interval_min | 整数 | 3 | 浏览间隔最小秒数 |
| browse_interval_max | 整数 | 8 | 浏览间隔最大秒数 |
| tg_bot_token | 字符串 | 空 | Telegram Bot Token |
| tg_chat_id | 字符串 | 空 | Telegram Chat ID |

### 环境变量

环境变量优先级高于 config.yaml，适用于 Docker 和青龙面板：

| 环境变量 | 对应配置 |
|----------|----------|
| LINUXDO_USERNAME | username |
| LINUXDO_PASSWORD | password |
| USER_DATA_DIR | user_data_dir |
| HEADLESS | headless |
| BROWSER_PATH | browser_path |
| BROWSE_COUNT | browse_count |
| LIKE_PROBABILITY | like_probability |
| TG_BOT_TOKEN | tg_bot_token |
| TG_CHAT_ID | tg_chat_id |

---

## Telegram 通知

### 获取 Bot Token

1. 在 Telegram 中搜索 **@BotFather**
2. 发送 `/newbot`
3. 按提示输入机器人名称和用户名
4. 获得 Bot Token（格式：`123456789:ABCdefGHIjklMNOpqrsTUVwxyz`）

### 获取 Chat ID

1. 在 Telegram 中搜索 **@userinfobot**
2. 发送任意消息
3. 获得你的 Chat ID（纯数字）

### 通知效果示例

**签到成功：**
```
✅ LINUX DO 签到成功
👤 你的用户名

📊 执行统计
├ 📖 浏览：10 篇
├ 💬 阅读评论：85 条
└ 👍 点赞：3 次

🏆 当前等级：2 级

📈 升级进度 (2→3 级)
├ ✅ 访问天数：50天/50天
├ ⏳ 点赞：15次/30次 (差15次)
├ ✅ 获赞：25次/20次
├ ✅ 回复的话题：10个/10个
├ ✅ 浏览的话题：200个/100个
└ ✅ 已读帖子：500篇/500篇

🎯 完成度 83%
🟩🟩🟩🟩🟩⬜
已完成 5/6 项
```

**签到失败：**
```
❌ LINUX DO 签到失败
👤 未知

📊 执行统计
├ 📖 浏览：0 篇
├ 💬 阅读评论：0 条
└ 👍 点赞：0 次

🏆 当前等级：0 级
```

---

## 常见问题

### Q1: 什么是「首次登录」？为什么需要？

**A:** 首次登录是为了保存浏览器的登录状态（Cookie）。

- Linux.do 使用 Cloudflare 保护，需要通过 CF 验证
- CF 验证后的状态保存在浏览器的用户数据目录中
- 首次登录时手动完成验证和登录，后续运行自动复用

### Q2: CF 5秒盾验证失败怎么办？

**A:** 尝试以下方法：

1. 确保使用有头模式（`headless: false`）
2. 重新运行首次登录（`python main.py --first-login`）
3. 手动通过 CF 验证后再按 Enter
4. 检查网络环境，某些 IP 可能被 CF 拦截

### Q3: 提示「未登录」怎么办？

**A:** 登录状态可能已过期：

1. 删除用户数据目录（默认 `~/.linuxdo-browser`）
2. 重新运行首次登录
3. 确保登录成功后再按 Enter

### Q4: 429 限流是什么意思？

**A:** 429 表示请求过于频繁，被服务器限流。

- 工具会自动暂停 30 分钟
- 建议减少每天执行次数（1-2 次即可）
- 不要同时运行多个签到实例

### Q5: Linux/Docker 如何首次登录？

**A:** 需要图形界面支持：

| 环境 | 方法 |
|------|------|
| 本地 Linux 桌面 | 直接运行 `python main.py --first-login` |
| 远程 VPS | 安装 VNC Server，通过 VNC 客户端连接后运行 |
| Docker | 使用 X11 转发或 VNC |

### Q6: 青龙面板运行报错？

**A:** 常见问题：

1. **未安装 Xvfb** - 运行 `apk add xvfb`（Alpine）或 `apt install xvfb`（Debian）
2. **依赖未安装** - 在依赖管理中添加 DrissionPage、PyYAML、requests
3. **命令格式错误** - 确保使用 `xvfb-run -a python3 /path/to/ql_main.py`

### Q7: macOS 任务没有执行？

**A:** 检查以下几点：

1. 电脑是否休眠 - 休眠状态不会执行
2. 任务是否加载 - 运行 `launchctl list | grep linuxdo`
3. 查看错误日志 - `cat logs/main.error.log`

### Q8: 如何修改浏览帖子数量？

**A:** 编辑 `config.yaml`：

```yaml
browse_count: 20  # 改为 20 篇
```

或设置环境变量：

```bash
export BROWSE_COUNT=20
```

### Q9: 如何关闭点赞功能？

**A:** 将点赞概率设为 0：

```yaml
like_probability: 0  # 不点赞
```

### Q10: 支持多账号吗？

**A:** 目前不支持。如需多账号，可以：

1. 复制项目到不同目录
2. 每个目录配置不同的 `user_data_dir`
3. 分别运行首次登录和定时任务

---

## 故障排除

### 问题 1：浏览器启动失败

**错误信息：**
```
[浏览器] 启动失败: ...
```

**解决方法：**

1. 检查 Chrome 是否已安装
2. 检查 `browser_path` 配置是否正确
3. 检查是否有其他 Chrome 进程占用用户数据目录

```bash
# Windows - 关闭所有 Chrome 进程
taskkill /f /im chrome.exe

# Linux/macOS - 关闭所有 Chrome 进程
pkill -f chrome
```

### 问题 2：页面加载超时

**错误信息：**
```
[浏览器] 访问失败: 超时
```

**解决方法：**

1. 检查网络连接
2. 检查是否能正常访问 linux.do
3. 尝试使用代理

### 问题 3：CF 验证循环

**现象：** CF 验证一直不通过，循环等待

**解决方法：**

1. 删除用户数据目录，重新首次登录
2. 更换网络环境（某些 IP 被 CF 标记）
3. 使用有头模式

### 问题 4：Telegram 通知失败

**错误信息：**
```
[通知] Telegram 发送失败: ...
```

**解决方法：**

1. 检查 Bot Token 是否正确
2. 检查 Chat ID 是否正确
3. 确保已与 Bot 对话（发送过 /start）
4. 检查网络是否能访问 Telegram API

```bash
# 测试 Telegram API
curl https://api.telegram.org/bot你的Token/getMe
```

### 问题 5：青龙面板 DrissionPage 安装失败

**错误信息：**
```
ERROR: Could not find a version that satisfies the requirement DrissionPage
```

**解决方法：**

```bash
# 进入青龙容器
docker exec -it qinglong bash

# 手动安装
pip3 install DrissionPage -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 问题 6：Xvfb 相关错误

**错误信息：**
```
Xvfb: command not found
```

**解决方法：**

```bash
# Debian/Ubuntu
apt-get update && apt-get install -y xvfb

# Alpine
apk add xvfb

# CentOS
yum install -y xorg-x11-server-Xvfb
```

### 问题 7：权限不足

**错误信息：**
```
Permission denied: '/root/.linuxdo-browser'
```

**解决方法：**

```bash
# 创建目录并设置权限
mkdir -p ~/.linuxdo-browser
chmod 755 ~/.linuxdo-browser
```

---

## 项目结构

```
linuxdo-checkin/
├── core/                        # 核心代码
│   ├── __init__.py             # 模块初始化
│   ├── browser.py              # 浏览器控制（启动、关闭、CF验证）
│   ├── checkin.py              # 签到逻辑（浏览、点赞、统计）
│   ├── config.py               # 配置管理（YAML + 环境变量）
│   └── notify.py               # Telegram 通知
├── scripts/                     # 定时任务脚本
│   ├── setup_task.bat          # Windows 任务计划
│   ├── setup_task.sh           # macOS launchd
│   └── setup_task_linux.sh     # Linux cron
├── main.py                      # 主入口（支持 --first-login）
├── ql_main.py                  # 青龙面板入口
├── reminder.py                 # Telegram 提醒脚本
├── config.yaml                 # 配置文件
├── .env.example                # 环境变量示例
├── requirements.txt            # Python 依赖
├── Dockerfile                  # Docker 镜像
├── docker-compose.yml          # Docker Compose
├── docker-entrypoint.sh        # Docker 入口脚本
└── README.md                   # 项目说明
```

---

## 免责声明

本工具仅供学习交流使用，请勿用于违反网站服务条款的行为。使用本工具产生的任何后果由使用者自行承担。

---

## 更新日志

### v1.0.0 (2026-01-30)

- 初始版本
- 支持 Windows/macOS/Linux/Docker/青龙面板
- 自动浏览帖子（热门+最新混合）
- 随机点赞
- 等级识别和升级进度
- Telegram 通知
- CF 5秒盾处理
- 429 限流保护
