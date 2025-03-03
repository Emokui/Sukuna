### 收集脚本并添加cdn ###

#### 1. 3XUI ####

```
bash <(curl -Ls https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/3xui.sh)
```

#### 2. Snell ####

```
wget -O snell.sh --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/snell.sh && chmod +x snell.sh && ./snell.sh
```

#### 3. DD系统 ####

```
wget -N --no-check-certificate "https://fbi.hk.dedyn.io/Emokui/Sukuna//main/Linux/dd.sh"
chmod +x dd.sh
./dd.sh
```

#### 4. AliceDns ####

```
wget https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/alicedns.sh && bash alicedns.sh
```

#### 5. Acme ####

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/acme.sh && bash acme.sh
```

#### 6. Hysteria ####

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/hysteria.sh && bash hysteria.sh
```

#### 7. SubStore ####

```
bash <(curl -fsSL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/substore-docker.sh)
```

#### 8. Serv00 ####

```
https://raw.githubusercontent.com/Emokui/Sukuna/refs/heads/main/Linux/serv00.sh
curl -O "https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/serv00.sh"
chmod +x serv00.sh
./serv00.sh
```

