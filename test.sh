#!/bin/bash

# 清理旧缓存，保证每次都重新申请 Argo 隧道
echo "清理旧缓存和订阅信息..."
rm -rf .cache sub.txt app.log

# 先杀掉可能存在的旧进程
echo "停止旧进程..."
pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2

# 生成新 UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}
UUID=$(generate_uuid)
echo "新 UUID: $UUID"

# 修改 app.py 中 UUID
sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID')/" app.py

# 启动服务
echo "启动 Python Xray Argo..."
nohup python3 app.py > app.log 2>&1 &
APP_PID=$!
sleep 5

# 等待临时隧道生成
echo "等待 Cloudflare Argo 临时隧道申请..."
MAX_WAIT=300
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt)
        if [ -n "$NODE_INFO" ]; then
            echo "临时隧道已生成！"
            break
        fi
    fi
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT+5))
done

if [ -z "$NODE_INFO" ]; then
    echo "节点生成超时，请检查日志"
    tail -n 20 app.log
    exit 1
fi

echo "节点信息："
echo "$NODE_INFO"
echo "部署完成，服务 PID: $APP_PID"
