#### DD系統 ####

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


#### ACME ####

```
wget -N --no-check-certificate https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/acme.sh && bash acme.sh
```


#### SubStore ####
**docker**
```
bash <(curl -fsSL https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/substore.sh)
```

#### Serv00 ####
**serv00重置**
```
curl -O "https://fbi.hk.dedyn.io/Emokui/Sukuna/main/Linux/serv00.sh"
chmod +x serv00.sh
./serv00.sh
```

