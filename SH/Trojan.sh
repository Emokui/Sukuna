#!/bin/bash

# 啟動 Trojan-Go
function start_trojan_go() {
    echo "正在啟動 Trojan-Go……"
    systemctl start trojan-go
    systemctl status trojan-go --no-pager
    echo ""
    echo "若你看見『Active: active (running)』，那麼你已經成功打開世界線之門。"
}

# 停止 Trojan-Go
function stop_trojan_go() {
    echo "正在停止 Trojan-Go……"
    systemctl stop trojan-go
    systemctl status trojan-go --no-pager
    echo ""
    echo "Trojan-Go 已經停止運行！"
}

# 重啟 Trojan-Go
function restart_trojan_go() {
    echo "正在重啟 Trojan-Go……"
    systemctl restart trojan-go
    systemctl status trojan-go --no-pager
    echo ""
    echo "Trojan-Go 已經重啟！"
}

# 徹底刪除 Trojan-Go 及相關配置
function remove_trojan_go() {
    echo "準備徹底刪除 Trojan-Go 及相關配置……"

    # 停止 Trojan-Go 服務
    systemctl stop trojan-go
    systemctl disable trojan-go

    # 刪除 Trojan-Go systemd 服務檔案
    rm -f /etc/systemd/system/trojan-go.service

    # 重新加載 systemd 配置
    systemctl daemon-reexec
    systemctl daemon-reload

    # 刪除 Trojan-Go 安裝檔案
    rm -rf /root/trojan

    # 刪除 SSL 憑證及私鑰（可選）
    read -p "是否刪除 SSL 憑證及私鑰？（yes/no）: " delete_ssl
    if [ "$delete_ssl" == "yes" ]; then
        rm -f /root/cert.crt
        rm -f /root/private.key
        echo "SSL 憑證與私鑰已被刪除。"
    else
        echo "SSL 憑證與私鑰保持不變。"
    fi

    # 刪除 Trojan-Go 相關的配置檔案
    rm -f /root/trojan/config.json

    echo "Trojan-Go 及相關配置已經徹底刪除！"
}

# 管理 Trojan-Go 服務
function manage_trojan_go() {
    echo "進入 Trojan-Go 管理選項："
    echo "1. 啟動 Trojan-Go"
    echo "2. 停止 Trojan-Go"
    echo "3. 重啟 Trojan-Go"
    echo "4. 刪除 Trojan-Go"

    read -p "請選擇操作 [1-4]: " choice

    case "$choice" in
        1) start_trojan_go ;;
        2) stop_trojan_go ;;
        3) restart_trojan_go ;;
        4) remove_trojan_go ;;
        *) echo "無效選擇，請重新嘗試。" ;;
    esac
}

# 安裝 ACME.sh SSL 脚本
function install_acme() {
    echo "正在安裝 ACME.sh 自動 SSL 憑證管理腳本……"
    wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/SH/Acme.sh && bash Acme.sh
}

# 安裝 Trojan-Go 並建立配置與 systemd 服務
function install_trojan_go() {
    echo "準備安裝 Trojan-Go 並設置配置……"

    # 創建 Trojan-Go 目錄
    mkdir -p /root/trojan && cd /root/trojan

    # 下載 Trojan-Go 二進制文件
    wget https://raw.githubusercontent.com/Emokui/Sukuna/main/Linux/trojan-go && chmod +x trojan-go

    # 配置文件設置
    echo "請根據提示設置 Trojan-Go 配置"
    
    read -p "請輸入本地監聽端口 (節點端口) [預設: 443]: " local_port
    local_port=${local_port:-443}

    read -p "請輸入轉發目標地址 (默認即可) [預設: httpforever.com]: " remote_addr
    remote_addr=${remote_addr:-httpforever.com}

    read -p "請輸入轉發目標端口 (默認即可) [預設: 80]: " remote_port
    remote_port=${remote_port:-80}

    read -p "請輸入密碼 (建議更改) [預設: 123123]: " password
    password=${password:-123123}
    
    read -p "請輸入路徑 (默認即可) [預設: /]: " ws_path
    ws_path=${ws_path:-/}
    
    read -p "請輸入你的域名 (證書域名) [預設: yourdomain.com]: " domain
    domain=${domain:-yourdomain.com}

    read -p "請輸入證書cert 路徑 [預設: /root/cert.crt]: " cert_path
    cert_path=${cert_path:-/root/cert.crt}

    read -p "請輸入證書key 路徑 [預設: /root/private.key]: " key_path
    key_path=${key_path:-/root/private.key}

    # 創建配置文件
    cat > /root/trojan/config.json <<EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $local_port,
    "remote_addr": "$remote_addr",
    "remote_port": $remote_port,
    "password": [
        "$password"
    ],
    "websocket": {
        "enabled": true,
        "path": "$ws_path",
        "host": "$domain"
    },
    "ssl": {
        "cert": "$cert_path",
        "key": "$key_path",
        "sni": "$domain"
    },
    "mux": {
        "enabled": true,
        "concurrency": 8,
        "idle_timeout": 60
    }
}
EOF

    # 設置 systemd 開機啟動
    cat > /etc/systemd/system/trojan-go.service <<EOF
[Unit]
Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/root/trojan/trojan-go -config /root/trojan/config.json
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    # 重新加載 systemd 配置
    systemctl daemon-reexec
    systemctl daemon-reload

    # 啟用並啟動 Trojan-Go 服務
    systemctl enable --now trojan-go

    echo "Trojan-Go 已安裝並設置開機自啟！"
}

# 主選單
function main_menu() {
    clear
    echo "======================================"
    echo "        鳳凰院凶真 - Trojan-Go"
    echo "        El Psy Kongroo. Version 1.2"
    echo "======================================"
    echo ""
    echo "請選擇你的命運："
    echo "1. 安裝 ACME.sh 證書申請腳本"
    echo "2. 安裝 Trojan-Go"
    echo "3. 管理 Trojan-Go"
    echo "0. 離開命運石之門"
    echo ""

    read -p "請輸入選項 [0-3]: " choice

    case "$choice" in
        1) install_acme ;;
        2) install_trojan_go ;;
        3) manage_trojan_go ;;
        0) echo "命運已中斷，回歸現實世界……" && exit 0 ;;
        *) echo "錯誤的命運選擇。請重新啟動世界線。" ;;
    esac
}

# 啟動主選單
main_menu
