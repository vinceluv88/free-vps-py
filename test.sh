#!/bin/bash

NODE_INFO_FILE="$HOME/.xray_nodes_info"

# 生成节点信息的逻辑
generate_nodes() {
    # ...你的生成节点信息的代码...
    NODE_INFO="这里是生成的节点信息"
    
    # 自动保存到固定文件
    echo "$NODE_INFO" > "$NODE_INFO_FILE"
    echo -e "\n节点信息已保存到 $NODE_INFO_FILE"
}

# 查看节点信息
view_nodes() {
    if [[ -f "$NODE_INFO_FILE" ]]; then
        cat "$NODE_INFO_FILE"
    else
        echo "节点信息文件不存在，请先运行脚本生成节点信息。"
    fi
}

# 主逻辑：支持 -v 参数查看节点
if [[ "$1" == "-v" ]]; then
    view_nodes
else
    generate_nodes
    # 这里也可以顺便显示节点信息
    echo "$NODE_INFO"
fi
