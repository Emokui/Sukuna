#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

sh_ver="1.7.0"
snell_v3="3.0.1"
snell_v4="4.1.1"
script_dir=$(cd "$(dirname "$0")"; pwd)
snell_dir="/root/snell"
snell_bin="${snell_dir}/snell-server"
snell_conf="${snell_dir}/config.conf"
snell_version_file="${snell_dir}/ver.txt"
sysctl_conf="/etc/sysctl.d/local.conf"

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Yellow_font_prefix="\033[0;33m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

checkRoot(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作。" && exit 1
}

sysArch() {
    uname=$(uname -m)
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        arch="i386"
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        arch="armv7l"
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        arch="aarch64"
    else
        arch="amd64"
    fi    
}

installDependencies(){
    if command -v apt &>/dev/null; then
        apt update -y
        apt install -y wget unzip jq gzip curl
    elif command -v yum &>/dev/null; then
        yum install -y wget unzip jq gzip curl
    elif command -v dnf &>/dev/null; then
        dnf install -y wget unzip jq gzip curl
    elif command -v apk &>/dev/null; then
        apk add wget unzip jq gzip curl
    fi
}

enableTCPFastOpen() {
    kernel=$(uname -r | awk -F . '{print $1}')
    if [ "$kernel" -ge 3 ]; then
        sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1
        if ! grep -q "^net.ipv4.tcp_fastopen" "$sysctl_conf" 2>/dev/null; then
            echo "net.ipv4.tcp_fastopen = 3" >> "$sysctl_conf"
        else
            sed -i 's/^net.ipv4.tcp_fastopen.*/net.ipv4.tcp_fastopen = 3/' "$sysctl_conf"
        fi
        sysctl --system >/dev/null 2>&1
    else
        echo -e "$Error 系统内核版本过低，无法支持 TCP Fast Open！"
    fi
}

setupService(){
cat > /etc/systemd/system/snell-server.service <<EOF
[Unit]
Description=Snell Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
LimitNOFILE=32767 
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStartPre=/bin/sh -c 'ulimit -n 51200'
ExecStart=${snell_bin} -c ${snell_conf}
[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable --now snell-server
}

writeConfig(){
    if [[ -f "${snell_conf}" ]]; then
        cp "${snell_conf}" "${snell_dir}/config.conf.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    cat > "${snell_conf}" << EOF
[snell-server]
listen = ::0:${port}
ipv6 = ${ipv6}
psk = ${psk}
obfs = ${obfs}
$(if [[ ${obfs} != "off" ]]; then echo "obfs-host = ${host}"; fi)
tfo = ${tfo}
dns = ${dns}
version = ${ver}
EOF
}

readConfig(){
	[[ ! -e ${snell_conf} ]] && echo -e "${Error} Snell Server 配置文件不存在！" && exit 1
	ipv6=$(grep 'ipv6 = ' ${snell_conf}|awk -F 'ipv6 = ' '{print $NF}')
	port=$(grep -E '^listen\s*=' ${snell_conf} | awk -F ':' '{print $NF}' | xargs)
	psk=$(grep 'psk = ' ${snell_conf}|awk -F 'psk = ' '{print $NF}')
	obfs=$(grep 'obfs = ' ${snell_conf}|awk -F 'obfs = ' '{print $NF}')
	host=$(grep 'obfs-host = ' ${snell_conf}|awk -F 'obfs-host = ' '{print $NF}')
	tfo=$(grep 'tfo = ' ${snell_conf}|awk -F 'tfo = ' '{print $NF}')
	dns=$(grep 'dns = ' ${snell_conf}|awk -F 'dns = ' '{print $NF}')
	ver=$(grep 'version = ' ${snell_conf}|awk -F 'version = ' '{print $NF}')
}

setPort(){
    while true; do
        echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
        echo -e "请输入 Snell Server 端口${Yellow_font_prefix}[1-65535]${Font_color_suffix}"
        read -e -p "(默认: 2345):" port
        [[ -z "${port}" ]] && port="2345"
        if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 && $port -le 65535 ]]; then
            if ss -tuln | grep -E "\b:$port\b" >/dev/null; then
                echo -e "${Error} 端口 $port 已被占用，请选择其他端口。"
            else
                break
            fi
        else
            echo "输入错误, 请输入正确的端口号。"
        fi
    done
}

setPSK(){
	echo "请输入 Snell Server 密钥 [0-9][a-z][A-Z] "
	read -e -p "(默认: 随机生成):" psk
	[[ -z "${psk}" ]] && psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
}

setObfs(){
    echo -e "配置 OBFS，${Tip} 无特殊作用不建议启用该项。
==================================
${Green_font_prefix} 1.${Font_color_suffix} TLS  ${Green_font_prefix} 2.${Font_color_suffix} HTTP ${Green_font_prefix} 3.${Font_color_suffix} 关闭
=================================="
    read -e -p "(默认：3.关闭)：" obfs
    [[ -z "${obfs}" ]] && obfs="3"
    if [[ ${obfs} == "1" ]]; then
        obfs="tls"
        setHost
    elif [[ ${obfs} == "2" ]]; then
        obfs="http"
        setHost
    else
        obfs="off"
        host=""
    fi
}

setHost(){
	read -e -p "请输入 OBFS 域名 (默认: icloud.com):" host
	[[ -z "${host}" ]] && host="icloud.com"
}

setIpv6(){
	read -e -p "是否开启 IPv6 解析？[y/N] (默认: false):" ipv6
	[[ -z "${ipv6}" ]] && ipv6="false"
	[[ "$ipv6" == "y" || "$ipv6" == "Y" ]] && ipv6="true" || ipv6="false"
}

setTFO(){
    read -e -p "是否开启 TCP Fast Open？[y/N] (默认: true):" tfo
    if [[ -z "${tfo}" || "$tfo" == "y" || "$tfo" == "Y" ]]; then
        tfo="true"
        enableTCPFastOpen
    else
        tfo="false"
    fi
}

setDNS(){
	read -e -p "请输入 DNS (默认: 1.1.1.1,8.8.8.8,2001:4860:4860::8888):" dns
	[[ -z "${dns}" ]] && dns="1.1.1.1, 8.8.8.8, 2001:4860:4860::8888"
}

setVer(){
	if [[ "$ver_install" == "3" ]]; then
		ver="3"
	else
		ver="4"
	fi
}

installSnell(){
    mkdir -p "${snell_dir}"
    sysArch
    installDependencies
    echo -e "请选择安装 Snell 版本：
${Green_font_prefix}3.${Font_color_suffix} v3  ${Green_font_prefix}4.${Font_color_suffix} v4"
    read -e -p "(默认: 4):" ver_install
    [[ -z "${ver_install}" ]] && ver_install="4"
    if [[ "${ver_install}" == "3" ]]; then
        snell_version="${snell_v3}"
        downloadSnellV3
    else
        snell_version="${snell_v4}"
        downloadSnellV4
    fi
    setPort
    setPSK
    setObfs
    setIpv6
    setTFO
    setDNS
    setVer
    writeConfig
    setupService
    echo -e "${Info} Snell Server 安装完成并已启动！"
    sleep 2
    startMenu
}

downloadSnellV3(){
    sysArch
    url="https://raw.githubusercontent.com/xOS/Others/master/snell/v3.0.1/snell-server-v3.0.1-linux-${arch}.zip"
    wget --no-check-certificate -O "${snell_dir}/snell-server-v3.zip" "$url"
    unzip -o "${snell_dir}/snell-server-v3.zip" -d "$snell_dir"
    chmod +x "${snell_dir}/snell-server"
    rm -f "${snell_dir}/snell-server-v3.zip"
    echo "v3.0.1" > "${snell_version_file}"
}

downloadSnellV4(){
    sysArch
    url="https://dl.nssurge.com/snell/snell-server-v${snell_v4}-linux-${arch}.zip"
    wget --no-check-certificate -O "${snell_dir}/snell-server-v4.zip" "$url"
    unzip -o "${snell_dir}/snell-server-v4.zip" -d "$snell_dir"
    chmod +x "${snell_dir}/snell-server"
    rm -f "${snell_dir}/snell-server-v4.zip"
    echo "v${snell_v4}" > "${snell_version_file}"
}

checkInstalledStatus(){
	[[ ! -e ${snell_bin} ]] && echo -e "${Error} Snell Server 没有安装，请检查！" && exit 1
}

checkStatus(){
    if systemctl is-active snell-server.service &> /dev/null; then
        status="running"
    else
        status="stopped"
    fi
}

startSnell(){
    checkInstalledStatus
    systemctl start snell-server
    echo -e "${Info} Snell Server 已启动"
    sleep 2
    startMenu
}
stopSnell(){
    checkInstalledStatus
    systemctl stop snell-server
    echo -e "${Info} Snell Server 已停止"
    sleep 2
    startMenu
}
restartSnell(){
    checkInstalledStatus
    systemctl restart snell-server
    echo -e "${Info} Snell Server 已重启"
    sleep 2
    startMenu
}
viewConfig(){
    checkInstalledStatus
    readConfig
    echo
    echo -e "Snell 配置信息："
    echo -e "端口: ${port}"
    echo -e "密钥: ${psk}"
    echo -e "OBFS: ${obfs}"
    echo -e "OBFS 域名: ${host}"
    echo -e "IPv6: ${ipv6}"
    echo -e "TFO: ${tfo}"
    echo -e "DNS: ${dns}"
    echo -e "协议版本: v${ver}"
    echo
    read -p "按回车返回主菜单..."
    startMenu
}
viewStatus(){
    systemctl status snell-server
    read -p "按回车返回主菜单..."
    startMenu
}

setConfig(){
    checkInstalledStatus
    readConfig
    echo "1. 修改端口"
    echo "2. 修改密钥"
    echo "3. 配置 OBFS"
    echo "4. 配置 OBFS 域名"
    echo "5. 开关 IPv6"
    echo "6. 开关 TFO"
    echo "7. 配置 DNS"
    echo "8. 配置协议版本"
    echo "9. 修改全部"
    read -p "请选择(1-9, 默认取消): " modify
    [[ -z "${modify}" ]] && startMenu
    case "$modify" in
        1) setPort;;
        2) setPSK;;
        3) setObfs;;
        4) setHost;;
        5) setIpv6;;
        6) setTFO;;
        7) setDNS;;
        8) setVer;;
        9) setPort; setPSK; setObfs; setIpv6; setTFO; setDNS; setVer;;
        *) startMenu;;
    esac
    writeConfig
    restartSnell
}

uninstallSnell(){
    checkInstalledStatus
    echo "确定要卸载 Snell Server 并删除所有配置文件吗? (y/N)"
    read -e -p "(默认: n):" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        systemctl stop snell-server
        systemctl disable snell-server
        rm -rf "${snell_dir}"
        rm -f /etc/systemd/system/snell-server.service
        systemctl daemon-reload
        echo && echo "Snell Server 及所有配置已彻底卸载！" && echo
    fi
    sleep 2
    startMenu
}

updateSnell(){
    checkInstalledStatus
    readConfig
    if [[ "$ver" == "3" ]]; then
        echo -e "${Error} Snell v3 不支持自动更新。"
        sleep 2
        startMenu
        return
    fi

    # 只抓取 amd64 架構的最新下載連結
    download_url=$(curl -s https://manual.nssurge.com/others/snell.html | grep -oE "https://dl\.nssurge\.com/snell/snell-server-v[0-9]+\.[0-9]+\.[0-9]+-linux-amd64\.zip" | head -n1)
    if [[ -z "$download_url" ]]; then
        echo -e "${Error} 无法获取最新版 Snell 下载链接，请稍后再试或检查网络。"
        sleep 2
        startMenu
        return
    fi

    # 解析最新版號
    latest_version=$(echo "$download_url" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    # 當前已裝版本
    current_version=$(cat "${snell_version_file}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

    if [[ "$current_version" == "$latest_version" ]]; then
        echo -e "${Info} 当前已是最新版 Snell v${latest_version}，无需更新。"
        sleep 2
        startMenu
        return
    fi

    echo -e "${Info} 检测到 Snell v4 可更新: 当前版本 v${current_version}，最新版本 v${latest_version}"
    tmpfile="${snell_dir}/snell-server-v4-update.zip"
    echo -e "${Info} 开始下载新版 Snell v${latest_version}..."
    wget --no-check-certificate -O "$tmpfile" "$download_url"
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 下载新版 Snell 失败，请检查网络或稍后再试。"
        rm -f "$tmpfile"
        sleep 2
        startMenu
        return
    fi
    unzip -o "$tmpfile" -d "$snell_dir"
    chmod +x "${snell_dir}/snell-server"
    rm -f "$tmpfile"
    echo "v${latest_version}" > "${snell_version_file}"
    # 更新配置里的 version 字段
    sed -i "s/^version = .*/version = 4/" "$snell_conf"
    echo -e "${Info} Snell v4 已更新至 v${latest_version}，服务即将重启..."
    systemctl restart snell-server
    sleep 2
    startMenu
}

startMenu(){
    clear
    checkRoot
    sysArch
    echo -e "  
==============================
Snell Server 管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
==============================
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 Snell Server
 ${Green_font_prefix} 2.${Font_color_suffix} 卸载 Snell Server
——————————————————————————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启动 Snell Server
 ${Green_font_prefix} 4.${Font_color_suffix} 停止 Snell Server
 ${Green_font_prefix} 5.${Font_color_suffix} 重启 Snell Server
——————————————————————————————
 ${Green_font_prefix} 6.${Font_color_suffix} 设置 配置信息
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix} 8.${Font_color_suffix} 查看 运行状态
——————————————————————————————
 ${Green_font_prefix} 9.${Font_color_suffix} 更新 Snell
 ${Green_font_prefix} 0.${Font_color_suffix} 退出脚本
==============================" && echo
    if [[ -e ${snell_bin} ]]; then
        checkStatus
        if [[ "$status" == "running" ]]; then
            echo -e " 当前状态: ${Green_font_prefix}已安装${Yellow_font_prefix}[$(cat ${snell_version_file})]${Font_color_suffix}并${Green_font_prefix}已启动${Font_color_suffix}"
        else
            echo -e " 当前状态: ${Green_font_prefix}已安装${Yellow_font_prefix}[$(cat ${snell_version_file})]${Font_color_suffix}但${Red_font_prefix}未启动${Font_color_suffix}"
        fi
    else
        echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
    fi
    echo
    read -e -p " 请输入数字[0-9]:" num
    case "$num" in
        1) installSnell;;
        2) uninstallSnell;;
        3) startSnell;;
        4) stopSnell;;
        5) restartSnell;;
        6) setConfig;;
        7) viewConfig;;
        8) viewStatus;;
        9) updateSnell;;
        0) exit 0;;
        *) startMenu;;
    esac
}

startMenu
