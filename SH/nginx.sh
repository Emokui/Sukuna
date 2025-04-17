#!/bin/bash

set -e

NGINX_HOME="/home/nginx"
NGINX_CONF="${NGINX_HOME}/nginx.conf"
CERT_DIR="${NGINX_HOME}/certs"
HTML_DIR="${NGINX_HOME}/html"
ACME_SH="${HOME}/.acme.sh/acme.sh"
DOCKER_IMAGE="nginx:latest"

color_info() { echo -e "\033[36m$1\033[0m"; }
color_warn() { echo -e "\033[33m$1\033[0m"; }
color_err()  { echo -e "\033[31m$1\033[0m"; }
pause_and_clear() { read -r -p "按 Enter 鍵繼續..."; clear_screen; }
clear_screen() { command -v clear &>/dev/null && clear || true; }

if [ "$EUID" -ne 0 ]; then
  color_err "請以 root 權限執行本腳本"
  exit 1
fi

banner() {
  color_info "————————————————————————————————"
  color_info "命運石之門：反向代理 Nginx"
  color_info "————————————————————————————————"
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
  domain=$1
  proxy_target=$2
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
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
      proxy_pass http://$proxy_target;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
    }
  }
BLOCK
}

ensure_acme() {
  if [ ! -d "$HOME/.acme.sh" ]; then
    color_info "[*] 安裝 acme.sh ..."
    curl https://get.acme.sh | sh
  fi
  if [ ! -f "$ACME_SH" ]; then
    color_err "[!] 未找到 acme.sh，請確認安裝已完成。"
    exit 1
  fi
}

ensure_cert_dir() { mkdir -p "$CERT_DIR"; }

issue_cert() {
  domain=$1
  email=$2
  ensure_acme
  ensure_cert_dir
  if [[ -f "${CERT_DIR}/${domain}.crt" && -f "${CERT_DIR}/${domain}.key" ]]; then
    color_info "[✓] 已檢測到 ${domain} 憑證，跳過簽發步驟。"
    return
  fi
  $ACME_SH --register-account -m "$email" || true
  color_info "[*] 正在簽發 $domain 憑證..."
  $ACME_SH --issue -d "$domain" --standalone
  if [ $? -ne 0 ]; then
    color_err "[✘] 憑證簽發失敗，請確認 DNS 或 80 埠可用性。"
    pause_and_clear
    exit 1
  fi
  $ACME_SH --install-cert -d "$domain" \
    --key-file "${CERT_DIR}/${domain}.key" \
    --fullchain-file "${CERT_DIR}/${domain}.crt"
}

backup_nginx_conf() {
  [ -f "$NGINX_CONF" ] && cp "$NGINX_CONF" "${NGINX_CONF}.$(date +%Y%m%d%H%M%S).bak"
}

append_server_block() {
  domain=$1
  proxy_target=$2
  events_section=$(sed -n '/^events/,/^}/p' "$NGINX_CONF")
  http_content=$(sed -n '/^http {/,/^}/p' "$NGINX_CONF" | sed '$d' | tail -n +2)
  new_block=$(gen_server_block "$domain" "$proxy_target")
  cat > "$NGINX_CONF" <<EOF
$events_section
http {
$http_content
$new_block
}
EOF
}

ensure_docker_installed() {
  if ! command -v docker &>/dev/null; then
    color_info "[*] 安裝 Docker..."
    curl -fsSL https://get.docker.com | sh
  fi
}

ensure_nginx_container() {
  if docker ps -a --format '{{.Names}}' | grep -q '^nginx$'; then
    color_warn "[*] 刪除舊 nginx 容器..."
    docker rm -f nginx
    sleep 1
  fi
}

reload_nginx_container() {
  if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
    docker restart nginx
  else
    # 如果已存在同名容器（不管是否已停止），先移除
    if docker ps -a --format '{{.Names}}' | grep -q '^nginx$'; then
      color_warn "[*] 偵測到已存在 nginx 容器，將自動刪除..."
      docker rm -f nginx
    fi

    docker run -d --name nginx \
      -p 80:80 -p 443:443 \
      --restart=always \
      -v "$NGINX_CONF":/etc/nginx/nginx.conf \
      -v "$CERT_DIR":/etc/nginx/certs \
      -v "$HTML_DIR":/usr/share/nginx/html \
      $DOCKER_IMAGE
  fi
}

install_or_add_proxy() {
  # 如果 nginx.conf 不存在，先創建一個空白配置
  if [ ! -f "$NGINX_CONF" ]; then
    mkdir -p "$NGINX_HOME"
    cat > "$NGINX_CONF" <<EOF
events {}
http {}
EOF
    color_info "[*] 已自動建立空白 nginx.conf 配置檔。"
  fi

  read -r -p "請輸入你的域名（例如 example.com）: " domain
  while true; do
    read -r -p "請輸入反向代理的 IP + 端口（例如 127.0.0.1:5212）: " proxy_target
    if validate_ip_port "$proxy_target"; then break; fi
    color_warn "[!] 格式錯誤，請輸入有效的 IPv4:Port"
  done
  read -r -p "請輸入你的 Email（ACME 使用，直接回車將隨機生成）: " email
  if [ -z "$email" ]; then
    email="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)@gmail.com"
    color_info "[!] 未輸入，已生成：$email"
  fi

  ensure_docker_installed
  mkdir -p "$CERT_DIR" "$HTML_DIR"

  if [ -f "$NGINX_CONF" ] && grep -q "server_name" "$NGINX_CONF"; then
    color_warn "[!] 已檢測到 nginx.conf 中存在反代設定，將自動視為新增反代，不覆蓋原有設定。"
    backup_nginx_conf
    docker stop nginx || true
    issue_cert "$domain" "$email"
    append_server_block "$domain" "$proxy_target"
    reload_nginx_container
    color_info "[✓] 已新增反代：$domain -> $proxy_target"
    pause_and_clear
    return
  fi

  ensure_nginx_container
  backup_nginx_conf
  ensure_acme
  $ACME_SH --register-account -m "$email" || true
  issue_cert "$domain" "$email"
  color_info "[*] 生成 nginx.conf..."
  new_block=$(gen_server_block "$domain" "$proxy_target")
  cat > "$NGINX_CONF" <<EOF
events {
  worker_connections 1024;
}
http {
  client_max_body_size 1000m;

$new_block
}
EOF

  reload_nginx_container
  color_info "[✓] Nginx 部署完成，已啟動。"
  docker ps | grep nginx
  pause_and_clear
}

manage_docker() {
  while true; do
    clear_screen
    color_info "=== Docker 管理選單 ==="
    echo "1. 更新 compose 所有鏡像"
    echo "2. 刪除 compose 所有鏡像"
    echo "3. 刪除指定鏡像"
    echo "4. 深度清理所有無用資源"
    echo "5. 徹底卸載 Docker"
    echo "0. 返回主選單"
    read -r -p "請選擇操作 (0-5): " action
    case $action in
      1)
        if command -v docker-compose &>/dev/null; then
          docker-compose pull
        else
          color_err "未安裝 docker-compose"
        fi
        ;;
      2)
        if command -v docker-compose &>/dev/null; then
          docker-compose down --rmi all
        else
          color_err "未安裝 docker-compose"
        fi
        ;;
      3)
        read -r -p "請輸入鏡像名稱或 ID: " image
        if [ -n "$image" ]; then
          docker image rm -f "$image"
        else
          color_warn "未輸入鏡像名稱"
        fi
        ;;
      4) docker system prune -af --volumes ;;
      5)
        color_warn "[*] 開始卸載..."
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker rmi $(docker images -q) 2>/dev/null || true
        docker network prune -f
        if command -v apt &>/dev/null; then
          apt-get remove -y docker docker-ce docker-ce-cli
          apt-get purge -y docker-ce docker-ce-cli
        elif command -v yum &>/dev/null; then
          yum remove -y docker docker-ce docker-ce-cli
        elif command -v dnf &>/dev/null; then
          dnf remove -y docker docker-ce docker-ce-cli
        elif command -v apk &>/dev/null; then
          apk del docker
        fi
        rm -rf /var/lib/docker /etc/docker
        # 新增自定義檔案與資料夾清理
        rm -rf /home/nginx
        rm -rf /root/docker-compose.yml
        rm -rf /root/sub-store-data
        color_info "[✓] Docker 及 nginx 配置與自定義檔案已清除。"
        ;;
      0) break ;;
      *) color_warn "無效選項。";;
    esac
    pause_and_clear
  done
}

while true; do
  clear_screen
  banner
  echo "1. 安裝/新增反向代理"
  echo "2. Docker 管理"
  echo "0. 離開世界線"
  read -r -p "請選擇操作 (0-2): " choice
  case "$choice" in
    1) install_or_add_proxy ;;
    2) manage_docker ;;
    0) color_info "觀測者離線，世界線收束。"; exit 0 ;;
    *) color_warn "你觸碰了未知的 Reading Steiner。"; pause_and_clear ;;
  esac
done
