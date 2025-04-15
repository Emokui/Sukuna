#!/bin/bash

set -e

NGINX_CONF="/home/nginx/nginx.conf"
CERT_DIR="/home/nginx/certs"

banner() {
  echo "————————————————————————————————"
  echo "命運石之門：多反向代理 Nginx 部署系統"
  echo "————————————————————————————————"
}

validate_ip_port() {
  local input=$1
  if [[ $input =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]]; then
    local ip=${input%:*}
    local port=${input##*:}
    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    if (( i1 <= 255 && i2 <= 255 && i3 <= 255 && i4 <= 255 && port >= 1 && port <= 65535 )); then
      return 0
    fi
  fi
  return 1
}

gen_server_block() {
  local domain=$1
  local proxy_target=$2

  cat <<BLOCK
  server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
  }

  server {
    listen 443 ssl http2;
    server_name $domain;
    ssl_certificate /etc/nginx/certs/${domain}.crt;
    ssl_certificate_key /etc/nginx/certs/${domain}.key;

    location / {
      proxy_pass http://$proxy_target;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
  }
BLOCK
}

issue_cert() {
  local domain=$1
  local email=$2

  if [[ -f "${CERT_DIR}/${domain}.crt" && -f "${CERT_DIR}/${domain}.key" ]]; then
    echo "[✓] 已檢測到 ${domain} 憑證，跳過簽發步驟。"
    return
  fi

  ~/.acme.sh/acme.sh --issue -d "$domain" --standalone
  if [ $? -ne 0 ]; then
    echo "[✘] 憑證簽發失敗，請確認 DNS 或 80 埠可用性。"
    sleep 2
    exec "$0"
  fi

  ~/.acme.sh/acme.sh --install-cert -d "$domain" \
    --key-file "${CERT_DIR}/${domain}.key" \
    --fullchain-file "${CERT_DIR}/${domain}.crt"
}

install_base() {
  read -p "請輸入你的域名（例如 example.com）: " domain
  while true; do
    read -p "請輸入反向代理的 IP + 端口（例如 127.0.0.1:5212）: " proxy_target
    if validate_ip_port "$proxy_target"; then break; fi
    echo "[!] 格式錯誤，請輸入有效的 IPv4:Port"
  done
  read -p "請輸入你的 Email（ACME 使用，直接回车將隨機生成）: " email
  if [ -z "$email" ]; then
    email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"
    echo "[!] 未輸入，已生成：$email"
  fi

  echo "[*] 系統更新與安裝工具..."
  sudo apt update -y && sudo apt install -y curl wget sudo socat

  echo "[*] 安裝 Docker（若尚未安裝）..."
  if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
  fi

  echo "[*] 建立 Nginx 資料夾..."
  mkdir -p /home/nginx/certs /home/nginx/html
  touch "$NGINX_CONF"

  echo "[*] 安裝 acme.sh 並註冊帳號..."
  curl https://get.acme.sh | sh
  ~/.acme.sh/acme.sh --register-account -m "$email"

  echo "[*] 簽發憑證..."
  issue_cert "$domain" "$email"

  echo "[*] 生成 nginx.conf..."
  cat > "$NGINX_CONF" <<EOF
events {
  worker_connections 1024;
}
http {
  client_max_body_size 1000m;

$(gen_server_block "$domain" "$proxy_target")
}
EOF

  echo "[*] 啟動 nginx 容器..."
  docker run -d --name nginx \
    -p 80:80 -p 443:443 \
    -v "$NGINX_CONF":/etc/nginx/nginx.conf \
    -v "$CERT_DIR":/etc/nginx/certs \
    -v /home/nginx/html:/usr/share/nginx/html \
    nginx:latest
  docker update --restart=always nginx

  echo "[✓] 命運已啟動！Nginx 部署完成。"
}

add_proxy() {
  read -p "請輸入新的域名: " domain
  while true; do
    read -p "請輸入反代的 IP + 端口: " proxy_target
    if validate_ip_port "$proxy_target"; then break; fi
    echo "[!] 無效輸入，請重試。"
  done
  read -p "請輸入 Email（可跳過）: " email
  [ -z "$email" ] && email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"

  if docker ps | grep -q nginx; then
    echo "[*] 停止 nginx 容器以申請新憑證..."
    docker stop nginx
    sleep 2
  fi

  issue_cert "$domain" "$email"
  docker start nginx

  echo "[*] 寫入 server 區塊..."
  # 创建备份
  cp "$NGINX_CONF" "${NGINX_CONF}.bak"
  
  # 提取events部分
  events_section=$(sed -n '/^events/,/^}/p' "$NGINX_CONF")
  
  # 提取http部分内容（不包括结束的花括号）
  http_content=$(sed -n '/^http {/,/^}/p' "$NGINX_CONF" | sed '$d' | tail -n +2)
  
  # 创建新配置文件
  cat > "$NGINX_CONF" <<EOF
$events_section
http {
$http_content
$(gen_server_block "$domain" "$proxy_target")
}
EOF

  docker restart nginx
  echo "[✓] 已添加新反代：$domain -> $proxy_target"
}

manage_docker() {
  echo "=== Docker 管理選單 ==="
  echo "1. 更新 compose 所有鏡像"
  echo "2. 刪除所有 compose 鏡像"
  echo "3. 刪除指定鏡像"
  echo "4. 深度清理所有無用資源"
  echo "5. 徹底卸載 Docker"
  read -p "請選擇操作 (1-5): " action
  case $action in
    1) docker-compose pull ;;
    2) docker-compose down --rmi all ;;
    3)
      read -p "請輸入鏡像名稱或 ID: " image
      docker image rm -f "$image"
      ;;
    4) docker system prune -af --volumes ;;
    5)
      echo "[*] 開始卸載..."
      docker rm $(docker ps -aq) 2>/dev/null || true
      docker rmi $(docker images -q) 2>/dev/null || true
      docker network prune -f
      sudo apt-get remove -y docker docker-ce docker-ce-cli
      sudo apt-get purge -y docker-ce docker-ce-cli
      sudo rm -rf /var/lib/docker /etc/docker
      echo "[✓] Docker 已清除。"
      ;;
    *) echo "無效選項。" ;;
  esac
}

# 命運選單
banner
echo "1. 安裝 Nginx 並部署第一個反向代理"
echo "2. 添加新的反向代理設定"
echo "3. Docker 系統管理"
echo "0. 離開世界線"

read -p "請選擇操作 (0-3): " choice
case "$choice" in
  1) install_base ;;
  2) add_proxy ;;
  3) manage_docker ;;
  0) echo "觀測者離線，世界線收束。"; exit 0 ;;
  *) echo "你觸碰了未知的 Reading Steiner。"; exit 1 ;;
esac
