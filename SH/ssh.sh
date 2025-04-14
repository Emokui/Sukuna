#!/bin/bash

# ====== 色彩變量 ======
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

send_stats() {
    local action="$1"
    echo -e "${gl_hui}記錄操作: $action${gl_bai}" >&2
}

# ====== 系統更新 ======
linux_update() {
    send_stats "系統更新"
    echo -e "${gl_huang}正在更新系統...${gl_bai}"
    if command -v apt &>/dev/null; then
        apt update -y && apt upgrade -y
    elif command -v dnf &>/dev/null; then
        dnf update -y
    elif command -v yum &>/dev/null; then
        yum update -y
    elif command -v apk &>/dev/null; then
        apk update && apk upgrade
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        zypper refresh && zypper update -y
    else
        echo -e "${gl_hong}未知的包管理器!${gl_bai}"
    fi
    echo -e "${gl_lv}系統更新完成${gl_bai}"
}

# ====== 系統清理 ======
linux_clean() {
    send_stats "系統清理"
    echo -e "${gl_huang}正在清理系統垃圾...${gl_bai}"
    if command -v apt &>/dev/null; then
        apt autoremove -y && apt autoclean -y
    elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        yum autoremove -y && yum clean all -y
    elif command -v apk &>/dev/null; then
        apk cache clean
    elif command -v pacman &>/dev/null; then
        pacman -Rns $(pacman -Qtdq) --noconfirm
    elif command -v zypper &>/dev/null; then
        zypper clean
    else
        echo -e "${gl_hong}未知的包管理器!${gl_bai}"
    fi
    echo -e "${gl_lv}系統清理完成${gl_bai}"
}

# ====== 開啟 root 登錄 ======
enable_root_login() {
    echo "==== 開啟 root 登錄 ===="
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo "[✓] Root 登錄已開啟"
}

# ====== 修改 root 密碼 ======
change_root_password() {
    echo "==== 修改 root 密碼 ===="
    passwd root
}

# ====== 修改 SSH 端口 ======
change_ssh_port() {
    echo "==== 修改 SSH 端口 ===="
    read -rp "請輸入新的 SSH 端口: " new_port
    if [[ "$new_port" =~ ^[0-9]+$ ]]; then
        sed -i "s/^#Port .*/Port $new_port/" /etc/ssh/sshd_config
        sed -i "s/^Port .*/Port $new_port/" /etc/ssh/sshd_config
        systemctl restart sshd
        echo "[✓] SSH 端口已修改為 $new_port"
    else
        echo "[!] 無效的端口格式"
    fi
}

# ====== 更改時區 ======
change_timezone() {
    echo "==== 更改時區 ===="
    while true; do
        echo "請選擇大區："
        PS3="輸入數字選擇大區: "
        zones=("Asia" "Europe" "America" "Africa" "Australia" "Etc" "返回")
        select zone in "${zones[@]}"; do
            [[ "$zone" == "返回" ]] && return
            [[ -n "$zone" ]] && break
            echo "[!] 無效選項，請重新選擇"
        done

        options=($(timedatectl list-timezones | grep "^$zone/" | sort))
        echo "請選擇具體時區："
        PS3="輸入數字選擇城市時區: "
        select city in "${options[@]}" "返回"; do
            [[ "$city" == "返回" ]] && break
            [[ -n "$city" ]] && timedatectl set-timezone "$city" && echo "[✓] 時區已設為 $city" && return
            echo "[!] 無效選項，請重新選擇"
        done
    done
}

# ====== 防火牆設置 ======
configure_firewall() {
    echo "[*] 偵測並準備防火牆工具..."
    FIREWALL_TOOL=""
    
    # 检查iptables是否安装
    if ! command -v iptables &>/dev/null; then
        echo "[!] 未偵測到iptables，開始安裝..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y iptables
        elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
            yum install -y iptables iptables-services
            systemctl enable iptables
            systemctl start iptables
        fi
        echo "[✓] iptables 已安裝"
    else
        echo "[✓] iptables 已存在"
    fi
    
    if command -v ufw &>/dev/null; then
        FIREWALL_TOOL="ufw"
    elif command -v firewall-cmd &>/dev/null; then
        FIREWALL_TOOL="firewalld"
    else
        echo "[!] 未偵測到防火牆工具，開始自動安裝..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y ufw
            FIREWALL_TOOL="ufw"
        elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
            yum install -y firewalld
            systemctl enable firewalld --now
            FIREWALL_TOOL="firewalld"
        fi
    fi
    echo "[✓] 使用防火牆：$FIREWALL_TOOL"
    while true; do
        echo "請選擇防火牆操作："
        echo "1) 開啟端口"
        echo "2) 關閉端口"
        echo "3) 開啟全部端口" 
        echo "4) 關閉全部端口"
        echo "5) 顯示已開啟的端口"
        echo "6) 返回世界线"
        read -rp "請輸入選項 (1-6): " action_choice
        case "$action_choice" in
            1|2)
                read -rp "請輸入端口（如 22 443 或 1000-2000）: " input_ports
                for port_spec in $input_ports; do
                    # 处理端口范围
                    if [[ "$port_spec" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                        start_port=${BASH_REMATCH[1]}
                        end_port=${BASH_REMATCH[2]}
                        
                        # 验证端口范围
                        if [[ $start_port -lt 1 || $start_port -gt 65535 || $end_port -lt 1 || $end_port -gt 65535 ]]; then
                            echo "[!] 无效端口范围: $port_spec (端口必须在 1-65535 之间)"
                            continue
                        fi
                        
                        echo "[*] 处理端口范围: $port_spec (从 $start_port 到 $end_port)"
                        
                        # 使用iptables直接添加规则，无论使用什么防火墙工具
                        if [[ "$action_choice" == "1" ]]; then
                            echo "[*] 使用iptables直接添加端口范围..."
                            iptables -A INPUT -p tcp --match multiport --dports $start_port:$end_port -j ACCEPT
                            iptables -A INPUT -p udp --match multiport --dports $start_port:$end_port -j ACCEPT
                        else
                            echo "[*] 使用iptables直接阻止端口范围..."
                            iptables -A INPUT -p tcp --match multiport --dports $start_port:$end_port -j DROP
                            iptables -A INPUT -p udp --match multiport --dports $start_port:$end_port -j DROP
                        fi
                        
                        # 保存iptables规则以便持久化
                        echo "[*] 保存iptables规则..."
                        if command -v netfilter-persistent &>/dev/null; then
                            netfilter-persistent save
                        elif [[ -f /etc/debian_version ]]; then
                            if ! command -v netfilter-persistent &>/dev/null; then
                                echo "[*] 安装 iptables-persistent..."
                                DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
                            fi
                            netfilter-persistent save
                        elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
                            service iptables save
                        fi
                        
                        # 如果使用的是防火墙工具，也相应地添加规则
                        if [[ "$FIREWALL_TOOL" == "firewalld" ]]; then
                            if [[ "$action_choice" == "1" ]]; then
                                echo "[*] 使用firewalld rich rules添加端口范围..."
                                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$start_port-$end_port' protocol='tcp' accept"
                                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$start_port-$end_port' protocol='udp' accept"
                            else
                                echo "[*] 使用firewalld rich rules阻止端口范围..."
                                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$start_port-$end_port' protocol='tcp' reject"
                                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$start_port-$end_port' protocol='udp' reject"
                            fi
                        fi
                    else
                        # 处理单个端口
                        if [[ ! "$port_spec" =~ ^[0-9]+$ || $port_spec -lt 1 || $port_spec -gt 65535 ]]; then
                            echo "[!] 无效端口: $port_spec (端口必须在 1-65535 之间)"
                            continue
                        fi
                        
                        if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
                            if [[ "$action_choice" == "1" ]]; then
                                ufw allow "$port_spec/tcp"
                                ufw allow "$port_spec/udp"
                            else
                                ufw deny "$port_spec/tcp"
                                ufw deny "$port_spec/udp"
                            fi
                        elif [[ "$FIREWALL_TOOL" == "firewalld" ]]; then
                            if [[ "$action_choice" == "1" ]]; then
                                firewall-cmd --permanent --add-port="$port_spec/tcp"
                                firewall-cmd --permanent --add-port="$port_spec/udp"
                            else
                                firewall-cmd --permanent --remove-port="$port_spec/tcp"
                                firewall-cmd --permanent --remove-port="$port_spec/udp"
                            fi
                        fi
                    fi
                done
                
                # 应用防火墙规则
                if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
                    ufw --force enable
                elif [[ "$FIREWALL_TOOL" == "firewalld" ]]; then
                    firewall-cmd --reload
                fi
                ;;
            3)
                echo "[*] 正在开启所有端口..."
                # 使用iptables直接开启所有端口
                iptables -P INPUT ACCEPT
                iptables -P FORWARD ACCEPT
                iptables -P OUTPUT ACCEPT
                iptables -F
                
                # 保存iptables规则
                if command -v netfilter-persistent &>/dev/null; then
                    netfilter-persistent save
                elif [[ -f /etc/debian_version ]]; then
                    if ! command -v netfilter-persistent &>/dev/null; then
                        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
                    fi
                    netfilter-persistent save
                elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
                    service iptables save
                fi
                
                # 同时配置防火墙工具
                [[ "$FIREWALL_TOOL" == "ufw" ]] && ufw default allow && ufw --force enable
                [[ "$FIREWALL_TOOL" == "firewalld" ]] && firewall-cmd --set-default-zone=trusted && firewall-cmd --reload
                ;;
            4)
                echo "[*] 正在关闭所有端口..."
                # 先关闭所有端口，但保留SSH (22)端口，防止被锁在系统外
                iptables -P INPUT DROP
                iptables -P FORWARD DROP
                iptables -F
                iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                iptables -A INPUT -i lo -j ACCEPT
                iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                
                # 保存iptables规则
                if command -v netfilter-persistent &>/dev/null; then
                    netfilter-persistent save
                elif [[ -f /etc/debian_version ]]; then
                    if ! command -v netfilter-persistent &>/dev/null; then
                        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
                    fi
                    netfilter-persistent save
                elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
                    service iptables save
                fi
                
                # 同时配置防火墙工具
                [[ "$FIREWALL_TOOL" == "ufw" ]] && ufw default deny && ufw allow 22/tcp && ufw --force enable
                [[ "$FIREWALL_TOOL" == "firewalld" ]] && firewall-cmd --set-default-zone=drop && firewall-cmd --add-port=22/tcp --permanent && firewall-cmd --reload
                ;;
            5)
                echo "[*] 显示已开启的端口..."
                echo "=== iptables开放的端口 ==="
                # 安装netstat工具（如果不存在）
                if ! command -v netstat &>/dev/null; then
                    echo "[*] 安装netstat工具..."
                    if [[ -f /etc/debian_version ]]; then
                        apt update && apt install -y net-tools
                    elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
                        yum install -y net-tools
                    fi
                fi
                
                # 使用netstat查看监听端口
                echo "系统正在监听的端口:"
                netstat -tuln | grep LISTEN
                
                # 显示iptables INPUT链中允许的端口
                echo -e "\niptables允许的端口:"
                iptables -L INPUT -n -v | grep -i accept
                
                # 根据防火墙工具显示更多信息
                if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
                    echo -e "\nUFW防火墙状态:"
                    ufw status verbose
                elif [[ "$FIREWALL_TOOL" == "firewalld" ]]; then
                    echo -e "\nFirewallD防火墙状态:"
                    firewall-cmd --list-all
                    echo -e "\n开放的端口范围:"
                    firewall-cmd --list-rich-rules | grep port
                fi
                
                # 如果安装了ss工具，也使用它来显示开放端口
                if command -v ss &>/dev/null; then
                    echo -e "\n使用ss工具显示开放端口:"
                    ss -tuln
                fi
                
                # 检查一些常见服务使用的端口
                echo -e "\n检查一些常见服务端口状态:"
                for common_port in 22 80 443 3306 8080 21 25 110 143 587 993 995 1433 3389 5432 6379 27017; do
                    # 使用nmap如果可用
                    if command -v nmap &>/dev/null; then
                        nmap -p $common_port localhost | grep $common_port
                    else
                        # 否则使用netcat或telnet
                        if command -v nc &>/dev/null; then
                            nc -zv 127.0.0.1 $common_port -w 1 >/dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                echo "端口 $common_port 开放"
                            fi
                        elif command -v telnet &>/dev/null; then
                            timeout 1 telnet 127.0.0.1 $common_port >/dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                echo "端口 $common_port 开放"
                            fi
                        fi
                    fi
                done
                ;;
            6) break ;;
            *) echo "[!] 無效選項，請重新選擇" ;;
        esac
    done
}

# ====== BBR 管理 ======
bbr_menu() {
    bash <(wget -O - https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh)
}

# ====== WARP 管理 ======
warp_menu() {
    bash <(wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh)
}

# ====== 重啟系統 ======
reboot_vps() {
    echo "即將重啟系統..."
    reboot
}

# ====== 安裝 wget unzip ======
install_base_tools() {
    if command -v apt &>/dev/null; then
        apt update && apt install -y wget unzip
    elif command -v yum &>/dev/null; then
        yum install -y wget unzip
    elif command -v apk &>/dev/null; then
        apk add wget unzip
    else
        echo "[!] 無法識別的系統"
    fi
}

# ====== 其他快速安裝 ======
install_snell() {
    bash <(curl -sL https://raw.githubusercontent.com/xOS/Snell/master/Snell.sh)
}
install_trojan() {
    bash <(curl -sL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/SH/trojan.sh)
}
install_hysteria() {
    bash <(curl -sL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/SH/hysteria.sh)
}
install_acme() {
    bash <(curl -sL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/SH/acme.sh)
}
install_mihomo() {
    bash <(curl -sL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/SH/mihomo.sh)
}
install_substore() {
    bash <(curl -fsSL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/SH/substore.sh)
}
install_install() {
    bash <(curl -sL https://raw.githubusercontent.com/chiakge/installNET/master/Install.sh)
}

# ====== DNS 配置工具 ======
# 檢測系統使用的網絡管理工具
detect_network_manager() {
    if command -v systemctl > /dev/null && systemctl is-active --quiet systemd-resolved; then
        echo "systemd-resolved"
    elif command -v nmcli > /dev/null; then
        echo "NetworkManager"
    elif [ -f "/etc/netplan" ] || [ -d "/etc/netplan" ]; then
        echo "netplan"
    else
        echo "traditional"
    fi
}

# 顯示當前DNS配置
show_current_dns() {
    echo -e "${gl_huang}當前DNS配置:${gl_bai}"
    echo "================="
    cat /etc/resolv.conf | grep "nameserver" || echo "未找到DNS配置"
    echo "================="
    
    # 顯示持久化配置信息（如果存在）
    network_manager=$(detect_network_manager)
    case $network_manager in
        "NetworkManager")
            echo -e "${gl_huang}NetworkManager配置:${gl_bai}"
            nmcli dev show | grep DNS || echo "未找到NetworkManager DNS配置"
            ;;
        "systemd-resolved")
            echo -e "${gl_huang}systemd-resolved配置:${gl_bai}"
            resolvectl status | grep "DNS Servers" || echo "未找到systemd-resolved DNS配置"
            ;;
    esac
}

# 持久化設置DNS
persistent_set_dns() {
    local primary_dns=$1
    local secondary_dns=$2
    
    network_manager=$(detect_network_manager)
    case $network_manager in
        "NetworkManager")
            echo -e "${gl_huang}使用NetworkManager持久化DNS配置...${gl_bai}"
            # 獲取當前活動連接
            CONNECTION=$(nmcli -t -f NAME c show --active | head -n1)
            if [ -z "$CONNECTION" ]; then
                echo -e "${gl_hong}錯誤: 未找到活動的網絡連接${gl_bai}"
                return 1
            fi
            
            # 設置DNS
            if [ -z "$secondary_dns" ]; then
                nmcli con mod "$CONNECTION" ipv4.dns "$primary_dns"
            else
                nmcli con mod "$CONNECTION" ipv4.dns "$primary_dns,$secondary_dns"
            fi
            
            # 確保NetworkManager不會覆蓋resolv.conf
            nmcli con mod "$CONNECTION" ipv4.ignore-auto-dns yes
            
            # 重新應用配置
            nmcli con up "$CONNECTION"
            ;;
            
        "systemd-resolved")
            echo -e "${gl_huang}使用systemd-resolved持久化DNS配置...${gl_bai}"
            # 獲取主要網絡接口
            INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
            if [ -z "$INTERFACE" ]; then
                echo -e "${gl_hong}錯誤: 未找到默認網絡接口${gl_bai}"
                return 1
            fi
            
            # 設置DNS
            if [ -z "$secondary_dns" ]; then
                resolvectl dns "$INTERFACE" "$primary_dns"
            else
                resolvectl dns "$INTERFACE" "$primary_dns" "$secondary_dns"
            fi
            ;;
            
        "netplan")
            echo -e "${gl_huang}使用netplan持久化DNS配置...${gl_bai}"
            # 找到主要的netplan配置文件
            NETPLAN_FILE=$(find /etc/netplan -name "*.yaml" | head -n1)
            if [ -z "$NETPLAN_FILE" ]; then
                echo -e "${gl_hong}錯誤: 未找到netplan配置文件${gl_bai}"
                return 1
            fi
            
            # 創建備份
            cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
            
            # 檢查文件中是否已經有nameservers配置
            if grep -q "nameservers:" "$NETPLAN_FILE"; then
                # 已存在nameservers配置，更新它
                sed -i '/nameservers:/,/addresses:/c\      nameservers:\n        addresses: ['"$primary_dns"']' "$NETPLAN_FILE"
            else
                # 不存在nameservers配置，添加它到第一個網絡接口
                sed -i '/dhcp4: true/a\      nameservers:\n        addresses: ['"$primary_dns"']' "$NETPLAN_FILE"
            fi
            
            # 如果有次要DNS，添加它
            if [ ! -z "$secondary_dns" ]; then
                sed -i '/addresses: \[/s/\[.*\]/\['"$primary_dns"', '"$secondary_dns"'\]/' "$NETPLAN_FILE"
            fi
            
            # 應用netplan配置
            netplan apply
            ;;
            
        *)
            echo -e "${gl_huang}使用傳統方法持久化DNS配置...${gl_bai}"
            # 創建備份
            cp /etc/resolv.conf /etc/resolv.conf.bak
            
            # 確保resolv.conf不會被其他進程修改
            chattr -i /etc/resolv.conf 2>/dev/null || true
            
            # 設置DNS
            echo "nameserver $primary_dns" > /etc/resolv.conf
            if [ ! -z "$secondary_dns" ]; then
                echo "nameserver $secondary_dns" >> /etc/resolv.conf
            fi
            
            # 保護文件不被修改（如果支持）
            chattr +i /etc/resolv.conf 2>/dev/null || true
            ;;
    esac
    
    # 更新當前resolv.conf（以防萬一）
    echo "nameserver $primary_dns" > /etc/resolv.conf
    if [ ! -z "$secondary_dns" ]; then
        echo "nameserver $secondary_dns" >> /etc/resolv.conf
    fi
    
    echo -e "${gl_lv}DNS設置已更新並已持久化${gl_bai}"
}

# 修改DNS為預設值(Google DNS 8.8.8.8和Cloudflare DNS 1.1.1.1)
set_predefined_dns() {
    echo -e "${gl_huang}正在設置DNS為 8.8.8.8 和 1.1.1.1...${gl_bai}"
    persistent_set_dns "8.8.8.8" "1.1.1.1"
}

# 手動設置DNS
set_manual_dns() {
    echo -e "${gl_huang}請輸入主要DNS服務器:${gl_bai}"
    read primary_dns
    echo -e "${gl_huang}請輸入次要DNS服務器(可選，直接按回車跳過):${gl_bai}"
    read secondary_dns
    
    if [ -z "$primary_dns" ]; then
        echo -e "${gl_hong}錯誤: 主要DNS服務器不能為空${gl_bai}"
        return
    fi
    
    echo -e "${gl_huang}正在設置DNS為 $primary_dns 和 $secondary_dns...${gl_bai}"
    persistent_set_dns "$primary_dns" "$secondary_dns"
}

# DNS配置工具主菜單
dns_config_menu() {
    while true; do
        clear
        echo -e "${gl_kjlan}DNS配置工具${gl_bai}"
        echo "================="
        
        show_current_dns
        
        echo -e "${gl_huang}請選擇操作:${gl_bai}"
        echo "1. 修改DNS為8.8.8.8和1.1.1.1"
        echo "2. 手動修改DNS"
        echo "0. 返回世界线"
        echo "================="
        echo -e "${gl_huang}請輸入選項(0-2):${gl_bai}"
        read option
        
        case $option in
            1)
                set_predefined_dns
                ;;
            2)
                set_manual_dns
                ;;
            0)
                return
                ;;
            *)
                echo -e "${gl_hong}無效選項，請重試${gl_bai}"
                sleep 2
                ;;
        esac
        
        echo ""
        echo -e "${gl_huang}按任意鍵繼續...${gl_bai}"
        read -n 1
    done
}

# ====== 主選單 ======
main_menu() {
    while true; do
        echo
        echo -e "${gl_kjlan}==== Steins Gate - 鳳凰院凶真 Ver.1.0 ==== ${gl_bai}"
        echo " 01. 系統更新"
        echo " 02. 系統清理"
        echo " 03. 開啟 root 登錄"
        echo " 04. 修改 root 密碼"
        echo " 05. 修改 SSH 端口"
        echo " 06. 更改時區"
        echo " 07. 設定防火牆"
        echo " 08. 配置 DNS"
        echo " 09. 管理 BBR"
        echo " 10. 管理 WARP"
        echo " 11. 重啟 VPS"
        echo " 12. 安裝 wget/unzip"
        echo " 13. 安裝 Acme"
        echo " 14. 安裝 Snell"
        echo " 15. 安裝 Mihomo"
        echo " 16. 安裝 Trojan"
        echo " 17. 安裝 Hysteria"
        echo " 18. 安裝 SubStore"
        echo " 19. 一键 DDSystem"
        echo "  0. 離開 El Psy Kongroo"
        read -rp "請選擇操作: " choice
        case "$choice" in
            1) linux_update ;;
            2) linux_clean ;;
            3) enable_root_login ;;
            4) change_root_password ;;
            5) change_ssh_port ;;
            6) change_timezone ;;
            7) configure_firewall ;;
            8) dns_config_menu ;;
            9) bbr_menu ;;
            10) warp_menu ;;
            11) reboot_vps ;;
            12) install_base_tools ;;
            13) install_acme ;;
            14) install_snell ;;
            15) install_mihomo ;;
            16) install_trojan ;;
            17) install_hysteria ;;
            18) install_substore ;;
            19) install_install ;;
            0) echo -e "${gl_zi}「運命石之扉の選択,El Psy Kongroo」${gl_bai}" && break ;;
            *) echo "[!] 無效選項，請重新選擇" ;;
        esac
    done
}

main_menu
