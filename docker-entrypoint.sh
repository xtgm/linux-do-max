#!/bin/bash
# Docker 入口脚本

# 启动虚拟显示
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# 等待 Xvfb 启动
sleep 2

# 执行命令
exec "$@"
