#!/bin/bash

# 定义可执行路径和配置文件路径
Mihomo_PATH="./clash/mihomo"
CONFIG_PATH="/root/clash/config.yaml"

# 显示菜单
while true; do
    echo "请选择操作："
    echo "1) 安装并配置 Mihomo (运行 N.sh 内容)"
    echo "2) 管理 Mihomo 服务 (运行 L.sh 内容)"
    echo "3) 退出"
    read -p "请输入选项 [1-3]: " choice

    case $choice in
        1)
            # 运行 N.sh 的内容 - 安装和配置 Mihomo
            echo "[*] 开始安装并配置 Mihomo..."
            
            # 1. 创建 clash 目录（如果不存在）
            echo "[*] 检查并创建 clash 目录..."
            mkdir -p ~/clash
            cd ~/clash

            # 2. 下载 Mihomo 可执行文件
            echo "[*] 下载 Mihomo..."
            wget https://github.com/MetaCubeX/mihomo/releases/download/v1.19.4/mihomo-linux-amd64-compatible-v1.19.4.gz -O mihomo-linux-amd64-compatible-v1.19.4.gz

            # 3. 解压并赋予执行权限
            echo "[*] 解压并赋予执行权限..."
            gunzip mihomo-linux-amd64-compatible-v1.19.4.gz
            mv mihomo-linux-amd64-compatible-v1.19.4 mihomo
            chmod +x mihomo

            # 4. 提示用户输入代理设置
            echo "[*] 请提供代理设置："
            read -p "Private-key: " private_key
            read -p "Server: " server
            read -p "Port: " port
            read -p "Public-key: " public_key
            read -p "Reserved: " reserved
            read -p "MTU: " mtu

            # 5. 创建 config.yaml 配置文件
            echo "[*] 创建 config.yaml 配置文件..."
            cat <<EOF > config.yaml
tun:
  enable: true
  stack: system
  dns-hijack:
    - 'any:53'
  strict_route: true
  auto-route: true
  auto-detect-interface: true

geodata-mode: false
geox-url:
  mmdb: "https://raw.githubusercontent.com/NobyDa/geoip/release/Private-GeoIP-CN.mmdb"
geo-update-interval: 24
tcp-concurrent: true
allow-lan: false
mode: rule
log-level: warning
ipv6: false
#interface-name: ens5
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
  #nameserver-policy:
  # 'www.google.com': '8.8.4.4'
  enhanced-mode: redir-host
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*'
    - '+.lan'
    - '+.local'
  use-hosts: true

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
  China:
    type: http
    behavior: classical
    format: text
    path: ./𝗗𝗜𝗥𝗘𝗖𝗧
    url: https://fbi.hk.dedyn.io/Emokui/Rule/𝗟𝗶𝘀𝘁/𝗗𝗜𝗥𝗘𝗖𝗧
    interval: 86400
  OpenAi:
    type: http
    behavior: classical
    format: text
    path: ./𝗢𝗽𝗲𝗻𝗔𝗜
    url: https://fbi.hk.dedyn.io/Emokui/Rule/𝗟𝗶𝘀𝘁/𝗢𝗽𝗲𝗻𝗔𝗜
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
  - RULE-SET,OpenAi,warp,no-resolve
  - RULE-SET,China,warp,no-resolve
  - GEOIP,CN,warp,no-resolve
  - MATCH,DIRECT
EOF

            # 6. 启动 Mihomo
            echo "[*] 启动 Mihomo..."
            ./mihomo -f ./config.yaml
            echo "[*] 请稍候，Mihomo 已启动并配置完成。"
            ;;
        
        2)
            # 运行 L.sh 的内容 - 管理 Mihomo 服务
            while true; do
                echo "请选择操作："
                echo "1) 停止 Mihomo"
                echo "2) 启动 Mihomo"
                echo "3) 重启 Mihomo"
                echo "4) 返回主菜单"
                read -p "请输入选项 [1-4]: " subchoice

                case $subchoice in
                    1)
                        # 停止 Mihomo
                        echo "[*] 停止 Mihomo..."
                        pkill mihomo
                        echo "[*] Mihomo 已停止。"
                        ;;
                    2)
                        # 启动 Mihomo
                        echo "[*] 启动 Mihomo..."
                        $Mihomo_PATH -f $CONFIG_PATH
                        echo "[*] Mihomo 已启动。"
                        ;;
                    3)
                        # 重启 Mihomo
                        echo "[*] 重启 Mihomo..."
                        pkill mihomo
                        sleep 2
                        $Mihomo_PATH -f $CONFIG_PATH
                        echo "[*] Mihomo 已重启。"
                        ;;
                    4)
                        # 返回主菜单
                        break
                        ;;
                    *)
                        echo "无效选项，请重新选择。"
                        ;;
                esac
            done
            ;;
        
        3)
            # 退出脚本
            echo "[*] 退出脚本..."
            break
            ;;
        
        *)
            echo "无效选项，请重新选择。"
            ;;
    esac
done
