#!/bin/bash

# 啟動 Trojan-Go
function start_trojan_go() {
    echo "正在啟動 Trojan-Go……"
    systemctl start trojan-go
    systemctl status trojan-go --no-pager
    echo ""
    echo "若你看見『Active: active (running)』，那麼你已經成功打開世界線之門。"
    pause_and_return
}

# 停止 Trojan-Go
function stop_trojan_go() {
    echo "正在停止 Trojan-Go……"
    systemctl stop trojan-go
    systemctl status trojan-go --no-pager
    echo ""
    echo "Trojan-Go 已經停止運行！"
    pause_and_return
}

# 重啟 Trojan-Go
function restart_trojan_go() {
    echo "正在重啟 Trojan-Go……"
    systemctl restart trojan-go
    systemctl status trojan-go --no-pager
    echo ""
    echo "Trojan-Go 已經重啟！"
    pause_and_return
}

# 徹底刪除 Trojan-Go 及相關配置
function remove_trojan_go() {
    echo "準備徹底刪除 Trojan-Go 及相關配置……"
    systemctl stop trojan-go
    systemctl disable trojan-go
    rm -f /etc/systemd/system/trojan-go.service
    systemctl daemon-reexec
    systemctl daemon-reload
    rm -rf /root/trojan

    read -p "是否刪除 SSL 憑證及私鑰？（yes/no）: " delete_ssl
    if [ "$delete_ssl" == "yes" ]; then
        rm -f /root/cert.crt
        rm -f /root/private.key
        echo "SSL 憑證與私鑰已被刪除。"
    else
        echo "SSL 憑證與私鑰保持不變。"
    fi

    rm -f /root/trojan/config.json
    echo "Trojan-Go 及相關配置已經徹底刪除！"
    pause_and_return
}

# 管理 Trojan-Go
function manage_trojan_go() {
    while true; do
        echo "進入 Trojan-Go 管理選項："
        echo "1. 啟動 Trojan-Go"
        echo "2. 停止 Trojan-Go"
        echo "3. 重啟 Trojan-Go"
        echo "4. 刪除 Trojan-Go"
        echo "0. 返回主菜單"
        read -p "請選擇操作 [0-4]: " choice
        case "$choice" in
            1) start_trojan_go; break ;;
            2) stop_trojan_go; break ;;
            3) restart_trojan_go; break ;;
            4) remove_trojan_go; break ;;
            0) break ;;
            *) echo "無效選擇，請重新嘗試。" ;;
        esac
    done
}

# 選項1：ACME 證書申請腳本（已用提取版替換）
function issue_acme_cert() {
    CERT_DIR="/root/cert"

    read -p "請輸入你的域名（例如 example.com）: " domain
    if [[ -z "$domain" ]]; then
      echo "請輸入域名參數，操作中止。"
      pause_and_return
      return 1
    fi

    read -p "請輸入你的 Email（ACME 使用，直接回車將隨機生成）: " email
    if [ -z "$email" ]; then
      email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"
      echo "[!] 未輸入，已生成：$email"
    fi

    mkdir -p "$CERT_DIR"

    if [[ -f "${CERT_DIR}/${domain}.crt" && -f "${CERT_DIR}/${domain}.key" ]]; then
      echo "[✓] 已檢測到 ${domain} 憑證，跳過簽發步驟。"
      pause_and_return
      return 0
    fi

    if ! command -v curl &>/dev/null; then
      echo "安裝 curl..."
      apt update -y && apt install -y curl
    fi

    if [ ! -d ~/.acme.sh ]; then
      echo "[*] 安裝 acme.sh ..."
      curl https://get.acme.sh | sh
    fi

    ~/.acme.sh/acme.sh --register-account -m "$email"

    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone
    if [ $? -ne 0 ]; then
      echo "[✘] 憑證簽發失敗，請確認 DNS 或 80 埠可用性。"
      pause_and_return
      return 2
    fi

    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
      --key-file "${CERT_DIR}/${domain}.key" \
      --fullchain-file "${CERT_DIR}/${domain}.crt"

    echo "[✓] 憑證已申請並保存於 ${CERT_DIR}/"
    pause_and_return
}

# 安裝 Trojan-Go
function install_trojan_go() {
    echo "準備安裝 Trojan-Go 並設置配置……"
    mkdir -p /root/trojan && cd /root/trojan
    wget https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/trojan-go && chmod +x trojan-go

    echo "請根據提示設置 Trojan-Go 配置"

    read -p "請輸入本地監聽端口 (節點端口) [預設: 443]: " local_port
    local_port=${local_port:-443}

    read -p "請輸入轉發目標地址 [預設: speedtest.tele2.net]: " remote_addr
    remote_addr=${remote_addr:-speedtest.tele2.net}

    read -p "請輸入轉發目標端口 [預設: 80]: " remote_port
    remote_port=${remote_port:-80}

    read -p "請輸入密碼 (建議更改) [預設: 123123asd]: " password
    password=${password:-123123asd}

    read -p "請輸入路徑 [預設: /]: " ws_path
    ws_path=${ws_path:-/}

    # 嘗試從 /root/cert 中尋找證書與私鑰
    default_cert=$(find /root/cert -type f \( -iname "*.crt" -o -iname "*.pem" \) | head -n 1)
    default_key=$(find /root/cert -type f -iname "*.key" | head -n 1)

    if [[ -z "$default_cert" ]]; then
        echo "⚠️ 未在 /root/cert 中找到 .crt 或 .pem 檔案，請手動輸入憑證路徑。"
        read -p "請輸入證書 cert 路徑: " cert_path
    else
        read -p "請輸入證書 cert 路徑 [預設: $default_cert]: " cert_path
        cert_path=${cert_path:-$default_cert}
    fi

    if [[ -z "$default_key" ]]; then
        echo "⚠️ 未在 /root/cert 中找到 .key 檔案，請手動輸入私鑰路徑。"
        read -p "請輸入私鑰 key 路徑: " key_path
    else
        read -p "請輸入私鑰 key 路徑 [預設: $default_key]: " key_path
        key_path=${key_path:-$default_key}
    fi

    # 自動從憑證中提取域名
    detected_domain=$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | sed -n 's/^subject=.*CN=\s*\([^,\/]*\).*/\1/p')
    if [[ -z "$detected_domain" ]]; then
        detected_domain=$(openssl x509 -in "$cert_path" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | grep -oE "DNS:[^, ]+" | head -n 1 | cut -d ":" -f2)
    fi

    if [[ -z "$detected_domain" ]]; then
        echo "⚠️ 無法自動從憑證中提取域名，請手動輸入."
        read -p "請輸入你的域名 (證書域名): " domain
    else
        read -p "請輸入你的域名 (證書域名) [預設: $detected_domain]: " domain
        domain=${domain:-$detected_domain}
    fi

    # 建立配置文件
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

    # systemd 啟動配置
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

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable --now trojan-go
    echo "✅ Trojan-Go 已安裝並設置開機自啟！"
    pause_and_return
}

# 回主菜單提示
function pause_and_return() {
    echo ""
    read -p "請按回車鍵返回主菜單..." temp
}

# 主選單
function main_menu() {
    while true; do
        clear
        echo "======================================"
        echo "        鳳凰院凶真 - Trojan-Go"
        echo "        El Psy Kongroo. Version 1.3"
        echo "======================================"
        echo ""
        echo "請選擇你的命運："
        echo "1. 安裝 ACME申請證書(需開放80端口)"
        echo "2. 安裝 Trojan-Go"
        echo "3. 管理 Trojan-Go"
        echo "0. 離開命運石之門"
        echo ""

        read -p "請輸入選項 [0-3]: " choice

        case "$choice" in
            1) issue_acme_cert ;;
            2) install_trojan_go ;;
            3) manage_trojan_go ;;
            0) echo "命運已中斷，回歸現實世界……" && exit 0 ;;
            *) echo "錯誤的命運選擇。請重新啟動世界線。"; pause_and_return ;;
        esac
    done
}

main_menu
