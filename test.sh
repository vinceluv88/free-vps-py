#!/bin/bash
# ========================================
# Cloudflare Argo 隧道自动刷新脚本
# ========================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志文件
LOG_FILE="./app.log"

# Argo 隧道相关缓存文件
CACHE_DIR="./.cache"
ARGO_FILE="./argo.json"

# 清理旧进程和缓存
echo -e "${YELLOW}停止旧的 Argo 隧道进程...${NC}"
pkill -f "python3 app.py" 2>/dev/null || true
sleep 2

echo -e "${YELLOW}删除缓存文件和旧隧道信息...${NC}"
rm -rf "$CACHE_DIR"
rm -f "$ARGO_FILE"

# 可选：清理环境变量的固定隧道（防止复用）
export ARGO_DOMAIN=""
export ARGO_AUTH=""

# 生成新的 UUID（如果 app.py 需要）
if command -v uuidgen &>/dev/null; then
    NEW_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
else
    NEW_UUID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
fi
export UUID="$NEW_UUID"
echo -e "${GREEN}生成新的 UUID: $UUID${NC}"

# 启动新的 Argo 隧道
echo -e "${YELLOW}启动新的 Argo 隧道...${NC}"
nohup python3 app.py > "$LOG_FILE" 2>&1 &

sleep 2
echo -e "${GREEN}Argo 隧道启动完成，日志输出到 $LOG_FILE${NC}"
echo -e "${YELLOW}可通过 tail -f $LOG_FILE 查看运行情况${NC}"
