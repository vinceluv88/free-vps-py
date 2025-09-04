#!/bin/bash

APP_DIR="$HOME/app"
LOG_FILE="$APP_DIR/app.log"

echo "停止旧的 Argo 隧道进程..."
pkill -f "app.py" 2>/dev/null || true

echo "删除旧日志..."
rm -f "$LOG_FILE"

# 生成新的 UUID
NEW_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "生成新的 UUID: $NEW_UUID"
export TUNNEL_UUID="$NEW_UUID"

echo "启动新的 Argo 隧道..."
nohup python3 "$APP_DIR/app.py" > "$LOG_FILE" 2>&1 &

echo "正在实时抓取节点信息..."
# 使用 tail -f 实时跟踪日志，并匹配包含节点信息的行
# 假设节点信息日志包含 "https://" 或者 "节点信息" 关键字，根据你的实际日志改
tail -f "$LOG_FILE" | while read line; do
    if [[ "$line" == *"https://"* ]] || [[ "$line" == *"节点信息"* ]]; then
        echo "检测到节点信息：$line"
        # 如果只需要第一条，取消注释下面这行：
        # pkill -P $$ tail
    fi
done
