#!/bin/bash

# 顏色定義
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

enable_root_login() {
    echo "==== 開啟 root 登錄 ===="
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo "[✓] root 登錄已啟用"
}

change_root_password() {
    echo "==== 修改 root 密碼 ===="
    passwd root
}

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

change_timezone() {
    while true; do
        echo "請選擇大區："
        PS3="輸入數字選擇大區: "
        zones=("Asia" "Europe" "America" "Africa" "Australia" "Etc" "返回")
        select zone in "${zones[@]}"; do
            [[ "$zone" == "返回" ]] && return
            [[ -n "$zone" ]] && break || echo "[!] 無效選項"
        done
        options=($(timedatectl list-timezones | grep "^$zone/" | sort))
        PS3="輸入數字選擇城市時區: "
        select city in "${options[@]}" "返回"; do
            [[ "$city" == "返回" ]] && break
            [[ -n "$city" ]] && timedatectl set-timezone "$city" && echo "[✓] 時區已設為 $city" && return
            echo "[!] 無效選項"
        done
    done
}

configure_firewall() {
    echo "[*] 偵測並準備防火牆工具..."
    FIREWALL_TOOL=""
    if command -v ufw &>/dev/null; then
        FIREWALL_TOOL="ufw"
    elif command -v firewall-cmd &>/dev/null; then
        FIREWALL_TOOL="firewalld"
    else
        echo "[!] 未偵測到防火牆工具，開始安裝..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y ufw && FIREWALL_TOOL="ufw"
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y firewalld && systemctl enable firewalld --now && FIREWALL_TOOL="firewalld"
        fi
    fi
    echo "[✓] 使用防火牆：$FIREWALL_TOOL"
    while true; do
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
                            for ((i=start; i<=end; i++)); do
                                parsed+=("$i")
                            done
                        else
                            parsed+=("$p")
                        fi
                    done
                    echo "${parsed[@]}"
                }
                PORTS=$(parse_ports "$input_ports")
                for port in $PORTS; do
                    if [[ "$FIREWALL_TOOL" == "ufw" ]]; then
                        [[ "$action_choice" == "1" ]] && ufw allow "$port/tcp" && ufw allow "$port/udp" || ufw deny "$port/tcp" && ufw deny "$port/udp"
                    elif [[ "$FIREWALL_TOOL" == "firewalld" ]]; then
                        [[ "$action_choice" == "1" ]] && firewall-cmd --permanent --add-port="$port/tcp" && firewall-cmd --permanent --add-port="$port/udp" || firewall-cmd --permanent --remove-port="$port/tcp" && firewall-cmd --permanent --remove-port="$port/udp"
                    fi
                done
                [[ "$FIREWALL_TOOL" == "ufw" ]] && ufw --force enable || firewall-cmd --reload
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
            *) echo "[!] 無效選項" ;;
        esac
    done
}

bbr_manage() {
    echo "==== BBR 管理（內核加速）===="
    bash <(curl -sL https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh)
}

warp_manage() {
    echo "==== WARP 管理（Cloudflare）===="
    read -rp "請輸入參數（可留空使用互動模式）: " warp_args
    bash <(curl -sL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh)
}

reboot_vps() {
    echo "==== 系統即將重新啟動 ===="
    read -rp "確認重啟？(y/n): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] && reboot
}

main_menu() {
    while true; do
        echo
        echo "==== VPS 控制腳本 ===="
        echo "1) 更新系統"
        echo "2) 清理緩存"
        echo "3) 開啟 root 登錄（供非 root）"
        echo "4) 修改 root 密碼"
        echo "5) 修改 SSH 端口"
        echo "6) 更改時區"
        echo "7) 設定防火牆"
        echo "8) BBR 管理"
        echo "9) WARP 管理"
        echo "10) 重啟 VPS"
        echo "11) 離開"
        read -rp "請選擇操作: " choice
        case $choice in
            1) linux_update ;;
            2) linux_clean ;;
            3) enable_root_login ;;
            4) change_root_password ;;
            5) change_ssh_port ;;
            6) change_timezone ;;
            7) configure_firewall ;;
            8) bbr_manage ;;
            9) warp_manage ;;
            10) reboot_vps ;;
            11) echo "腳本結束，觀測中止。El Psy Kongroo。" && break ;;
            *) echo "[!] 無效選項，請重新選擇" ;;
        esac
    done
}

main_menu
