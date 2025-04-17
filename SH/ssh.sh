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
    echo -e "${gl_hui}执行选项: $action${gl_bai}" >&2
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
    # 定义颜色变量
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    BOLD='\033[1m'
    
    important_messages=""
    
    while true; do
        clear
        if [[ -n "$important_messages" ]]; then
            echo -e "${important_messages}"
            echo -e "------------------------------------------------\n"
        fi
        
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        echo -e "${BOLD}${CYAN}             更改時區設置                ${NC}"
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        
        echo -e "${CYAN}目前時區: ${YELLOW}$(timedatectl | grep "Time zone" | awk '{print $3}')${NC}"
        echo -e "${CYAN}請選擇大區：${NC}"
        
        zones=("Asia" "Europe" "America" "Africa" "Australia" "Etc" "返回")
        
        for i in "${!zones[@]}"; do
            if [[ "${zones[$i]}" == "返回" ]]; then
                echo -e "${YELLOW}$((i+1)). ${zones[$i]}${NC}"
            else
                echo -e "${GREEN}$((i+1)). ${zones[$i]}${NC}"
            fi
        done
        
        read -rp "$(echo -e ${CYAN}"輸入數字選擇大區 (1-${#zones[@]}): "${NC})" zone_choice
        
        if ! [[ "$zone_choice" =~ ^[0-9]+$ ]] || [ "$zone_choice" -lt 1 ] || [ "$zone_choice" -gt ${#zones[@]} ]; then
            message="${RED}[!] 無效選項，請重新選擇${NC}"
            echo -e "$message"
            important_messages="$message"
            sleep 1
            continue
        fi
        
        zone="${zones[$((zone_choice-1))]}"
        
        if [[ "$zone" == "返回" ]]; then
            echo -e "${YELLOW}[*] 返回主菜單...${NC}"
            return
        fi
        
        options=($(timedatectl list-timezones | grep "^$zone/" | sort))
        
        options+=("返回")
        
        clear
        if [[ -n "$important_messages" ]]; then
            echo -e "${important_messages}"
            echo -e "------------------------------------------------\n"
        fi
        
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        echo -e "${BOLD}${CYAN}          選擇 ${zone} 內的時區                ${NC}"
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        
        total_options=${#options[@]}
        page_size=15
        total_pages=$(( (total_options + page_size - 1) / page_size ))
        current_page=1
        
        while true; do
            clear
            if [[ -n "$important_messages" ]]; then
                echo -e "${important_messages}"
                echo -e "------------------------------------------------\n"
            fi
            
            echo -e "${BOLD}${PURPLE}===============================================${NC}"
            echo -e "${BOLD}${CYAN}          選擇 ${zone} 內的時區                ${NC}"
            echo -e "${BOLD}${PURPLE}===============================================${NC}"
            echo -e "${BLUE}第 ${current_page}/${total_pages} 頁 (共 ${total_options} 個時區)${NC}"
            
            start_idx=$(( (current_page - 1) * page_size ))
            end_idx=$(( start_idx + page_size - 1 ))
            
            if (( end_idx >= total_options )); then
                end_idx=$(( total_options - 1 ))
            fi
            
            for i in $(seq $start_idx $end_idx); do
                option_num=$(( i + 1 ))
                if [[ "${options[$i]}" == "返回" ]]; then
                    echo -e "${YELLOW}$option_num. ${options[$i]}${NC}"
                else
                    echo -e "${GREEN}$option_num. ${options[$i]}${NC}"
                fi
            done
            
            echo -e "${PURPLE}===============================================${NC}"
            echo -e "${CYAN}导航控制: ${YELLOW}n${NC} - 下一页 ${YELLOW}p${NC} - 上一页 ${YELLOW}q${NC} - 返回大区选择${NC}"
            
            read -rp "$(echo -e ${CYAN}"輸入數字選擇時區或導航指令: "${NC})" city_choice
            
            if [[ "$city_choice" == "n" ]]; then
                if (( current_page < total_pages )); then
                    current_page=$(( current_page + 1 ))
                else
                    echo -e "${YELLOW}[!] 已經是最後一頁${NC}"
                    sleep 1
                fi
                continue
            elif [[ "$city_choice" == "p" ]]; then
                if (( current_page > 1 )); then
                    current_page=$(( current_page - 1 ))
                else
                    echo -e "${YELLOW}[!] 已經是第一頁${NC}"
                    sleep 1
                fi
                continue
            elif [[ "$city_choice" == "q" ]]; then
                break
            fi
            
            if ! [[ "$city_choice" =~ ^[0-9]+$ ]] || [ "$city_choice" -lt 1 ] || [ "$city_choice" -gt ${#options[@]} ]; then
                message="${RED}[!] 無效選項，請重新選擇${NC}"
                echo -e "$message"
                important_messages="$message"
                sleep 1
                continue
            fi
            
            city="${options[$((city_choice-1))]}"
            
            if [[ "$city" == "返回" ]]; then
                break
            fi
            
            echo -e "${BLUE}[*] 正在設置時區為 ${city}...${NC}"
            if timedatectl set-timezone "$city"; then
                message="${GREEN}[✓] 時區已成功設為 ${BOLD}${city}${NC}"
                echo -e "$message"
                important_messages="$message"
                
                current_time=$(date "+%Y-%m-%d %H:%M:%S")
                echo -e "${BLUE}[i] 當前時間: ${YELLOW}${current_time}${NC}"
                important_messages+="\n${BLUE}[i] 當前時間: ${YELLOW}${current_time}${NC}"
                
                echo -e "\n${CYAN}按任意键返回主菜单...${NC}"
                read -n 1 -s
                return
            else
                message="${RED}[!] 設置時區失敗，請重試${NC}"
                echo -e "$message"
                important_messages="$message"
                sleep 2
            fi
        done
    done
}

# ====== 防火牆設置 ======
configure_firewall() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    BOLD='\033[1m'
    
    echo -e "${BLUE}[*] 检查 iptables 是否安装...${NC}"
    
    if ! command -v iptables &>/dev/null; then
        echo -e "${YELLOW}[!] 未检测到 iptables，开始安装...${NC}"
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y iptables iptables-persistent
        elif [[ -f /etc/centos-release || -f /etc/redhat-release ]]; then
            yum install -y iptables iptables-services
            systemctl enable iptables
            systemctl start iptables
        fi
        echo -e "${GREEN}[✓] iptables 已安装${NC}"
    else
        echo -e "${GREEN}[✓] iptables 已存在${NC}"
    fi
    
    if [[ -f /etc/debian_version ]] && ! command -v netfilter-persistent &>/dev/null; then
        echo -e "${BLUE}[*] 安装 iptables-persistent...${NC}"
        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
    fi
    
    ensure_ssh_access() {
        if ! iptables -L INPUT -n | grep -q "dport 22"; then
            echo -e "${BLUE}[*] 确保 SSH 端口 (22) 永久开放...${NC}"
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            save_rules
        fi
    }
    
    save_rules() {
        echo -e "${BLUE}[*] 保存 iptables 规则...${NC}"
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
    }
    
    ensure_ssh_access
    
    important_messages=""
    
    while true; do
        clear
        if [[ -n "$important_messages" ]]; then
            echo -e "${important_messages}"
            echo -e "------------------------------------------------\n"
        fi
        
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        echo -e "${BOLD}${CYAN}            iptables 防火墙管理                ${NC}"
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        echo -e "${CYAN}请选择防火墙操作：${NC}"
        echo -e "${GREEN}1. 开启端口${NC}"
        echo -e "${RED}2. 关闭端口${NC}"
        echo -e "${GREEN}3. 开启全部端口${NC}" 
        echo -e "${RED}4. 关闭全部端口 (保留 SSH)${NC}"
        echo -e "${BLUE}5. 显示已开启的端口${NC}"
        echo -e "${YELLOW}0. 返回主菜单${NC}"
        echo -e "${BOLD}${PURPLE}===============================================${NC}"
        read -rp "$(echo -e ${CYAN}"请输入选项 (0-5): "${NC})" action_choice
        
        important_messages=""
        
        case "$action_choice" in
            1|2)
                read -rp "$(echo -e ${CYAN}"请输入端口（如 22 443 或 1000-2000）: "${NC})" input_ports
                for port_spec in $input_ports; do
                    if [[ "$port_spec" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                        start_port=${BASH_REMATCH[1]}
                        end_port=${BASH_REMATCH[2]}
                        
                        if [[ $start_port -lt 1 || $start_port -gt 65535 || $end_port -lt 1 || $end_port -gt 65535 ]]; then
                            message="${RED}[!] 无效端口范围: $port_spec (端口必须在 1-65535 之间)${NC}"
                            echo -e "$message"
                            important_messages+="$message\n"
                            continue
                        fi
                        
                        echo -e "${BLUE}[*] 处理端口范围: $port_spec (从 $start_port 到 $end_port)${NC}"
                        
                        iptables -D INPUT -p tcp --match multiport --dports $start_port:$end_port -j ACCEPT 2>/dev/null
                        iptables -D INPUT -p udp --match multiport --dports $start_port:$end_port -j ACCEPT 2>/dev/null
                        iptables -D INPUT -p tcp --match multiport --dports $start_port:$end_port -j DROP 2>/dev/null
                        iptables -D INPUT -p udp --match multiport --dports $start_port:$end_port -j DROP 2>/dev/null
                        
                        if [[ "$action_choice" == "1" ]]; then
                            echo -e "${BLUE}[*] 开启端口范围...${NC}"
                            iptables -A INPUT -p tcp --match multiport --dports $start_port:$end_port -j ACCEPT
                            iptables -A INPUT -p udp --match multiport --dports $start_port:$end_port -j ACCEPT
                            important_messages+="${GREEN}[✓] 端口范围 $port_spec 已开启${NC}\n"
                        else
                            echo -e "${BLUE}[*] 关闭端口范围...${NC}"
                            iptables -A INPUT -p tcp --match multiport --dports $start_port:$end_port -j DROP
                            iptables -A INPUT -p udp --match multiport --dports $start_port:$end_port -j DROP
                            important_messages+="${RED}[✓] 端口范围 $port_spec 已关闭${NC}\n"
                        fi
                    else
                        if [[ ! "$port_spec" =~ ^[0-9]+$ || $port_spec -lt 1 || $port_spec -gt 65535 ]]; then
                            message="${RED}[!] 无效端口: $port_spec (端口必须在 1-65535 之间)${NC}"
                            echo -e "$message"
                            important_messages+="$message\n"
                            continue
                        fi
                        
                        if [[ "$port_spec" == "22" && "$action_choice" == "2" ]]; then
                            message="${YELLOW}[!] 警告: 不允许关闭 SSH 端口 (22)，跳过${NC}"
                            echo -e "$message"
                            important_messages+="$message\n"
                            continue
                        fi
                        
                        iptables -D INPUT -p tcp --dport $port_spec -j ACCEPT 2>/dev/null
                        iptables -D INPUT -p udp --dport $port_spec -j ACCEPT 2>/dev/null
                        iptables -D INPUT -p tcp --dport $port_spec -j DROP 2>/dev/null
                        iptables -D INPUT -p udp --dport $port_spec -j DROP 2>/dev/null
                        
                        if [[ "$action_choice" == "1" ]]; then
                            echo -e "${BLUE}[*] 开启端口: $port_spec${NC}"
                            iptables -A INPUT -p tcp --dport $port_spec -j ACCEPT
                            iptables -A INPUT -p udp --dport $port_spec -j ACCEPT
                            important_messages+="${GREEN}[✓] 端口 $port_spec 已开启${NC}\n"
                        else
                            echo -e "${BLUE}[*] 关闭端口: $port_spec${NC}"
                            iptables -A INPUT -p tcp --dport $port_spec -j DROP
                            iptables -A INPUT -p udp --dport $port_spec -j DROP
                            important_messages+="${RED}[✓] 端口 $port_spec 已关闭${NC}\n"
                        fi
                    fi
                done
                
                save_rules
                message="${GREEN}[✓] 端口规则已应用并保存${NC}"
                echo -e "$message"
                important_messages+="$message\n"
                ;;
            3)
                echo -e "${BLUE}[*] 正在开启所有端口...${NC}"
                iptables -F
                iptables -P INPUT ACCEPT
                iptables -P FORWARD ACCEPT
                iptables -P OUTPUT ACCEPT
                
                save_rules
                message="${GREEN}[✓] 所有端口已开启${NC}"
                echo -e "$message"
                important_messages+="$message\n"
                ;;
            4)
                echo -e "${BLUE}[*] 正在关闭所有端口 (保留 SSH)...${NC}"
                iptables -F
                
                iptables -P INPUT DROP          
                iptables -P FORWARD DROP        
                iptables -P OUTPUT ACCEPT       
                
                iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                
                iptables -A INPUT -i lo -j ACCEPT
                
                iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                
                save_rules
                message="${RED}[✓] 所有端口已关闭 (SSH 端口除外)${NC}"
                echo -e "$message"
                important_messages+="$message\n"
                ;;
            5)
                echo -e "${BOLD}${PURPLE}===============================================${NC}"
                echo -e "${BOLD}${CYAN}           iptables 防火墙规则                 ${NC}"
                echo -e "${BOLD}${PURPLE}===============================================${NC}"
                iptables_output=$(iptables -L INPUT -n -v)
                echo -e "${BLUE}$iptables_output${NC}"
                
                ;;
            0) 
                echo -e "${YELLOW}[*] 返回主菜单...${NC}"
                return 
                ;;
            *) 
                message="${RED}[!] 无效选项，请重新选择${NC}"
                echo -e "$message"
                important_messages+="$message\n"
                ;;
        esac
        
        echo -e "\n${CYAN}按任意键继续...${NC}"
        read -n 1 -s
    done
}

# ====== BBR 管理 ======
bbr_menu() {
    bash <(wget -O - https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh)
}

# ====== WARP 管理 ======
warp_menu() {
    bash <(curl -sL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh)
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
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/snell.sh)
}
install_snell-pro() {
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/snell-pro.sh)
}
install_trojan() {
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/trojan.sh)
}
install_hysteria() {
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/hysteria.sh)
}
install_acme() {
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/acme.sh)
}
install_mihomo() {
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/mihomo.sh)
}
install_substore() {
    bash <(curl -fsSL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/substore.sh)
}
install_install() {
    bash <(curl -sL https://raw.githubusercontent.com/chiakge/installNET/master/Install.sh)
}
install_nginx() {
    bash <(curl -sL https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/nginx.sh)
}

# ====== DNS 配置工具 ======
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

show_current_dns() {
    echo -e "${gl_huang}當前DNS配置:${gl_bai}"
    echo "================="
    cat /etc/resolv.conf | grep "nameserver" || echo "未找到DNS配置"
    echo "================="
    
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

persistent_set_dns() {
    local primary_dns=$1
    local secondary_dns=$2
    
    network_manager=$(detect_network_manager)
    case $network_manager in
        "NetworkManager")
            echo -e "${gl_huang}使用NetworkManager持久化DNS配置...${gl_bai}"
            CONNECTION=$(nmcli -t -f NAME c show --active | head -n1)
            if [ -z "$CONNECTION" ]; then
                echo -e "${gl_hong}錯誤: 未找到活動的網絡連接${gl_bai}"
                return 1
            fi
            
            if [ -z "$secondary_dns" ]; then
                nmcli con mod "$CONNECTION" ipv4.dns "$primary_dns"
            else
                nmcli con mod "$CONNECTION" ipv4.dns "$primary_dns,$secondary_dns"
            fi
            
            nmcli con mod "$CONNECTION" ipv4.ignore-auto-dns yes
            
            nmcli con up "$CONNECTION"
            ;;
            
        "systemd-resolved")
            echo -e "${gl_huang}使用systemd-resolved持久化DNS配置...${gl_bai}"
            INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
            if [ -z "$INTERFACE" ]; then
                echo -e "${gl_hong}錯誤: 未找到默認網絡接口${gl_bai}"
                return 1
            fi
            
            if [ -z "$secondary_dns" ]; then
                resolvectl dns "$INTERFACE" "$primary_dns"
            else
                resolvectl dns "$INTERFACE" "$primary_dns" "$secondary_dns"
            fi
            ;;
            
        "netplan")
            echo -e "${gl_huang}使用netplan持久化DNS配置...${gl_bai}"
            NETPLAN_FILE=$(find /etc/netplan -name "*.yaml" | head -n1)
            if [ -z "$NETPLAN_FILE" ]; then
                echo -e "${gl_hong}錯誤: 未找到netplan配置文件${gl_bai}"
                return 1
            fi
            
            cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
            
            if grep -q "nameservers:" "$NETPLAN_FILE"; then
                sed -i '/nameservers:/,/addresses:/c\      nameservers:\n        addresses: ['"$primary_dns"']' "$NETPLAN_FILE"
            else
                sed -i '/dhcp4: true/a\      nameservers:\n        addresses: ['"$primary_dns"']' "$NETPLAN_FILE"
            fi
            
            if [ ! -z "$secondary_dns" ]; then
                sed -i '/addresses: \[/s/\[.*\]/\['"$primary_dns"', '"$secondary_dns"'\]/' "$NETPLAN_FILE"
            fi
            
            netplan apply
            ;;
            
        *)
            echo -e "${gl_huang}使用傳統方法持久化DNS配置...${gl_bai}"
            cp /etc/resolv.conf /etc/resolv.conf.bak
            
            chattr -i /etc/resolv.conf 2>/dev/null || true
            
            echo "nameserver $primary_dns" > /etc/resolv.conf
            if [ ! -z "$secondary_dns" ]; then
                echo "nameserver $secondary_dns" >> /etc/resolv.conf
            fi
            
            chattr +i /etc/resolv.conf 2>/dev/null || true
            ;;
    esac
    
    echo "nameserver $primary_dns" > /etc/resolv.conf
    if [ ! -z "$secondary_dns" ]; then
        echo "nameserver $secondary_dns" >> /etc/resolv.conf
    fi
    
    echo -e "${gl_lv}DNS設置已更新並已持久化${gl_bai}"
}

set_predefined_dns() {
    echo -e "${gl_huang}正在設置DNS為 8.8.8.8 和 1.1.1.1...${gl_bai}"
    persistent_set_dns "8.8.8.8" "1.1.1.1"
}

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

        clear
        
        echo
        echo -e "${gl_kjlan}==== Steins Gate - 鳳凰院凶真 Ver.1.0 ==== ${gl_bai}"
        echo -e "${gl_lv}01.${gl_bai} 系統更新"
        echo -e "${gl_lv}02.${gl_bai} 系統清理"
        echo -e "${gl_lv}03.${gl_bai} 開啟 root 登錄"
        echo -e "${gl_lv}04.${gl_bai} 修改 root 密碼"
        echo -e "${gl_lv}05.${gl_bai} 修改 SSH 端口"
        echo -e "${gl_lv}06.${gl_bai} 更改時區"
        echo -e "${gl_lv}07.${gl_bai} 設定防火牆"
        echo -e "${gl_lv}08.${gl_bai} 配置 DNS"
        echo -e "${gl_lv}09.${gl_bai} 管理 BBR"
        echo -e "${gl_lv}10.${gl_bai} 管理 WARP"
        echo -e "${gl_lv}11.${gl_bai} 重啟 VPS"
        echo -e "${gl_lv}12.${gl_bai} 安裝 wget/unzip"
        echo -e "${gl_lv}13.${gl_bai} 安裝 Acme"
        echo -e "${gl_lv}14.${gl_bai} 安裝 Snell"
        echo -e "${gl_lv}15.${gl_bai} 安裝 Mihomo"
        echo -e "${gl_lv}16.${gl_bai} 安裝 Trojan"
        echo -e "${gl_lv}17.${gl_bai} 安裝 Hysteria"
        echo -e "${gl_lv}18.${gl_bai} 安裝 SubStore"
        echo -e "${gl_lv}19.${gl_bai} 一键 DDSystem"
        echo -e "${gl_lv}20.${gl_bai} 反代 Nginx"
        echo -e "${gl_lv}21.${gl_bai} 超级 Snell"
        echo -e "${gl_lv} 0.${gl_bai} 離開 El Psy Kongroo"
        
        read -rp "請選擇操作: " choice
        case "$choice" in
            1) 
                clear
                linux_update 
                ;;
            2) 
                clear
                linux_clean 
                ;;
            3) 
                clear
                enable_root_login 
                ;;
            4) 
                clear
                change_root_password 
                ;;
            5) 
                clear
                change_ssh_port 
                ;;
            6) 
                clear
                change_timezone 
                ;;
            7) 
                clear
                configure_firewall 
                ;;
            8) 
                clear
                dns_config_menu 
                ;;
            9) 
                clear
                bbr_menu 
                ;;
            10) 
                clear
                warp_menu 
                ;;
            11) 
                echo "系統將在 3 秒後重新啟動..."
                sleep 3
                reboot_vps 
                ;;
            12) 
                clear
                install_base_tools 
                ;;
            13) 
                clear
                install_acme 
                ;;
            14) 
                clear
                install_snell 
                ;;
            15) 
                clear
                install_mihomo 
                ;;
            16) 
                clear
                install_trojan 
                ;;
            17) 
                clear
                install_hysteria 
                ;;
            18) 
                clear
                install_substore 
                ;;
            19) 
                clear
                install_install 
                ;;
            20) 
                clear
                install_nginx 
                ;;
            21) 
                clear
                install_snell-pro 
                ;;
            0) 
                clear
                echo -e "${gl_zi}「運命石之扉の選択,El Psy Kongroo」${gl_bai}" 
                sleep 1
                clear
                break 
                ;;
            *) 
                clear
                echo -e "${gl_hong}[!] 無效選項，請重新選擇${gl_bai}"
                sleep 2
                ;;
        esac
    done
}

main_menu
