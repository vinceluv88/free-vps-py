#!/bin/bash

# =========================
# 强制生成新的 Cloudflare Argo 隧道脚本
# =========================

# 依赖文件和目录
ARGO_FILE="$HOME/argo.json"
CACHE_DIR="$HOME/.argo_cache"
LOG_FILE="$HOME/argo.log"

# 停掉旧的隧道进程
pkill -f "app.py"

# 创建缓存目录
mkdir -p "$CACHE_DIR"

# 生成新的 UUID
NEW_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "生成新的 UUID: $NEW_UUID"

# 将 UUID 写入 app.py 配置（假设 app.py 可以读取此环境变量）
export TUNNEL_UUID="$NEW_UUID"

# 删除旧隧道信息文件
rm -f "$ARGO_FILE"

# 启动隧道
echo "启动 Cloudflare Argo 隧道..."
nohup python3 app.py > "$LOG_FILE" 2>&1 &

# 等待隧道启动完成
echo "等待隧道启动中..."
sleep 5

# 检查隧道信息是否生成
if [ -f "$ARGO_FILE" ]; then
    echo "新的隧道已生成，节点信息如下："
    cat "$ARGO_FILE"
else
    echo "隧道信息尚未生成，请查看日志：$LOG_FILE"
fi

# 输出日志最后 20 行
echo "日志输出（最后 20 行）："
tail -n 20 "$LOG_FILE"
