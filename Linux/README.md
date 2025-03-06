### CDN命令 ###


### 1. 3XUI ###

```
bash <(curl -Ls https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/3xui.sh)
```

### 2. Snell ###

```
wget -O snell.sh --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/snell.sh && chmod +x snell.sh && ./snell.sh
```

### 3. DD系统 ###

```
wget -N --no-check-certificate "https://fbi.hk.dedyn.io/Emokui/Sukuna//main/Linux/dd.sh"
chmod +x dd.sh
./dd.sh
```

**dd系统后安装 sudo 与 curl**

```
apt-get install sudo
sudo apt install curl -y
```

### 4. AliceDns ###

```
wget https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/alicedns.sh && bash alicedns.sh
```

### 5. Acme ###

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/acme.sh && bash acme.sh
```

### 6. Hysteria ###

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/hysteria.sh && bash hysteria.sh
```

### 7. SubStore ###
**docker一件部署**
```
bash <(curl -fsSL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/substore-docker.sh)
```

### 8. Serv00 ###
**serv00重置**
```
curl -O "https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/serv00.sh"
chmod +x serv00.sh
./serv00.sh
```

