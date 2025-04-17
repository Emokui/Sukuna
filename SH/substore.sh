#!/usr/bin/env bash
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[1;35m'
PLAIN='\033[0m'

SUBSTORE_COMPOSE_PATH="/root/substore/docker-compose.yml"
SUBSTORE_DATA_PATH="/root/substore/data"
SUBSTORE_INFO_PATH="/root/substore/info.txt"

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}运行脚本需要 root 权限${PLAIN}" >&2
        exit 1
    fi
}

install_packages() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}正在安装 Docker 和 Docker Compose...${PLAIN}"
        if ! curl -fsSL https://get.docker.com | bash; then
            echo -e "${RED}Docker 安装失败${PLAIN}" >&2
            exit 1
        fi
        if ! apt-get update && apt-get install -y docker-compose; then
            echo -e "${RED}Docker Compose 安装失败${PLAIN}" >&2
            exit 1
        fi
        echo -e "${GREEN}Docker 和 Docker Compose 安装完成。${PLAIN}"
    else
        echo -e "${GREEN}Docker 和 Docker Compose 已安装。${PLAIN}"
    fi
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    local public_ip

    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -sS --connect-timeout 5 "$service"); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$public_ip"
                return 0
            fi
        fi
        sleep 1
    done

    echo -e "${RED}无法获取公共 IP 地址。${PLAIN}" >&2
    exit 1
}

install_substore() {
    install_packages
    local public_ip
    public_ip=$(get_public_ip)
    local secret_key
    secret_key=$(openssl rand -hex 16)

    echo -e "${CYAN}生成的密钥: $secret_key${PLAIN}"

    local default_port=3001
    read -p "请输入你想使用的端口号（默认: $default_port）: " custom_port
    custom_port="${custom_port:-$default_port}"

    if ! [[ "$custom_port" =~ ^[0-9]+$ ]] || [ "$custom_port" -lt 1 ] || [ "$custom_port" -gt 65535 ]; then
        echo -e "${YELLOW}无效端口号，使用默认端口 $default_port${PLAIN}"
        custom_port=$default_port
    fi

    mkdir -p /root/substore "$SUBSTORE_DATA_PATH"

    echo -e "${YELLOW}清理旧容器和配置...${PLAIN}"
    docker rm -f sub-store >/dev/null 2>&1 || true
    docker compose -p sub-store down >/dev/null 2>&1 || true

    cat <<EOF > "$SUBSTORE_COMPOSE_PATH"
name: sub-store-app
services:
  sub-store:
    image: xream/sub-store
    container_name: sub-store
    restart: always
    environment:
      - SUB_STORE_BACKEND_UPLOAD_CRON=55 23 * * *
      - SUB_STORE_FRONTEND_BACKEND_PATH=/$secret_key
    ports:
      - "${custom_port}:3001"
    volumes:
      - $SUBSTORE_DATA_PATH:/opt/app/data
EOF

    cd /root/substore

    echo -e "${CYAN}拉取最新镜像...${PLAIN}"
    docker compose -f "$SUBSTORE_COMPOSE_PATH" -p sub-store pull

    echo -e "${CYAN}启动容器...${PLAIN}"
    docker compose -f "$SUBSTORE_COMPOSE_PATH" -p sub-store up -d

    if ! command -v cron &>/dev/null; then
        echo -e "${YELLOW}安装 cron...${PLAIN}"
        apt-get update >/dev/null 2>&1
        apt-get install -y cron >/dev/null 2>&1
    fi
    systemctl enable cron >/dev/null 2>&1
    systemctl start cron

    local cron_job="0 * * * * cd /root/substore && docker stop sub-store && docker rm sub-store && docker compose -f $SUBSTORE_COMPOSE_PATH -p sub-store pull sub-store && docker compose -f $SUBSTORE_COMPOSE_PATH -p sub-store up -d sub-store >/dev/null 2>&1"
    (crontab -l 2>/dev/null || true; echo "$cron_job") | sort -u | crontab -

    echo -e "${CYAN}等待服务启动...${PLAIN}"
    for i in {1..30}; do
        if curl -s "http://127.0.0.1:$custom_port" >/dev/null; then
            echo -e "\n${GREEN}部署成功！您的 Sub-Store 信息如下：${PLAIN}"
            echo -e "${YELLOW}Sub-Store 面板：http://$public_ip:$custom_port${PLAIN}"
            echo -e "${YELLOW}后端地址：http://$public_ip:$custom_port/$secret_key${PLAIN}\n"
            echo "PORT=$custom_port" > "$SUBSTORE_INFO_PATH"
            echo "SECRET=$secret_key" >> "$SUBSTORE_INFO_PATH"
            echo "IP=$public_ip" >> "$SUBSTORE_INFO_PATH"
            return 0
        fi
        sleep 1
    done

    echo -e "${YELLOW}警告: 服务似乎未能在预期时间内启动，但可能仍在进行中。${PLAIN}"
    echo "PORT=$custom_port" > "$SUBSTORE_INFO_PATH"
    echo "SECRET=$secret_key" >> "$SUBSTORE_INFO_PATH"
    echo "IP=$public_ip" >> "$SUBSTORE_INFO_PATH"
    echo -e "${YELLOW}Sub-Store 面板：http://$public_ip:$custom_port${PLAIN}"
    echo -e "${YELLOW}后端地址：http://$public_ip:$custom_port/$secret_key${PLAIN}\n"
}

show_substore_info() {
    if [[ -f "$SUBSTORE_INFO_PATH" ]]; then
        source "$SUBSTORE_INFO_PATH"
        echo -e "${GREEN}Sub-Store 面板: ${CYAN}http://$IP:$PORT${PLAIN}"
        echo -e "${GREEN}后端地址: ${CYAN}http://$IP:$PORT/$SECRET${PLAIN}"
    else
        echo -e "${RED}Sub-Store 信息不存在，请先安装。${PLAIN}"
    fi
}

restart_substore() {
    if [[ ! -f "$SUBSTORE_COMPOSE_PATH" ]]; then
        echo -e "${RED}未检测到 Sub-Store 配置，无法重启。${PLAIN}"
        return 1
    fi
    cd /root/substore
    docker compose -f "$SUBSTORE_COMPOSE_PATH" -p sub-store restart
    echo -e "${GREEN}Sub-Store 已重启。${PLAIN}"
}

update_substore() {
    if [[ ! -f "$SUBSTORE_COMPOSE_PATH" ]]; then
        echo -e "${RED}未检测到 Sub-Store 配置，无法更新。${PLAIN}"
        return 1
    fi
    cd /root/substore
    echo -e "${CYAN}拉取最新 Sub-Store 镜像...${PLAIN}"
    docker compose -f "$SUBSTORE_COMPOSE_PATH" -p sub-store pull
    echo -e "${CYAN}重启 Sub-Store...${PLAIN}"
    docker compose -f "$SUBSTORE_COMPOSE_PATH" -p sub-store up -d
    echo -e "${GREEN}Sub-Store 已更新并重启。${PLAIN}"
}

delete_substore() {
    echo -e "${RED}即将删除 Sub-Store 及其所有数据，是否继续? [y/N]${PLAIN}"
    read -r confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        docker rm -f sub-store >/dev/null 2>&1 || true
        docker compose -f "$SUBSTORE_COMPOSE_PATH" -p sub-store down >/dev/null 2>&1 || true
        rm -rf /root/substore
        echo -e "${GREEN}Sub-Store 及相关数据已删除。${PLAIN}"
    else
        echo -e "${YELLOW}已取消删除。${PLAIN}"
    fi
}

substore_manage_menu() {
    while true; do
        clear
        echo -e "${MAGENTA}============== Sub-Store 管理 ==============${PLAIN}"
        echo -e "${GREEN}1.${PLAIN} 查看当前 Sub-Store 地址及后端"
        echo -e "${GREEN}2.${PLAIN} 重启 Sub-Store"
        echo -e "${GREEN}3.${PLAIN} 更新 Sub-Store"
        echo -e "${GREEN}4.${PLAIN} 删除 Sub-Store 及相关"
        echo -e "${GREEN}0.${PLAIN} 返回主菜单"
        read -p "请选择操作：" sub_choice
        case $sub_choice in
            1) show_substore_info; read -p "按回车键返回管理菜单..." ;;
            2) restart_substore; read -p "按回车键返回管理菜单..." ;;
            3) update_substore; read -p "按回车键返回管理菜单..." ;;
            4) delete_substore; read -p "按回车键返回管理菜单..." ;;
            0) break ;;
            *) echo -e "${RED}无效选项，请重新选择。${PLAIN}"; read -p "按回车键返回管理菜单..." ;;
        esac
        clear
    done
}

main_menu() {
    while true; do
        clear
        echo -e "${BLUE}=======================${PLAIN}"
        echo -e "${CYAN}      Sub-Store 脚本${PLAIN}"
        echo -e "${BLUE}=======================${PLAIN}"
        echo -e "${YELLOW}1.${PLAIN} 安装 Sub-Store"
        echo -e "${YELLOW}2.${PLAIN} 管理 Sub-Store"
        echo -e "${YELLOW}0.${PLAIN} 退出"
        read -p "请选择操作：" main_choice
        case $main_choice in
            1) install_substore; read -p "按回车键返回菜单..." ;;
            2) substore_manage_menu ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项，请重新选择。${PLAIN}"; read -p "按回车键返回菜单..." ;;
        esac
        clear
    done
}

trap 'echo -e "${RED}错误发生在第 $LINENO 行${PLAIN}"; exit 1' ERR

check_root
main_menu
