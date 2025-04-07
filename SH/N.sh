#!/bin/bash

# 定义可执行路径
Mihomo_PATH="./clash/mihomo"
CONFIG_PATH="/root/clash/config.yaml"

# 显示菜单
while true; do
    echo "请选择操作："
    echo "1) 停止 Mihomo"
    echo "2) 启动 Mihomo"
    echo "3) 重启 Mihomo"
    echo "4) 退出"
    read -p "请输入选项 [1-4]: " choice

    case $choice in
        1)
            # 停止 Mihomo
            echo "[*] 停止 Mihomo..."
            pkill mihomo
            echo "[*] Mihomo 已停止。"
            ;;
        2)
            # 启动 Mihomo
            echo "[*] 启动 Mihomo..."
            $Mihomo_PATH -f $CONFIG_PATH
            echo "[*] Mihomo 已启动。"
            ;;
        3)
            # 重启 Mihomo
            echo "[*] 重启 Mihomo..."
            pkill mihomo
            sleep 2
            $Mihomo_PATH -f $CONFIG_PATH
            echo "[*] Mihomo 已重启。"
            ;;
        4)
            # 退出脚本
            echo "[*] 退出脚本..."
            break
            ;;
        *)
            echo "无效选项，请重新选择。"
            ;;
    esac
done
