#!/bin/bash

# 定義變量
MIHOMO_PATH="${HOME}/clash/mihomo"
CONFIG_PATH="${HOME}/clash/config.yaml"

# 函數：檢查命令執行結果
check_status() {
    if [ $? -ne 0 ]; then
        echo "[!] $1 失败。"
        exit 1
    fi
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
    echo "$latest_version" # 僅將版本號輸出到 stdout
}

# 函數：更新 Mihomo
update_mihomo() {
    echo "[*] 开始更新 Mihomo..."
    cd ~/clash || { echo "[!] 无法进入 ~/clash 目录。"; exit 1; }

    # 獲取最新穩定版本
    latest_version=$(get_latest_stable_version)
    download_url="https://github.com/MetaCubeX/mihomo/releases/download/${latest_version}/mihomo-linux-amd64-compatible-${latest_version}.gz"

    # 驗證 URL 格式
    echo "[*] 验证下载 URL: $download_url"
    if ! echo "$download_url" | grep -q "^https://"; then
        echo "[!] 下载 URL 格式错误: $download_url"
        exit 1
    fi

    # 停止正在运行的 Mihomo
    if pgrep -f mihomo > /dev/null; then
        echo "[*] 检测到 Mihomo 正在运行，尝试停止..."
        pkill -f mihomo
        check_status "停止 Mihomo"
        sleep 2
    fi

    # 下載並更新
    echo "[*] 下载 Mihomo $latest_version..."
    wget "$download_url" -O "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "下载 Mihomo"

    echo "[*] 解压并替换文件..."
    gunzip "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "解压文件"
    # 備份舊版本並立即刪除
    if [ -f "$MIHOMO_PATH" ]; then
        mv "$MIHOMO_PATH" "$MIHOMO_PATH.old"
        echo "[*] 已备份旧内核到 $MIHOMO_PATH.old"
    fi
    mv "mihomo-linux-amd64-compatible-${latest_version}" mihomo
    chmod +x mihomo
    check_status "设置执行权限"

    # 刪除舊內核
    if [ -f "$MIHOMO_PATH.old" ]; then
        rm -f "$MIHOMO_PATH.old"
        echo "[*] 已删除旧内核 $MIHOMO_PATH.old"
    fi

    # 重啟 Mihomo 服務
    echo "[*] 重启 Mihomo 服务..."
    "$MIHOMO_PATH" -f "$CONFIG_PATH" &
    check_status "重启 Mihomo"
    echo "[*] Mihomo 更新并重启完成。"
}

# 函數：下載並安裝 Mihomo
install_mihomo() {
    echo "[*] 开始安装并配置 Mihomo..."
    mkdir -p ~/clash && cd ~/clash || exit 1

    # 獲取最新穩定版本
    latest_version=$(get_latest_stable_version)
    download_url="https://github.com/MetaCubeX/mihomo/releases/download/${latest_version}/mihomo-linux-amd64-compatible-${latest_version}.gz"

    # 驗證 URL 格式
    echo "[*] 验证下载 URL: $download_url"
    if ! echo "$download_url" | grep -q "^https://"; then
        echo "[!] 下载 URL 格式错误: $download_url"
        exit 1
    fi

    # 下載文件
    echo "[*] 下载 Mihomo $latest_version..."
    wget "$download_url" -O "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "下载 Mihomo"

    # 解壓並設置執行權限
    echo "[*] 解压并赋予执行权限..."
    gunzip "mihomo-linux-amd64-compatible-${latest_version}.gz"
    check_status "解压文件"
    mv "mihomo-linux-amd64-compatible-${latest_version}" mihomo
    chmod +x mihomo
    check_status "设置执行权限"

    # 提示用户输入代理设置
    echo "[*] 请提供代理设置："
    read -p "Private-key: " private_key
    read -p "Server: " server
    read -p "Port: " port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "[!] 无效的端口号，请输入 1-65535 之间的数字。"
        exit 1
    fi
    read -p "Public-key: " public_key
    read -p "Reserved: " reserved
    read -p "MTU: " mtu

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

    # 启动 Mihomo
    echo "[*] 启动 Mihomo..."
    ./mihomo -f ./config.yaml
    check_status "启动 Mihomo"
    echo "[*] 请稍候，Mihomo 已启动并配置完成。"
}

# 函數：管理 Mihomo 服務
manage_service() {
    while true; do
        echo "请选择操作："
        echo "1) 停止 Mihomo"
        echo "2) 启动 Mihomo"
        echo "3) 重启 Mihomo"
        echo "4) 返回主菜单"
        read -p "请输入选项 [1-4]: " subchoice

        case $subchoice in
            1)
                echo "[*] 停止 Mihomo..."
                if pgrep -f mihomo > /dev/null; then
                    pkill -f mihomo
                    check_status "停止 Mihomo"
                    echo "[*] Mihomo 已停止。"
                else
                    echo "[*] Mihomo 未运行。"
                fi
                ;;
            2)
                echo "[*] 启动 Mihomo..."
                $MIHOMO_PATH -f $CONFIG_PATH
                check_status "启动 Mihomo"
                echo "[*] Mihomo 已启动。"
                ;;
            3)
                echo "[*] 重启 Mihomo..."
                if pgrep -f mihomo > /dev/null; then
                    pkill -f mihomo
                    sleep 2
                fi
                $MIHOMO_PATH -f $CONFIG_PATH
                check_status "重启 Mihomo"
                echo "[*] Mihomo 已重启。"
                ;;
            4)
                break
                ;;
            *)
                echo "无效选项，请重新选择。"
                ;;
        esac
    done
}

# 主菜單
while true; do
    echo "请选择操作："
    echo "1) 安装并配置 Mihomo"
    echo "2) 管理 Mihomo 服务"
    echo "3) 更新 Mihomo"
    echo "4) 退出"
    read -p "请输入选项 [1-4]: " choice

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
        4) echo "[*] 退出脚本..."; exit 0 ;;
        *) echo "无效选项，请重新选择。" ;;
    esac
done
