#!/bin/bash
# =========================================================
# Xray Google 送中模式管理脚本 (全平台/Alpine LXC 防卡死版)
# 快捷指令: sz
# =========================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PING_SCRIPT="/usr/local/bin/google_cn_ping.sh"
SERVICE_FILE_SYSTEMD="/etc/systemd/system/google-cn-ping.service"
SERVICE_FILE_OPENRC="/etc/init.d/google-cn-ping"

# 打印开场 Banner
show_banner() {
    clear
    echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ ${YELLOW}★ ${RED}  ${YELLOW}*${RED}                                                  ║${NC}"
    echo -e "${RED}║    ${YELLOW}*${RED}                                                     ║${NC}"
    echo -e "${RED}║    ${YELLOW}*${RED}                                                     ║${NC}"
    echo -e "${RED}║   ${YELLOW}*${RED}                                                      ║${NC}"
    echo -e "${RED}║                                                       ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "   ${BLUE}██████${NC}   ${RED}██████${NC}   ${YELLOW}██████${NC}   ${BLUE}██████${NC}   ${GREEN}██${NC}      ${RED}██████${NC}"
    echo -e "  ${BLUE}██${NC}        ${RED}██  ██${NC}  ${YELLOW}██  ██${NC}  ${BLUE}██${NC}       ${GREEN}██${NC}      ${RED}██${NC}"
    echo -e "  ${BLUE}██   ███${NC}  ${RED}██  ██${NC}  ${YELLOW}██  ██${NC}  ${BLUE}██   ███${NC}  ${GREEN}██${NC}      ${RED}█████${NC}"
    echo -e "  ${BLUE}██    ██${NC}  ${RED}██  ██${NC}  ${YELLOW}██  ██${NC}  ${BLUE}██    ██${NC}  ${GREEN}██${NC}      ${RED}██${NC}"
    echo -e "   ${BLUE}██████${NC}   ${RED}██████${NC}   ${YELLOW}██████${NC}   ${BLUE}██████${NC}   ${GREEN}███████${NC}  ${RED}██████${NC}"
    echo ""
}

find_config() {
    XRAY_CONF=""
    for path in "/usr/local/etc/xray/config.json" "/etc/xray/config.json" "/etc/v2ray/config.json" "/usr/local/etc/v2ray/config.json"; do
        if [ -f "$path" ]; then
            XRAY_CONF="$path"
            break
        fi
    done
}

setup_shortcut() {
    LOCAL_SCRIPT="/usr/local/bin/google_cn_manager.sh"

    if [ ! -f "$LOCAL_SCRIPT" ] || [ "$(readlink -f "$0")" != "$LOCAL_SCRIPT" ]; then
        if [ -f "$0" ] && [ "$0" != "/dev/stdin" ] && [[ "$0" != /dev/fd/* ]]; then
            cp -f "$(readlink -f "$0")" "$LOCAL_SCRIPT"
        else
            echo -e "${YELLOW}正在将脚本持久化安装至 $LOCAL_SCRIPT ...${NC}"
            curl -sSL "https://raw.githubusercontent.com/edmond1294/GoogleToChina/main/sz.sh" -o "$LOCAL_SCRIPT"
        fi
        chmod +x "$LOCAL_SCRIPT"
    fi

    ln -sf "$LOCAL_SCRIPT" /usr/local/bin/sz
    chmod +x /usr/local/bin/sz
}

# 预防内存不足 (自动检测 LXC/Docker 容器并安全处理)
check_swap() {
    # 如果检测到在 LXC / Docker 容器内，直接跳过 Swap 建立
    if [ -f /proc/1/environ ] && grep -qa -e "container=lxc" -e "container=docker" /proc/1/environ; then
        return 0
    fi
    if [ -d /dev/pve ] || grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi

    MEM_FREE=$(free -m | awk '/Mem:/ {print $4+$6}')
    SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')

    if [ "$MEM_FREE" -lt 300 ] && [ "$SWAP_TOTAL" -eq 0 ]; then
        echo -e "${YELLOW}检测到 KVM 虚拟机内存不足且未配置 Swap，正在建立 1GB 临时 Swap...${NC}"
        dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none 2>/dev/null || true
        chmod 600 /swapfile 2>/dev/null || true
        mkswap /swapfile >/dev/null 2>&1 || true
        swapon /swapfile >/dev/null 2>&1 || true
    fi
}

create_ping_service() {
    cat << 'EOF' > "$PING_SCRIPT"
#!/bin/bash
UA_MOBILE="Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UD1A.230803.041) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.119 Mobile Safari/537.36"

endpoints=(
    "https://www.google.com/generate_204"
    "https://www.google.cn/generate_204"
    "https://connectivitycheck.gstatic.com/generate_204"
    "https://clients3.google.com/generate_204"
    "https://location.services.mozilla.com/v1/geolocate"
    "https://play.googleapis.com/generate_204"
    "https://safebrowsing.googleapis.com/v4/threatListUpdates:fetch"
)

while true; do
    curl -s "https://dns.alidns.com/dns-query?name=www.google.com&type=A&edns_client_subnet=114.240.0.0/16" >/dev/null 2>&1 || true
    curl -s "https://dns.alidns.com/dns-query?name=location.services.mozilla.com&type=A&edns_client_subnet=202.108.22.0/16" >/dev/null 2>&1 || true

    for url in "${endpoints[@]}"; do
        curl -s -A "$UA_MOBILE" \
             -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8" \
             -H "Cache-Control: no-cache" \
             --connect-timeout 5 \
             "$url" >/dev/null 2>&1 || true
    done

    SLEEP_TIME=$((120 + RANDOM % 180))
    sleep $SLEEP_TIME
done
EOF
    chmod +x "$PING_SCRIPT"

    # 判断服务管理器：OpenRC (Alpine) vs Systemd
    if command -v rc-service >/dev/null 2>&1 || [ -f /etc/alpine-release ]; then
        cat << 'EOF' > "$SERVICE_FILE_OPENRC"
#!/sbin/openrc-run

name="google-cn-ping"
description="Google CN Location Keep-Alive Service"
command="/usr/local/bin/google_cn_ping.sh"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"

depend() {
    need net
}
EOF
        chmod +x "$SERVICE_FILE_OPENRC"
        rc-update add google-cn-ping default >/dev/null 2>&1 || true
    else
        cat << EOF > "$SERVICE_FILE_SYSTEMD"
[Unit]
Description=Google CN Location Keep-Alive Service (High Intensity)
After=network.target

[Service]
Type=simple
ExecStart=$PING_SCRIPT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

install_xray() {
    setup_shortcut

    NEED_INSTALL=0
    for pkg in curl jq python3 bash; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            NEED_INSTALL=1
            break
        fi
    done

    if [ "$NEED_INSTALL" -eq 1 ]; then
        echo -e "${YELLOW}=== 检测到缺少依赖，开始安装环境 ===${NC}"
        check_swap
        
        if command -v apk >/dev/null 2>&1; then
            apk update -q
            apk add -q curl jq python3 bash
        elif command -v apt-get >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq curl jq python3 bash
        elif command -v yum >/dev/null 2>&1; then
            yum install -y -q curl jq python3 bash
        fi
    fi

    find_config
    if [ -z "$XRAY_CONF" ]; then
        echo -e "${YELLOW}未检测到 Xray，开始执行官方一键安装脚本...${NC}"
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        find_config
    fi

    if [ ! -s "$XRAY_CONF" ]; then
        mkdir -p "$(dirname "$XRAY_CONF")"
        cat << 'CONF_EOF' > "$XRAY_CONF"
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
CONF_EOF
        echo -e "${GREEN}已创建基础 Xray 配置文件。${NC}"
    fi

    create_ping_service
}

restart_service() {
    local action="$1" # start or stop
    if command -v rc-service >/dev/null 2>&1 || [ -f /etc/alpine-release ]; then
        rc-service xray $action 2>/dev/null || true
        rc-service google-cn-ping $action 2>/dev/null || true
    else
        systemctl $action xray 2>/dev/null || systemctl $action v2ray 2>/dev/null || true
        if [ "$action" = "start" ]; then
            systemctl enable google-cn-ping.service >/dev/null 2>&1 || true
            systemctl restart google-cn-ping.service >/dev/null 2>&1 || true
        else
            systemctl stop google-cn-ping.service >/dev/null 2>&1 || true
            systemctl disable google-cn-ping.service >/dev/null 2>&1 || true
        fi
    fi
}

enable_cn_dns() {
    find_config
    if [ -z "$XRAY_CONF" ]; then
        echo -e "${RED}错误：未找到 Xray 配置文件，请先执行安装！${NC}"
        return
    fi

    cp "$XRAY_CONF" "${XRAY_CONF}.bak"

    python3 -c "
import json

conf_path = '$XRAY_CONF'
with open(conf_path, 'r') as f:
    data = json.load(f)

data['dns'] = {
    'servers': [
        {
            'address': 'https://dns.alidns.com/dns-query',
            'domains': [
                'geosite:google',
                'domain:google.com',
                'domain:google.cn',
                'domain:google.com.hk',
                'domain:googleapis.com',
                'domain:gstatic.com',
                'domain:gvt1.com',
                'domain:1e100.net',
                'domain:location.services'
            ]
        },
        'https://1.1.1.1/dns-query',
        '8.8.8.8'
    ]
}

if 'routing' not in data:
    data['routing'] = {}
data['routing']['domainStrategy'] = 'IPIfNonMatch'

with open(conf_path, 'w') as f:
    json.dump(data, f, indent=2)
"
    restart_service "start"

    echo -e "${GREEN}✅ 已成功开启『高强度送中模式』！${NC}"
    echo -e "${GREEN}✅ 多维度模拟发包服务已启动。${NC}"
}

disable_cn_dns() {
    find_config
    if [ -z "$XRAY_CONF" ]; then
        echo -e "${RED}错误：未找到 Xray 配置文件！${NC}"
        return
    fi

    cp "$XRAY_CONF" "${XRAY_CONF}.bak"

    python3 -c "
import json

conf_path = '$XRAY_CONF'
with open(conf_path, 'r') as f:
    data = json.load(f)

data['dns'] = {
    'servers': [
        'https://1.1.1.1/dns-query',
        '8.8.8.8',
        '1.1.1.1'
    ]
}

with open(conf_path, 'w') as f:
    json.dump(data, f, indent=2)
"
    restart_service "stop"

    echo -e "${GREEN}✅ 已成功关闭『送中模式』，恢复默认国际解析！${NC}"
}

show_menu() {
    show_banner
    echo "================================================="
    echo "       Xray Google 送中模式管理脚本 (全平台版)   "
    echo "================================================="
    echo -e " 1. ${GREEN}开启高强度送中模式 (多维发包 + 动态间隔)${NC}"
    echo -e " 2. ${RED}关闭送中模式${NC}"
    echo -e " 3. ${YELLOW}一键安装/修复 Xray 与依赖环境${NC}"
    echo " 0. 退出脚本"
    echo "================================================="
    echo -e " 💡 提示：后续可在命令行直接输入 ${GREEN}sz${NC} 呼出本菜单"
    echo "================================================="
    read -p "请选择选项 [0-3]: " choice

    case "$choice" in
        1)
            enable_cn_dns
            ;;
        2)
            disable_cn_dns
            ;;
        3)
            install_xray
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新输入！${NC}"
            show_menu
            ;;
    esac
}

install_xray
show_menu
