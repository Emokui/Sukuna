#!/bin/bash

# 彩色與格式化
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[1;34m"
PLAIN='\033[0m'

red(){ echo -e "\033[31m\033[01m$1\033[0m"; }
green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }

pause_and_return() {
    echo ""
    read -p "請按回車鍵返回上一層..." temp
}

generate_self_signed_cert() {
    echo ""
    yellow "開始生成自簽名ECC證書..."
    DEFAULT_DOMAIN="bing.com"
    DEFAULT_CERT_PATH="/etc/cert"
    DEFAULT_DAYS=36500

    read -rp "請輸入證書的域名（預設: ${DEFAULT_DOMAIN}）: " domain
    domain="${domain:-$DEFAULT_DOMAIN}"
    read -rp "請輸入證書存放路徑（預設: ${DEFAULT_CERT_PATH}）: " cert_path
    cert_path="${cert_path:-$DEFAULT_CERT_PATH}"
    read -rp "請輸入證書有效天數（預設: ${DEFAULT_DAYS}）: " days
    days="${days:-$DEFAULT_DAYS}"

    key_file="${cert_path}/server.key"
    crt_file="${cert_path}/server.crt"

    sudo mkdir -p "$cert_path"
    echo "生成 ECC 私鑰..."
    sudo openssl ecparam -name prime256v1 -genkey -noout -out "$key_file"

    echo "使用私鑰生成自簽證書..."
    sudo openssl req -new -x509 -key "$key_file" -out "$crt_file" -days "$days" \
        -subj "/CN=$domain" -addext "subjectAltName=DNS:$domain"

    sudo chmod 644 "$crt_file"
    sudo chmod 600 "$key_file"

    echo ""
    green "自簽名證書生成完成！"
    echo "私鑰位置: $key_file"
    echo "證書位置: $crt_file"
    pause_and_return
}

issue_acme_cert() {
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

cert_menu() {
    while true; do
        clear
        echo "#############################################"
        echo -e "#        ${GREEN}證書生成/申請輔助工具${PLAIN}           #"
        echo "#############################################"
        echo ""
        echo -e " ${GREEN}1.${PLAIN} 生成自簽名ECC證書"
        echo -e " ${GREEN}2.${PLAIN} 申請 ACME 證書（需開放80端口 自動保存於 /root/cert）"
        echo -e " ${GREEN}0.${PLAIN} 返回主菜單"
        echo ""

        read -p "請輸入選項 [0-2]: " choice

        case "$choice" in
            1) generate_self_signed_cert ;;
            2) issue_acme_cert ;;
            0) break ;;
            *) echo "無效選項，請重新輸入。"; pause_and_return ;;
        esac
    done
}

random_pass() {
    head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10
}

select_cert_for_hysteria() {
    echo "請選擇證書配置方式："
    echo "1. 自簽證書（檢查 /etc/cert/ 下證書直接使用）"
    echo "2. 域名證書（檢查 /root/cert 下所有證書，支持多域名選擇）"
    echo "3. 自定義證書路徑"
    echo "0. 返回主菜單"
    read -p "請選擇 [0-3]: " cert_option

    if [[ "$cert_option" == "1" ]]; then
        if [[ -f /etc/cert/server.crt && -f /etc/cert/server.key ]]; then
            cert_path="/etc/cert/server.crt"
            key_path="/etc/cert/server.key"
            return 0
        else
            red "未檢測到 /etc/cert/server.crt 與 /etc/cert/server.key，請先生成自簽證書！"
            pause_and_return
            return 1
        fi
    elif [[ "$cert_option" == "2" ]]; then
        if ! compgen -G "/root/cert/*.crt" > /dev/null; then
            red "未檢測到 /root/cert 下任何證書，請先申請域名證書！"
            pause_and_return
            return 1
        fi
        echo "檢測到以下域名證書："
        select crtfile in /root/cert/*.crt; do
            [[ -z "$crtfile" ]] && echo "請輸入有效選項。" && continue
            domain_base=$(basename "$crtfile" .crt)
            keyfile="/root/cert/${domain_base}.key"
            if [[ -f "$keyfile" ]]; then
                cert_path="$crtfile"
                key_path="$keyfile"
                break
            else
                echo "未找到對應私鑰：$keyfile，請重新選擇。"
            fi
        done
    elif [[ "$cert_option" == "3" ]]; then
        read -p "請輸入證書(.crt/.pem)路徑: " cert_path
        read -p "請輸入私鑰(.key)路徑: " key_path
        if [[ ! -f "$cert_path" || ! -f "$key_path" ]]; then
            red "自定義證書或私鑰路徑無效！"
            pause_and_return
            return 1
        fi
    else
        return 1
    fi
    return 0
}

while true; do
  # ==== 高亮藍色主菜單標題 ====
  echo -e "${BLUE}==============================================${PLAIN}"
  echo -e "${BLUE}====      Steins Gate - hysteria Ver.1.0    ====${PLAIN}"
  echo -e "${BLUE}==============================================${PLAIN}"
  echo "请选择你的命运石之门:"
  echo "1. 申请證書or自签证书"
  echo "2. 安裝 Hysteria"
  echo "3. 管理 Hysteria 服務"
  echo "4. 設置端口跳躍規則"
  echo "0. 離開 El Psy Kongroo"
  read -p "請選擇操作: " option

  # 選項0: 退出腳本
  if [ "$option" -eq 0 ]; then
      echo "退出腳本..."
      exit 0

  # 選項1: 申请證書or自签证书 
  elif [ "$option" -eq 1 ]; then
      cert_menu

  # 選項2: 安裝 Hysteria
  elif [ "$option" -eq 2 ]; then
      HY2_DIR="/root/hysteria"
      EXEC_PATH="${HY2_DIR}/hysteria"

      mkdir -p "$HY2_DIR"

      echo "正在下載最新版本的 Hysteria 內核..."
      wget -O "${EXEC_PATH}" "https://download.hysteria.network/app/latest/hysteria-linux-amd64"

      if [ ! -s "$EXEC_PATH" ]; then
          echo "下載的文件為空，請檢查網絡或下載鏈接是否正確。"
          exit 1
      fi

      chmod +x "$EXEC_PATH"
      echo "Hysteria 內核已成功下載並賦予執行權限"

      # 證書/私鑰選擇
      while true; do
          select_cert_for_hysteria
          CERT_RTN=$?
          [[ $CERT_RTN -eq 0 ]] && break
          # 用戶選了返回或錯誤則返回主菜單
          [[ $CERT_RTN -eq 1 ]] && break
      done

      # 若未正確選擇證書則不再繼續
      [[ $CERT_RTN -ne 0 ]] && continue

      echo "請輸入監聽端口 (默認 :443):"
      read -r listen_port
      listen_port=${listen_port:-:443}

      # 密碼支持自定義，回車為隨機
      read -p "請輸入認證密碼 (回車自動隨機): " auth_password
      if [ -z "$auth_password" ]; then
        auth_password=$(random_pass)
        echo "已自動生成認證密碼: $auth_password"
      fi

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
ExecStart=/root/hysteria/hysteria server --config /root/hysteria/config.yaml
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
      HY2_DIR="/root/hysteria"
      EXEC_PATH="${HY2_DIR}/hysteria"
      CONFIG_PATH="${HY2_DIR}/config.yaml"
      SERVICE_FILE="/etc/systemd/system/hysteria.service"
      CERT_DIR="/etc/cert"
      PORT_JUMP_SERVICE="/etc/systemd/system/port-jump.service"

      echo "请选择你的命运石之门:"
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
      echo "檢查 iptables 是否已安裝..."
      if ! command -v iptables &> /dev/null; then
          echo "未檢測到 iptables，正在安裝中..."
          if [ -f /etc/debian_version ]; then
              sudo apt-get update
              sudo apt-get install -y iptables
          elif [ -f /etc/redhat-release ]; then
              sudo yum install -y iptables
          else
              echo "無法識別的系統，請手動安裝 iptables！中止任務！"
              exit 1
          fi
      else
          echo "iptables 已安裝，進入跳躍準備階段..."
      fi

      interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

      if [ -z "$interface" ]; then
        echo "未檢測到有效的網卡，請檢查網絡配置。"
        exit 1
      fi

      echo "檢測到的網卡名稱為: $interface"
      echo "如果需要更改網卡名稱，請手動輸入，默認為 $interface"

      read -r user_interface
      user_interface=${user_interface:-$interface}

      echo "請輸入端口範圍 (默認 18443:28444):"
      read -r port_range
      port_range=${port_range:-18443:28444}

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
  fi
done
