#!/bin/bash
# =========================================================
# Xray Google 送中模式管理脚本 (高强度多维度发包)
# 快捷指令: sz
# =========================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PING_SCRIPT="/usr/local/bin/google_cn_ping.sh"
SERVICE_FILE="/etc/systemd/system/google-cn-ping.service"

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
    SCRIPT_PATH=$(readlink -f "$0")
    if [ ! -f /usr/local/bin/sz ] || [ "$(readlink -f /usr/local/bin/sz)" != "$SCRIPT_PATH" ]; then
        ln -sf "$SCRIPT_PATH" /usr/local/bin/sz
        chmod +x /usr/local/bin/sz
    fi
}

# 创建高强度多元化发包脚本
create_ping_service() {
    cat << 'EOF' > "$PING_SCRIPT"
#!/bin/bash
# 高强度送中维持脚本：模拟移动设备特征，多节点随机间隔发包

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
    # 1. 触发 AliDNS DoH 解析 query（附带 ECS 参数模拟中国电信/联通源）
    curl -s "https://dns.alidns.com/dns-query?name=www.google.com&type=A&edns_client_subnet=114.240.0.0/16" >/dev/null 2>&1 || true
    curl -s "https://dns.alidns.com/dns-query?name=location.services.mozilla.com&type=A&edns_client_subnet=202.108.22.0/16" >/dev/null 2>&1 || true

    # 2. 模拟移动终端连续向 Google 各 API 节点发包
    for url in "${endpoints[@]}"; do
        curl -s -A "$UA_MOBILE" \
             -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8" \
             -H "Cache-Control: no-cache" \
             --connect-timeout 5 \
             "$url" >/dev/null 2>&1 || true
    done

    # 3. 随机休眠 120 ~ 300 秒（模拟真实行为，防止被识别为固定 Cron）
    SLEEP_TIME=$((120 + RANDOM % 180))
    sleep $SLEEP_TIME
done
EOF
    chmod +x "$PING_SCRIPT"

    cat << EOF > "$SERVICE_FILE"
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

    systemctl daemon-reload
}

install_xray() {
    echo -e "${YELLOW}=== 开始安装系统依赖与 Xray ===${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y curl jq python3
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y curl jq python3
    fi

    find_config
    if [ -z "$XRAY_CONF" ]; then
        echo -e "${YELLOW}未检测到 Xray，开始执行官方一键安装脚本...${NC}"
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        find_config
    else
        echo -e "${GREEN}检测到 Xray 配置文件：$XRAY_CONF${NC}"
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

    setup_shortcut
    create_ping_service
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

# 扩展 Google 核心网域与底层 CDN 网域
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
    systemctl restart xray 2>/dev/null || systemctl restart v2ray 2>/dev/null || true
    systemctl enable google-cn-ping.service >/dev/null 2>&1 || true
    systemctl restart google-cn-ping.service >/dev/null 2>&1 || true

    echo -e "${GREEN}✅ 已成功开启『高强度送中模式』！${NC}"
    echo -e "${GREEN}✅ 已注入全套 Google 核心与底层 CDN 网域路由规则。${NC}"
    echo -e "${GREEN}✅ 多维度模拟发包服务已启动（含 Android User-Agent、ECS 伪装及随机延迟）。${NC}"
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
    systemctl restart xray 2>/dev/null || systemctl restart v2ray 2>/dev/null || true
    systemctl stop google-cn-ping.service >/dev/null 2>&1 || true
    systemctl disable google-cn-ping.service >/dev/null 2>&1 || true

    echo -e "${GREEN}✅ 已成功关闭『送中模式』，恢复默认国际解析！${NC}"
    echo -e "${YELLOW}（高强度发包维持服务已停止）${NC}"
}

show_menu() {
    echo "================================================="
    echo "       Xray Google 送中模式管理脚本 (高强度)     "
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
