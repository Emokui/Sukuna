# snell节点分流wireguard #
**解决垃圾IP不登陆无法观看YouTube,无法使用openai,及流媒体**

可根据自己需要解锁的平台，添加对应的分流规则

#### 1.提取 wireguard ####
[注册提取一条龙教程](https://102004.xyz/feed/16)

#### 2.配置 snell ####
无脑回车即可 (如需免流,则开启obfs,host填写伪装域名)
```
wget -O snell.sh --no-check-certificate https://git.io/Snell.sh && chmod +x snell.sh && ./snell.sh
```
#### 3.下载 mihomo ####

**不放心可去 mihomo仓库 https://github.com/MetaCubeX/mihomo 获取**
```
wget https://raw.githubusercontent.com/Emokui/Sukuna/raw/main/Linux/mihomo.gz
```
### 4.解压 ###
**如果解压后名字不同，请重命名为 `mihomo`**
```
gzip -d mihomo.gz
```
#### 5.赋权 ####
```
chmod +x mihomo
```
#### 6.创建配置命名为 `config.yaml` ####
```
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
allow-lan: false
mode: rule
log-level: warning
ipv6: false
#interface-name: en0        #出口网卡名称
profile:                   
  store-fake-ip: true      #fake-ip缓存
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
 #nameserver-policy:                #指定域名使用自定义DNS解析
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
  private-key: 
  server: 
  port: 
  ip: 172.16.0.2
  public-key: 
  allowed-ips: ['0.0.0.0/0']
  reserved: 
  udp: true
  mtu: 1280
  dns: [ 1.1.1.1 ]
rule-providers:
  YouTube:
    type: http
    behavior: classical
    format: text
    path: ./𝗬𝗼𝘂𝗧𝘂𝗯𝗲
    url: https://fbi.hk.dedyn.io/Emokui/Rule/𝗟𝗶𝘀𝘁/𝗬𝗼𝘂𝗧𝘂𝗯𝗲
    interval: 86400
  OpenAi:
    type: http
    behavior: classical
    format: text
    path: ./𝗢𝗽𝗲𝗻𝗔𝗜
    url: https://fbi.hk.dedyn.io/Emokui/Rule/𝗟𝗶𝘀𝘁/𝗢𝗽𝗲𝗻𝗔𝗜
    interval: 86400
rules:
  - RULE-SET,OpenAi,warp
  - RULE-SET,YouTube,warp
  - GEOIP,CN,warp
  - MATCH,DIRECT
```
#### 7.运行 mihomo ####
```
./mihomo -f /root/config.yaml
```
#### 8.停止 mihomo ####
```
pkill mihomo
```
#### 9.设置开机启动 ####
etc/systemd/system 下创建 `mihomo.service` 内容如下
```
[Unit]
Description=Clash Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/mihomo -f /root/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
#### 10.重新加载 systemd 管理器配置，并启用 mihomo 服务 ####
```
sudo systemctl daemon-reload
sudo systemctl enable --now mihomo.service
systemctl status mihomo.service
```
