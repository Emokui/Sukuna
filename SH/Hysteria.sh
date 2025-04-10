#!/bin/bash

# 顯示選項菜單
echo "請選擇操作:"
echo "0. 退出腳本"
echo "1. 生成自簽證書"
echo "2. 安裝 Hysteria"
echo "3. 管理 Hysteria 服務"
echo "4. 設置端口跳躍規則"
read -p "請選擇操作: " option

# 選項0: 退出腳本
if [ "$option" -eq 0 ]; then
    echo "退出腳本..."
    exit 0

# 選項1: 生成自簽證書
elif [ "$option" -eq 1 ]; then
    # 默認的域名和存放路徑
    default_domain="bing.com"
    default_path="/etc/hysteria"

    # 提示用戶輸入域名，若未輸入則使用默認域名
    read -p "請輸入證書的域名（默認為 ${default_domain}）： " domain
    domain=${domain:-$default_domain}

    # 提示用戶輸入存放路徑，若未輸入則使用默認路徑
    read -p "請輸入證書存放路徑（默認為 ${default_path}）： " cert_path
    cert_path=${cert_path:-$default_path}

    # 設置文件路徑
    key_file="${cert_path}/server.key"
    crt_file="${cert_path}/server.crt"

    # 創建目錄，如果不存在
    sudo mkdir -p "$cert_path"

    # 生成證書
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "$key_file" -out "$crt_file" -subj "/CN=${domain}" -days 36500

    # 設置證書擁有者
    sudo chown hysteria "$key_file"
    sudo chown hysteria "$crt_file"

    echo "證書生成完成！"

# 選項2: 安裝 Hysteria
elif [ "$option" -eq 2 ]; then
    # 設置安裝路徑
    HY2_DIR="/root/hy2"
    EXEC_PATH="${HY2_DIR}/hysteria"

    # 創建目錄
    mkdir -p "$HY2_DIR"

    # 下載最新版的 hysteria-linux-amd64
    echo "正在下載最新版本的 Hysteria 內核..."
    wget -O "${EXEC_PATH}" "https://download.hysteria.network/app/latest/hysteria-linux-amd64"

    # 檢查下載的文件是否成功
    if [ ! -s "$EXEC_PATH" ]; then
        echo "下載的文件為空，請檢查網絡或下載鏈接是否正確。"
        exit 1
    fi

    # 重命名文件為 hysteria
    mv "$EXEC_PATH" "$HY2_DIR/hysteria"

    # 賦予執行權限
    chmod +x "$HY2_DIR/hysteria"

    echo "Hysteria 內核已成功下載並賦予執行權限"

    # 交互式設置配置文件參數
    echo "請輸入監聽端口 (默認 :443):"
    read -r listen_port
    listen_port=${listen_port:-:443}

    echo "請輸入證書路徑 (默認 /etc/hysteria/server.crt):"
    read -r cert_path
    cert_path=${cert_path:-/etc/hysteria/server.crt}

    echo "請輸入私鑰路徑 (默認 /etc/hysteria/server.key):"
    read -r key_path
    key_path=${key_path:-/etc/hysteria/server.key}

    echo "請輸入認證密碼 (默認 123456asd):"
    read -r auth_password
    auth_password=${auth_password:-123456asd}

    echo "請輸入偽裝 URL (默認 https://www.bing.com):"
    read -r masquerade_url
    masquerade_url=${masquerade_url:-https://www.bing.com}

    # 創建 config.yaml 文件
    cat > "$HY2_DIR/config.yaml" << EOF
listen: :${listen_port}

tls:
  cert: ${cert_path}
  key: ${key_path}

auth:
  type: password
  password: ${auth_password}

masquerade:
  type: proxy
  proxy:
    url: ${masquerade_url}
    rewriteHost: true
EOF

    echo "已完成以下操作："
    echo "- 下載最新版 hysteria-linux-amd64"
    echo "- 賦予執行權限"
    echo "- 創建配置文件 config.yaml"
    echo "配置文件內容如下："
    cat "$HY2_DIR/config.yaml"

    # 創建 systemd 服務單元文件
    echo "正在創建 systemd 服務單元文件..."

    cat > /etc/systemd/system/hysteria.service << EOF
[Unit]
Description=Hysteria Server Service
After=network.target

[Service]
ExecStart=/root/hy2/hysteria server --config /root/hy2/config.yaml
User=root
Group=root
Restart=always
Environment=PATH=/usr/bin:/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

    # 重新加載 systemd 配置並啟用服務
    echo "重新加載 systemd 配置並啟用服務..."
    sudo systemctl daemon-reload
    sudo systemctl enable hysteria.service

    # 啟動 Hysteria 服務
    echo "正在啟動 Hysteria 服務..."
    sudo systemctl start hysteria.service

    # 顯示服務狀態
    echo "Hysteria 服務啟動狀態："
    sudo systemctl status hysteria.service

    # 完成提示
    echo "已成功設置 Hysteria 開機自啟並啟動服務！"

# 選項3: 管理 Hysteria 服務
elif [ "$option" -eq 3 ]; then
    # 定義服務名稱
    SERVICE_NAME="hysteria"
    HY2_DIR="/root/hy2"
    EXEC_PATH="${HY2_DIR}/hysteria"
    CONFIG_PATH="${HY2_DIR}/config.yaml"
    SERVICE_FILE="/etc/systemd/system/hysteria.service"

    # 顯示菜單
    echo "請選擇操作:"
    echo "1) 啟動 Hysteria 服務"
    echo "2) 關閉 Hysteria 服務"
    echo "3) 重啟 Hysteria 服務"
    echo "4) 刪除 Hysteria 服務"
    echo "5) 更新 Hysteria 內核"
    read -p "選擇操作 (1-5): " ACTION

    # 根據用戶選擇執行操作
    case "$ACTION" in
      1)
        echo "正在啟動 Hysteria 服務..."
        sudo systemctl start $SERVICE_NAME
        echo "Hysteria 服務已啟動"
        ;;

      2)
        echo "正在停止 Hysteria 服務..."
        sudo systemctl stop $SERVICE_NAME
        echo "Hysteria 服務已停止"
        ;;

      3)
        echo "正在重啟 Hysteria 服務..."
        sudo systemctl restart $SERVICE_NAME
        echo "Hysteria 服務已重啟"
        ;;

      4)
        echo "正在刪除 Hysteria 服務..."
        # 停止服務
        sudo systemctl stop $SERVICE_NAME
        # 禁用服務自啟
        sudo systemctl disable $SERVICE_NAME
        # 刪除 systemd 服務文件
        sudo rm -f $SERVICE_FILE
        # 刪除 Hysteria 文件和配置
        sudo rm -rf $HY2_DIR
        echo "Hysteria 服務已刪除"
        ;;

      5)
        echo "正在更新 Hysteria 內核 (二進制文件)..."
        
        # 獲取最新版本的標籤名稱
        LATEST_TAG=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
        
        # 構建下載 URL
        DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_TAG}/hysteria-linux-amd64"

        # 下載最新版的 hysteria-linux-amd64
        wget "$DOWNLOAD_URL" -O $EXEC_PATH

        # 賦予執行權限
        chmod +x $EXEC_PATH

        echo "Hysteria 內核已更新"
        
        # 重新加載 systemd 配置
        sudo systemctl daemon-reload
        # 重啟服務
        sudo systemctl restart $SERVICE_NAME
        echo "Hysteria 服務已重啟"
        ;;

      *)
        echo "無效選項，請選擇 1 到 5 的選項"
        exit 1
        ;;
    esac

# 選項4: 設置端口跳躍規則
elif [ "$option" -eq 4 ]; then
    # 自動檢測網卡名稱，並將其設置為默認值
    interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

    # 如果檢測不到網卡，則提示用戶並退出
    if [ -z "$interface" ]; then
      echo "未檢測到有效的網卡，請檢查網絡配置。"
      exit 1
    fi

    echo "檢測到的網卡名稱為: $interface"
    echo "如果需要更改網卡名稱，請手動輸入，默認為 $interface"

    # 提示用戶輸入網卡名稱
    read -r user_interface
    user_interface=${user_interface:-$interface}

    # 提示用戶輸入轉發的端口範圍
    echo "請輸入端口範圍 (默認 20000:50000):"
    read -r port_range
    port_range=${port_range:-20000:50000}

    # 提示用戶輸入目標端口（默認設置為 443）
    echo "請輸入目標端口 (默認 443):"
    read -r target_port
    target_port=${target_port:-443}

    # 設置 iptables 規則
    echo "正在設置端口跳躍規則..."
    sudo iptables -t nat -A PREROUTING -i $user_interface -p udp --dport $port_range -j REDIRECT --to-ports $target_port

    # 顯示當前的 iptables 規則
    echo "以下是當前的 iptables 規則："
    sudo iptables -t nat -L -n
else
    echo "無效選項，請選擇 0 到 4 的選項"
fi
