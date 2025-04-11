#!/bin/bash

while true; do
  # 顯示選項菜單
  echo "請選擇操作:"
  echo "0. 退出腳本"
  echo "1. 申请證書or自签证书"
  echo "2. 安裝 Hysteria"
  echo "3. 管理 Hysteria 服務"
  echo "4. 設置端口跳躍規則"
  read -p "請選擇操作: " option

  # 選項0: 退出腳本
  if [ "$option" -eq 0 ]; then
      echo "退出腳本..."
      exit 0

  # 選項1: 申请證書or自签证书 
  elif [ "$option" -eq 1 ]; then
      echo "正在下載並執行 Acme.sh..."
      wget -N --no-check-certificate https://raw.githubusercontent.com/Emokui/Sukuna/main/SH/Acme.sh && bash Acme.sh
      
      read -p "按 Enter 鍵返回主菜單..." _

  # 選項2: 安裝 Hysteria
  elif [ "$option" -eq 2 ]; then
      HY2_DIR="/root/hy2"
      EXEC_PATH="${HY2_DIR}/hysteria"

      mkdir -p "$HY2_DIR"

      echo "正在下載最新版本的 Hysteria 內核..."
      wget -O "${EXEC_PATH}" "https://download.hysteria.network/app/latest/hysteria-linux-amd64"

      if [ ! -s "$EXEC_PATH" ]; then
          echo "下載的文件為空，請檢查網絡或下載鏈接是否正確。"
          exit 1
      fi

      mv "$EXEC_PATH" "$HY2_DIR/hysteria"
      chmod +x "$HY2_DIR/hysteria"

      echo "Hysteria 內核已成功下載並賦予執行權限"

      echo "請輸入監聽端口 (默認 :443):"
      read -r listen_port
      listen_port=${listen_port:-:443}

      echo "請輸入證書路徑 (默認自签证书 /etc/cert/server.crt):"
      read -r cert_path
      cert_path=${cert_path:-/etc/cert/server.crt}

      echo "請輸入私鑰路徑 (默認自签证书 /etc/cert/server.key):"
      read -r key_path
      key_path=${key_path:-/etc/cert/server.key}

      echo "請輸入認證密碼 (默認 123456asd):"
      read -r auth_password
      auth_password=${auth_password:-123456asd}

      echo "請輸入偽裝 URL (默認 https://www.bing.com):"
      read -r masquerade_url
      masquerade_url=${masquerade_url:-https://www.bing.com}

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

      echo "配置文件內容如下："
      cat "$HY2_DIR/config.yaml"

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

      sudo systemctl daemon-reload
      sudo systemctl enable hysteria.service
      sudo systemctl start hysteria.service

      echo "Hysteria 服務啟動狀態："
      sudo systemctl status hysteria.service
      echo "已成功設置 Hysteria 開機自啟並啟動服務！"
      read -p "按 Enter 鍵返回主菜單..." _

  # 選項3: 管理 Hysteria 服務
  elif [ "$option" -eq 3 ]; then
      SERVICE_NAME="hysteria"
      HY2_DIR="/root/hy2"
      EXEC_PATH="${HY2_DIR}/hysteria"
      CONFIG_PATH="${HY2_DIR}/config.yaml"
      SERVICE_FILE="/etc/systemd/system/hysteria.service"
      CERT_DIR="/etc/hysteria"
      PORT_JUMP_SERVICE="/etc/systemd/system/port-jump.service"

      echo "請選擇操作:"
      echo "1) 查看 Hysteria 狀態"
      echo "2) 啟動 Hysteria 服務"
      echo "3) 停止 Hysteria 服務"
      echo "4) 重啟 Hysteria 服務"
      echo "5) 更新 Hysteria 內核"
      echo "6) 刪除 Hysteria 服務與相關資源"
      read -p "選擇操作 (1-6): " ACTION

      case "$ACTION" in
          1)
              echo "Hysteria 服務當前狀態："
              sudo systemctl status $SERVICE_NAME
              ;;

          2)
              echo "正在啟動 Hysteria 服務..."
              sudo systemctl start $SERVICE_NAME
              echo "已啟動"
              ;;

          3)
              echo "正在停止 Hysteria 服務..."
              sudo systemctl stop $SERVICE_NAME
              echo "已停止"
              ;;

          4)
              echo "正在重啟 Hysteria 服務..."
              sudo systemctl restart $SERVICE_NAME
              echo "已重啟"
              ;;

          5)
              echo "正在更新 Hysteria 內核..."
              LATEST_TAG=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
              DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_TAG}/hysteria-linux-amd64"
              wget "$DOWNLOAD_URL" -O "$EXEC_PATH"
              chmod +x "$EXEC_PATH"
              echo "內核已更新，重啟服務中..."
              sudo systemctl daemon-reload
              sudo systemctl restart $SERVICE_NAME
              ;;

          6)
              echo "正在刪除 Hysteria 相關資源..."
              sudo systemctl stop $SERVICE_NAME
              sudo systemctl disable $SERVICE_NAME
              sudo rm -f $SERVICE_FILE
              sudo rm -rf $HY2_DIR
              sudo rm -f $CERT_DIR/server.key
              sudo rm -f $CERT_DIR/server.crt
              if [ -f "$PORT_JUMP_SERVICE" ]; then
                  sudo systemctl stop port-jump.service
                  sudo systemctl disable port-jump.service
                  sudo rm -f "$PORT_JUMP_SERVICE"
              fi
              sudo systemctl daemon-reload
              echo "所有 Hysteria 相關資源已刪除"
              ;;

          *)
              echo "無效選項，請輸入 1 到 6"
              ;;
      esac

      read -p "按 Enter 鍵返回主菜單..." _

  # 選項4: 設置端口跳躍規則
  elif [ "$option" -eq 4 ]; then
      interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

      if [ -z "$interface" ]; then
        echo "未檢測到有效的網卡，請檢查網絡配置。"
        exit 1
      fi

      echo "檢測到的網卡名稱為: $interface"
      echo "如果需要更改網卡名稱，請手動輸入，默認為 $interface"

      read -r user_interface
      user_interface=${user_interface:-$interface}

      echo "請輸入端口範圍 (默認 20000:50000):"
      read -r port_range
      port_range=${port_range:-20000:50000}

      echo "請輸入HY端口 (默認 443):"
      read -r target_port
      target_port=${target_port:-443}

      echo "正在設置端口跳躍規則..."
      sudo iptables -t nat -A PREROUTING -i $user_interface -p udp --dport $port_range -j REDIRECT --to-ports $target_port

      echo "以下是當前的 iptables 規則："
      sudo iptables -t nat -L -n

      echo "創建 systemd 自啟服務: port-jump.service"
      cat > /etc/systemd/system/port-jump.service << EOF
[Unit]
Description=UDP Port Jumping NAT Rule
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A PREROUTING -i $user_interface -p udp --dport $port_range -j REDIRECT --to-ports $target_port
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

      sudo systemctl daemon-reload
      sudo systemctl enable port-jump.service
      sudo systemctl start port-jump.service

      echo "端口跳躍規則已啟用並設置為開機自動啟動"
      read -p "按 Enter 鍵返回主菜單..." _

  else
      echo "無效選項，請選擇 0 到 4 的選項"
      read -p "按 Enter 鍵返回主菜單..." _
  fi
done
