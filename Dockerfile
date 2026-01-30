FROM python:3.11-slim

# 安装依赖
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    xvfb \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# 创建用户数据目录
RUN mkdir -p /root/.linuxdo-browser /app/logs

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV BROWSER_PATH=/usr/bin/chromium
ENV USER_DATA_DIR=/root/.linuxdo-browser
ENV HEADLESS=false

# 启动脚本
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["python", "main.py"]
