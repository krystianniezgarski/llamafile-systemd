# Linux-Lab — odtworzenie konfiguracji

Procedura przygotowania nowej maszyny przed wykonaniem PS2. Po wykonaniu tych kroków wróć do README.md, aby dodać usługę modelu i dostęp do portu 8080. Polecenia oznaczone „Ubuntu” wpisuj w konsoli maszyny w VirtualBox. `sudo` oznacza wykonanie polecenia z uprawnieniami administratora; hasło podczas wpisywania jest niewidoczne.

## 1. Maszyna i trzy karty — VirtualBox

Utwórz `Linux-Lab`: Ubuntu Server 24.04 LTS, RAM 4096 MB, 1 procesor, dysk 30 GB. Zainstaluj Ubuntu z ISO, utwórz użytkownika `student` i własne hasło. Po instalacji odłącz ISO, aby system uruchamiał się z dysku.

Przy wyłączonej maszynie:

1. W narzędziach VirtualBox otwórz menedżer sieci / **Network Manager → Host-only Networks**. Utwórz lub wybierz sieć host-only. Ustaw IPv4 gospodarza `192.168.56.1`, maskę `255.255.255.0`, wyłącz DHCP tej sieci.
2. W **Linux-Lab → Ustawienia → Sieć** włącz trzy karty i zaznacz przy każdej „Kabel podłączony”.

| Karta | Podłączona do | Ustawienie |
|---|---|---|
| 1 | NAT | Bez przekierowania portów |
| 2 | Host-only Adapter / Karta sieci izolowanej | VirtualBox Host-Only Ethernet Adapter |
| 3 | Bridged Adapter / Mostkowana | Fizyczna karta używana przez Windows do sieci, tutaj Wi-Fi |

Uruchom Ubuntu. Interfejs `lo` jest wewnętrzny i nie wlicza się do tych trzech kart.

## 2. Zapisz adresy swojej sieci

**Windows:** otwórz wiersz polecenia albo PowerShell i wykonaj:

```powershell
ipconfig
```

W przygotowanej konfiguracji:

| Element | Wartość |
|---|---|
| Windows w LAN | `10.224.25.241` |
| Podsieć LAN | `10.224.25.0/24` — maska `255.255.255.0` |
| Windows w host-only | `192.168.56.1/24` |
| Ubuntu w host-only | `192.168.56.10/24` |
| Ubuntu w NAT | `10.0.2.15/24` |
| Ubuntu w LAN | DHCP, podczas testów `10.224.25.184/24` |

Przy odtwarzaniu w innej sieci dopasuj adres Windowsa i podsieć LAN w regułach zapory z punktu 5. Wszystkie trzy podsieci muszą być różne; jeśli Twoja sieć już używa `10.0.2.0/24` albo `192.168.56.0/24`, trzeba zmienić także odpowiednią sieć VirtualBox i jej adresy w konfiguracji Ubuntu.

## 3. Pakiety — Ubuntu

Przed zmianą adresacji użyj początkowego połączenia przez NAT:

```bash
sudo apt update
sudo apt install -y openssh-server nftables curl
```

`openssh-server` umożliwia zdalne logowanie, `nftables` jest zaporą, a `curl` służy do sprawdzania HTTP. Podczas instalowania Ubuntu można również zaznaczyć opcję instalacji OpenSSH.

## 4. Adresy kart — Ubuntu

Odczytaj adresy MAC:

```bash
ip -br link
```

Przyporządkuj je do kart 1–3 w ustawieniach VirtualBox, w rozwinięciu „Zaawansowane”. W poniższym pliku są MAC obecnej maszyny. **Na nowej VM zastąp te trzy wartości jej własnymi adresami MAC.**

Zachowaj początkową konfigurację i wyłącz ponowne generowanie sieci przez cloud-init:

```bash
sudo mkdir -p /root/netplan-before-lab
sudo mv /etc/netplan/*.yaml /root/netplan-before-lab/
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

Utwórz konfigurację sieci:

```bash
sudo tee /etc/netplan/01-linux-lab.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    nat0:
      match: {macaddress: "08:00:27:2b:cd:4c"}
      set-name: nat0
      dhcp4: false
      dhcp6: false
      accept-ra: false
      link-local: []
      addresses: [10.0.2.15/24]
      routes:
        - {to: default, via: 10.0.2.2}
      nameservers: {addresses: [10.0.2.3]}
    host0:
      match: {macaddress: "08:00:27:56:00:10"}
      set-name: host0
      dhcp4: false
      dhcp6: false
      accept-ra: false
      link-local: []
      addresses: [192.168.56.10/24]
    lan0:
      match: {macaddress: "08:00:27:79:00:10"}
      set-name: lan0
      dhcp4: true
      dhcp6: false
      accept-ra: false
      link-local: []
      optional: true
      dhcp-identifier: mac
      dhcp4-overrides: {use-routes: false, use-dns: false}
EOF
sudo chmod 600 /etc/netplan/01-linux-lab.yaml
sudo netplan generate
sudo netplan apply
```

`match` przypisuje ustawienia do karty po MAC, a `set-name` nadaje jej nazwę. NAT i host-only mają stałe adresy. LAN dostaje adres przez DHCP, ale `use-routes: false` zapobiega dodaniu drugiej domyślnej trasy. Wyjście do Internetu prowadzi przez `10.0.2.2` na `nat0`.

Zmiany wykonuj z konsoli VirtualBox, ponieważ połączenie sieciowe może zostać przerwane podczas zmiany adresów.

## 5. Ograniczenie dostępu — Ubuntu

Wyłącz przekazywanie pakietów między kartami i IPv6:

```bash
sudo tee /etc/sysctl.d/99-linux-lab.conf > /dev/null <<'EOF'
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sudo sysctl --system
```

Zapisz zaporę. Przy odtwarzaniu dopasuj `10.224.25.241` do adresu Windowsa w LAN oraz `10.224.25.0/24` do swojej podsieci LAN:

```bash
sudo tee /etc/nftables.conf > /dev/null <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet lab {
 chain input {
  type filter hook input priority 0; policy drop;
  iifname "lo" accept
  ct state invalid drop
  iifname != "nat0" ip daddr 10.0.2.15 counter drop
  iifname != "host0" ip daddr 192.168.56.10 counter drop
  iifname "host0" ip daddr != 192.168.56.10 counter drop
  iifname "nat0" ip daddr != 10.0.2.15 counter drop
  iifname "lan0" ip saddr 10.224.25.241 counter drop
  ct state established,related accept
  iifname "lan0" udp sport 67 udp dport 68 accept
  iifname "host0" ip saddr 192.168.56.1 ip daddr 192.168.56.10 tcp dport 22 counter accept
  iifname "host0" ip saddr 192.168.56.1 ip daddr 192.168.56.10 icmp type echo-request counter accept
  iifname "lan0" ip saddr 10.224.25.0/24 tcp dport 22 counter accept
  iifname "lan0" ip saddr 10.224.25.0/24 icmp type echo-request counter accept
 }
 chain forward { type filter hook forward priority 0; policy drop; }
 chain output { type filter hook output priority 0; policy accept; }
}
EOF
sudo nft -c -f /etc/nftables.conf
sudo systemctl enable nftables
sudo systemctl restart nftables
```

`nft -c` sprawdza poprawność pliku bez zastosowania zmian. Jeśli zgłosi błąd, popraw go przed uruchomieniem zapory. Reguły zastępują istniejący zestaw nftables — procedura zakłada nową VM z jedną zaporą.

Znaczenie reguł:

- `policy drop`: domyślnie odrzucaj ruch przychodzący i przekazywany.
- `established,related`: wpuszczaj odpowiedzi na już nawiązane połączenia, np. pobieranie przez NAT.
- Reguły `iifname` i `ip daddr`: adres NAT i host-only wolno obsługiwać tylko na właściwej karcie.
- `host0`: pozwól Windowsowi `192.168.56.1` na SSH (`tcp/22`) i ping do `192.168.56.10`.
- `lan0`: pozwól na SSH i ping z LAN, ale najpierw zablokuj adres LAN gospodarza. Dzięki temu Windows używa tylko host-only.
- Reguła UDP `67 → 68`: pozwól karcie LAN odebrać konfigurację DHCP.
- Brak reguły dopuszczającej nowe połączenia na `nat0`: NAT służy do połączeń rozpoczynanych przez Ubuntu. Nie dodawaj przekierowań portów w VirtualBox.

## 6. SSH i automatyczny start — Ubuntu

```bash
sudo ssh-keygen -A
sudo systemctl enable --now ssh
systemctl is-active ssh nftables
```

`ssh-keygen -A` tworzy brakujące klucze identyfikujące serwer. `enable` ustawia start przy uruchomieniu systemu, a `--now` uruchamia usługę od razu. Oczekiwany wynik ostatniego polecenia: dwa razy `active`.

## 7. Sprawdzenie konfiguracji

**Ubuntu:**

```bash
ip -br -4 addr
ip -4 route
sudo ss -tlnp
sudo nft list ruleset
curl -I --max-time 20 https://ubuntu.com
```

Oczekuj trzech kart z różnych podsieci, jednej trasy `default via 10.0.2.2 dev nat0`, nasłuchiwania SSH na porcie 22 i odpowiedzi HTTP, np. `HTTP/2 200`. O dostępności SSH decyduje także zapora, nie sam wynik `ss`.

**PowerShell Windows:**

```powershell
ssh student@192.168.56.10
```

Potwierdź klucz serwera przy pierwszym połączeniu i podaj hasło konta `student`. W osobnym oknie PowerShella wykonaj:

```powershell
Test-NetConnection 192.168.56.10 -Port 22 -InformationLevel Quiet
Test-NetConnection 10.0.2.15 -Port 22 -InformationLevel Quiet
Test-NetConnection 10.224.25.184 -Port 22 -InformationLevel Quiet
```

Oczekiwane kolejno: **True, False, False**. W ostatnim poleceniu użyj aktualnego adresu `lan0`. Testy odmowy mogą potrwać kilkadziesiąt sekund.

**Inny komputer w tej samej sieci LAN:**

```bash
ssh student@10.224.25.184
```

Połączenie przez aktualny adres `lan0` powinno działać. Dostęp do `192.168.56.10` i `10.0.2.15` z LAN ma być zablokowany. Podczas wykonanych testów potwierdzono to z drugiej maszyny wirtualnej, także po dodaniu tras kierujących te adresy przez kartę LAN Linux-Lab.

Zapora nie dopuszcza nowych połączeń z adresów WAN. Nie wykonywano fizycznego testu z zewnętrznego łącza. Samo sprawdzenie prywatnego adresu z Internetu nie jest wystarczającym testem; pełny test wymaga uwzględnienia publicznego adresu i konfiguracji routera.

## 8. Wyłączanie, ponowny start i migawka

W Ubuntu wykonaj:

```bash
sudo poweroff
```

Poczekaj na stan „Wyłączona” w VirtualBox. Kliknij „Uruchom”, poczekaj około 2–3 minut i ponownie sprawdź SSH. W ten sposób sprawdzasz trwałość konfiguracji po ponownym starcie.

Po poprawnych testach wyłącz maszynę i utwórz w VirtualBox migawkę `Gotowy-lab`. Pozwala ona powtarzać uruchomienie od zapisanego stanu. Przywracanie migawki cofa późniejsze zmiany, również zmianę hasła.

Po zmianie sieci Wi-Fi albo adresu Windowsa w LAN dostosuj reguły w `/etc/nftables.conf`, sprawdź je przez `sudo nft -c -f /etc/nftables.conf` i uruchom `sudo systemctl restart nftables`.
