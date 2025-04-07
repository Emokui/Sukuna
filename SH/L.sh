#!/bin/bash

# 1. 创建 clash 目录（如果不存在）
echo "[*] 检查并创建 clash 目录..."
mkdir -p ~/clash
cd ~/clash

# 2. 下載 Mihomo 可執行文件
echo "[*] 下載 Mihomo..."
wget https://github.com/MetaCubeX/mihomo/releases/download/v1.19.4/mihomo-linux-amd64-compatible-v1.19.4.gz -O mihomo-linux-amd64-compatible-v1.19.4.gz

# 3. 解壓縮並賦予執行權限
echo "[*] 解壓並賦予執行權限..."
gunzip mihomo-linux-amd64-compatible-v1.19.4.gz
mv mihomo-linux-amd64-compatible-v1.19.4 mihomo
chmod +x mihomo


# 4. 提示用户输入代理设置
echo "[*] 请提供代理设置："

# 交互式获取输入
read -p "Private-key: " private_key
read -p "Server: " server
read -p "Port: " port
read -p "Public-key: " public_key
read -p "Reserved: " reserved
read -p "MTU: " mtu

# 5. 创建 config.yaml 配置文件，将用户输入的值填入
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
