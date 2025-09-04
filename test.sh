#!/bin/bash

# ===================== 颜色 =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"

# ===================== 查看节点信息参数 -v =====================
if [ "$1" = "-v" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}           节点信息查看               ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
    else
        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
    fi
    exit 0
fi

# ===================== 生成 UUID =====================
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom \
        | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' \
        | tr '[:upper:]' '[:lower:]'
    fi
}

# ===================== 刷新 Cloudflare 临时隧道 =====================
refresh_cloudflare_tunnel() {
    echo -e "${YELLOW}尝试重新获取临时 Cloudflare 隧道...${NC}"
    # 停掉原来的服务
    pkill -f "python3 app.py" > /dev/null 2>&1
    sleep 2
    # 启动服务
    python3 app.py > app.log 2>&1 &
    sleep 5
}

# ===================== 清屏 =====================
clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo 一键部署脚本    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# ===================== 生成配置 =====================
UUID_VALUE=$(generate_uuid)
echo -e "${BLUE}生成 UUID: $UUID_VALUE${NC}"

# 这里你原来的 app.py 配置生成逻辑保持不变
# 假设 app.py 会根据 UUID 和其他配置启动服务

# ===================== 启动服务 =====================
python3 app.py > app.log 2>&1 &
APP_PID=$!
sleep 5

# ===================== 节点信息等待逻辑 =====================
MAX_WAIT=600  # 最大等待时间 10 分钟
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
    fi

    if [ -n "$NODE_INFO" ]; then
        echo -e "${GREEN}节点信息已生成！${NC}"
        break
    fi

    # 每30秒提示
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        MINUTES=$((WAIT_COUNT / 60))
        SECONDS=$((WAIT_COUNT % 60))
        echo -e "${YELLOW}已等待 ${MINUTES}分${SECONDS}秒，继续等待节点生成...${NC}"
    fi

    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))

    # 每60秒尝试刷新临时 Cloudflare 隧道
    if [ $((WAIT_COUNT % 60)) -eq 0 ]; then
        refresh_cloudflare_tunnel
    fi
done

if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}等待超时！节点信息未能在10分钟内生成${NC}"
    echo -e "${YELLOW}请检查网络或重新运行脚本${NC}"
    exit 1
fi

# ===================== 显示节点信息 =====================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成！                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${YELLOW}=== 节点信息 ===${NC}"
DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")
echo "$DECODED_NODES"

# 保存节点信息
echo "$NODE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 ${NODE_INFO_FILE}${NC}"
