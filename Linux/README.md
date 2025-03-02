# snell节点分流warp #
**解决垃圾IP不登陆无法观看YouTube,无法使用openai,及流媒体**

可根据自己需要解锁的平台，添加对应的分流规则



#### 1.配置 warp socks5 ####
运行脚本,选择13,默认端口40000
```
wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh [option] [lisence/url/token]
```


#### 2.配置 snell ####
无脑回车即可 (如需免流,则开启obfs,host填写伪装域名)
```
wget -O snell.sh --no-check-certificate https://git.io/Snell.sh && chmod +x snell.sh && ./snell.sh
```


#### 3.下载 mihomo ####


**不放心可去 mihomo仓库 https://github.com/MetaCubeX/mihomo 获取**
```
wget https://github.com/Emokui/Sukuna/raw/refs/heads/main/Linux/mihomo.gz
```
**系统兼容版**
```
wget https://github.com/Emokui/Sukuna/raw/refs/heads/main/Linux/mihomo-compatible.zip
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
allow-lan: false
mode: rule
log-level: info
ipv6: false
tcp-concurrent: true
external-controller: 127.0.0.1:9093
profile:
  store-selected: true
  store-fake-ip: true
sniffer:
  enable: true
  parse-pure-ip: true
tun:
  enable: true
  stack: gvisor
  dns-hijack:
     - 'any:53'
  strict_route: true
  auto-route: true
  auto-detect-interface: true

dns:
  enable: true
  ipv6: false
  default-nameserver:
      - 8.8.8.8
  nameserver:
      - 1.1.1.1
  enhanced-mode: redir-host
  listen: 0.0.0.0:53

proxies:
  - {"name":"socks","server":"127.0.0.1","port":40000,"udp":true,"ip-version":"v4-only","type":"socks5"}

rule-providers:
      
  YouTube:
      type: http
      behavior: classical
      format: text
      path: ./Rule/YouTube.list            
      url: https://raw.githubusercontent.com/Emokui/Sukuna/main/Rule/YouTube.list
      interval: 86400

  OpenAi:
      type: http
      behavior: classical
      format: yaml
      path: ./Rule/OpenAi.list
      url: https://raw.githubusercontent.com/Emokui/Sukuna/main/Rule/OpenAi.list
      interval: 86400

rules:
- RULE-SET,OpenAi,socks
- RULE-SET,YouTube,socks
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
