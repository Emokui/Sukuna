### CDN脚本命令 ###


##### 3XUI ####

```
bash <(curl -Ls https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/3xui.sh)
```

#### Snell ####

```
wget -O snell.sh --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/snell.sh && chmod +x snell.sh && ./snell.sh
```

#### DD system ####

```
wget -N --no-check-certificate "https://fbi.hk.dedyn.io/Emokui/Sukuna//main/Linux/dd.sh"
chmod +x dd.sh
./dd.sh
```

**install sudo and curl**

```
apt-get install sudo
sudo apt install curl -y
```

#### AliceDNS ####

```
wget https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/alicedns.sh && bash alicedns.sh
```

#### ACME ####

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/acme.sh && bash acme.sh
```

#### Hysteria ####

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/hysteria.sh && bash hysteria.sh
```

#### SubStore ####
**docker**
```
bash <(curl -fsSL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/substore-docker.sh)
```

#### Serv00 ####
**serv00重置**
```
curl -O "https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/serv00.sh"
chmod +x serv00.sh
./serv00.sh
```

