#!/bin/bash
# ============================================================
# 哪吒探针 (Nezha Agent) 主控地址一键切换工具
# 适用场景：主控面板迁移、批量切换 Agent 指向的 Server IP/域名
# ============================================================

# 颜色与样式定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

AGENT_DIR="/opt/nezha/agent"
QUICK_NEW_SERVER="$1" # 支持通过命令行第一个参数直接传入新 IP

# 检查 Root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[错误] 请使用 root 权限运行此脚本 (sudo -i)！${NC}"
    exit 1
fi

clear
echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}${GREEN}          哪吒探针 (Nezha Agent) 主控地址一键切换工具        ${NC}"
echo -e "${CYAN}============================================================${NC}"

# 1. 收集正在运行的进程所使用的配置文件
RUNNING_CONFIGS=$(ps -eo args | grep "[n]ezha-agent" | sed -n 's/.*-c \([^ ]*\).*/\1/p' | sort -u)

# 2. 收集 systemd 服务文件中绑定的配置文件
SERVICE_CONFIGS=$(grep -h "ExecStart=" /etc/systemd/system/nezha-agent*.service 2>/dev/null | sed -n 's/.*-c \([^ ]*\).*/\1/p' | sort -u)

# 3. 收集 /opt/nezha/agent 下的所有 yml/yaml 文件
DIR_CONFIGS=""
if [ -d "$AGENT_DIR" ]; then
    DIR_CONFIGS=$(find "$AGENT_DIR" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null)
fi

# 合并去重所有发现的配置文件
ALL_CONFIGS=$(printf "%s\n%s\n%s\n" "$RUNNING_CONFIGS" "$SERVICE_CONFIGS" "$DIR_CONFIGS" | sed '/^$/d' | sort -u)

if [ -z "$ALL_CONFIGS" ]; then
    echo -e "\n${RED}[错误] 未在系统中检测到任何哪吒探针进程或配置文件 ($AGENT_DIR)！${NC}"
    exit 1
fi

# 存入数组并展示列表
declare -a CONFIG_ARRAY
idx=1
ACTIVE_DEFAULT=""

echo -e "\n${BOLD}🔍 扫描到以下哪吒探针配置文件：${NC}\n"

while IFS= read -r cfg; do
    [ ! -f "$cfg" ] && continue
    CONFIG_ARRAY[$idx]="$cfg"
    
    curr_server=$(grep -E "^[[:space:]]*server:" "$cfg" | head -n 1 | awk -F'server:' '{print $2}' | tr -d ' "\r'"'")
    [ -z "$curr_server" ] && curr_server="未知"

    status_tag="${GRAY}[未激活/残留]${NC}"
    if echo "$RUNNING_CONFIGS" | grep -qx "$cfg"; then
        status_tag="${GREEN}${BOLD}[★ 进程运行中]${NC}"
        [ -z "$ACTIVE_DEFAULT" ] && ACTIVE_DEFAULT=$idx
    elif echo "$SERVICE_CONFIGS" | grep -qx "$cfg"; then
        status_tag="${CYAN}[服务已绑定]${NC}"
        [ -z "$ACTIVE_DEFAULT" ] && ACTIVE_DEFAULT=$idx
    fi

    printf "  ${YELLOW}[%d]${NC} %-38s %b\n" "$idx" "$cfg" "$status_tag"
    printf "      └─ 当前主控 (server): ${BOLD}${BLUE}%s${NC}\n\n" "$curr_server"
    ((idx++))
done <<< "$ALL_CONFIGS"

total=$((idx - 1))
if [ $total -eq 0 ]; then
    echo -e "${RED}[错误] 找到的配置文件路径均不存在！${NC}"
    exit 1
fi

echo -e "  ${YELLOW}[0]${NC} ${BOLD}修改以上全部配置文件${NC}"
echo -e "${CYAN}------------------------------------------------------------${NC}"

[ -z "$ACTIVE_DEFAULT" ] && ACTIVE_DEFAULT=1

# 判断是否使用了命令行传参的极速模式
if [ -n "$QUICK_NEW_SERVER" ]; then
    echo -e "⚡ 检测到极速传参模式，自动选中默认生效配置 ${GREEN}[${ACTIVE_DEFAULT}]${NC}，目标地址: ${GREEN}${QUICK_NEW_SERVER}${NC}"
    choice="$ACTIVE_DEFAULT"
    new_input="$QUICK_NEW_SERVER"
else
    # 注意：使用 </dev/tty 确保在 curl | bash 管道模式下依然能正常等待用户输入
    read -p "$(echo -e "👉 请选择要修改的配置文件编号 [默认: ${GREEN}${ACTIVE_DEFAULT}${NC}，输入 q 退出]: ")" choice </dev/tty
    choice=${choice:-$ACTIVE_DEFAULT}

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo -e "${YELLOW}已取消操作。${NC}"
        exit 0
    fi

    echo ""
    echo -e "${GRAY}提示：如果只输入 IP 或域名（如 1.2.3.4），脚本会自动保留原来的端口号；${NC}"
    echo -e "${GRAY}      如果输入 IP:端口（如 1.2.3.4:8008），则会连同端口一起修改。${NC}"
    read -p "$(echo -e "✏️  请输入新的主控 Server 地址: ")" new_input </dev/tty
fi

# 验证选择合法性
declare -a TARGET_CONFIGS
if [[ "$choice" == "0" ]]; then
    TARGET_CONFIGS=("${CONFIG_ARRAY[@]}")
elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
    TARGET_CONFIGS=("${CONFIG_ARRAY[$choice]}")
else
    echo -e "${RED}[错误] 无效的编号选择！${NC}"
    exit 1
fi

new_input=$(echo "$new_input" | tr -d ' ')
if [ -z "$new_input" ]; then
    echo -e "${RED}[错误] 新主控地址不能为空！${NC}"
    exit 1
fi

echo -e "\n${CYAN}------------------------------------------------------------${NC}"

# 执行修改
for target in "${TARGET_CONFIGS[@]}"; do
    old_server=$(grep -E "^[[:space:]]*server:" "$target" | head -n 1 | awk -F'server:' '{print $2}' | tr -d ' "\r'"'")
    old_port=""
    if [[ "$old_server" == *:* ]]; then
        old_port="${old_server##*:}"
    fi

    if [[ "$new_input" == *:* ]]; then
        final_server="$new_input"
    else
        if [ -n "$old_port" ]; then
            final_server="${new_input}:${old_port}"
        else
            final_server="$new_input"
        fi
    fi

    cp "$target" "${target}.bak"
    sed -i -E "s|^([[:space:]]*server:[[:space:]]*).*|\1${final_server}|" "$target"

    echo -e "✅ 已更新: ${BOLD}$target${NC}"
    echo -e "   ├─ 原地址: ${GRAY}${old_server}${NC}"
    echo -e "   ├─ 新地址: ${GREEN}${BOLD}${final_server}${NC}"
    echo -e "   └─ 备份至: ${GRAY}${target}.bak${NC}"
done

echo -e "${CYAN}------------------------------------------------------------${NC}"

# 查找并重启对应的 systemd 服务
SERVICES=$(systemctl list-unit-files "nezha-agent*.service" 2>/dev/null | awk '/nezha-agent/ {print $1}')

if [ -n "$SERVICES" ]; then
    echo -e "🔄 正在重启哪吒探针服务使配置生效..."
    for svc in $SERVICES; do
        systemctl restart "$svc"
        if systemctl is-active --quiet "$svc"; then
            echo -e "🎉 服务 ${GREEN}${BOLD}${svc}${NC} 重启成功，当前状态: ${GREEN}Active (Running)${NC}"
        else
            echo -e "⚠️  服务 ${RED}${BOLD}${svc}${NC} 重启异常，请使用 systemctl status $svc 检查！"
        fi
    done
else
    echo -e "${YELLOW}⚠️ 未检测到标准的 systemd 服务 (nezha-agent.service)，请手动重启探针进程。${NC}"
fi

echo -e "${CYAN}============================================================${NC}"
