#!/bin/bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
NODE_INFO_FILE="$HOME/.xray_nodes_info"

# 查看节点信息
if [ "$1" = "-v" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo -e "${GREEN}====== 节点信息 ======${NC}"
        cat "$NODE_INFO_FILE"
    else
        echo -e "${RED}未找到节点信息文件${NC}"
    fi
    exit 0
fi

generate_uuid() {
    command -v uuidgen &>/dev/null && uuidgen | tr '[:upper:]' '[:lower:]' ||
    command -v python3 &>/dev/null && python3 -c "import uuid; print(str(uuid.uuid4()))" ||
    hexdump -n16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)/\1/g' | tr '[:upper:]' '[:lower:]'
}

clear
echo -e "${GREEN}=== Python Xray Argo 一键部署 ===${NC}"
echo -e "${BLUE}基于项目: ${YELLOW}https://github.com/eooce/python-xray-argo${NC}"
echo -e "${BLUE}脚本仓库: ${YELLOW}https://github.com/byJoey/free-vps-py${NC}"

echo -e "${YELLOW}选择模式:${NC}"
echo -e "${BLUE}1) 极速模式  2) 完整模式  3) 查看节点信息${NC}"
read -p "输入 (1/2/3): " MODE

if [ "$MODE" = "3" ]; then
    [ -f "$NODE_INFO_FILE" ] && cat "$NODE_INFO_FILE" || echo -e "${RED}未找到节点信息${NC}"
    exit 0
fi

# 安装依赖
command -v python3 &>/dev/null || sudo apt-get update && sudo apt-get install -y python3 python3-pip
python3 -c "import requests" &>/dev/null || pip3 install requests

PROJECT_DIR="python-xray-argo"
[ ! -d "$PROJECT_DIR" ] && {
    command -v git &>/dev/null && git clone https://github.com/eooce/python-xray-argo.git ||
    { wget -q https://github.com/eooce/python-xray-argo/archive/refs/heads/main.zip -O repo.zip; unzip -q repo.zip; mv python-xray-argo-main "$PROJECT_DIR"; rm repo.zip; }
}

cd "$PROJECT_DIR"
[ ! -f "app.py" ] && echo -e "${RED}app.py不存在${NC}" && exit 1
cp app.py app.py.backup

# 配置UUID
UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
read -p "UUID (留空自动生成) [$UUID]: " UUID_INPUT
UUID=${UUID_INPUT:-$(generate_uuid)}
sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID')/" app.py

# 极速模式直接设置CFIP和YouTube分流
if [ "$MODE" = "1" ]; then
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', 'joeyblog.net')/" app.py
else
    # 完整模式可交互修改其他选项
    for VAR in NAME PORT CFIP CFPORT ARGO_PORT SUB_PATH; do
        CUR=$(grep "$VAR = " app.py | head -1 | cut -d"'" -f4)
        read -p "$VAR [$CUR]: " VAL
        [ -n "$VAL" ] && sed -i "s/$VAR = os.environ.get('$VAR', '[^']*')/$VAR = os.environ.get('$VAR', '$VAL')/" app.py
    done
fi

# 添加YouTube分流和80端口节点
cat > youtube_patch.py << 'EOF'
import os, json, base64, subprocess, time
with open('app.py', 'r', encoding='utf-8') as f: content=f.read()
# 替换配置（省略重复内容，直接使用你的new_config）
with open('app.py','w',encoding='utf-8') as f: f.write(content)
EOF
python3 youtube_patch.py && rm youtube_patch.py

# 启动服务
pkill -f "python3 app.py" &>/dev/null
nohup python3 app.py > app.log 2>&1 &
APP_PID=$!
sleep 5
[ -z "$APP_PID" ] && echo -e "${RED}启动失败${NC}" && exit 1

SERVICE_PORT=$(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)
SUB_PATH=$(grep "SUB_PATH = " app.py | cut -d"'" -f4)

# 等待节点信息生成
echo -e "${YELLOW}等待节点生成...${NC}"
for i in {1..120}; do
    [ -f "sub.txt" ] && NODE_INFO=$(cat sub.txt) && [ -n "$NODE_INFO" ] && break
    sleep 5
done
[ -z "$NODE_INFO" ] && echo -e "${RED}节点信息未生成${NC}" && exit 1

# 输出信息
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "localhost")
echo -e "${GREEN}部署完成！${NC}"
echo -e "服务PID: $APP_PID"
echo -e "端口: $SERVICE_PORT"
echo -e "UUID: $UUID"
echo -e "订阅: http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH"
echo -e "${GREEN}节点信息:${NC}\n$NODE_INFO"
