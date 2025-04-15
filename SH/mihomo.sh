#!/bin/bash

# 定義變量
MIHOMO_DIR="${HOME}/clash"
MIHOMO_PATH="${MIHOMO_DIR}/mihomo"
CONFIG_PATH="${MIHOMO_DIR}/config.yaml"
SERVICE_NAME="mihomo-user"
TIMER_NAME="mihomo-user.timer"

# 檢查命令執行結果
check_status() {
    if [ $? -ne 0 ]; then
        echo "[!] $1 失败。"
        exit 1
    fi
}

# 產生 systemd 服務單元文件
create_systemd_service() {
    cat <<EOF | sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null
[Unit]
Description=User Mihomo Service (Delayed Start)
After=network.target

[Service]
Type=simple
ExecStart=${MIHOMO_PATH} -f ${CONFIG_PATH}
WorkingDirectory=${MIHOMO_DIR}
Restart=on-failure
User=${USER}
EOF
    sudo chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
}

# 產生 systemd timer 文件（開機5分鐘後啟動）
create_systemd_timer() {
    cat <<EOF | sudo tee /etc/systemd/system/${TIMER_NAME} > /dev/null
[Unit]
Description=Start Mihomo 5 minutes after boot

[Timer]
OnBootSec=5min
AccuracySec=30s
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF
    sudo chmod 644 /etc/systemd/system/${TIMER_NAME}
}

# 函數：獲取最新穩定 Mihomo 版本
get_latest_stable_version() {
    local raw_version
    echo "[*] 检查最新稳定 Mihomo 版本..." >&2
    raw_version=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases | \
                  grep -oP '(?<=tag_name": "v)\d+\.\d+\.\d+(?=")' | \
                  grep -v "Prerelease" | head -n 1)
    if [ -z "$raw_version" ]; then
        echo "[!] 无法获取最新稳定版本，请检查网络或 GitHub API。" >&2
        exit 1
    fi
    local latest_version="v${raw_version}"
    echo "[*] 最新稳定版本: $latest_version" >&2
    echo "$latest_version"
}

# 安裝並配置 Mihomo + systemd
install_mihomo() {
    echo "[*] 开始安装并配置 Mihomo..."
    mkdir -p "$MIHOMO_DIR" && cd "$MIHOMO_DIR" || exit 1

    # 獲取最新穩定版本
    latest_version=$(get_latest_stable_version)
    download_url="https://github.com/MetaCubeX/mihomo/releases/download/${latest_version}/mihomo-linux-amd64-compatible-${latest_version}.gz"

    echo "[*] 下载 Mihomo $latest_version..."
    wget "$download_url" -O "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "下载 Mihomo"

    echo "[*] 解压并赋予执行权限..."
    gunzip "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "解压文件"
    mv "mihomo-linux-amd64-compatible-${latest_version}" mihomo
    chmod +x mihomo
    check_status "设置执行权限"

    # 提示用户输入 wireguard 配置，提供默认值
    echo "[*] 请提供 wireguard 配置（按 Enter 使用默认值）："
    read -p "Private-key 回车默认: " private_key
    private_key=${private_key:-2Nk08dzxAkzubjt19fO2VKEgdBjpHxEluNvTJKDHW1w=}
    read -p "Endpoint 回车默认: " server
    server=${server:-162.159.193.10}
    read -p "Port 回车默认: " port
    port=${port:-2408}
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "[!] 无效的端口号，请输入 1-65535 之间的数字。"
        exit 1
    fi
    read -p "Public-key 回车默认: " public_key
    public_key=${public_key:-bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=}
    read -p "Reserved 回车默认: " reserved
    reserved=${reserved:-[154,242,221]}
    read -p "MTU 回车默认: " mtu
    mtu=${mtu:-1280}

    # 创建 config.yaml 配置文件
    echo "[*] 创建 config.yaml 配置文件..."
    cat <<EOF > config.yaml
tun:
  enable: true
  stack: system
  dns-hijack:
    - '0.0.0.0:53'
  strict_route: true
  auto-route: true
  auto-detect-interface: true

geodata-mode: false
geox-url:
  mmdb: "https://raw.githubusercontent.com/NobyDa/geoip/release/Private-GeoIP-CN.mmdb"
geo-update-interval: 24
tcp-concurrent: true
find-process-mode: off
allow-lan: false
mode: rule
log-level: warning
ipv6: false
profile:
  store-fake-ip: true
sniffer:
  enable: false
dns:
  enable: true
  listen: 0.0.0.0:53
  ipv6: false
  default-nameserver:
    - 8.8.8.8
    - 1.1.1.1
  nameserver:
    - 1.1.1.1
    - 8.8.8.8
  direct-nameserver:
    - 1.1.1.1
    - 8.8.8.8
  enhanced-mode: fake-ip # or redir-host

  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*'
    - '+.lan'
    - '+.local'
 # use-hosts: true

proxies:
  - name: "warp"
    type: wireguard
    private-key: $private_key
    server: $server
    port: $port
    ip: 172.16.0.2
    public-key: $public_key
    allowed-ips: ['0.0.0.0/0']
    reserved: $reserved
    udp: true
    mtu: $mtu

rule-providers:
  Ai:
    type: http
    behavior: classical
    format: text
    path: ./𝗔𝗜
    url: https://fbi.hk.dedyn.io/Emokui/Rule/𝗟𝗶𝘀𝘁/𝗔𝗜
    interval: 86400
  YouTube:
    type: http
    behavior: classical
    format: text
    path: ./𝗬𝗼𝘂𝗧𝘂𝗯𝗲
    url: https://fbi.hk.dedyn.io/Emokui/Rule/𝗟𝗶𝘀𝘁/𝗬𝗼𝘂𝗧𝘂𝗯𝗲
    interval: 86400

rules:
  - RULE-SET,YouTube,warp,no-resolve
  - RULE-SET,Ai,warp,no-resolve
  - MATCH,DIRECT
EOF
    check_status "创建配置文件"

    echo "[*] 配置 systemd service 與 timer..."
    create_systemd_service
    create_systemd_timer

    sudo systemctl daemon-reload
    sudo systemctl enable --now ${TIMER_NAME}
    echo "[*] Mihomo 安裝完成，將於開機5分鐘後自動啟動。"
    echo "你也可以用 'sudo systemctl [start|stop|restart|status] ${SERVICE_NAME}' 管理"
    echo "查看定時器狀態：sudo systemctl status ${TIMER_NAME}"
}

# 更新 Mihomo 僅需覆蓋二進制，無需動到 systemd/timer
update_mihomo() {
    echo "[*] 开始更新 Mihomo..."
    cd "$MIHOMO_DIR" || { echo "[!] 无法进入 $MIHOMO_DIR 目录。"; exit 1; }
    latest_version=$(get_latest_stable_version)
    download_url="https://github.com/MetaCubeX/mihomo/releases/download/${latest_version}/mihomo-linux-amd64-compatible-${latest_version}.gz"

    echo "[*] 下载 Mihomo $latest_version..."
    wget "$download_url" -O "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "下载 Mihomo"

    echo "[*] 解压并替换文件..."
    gunzip "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "解压文件"
    if [ -f "$MIHOMO_PATH" ]; then
        mv "$MIHOMO_PATH" "$MIHOMO_PATH.old"
        echo "[*] 已备份旧内核到 $MIHOMO_PATH.old"
    fi
    mv "mihomo-linux-amd64-compatible-${latest_version}" mihomo
    chmod +x mihomo
    check_status "设置执行权限"
    rm -f "$MIHOMO_PATH.old"

    echo "[*] 重启 Mihomo systemd 服務..."
    sudo systemctl restart ${SERVICE_NAME}.service
    sleep 2
    sudo systemctl status ${SERVICE_NAME}.service
}

# 刪除 Mihomo 及配置並關閉 systemd
delete_mihomo() {
    echo "[!] 此操作将停止并彻底删除 Mihomo 及其配置，无法恢复！"
    read -p "确定要删除 Mihomo 及配置吗？(yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        echo "[*] 停止並禁用 Mihomo systemd/timer..."
        sudo systemctl stop ${SERVICE_NAME}.service
        sudo systemctl disable ${SERVICE_NAME}.service
        sudo systemctl stop ${TIMER_NAME}
        sudo systemctl disable ${TIMER_NAME}
        sudo rm -f /etc/systemd/system/${SERVICE_NAME}.service
        sudo rm -f /etc/systemd/system/${TIMER_NAME}
        sudo systemctl daemon-reload

        if [ -d "$MIHOMO_DIR" ]; then
            rm -rf "$MIHOMO_DIR"
            if [ ! -d "$MIHOMO_DIR" ]; then
                echo "[*] 已彻底删除 $MIHOMO_DIR 及其中所有内容。"
            else
                echo "[!] 删除失败，请检查权限。"
            fi
        else
            echo "[*] 未检测到 $MIHOMO_DIR 目录。"
        fi
        echo "[*] Mihomo 及配置、systemd單元已全部刪除。"
    else
        echo "[*] 已取消删除操作。"
    fi
}

# 管理 Mihomo systemd 服務
manage_service() {
    while true; do
        echo "選擇屬於你的命運之門"
        echo "1. 停止 Mihomo"
        echo "2. 启动 Mihomo"
        echo "3. 重启 Mihomo"
        echo "4. 查看 Mihomo 狀態"
        echo "5. 查看 Timer 狀態"
        echo "6. 刪除 Mihomo 及配置"
        echo "0. 返回世界線"
        read -p "请输入选项 [0-6]: " subchoice

        case $subchoice in
            1)
                echo "[*] systemd 停止 Mihomo..."
                sudo systemctl stop ${SERVICE_NAME}.service
                ;;
            2)
                echo "[*] systemd 启动 Mihomo..."
                sudo systemctl start ${SERVICE_NAME}.service
                ;;
            3)
                echo "[*] systemd 重启 Mihomo..."
                sudo systemctl restart ${SERVICE_NAME}.service
                ;;
            4)
                echo "[*] systemd 查看 Mihomo 狀態..."
                sudo systemctl status ${SERVICE_NAME}.service
                ;;
            5)
                echo "[*] 查看 Timer 狀態..."
                sudo systemctl status ${TIMER_NAME}
                ;;
            6)
                delete_mihomo
                break
                ;;
            0)
                echo "[*] 返回主菜单..."
                break
                ;;
            *)
                echo "无效选项，请重新选择。"
                ;;
        esac
    done
}

# 主菜單
BLUE="\033[1;34m"
PLAIN="\033[0m"
while true; do
    clear
    echo -e "${BLUE}==============================================${PLAIN}"
    echo -e "${BLUE}====      Steins Gate - mihomo Ver.1.0     ====${PLAIN}"
    echo -e "${BLUE}==============================================${PLAIN}"
    echo "選擇屬於你的命運之門："
    echo "1. 安装并配置 Mihomo (systemd/timer 5分钟后自启)"
    echo "2. 管理 Mihomo 服务 (systemd)"
    echo "3. 更新 Mihomo"
    echo "0. 再见 El Psy Kongroo"
    read -p "请输入选项 [0-3]: " choice

    case $choice in
        1) install_mihomo ;;
        2)
            if [ ! -f "$MIHOMO_PATH" ]; then
                echo "[!] Mihomo 未安装，请先选择选项 1。"
                continue
            fi
            manage_service
            ;;
        3)
            if [ ! -d "${HOME}/clash" ]; then
                echo "[!] 未找到 ~/clash 目录，请先选择选项 1 安装。"
                continue
            fi
            update_mihomo
            ;;
        0) echo "[*] 退出脚本..."; exit 0 ;;
        *) echo "无效选项，请重新选择。" ;;
    esac
done
