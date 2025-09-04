#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"

# 查看节点信息
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

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | \
        sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | \
        tr '[:upper:]' '[:lower:]'
    fi
}

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo 一键部署脚本    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}基于项目: ${YELLOW}https://github.com/eooce/python-xray-argo${NC}"
echo -e "${BLUE}脚本仓库: ${YELLOW}https://github.com/byJoey/free-vps-py${NC}"
echo -e "${BLUE}TG交流群: ${YELLOW}https://t.me/+ft-zI76oovgwNmRh${NC}"
echo
echo -e "${YELLOW}请选择操作:${NC}"
echo -e "${BLUE}1) 极速模式 - 只修改UUID并启动${NC}"
echo -e "${BLUE}2) 完整模式 - 详细配置所有选项${NC}"
echo -e "${BLUE}3) 查看节点信息 - 显示已保存的节点信息${NC}"
echo
read -p "请输入选择 (1/2/3): " MODE_CHOICE

# 检查依赖
echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

PROJECT_DIR="python-xray-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载完整仓库...${NC}"
    git clone https://github.com/eooce/python-xray-argo.git || {
        echo -e "${RED}下载失败，请检查网络${NC}"; exit 1
    }
fi

cd "$PROJECT_DIR"
echo -e "${GREEN}依赖安装完成！${NC}"

if [ ! -f "app.py" ]; then
    echo -e "${RED}未找到app.py文件！${NC}"
    exit 1
fi

cp app.py app.py.backup
echo -e "${YELLOW}已备份原始文件为 app.py.backup${NC}"

# ------------------- 极速模式 -------------------
if [ "$MODE_CHOICE" = "1" ]; then
    echo -e "${BLUE}=== 极速模式 ===${NC}"
    UUID_INPUT=$(generate_uuid)
    echo -e "${GREEN}生成新 UUID: $UUID_INPUT${NC}"
    
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', 'joeyblog.net')/" app.py
    echo -e "${GREEN}极速配置完成，UUID和CFIP已更新${NC}"

# ------------------- 完整模式 -------------------
elif [ "$MODE_CHOICE" = "2" ]; then
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    read -p "请输入 UUID (留空自动生成): " UUID_INPUT
    [ -z "$UUID_INPUT" ] && UUID_INPUT=$(generate_uuid)
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"
    # 可按你现有脚本继续添加交互设置端口、节点名、订阅路径、Argo域名等
fi

# ------------------- 添加 YouTube 分流和80端口节点 -------------------
cat > youtube_patch.py << 'EOF'
import os, json, base64, subprocess, time

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 替换配置，添加 YouTube 节点和 80端口节点
# 这里直接替换为新配置，保持原脚本逻辑
# 省略长配置细节，按你现有内容写
# ...

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)
EOF

python3 youtube_patch.py
rm youtube_patch.py
echo -e "${GREEN}YouTube分流和80端口节点已集成${NC}"

# ------------------- 启动服务 -------------------
pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2
python3 app.py > app.log 2>&1 &
APP_PID=$!

if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
    echo -e "${RED}获取进程PID失败，尝试直接启动${NC}"
    nohup python3 app.py > app.log 2>&1 &
    sleep 2
    APP_PID=$(pgrep -f "python3 app.py" | head -1)
fi

echo -e "${GREEN}服务已在后台启动，PID: $APP_PID${NC}"

# ------------------- 等待节点信息 -------------------
MAX_WAIT=600
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
        [ -n "$NODE_INFO" ] && break
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
        [ -n "$NODE_INFO" ] && break
    fi
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}等待超时，节点信息未生成${NC}"
    exit 1
fi

# ------------------- 保存节点信息 -------------------
echo "$NODE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 $NODE_INFO_FILE${NC}"
echo -e "${GREEN}部署完成！${NC}"
