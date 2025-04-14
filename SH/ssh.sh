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
        echo "5) 返回上一層"
        read -rp "請輸入選項 (1-5): " action_choice

        case "$action_choice" in
            1|2)
                read -rp "請輸入端口（如 22 443 或 1000-2000）: " input_ports
                parse_ports() {
                    local input=($1)
                    local parsed=()
                    for p in "${input[@]}"; do
                        if [[ "$p" =~ ^[0-9]+-[0-9]+$ ]]; then
                            start=${p%-*}
                            end=${p#*-}
                            for ((i=start; i<=end; i++)); do parsed+=("$i"); done
                        else
                            parsed+=("$p")
                        fi
                    done
                    echo "${parsed[@]}"
                }
                PORTS=$(parse_ports "$input_ports")

                if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
                    for port in $PORTS; do
                        [[ "$action_choice" == "1" ]] && ufw allow "$port/tcp" && ufw allow "$port/udp" || ufw deny "$port/tcp" && ufw deny "$port/udp"
                    done
                    ufw --force enable
                elif [[ "$FIREWALL_TOOL" == "firewalld" ]]; then
                    for port in $PORTS; do
                        [[ "$action_choice" == "1" ]] && \
                        firewall-cmd --permanent --add-port="$port/tcp" && \
                        firewall-cmd --permanent --add-port="$port/udp" || \
                        firewall-cmd --permanent --remove-port="$port/tcp" && \
                        firewall-cmd --permanent --remove-port="$port/udp"
                    done
                    firewall-cmd --reload
                fi
                ;;
            3)
                [[ "$FIREWALL_TOOL" == "ufw" ]] && ufw default allow && ufw --force enable
                [[ "$FIREWALL_TOOL" == "firewalld" ]] && firewall-cmd --set-default-zone=trusted && firewall-cmd --reload
                ;;
            4)
                [[ "$FIREWALL_TOOL" == "ufw" ]] && ufw default deny && ufw --force enable
                [[ "$FIREWALL_TOOL" == "firewalld" ]] && firewall-cmd --set-default-zone=drop && firewall-cmd --reload
                ;;
            5) break ;;
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

# ====== 主選單 ======
main_menu() {
    while true; do
        echo
        echo -e "${gl_kjlan}==== Steins Gate - 鳳凰院凶真 Ver.1.0 ==== ${gl_bai}"
        echo " 1) 系統更新"
        echo " 2) 系統清理"
        echo " 3) 開啟 root 登錄"
        echo " 4) 修改 root 密碼"
        echo " 5) 修改 SSH 端口"
        echo " 6) 更改時區"
        echo " 7) 設定防火牆"
        echo " 8) BBR 管理"
        echo " 9) WARP 管理"
        echo "10) 重啟 VPS"
        echo "11) 安裝 wget 與 unzip"
        echo "12) 安裝 Snell"
        echo "13) 安裝 Trojan"
        echo "14) 安裝 Hysteria"
        echo "15) 安裝 Acme"
        echo "16) 安裝 Mihomo"
        echo " 0) 離開"
        read -rp "請選擇操作: " choice
        case "$choice" in
            1) linux_update ;;
            2) linux_clean ;;
            3) enable_root_login ;;
            4) change_root_password ;;
            5) change_ssh_port ;;
            6) change_timezone ;;
            7) configure_firewall ;;
            8) bbr_menu ;;
            9) warp_menu ;;
            10) reboot_vps ;;
            11) install_base_tools ;;
            12) install_snell ;;
            13) install_trojan ;;
            14) install_hysteria ;;
            15) install_acme ;;
            16) install_mihomo ;;
            0) echo -e "${gl_zi}「運命石之扉の選択,El Psy Kongroo」${gl_bai}" && break ;;
            *) echo "[!] 無效選項，請重新選擇" ;;
        esac
    done
}

main_menu
