# PS2 — model językowy jako usługa systemd

Na VM **Linux-Lab, Ubuntu Server 24.04.3**, uruchomiono **Bonsai-1.7B jako llamafile 0.10.6**. Jeden plik zawiera silnik i wagi. Usługa działa jako użytkownik `llamafile`, startuje z systemem, jest automatycznie odtwarzana po awarii i udostępnia API tylko na **192.168.56.10:8080**.

Publiczne repozytorium: <https://github.com/krystianniezgarski/llamafile-systemd>. Zgodność z każdym punktem polecenia: [CHECKLIST.md](CHECKLIST.md).

Data testów: **26.10.2026**. Polecenie zadania: [ZADANIE.md](ZADANIE.md). Źródło modelu, przypięta wersja i SHA-256: [MODEL.md](MODEL.md).

## 1. Wymagania i sieć

VM z poprzedniego zadania: 4 GB RAM, 1 CPU, Ubuntu Server 24.04 LTS, SSH i zapora nftables. Wszystkie polecenia `sudo` wykonuje administrator VM. Sam model działa bez uprawnień roota.

Jeżeli zaczynasz od nowej maszyny, najpierw wykonaj [instrukcję utworzenia VM i trzech sieci](docs/VM-network.md). Następnie wróć do tego pliku.

| Karta VM | Tryb | Adres podczas testu |
|---|---|---|
| nat0 | NAT, wyjście do Internetu | 10.0.2.15/24 |
| host0 | Host-only | 192.168.56.10/24 |
| lan0 | Mostkowana do Wi-Fi, DHCP | 10.224.25.184/24 |

Windows w host-only: `192.168.56.1`. Windows w LAN podczas testu: `10.224.25.241`, podsieć `10.224.25.0/24`. Adresy LAN mogą się zmienić; przy odtwarzaniu dopasuj je do swojej sieci.

W Ubuntu sprawdź:

```bash
ip -br -4 addr
systemctl is-active ssh nftables
sudo apt update
sudo apt install -y curl git openssh-server nftables python3
```

## 2. Przeniesienie projektu i modelu

Na nowej VM pobierz projekt z publicznego GitHub:

```bash
git clone https://github.com/krystianniezgarski/llamafile-systemd.git
```

Alternatywnie skopiuj lokalny katalog z Windowsa przez `scp`. Przykład z PowerShella Windows:

```powershell
scp -r .\llamafile-systemd student@192.168.56.10:/home/student/
```

W Ubuntu:

```bash
cd /home/student/llamafile-systemd
source config/model.env
curl --fail --location --retry 3 --output model.llamafile "$MODEL_URL"
printf '%s  %s\n' "$MODEL_SHA256" model.llamafile | sha256sum --check
```

Oczekiwane: `model.llamafile: OK`. Plik ma około 292 MB. ZIP z kodem źródłowym nie zastępuje tego gotowego pliku.

Podczas wykonanego wdrożenia model pobrano na Windowsie, sprawdzono SHA-256 i przesłano przez `scp` do `/home/student/ps2/model.llamafile`. Odpowiednik polecenia transferu:

```powershell
scp .\Bonsai-1.7B.llamafile student@192.168.56.10:/home/student/model.llamafile
```

Następnie można wskazać ten plik skryptowi instalacyjnemu zamiast ponownie go pobierać.

## 3. Instalacja usługi

Jeśli od poprzedniego zadania zmienił się adres Windowsa lub podsieć LAN, zaktualizuj poprzednie reguły. Użyj rzeczywistych wartości odczytanych z `ipconfig` w Windowsie, np.:

```bash
sudo python3 scripts/update-lan-firewall.py 10.224.25.241 10.224.25.0/24
```

Zainstaluj model i usługę:

```bash
sudo bash scripts/install.sh "$PWD/model.llamafile"
```

Skrypt jest powtarzalny: sprawdza SHA-256, tworzy konto tylko wtedy, gdy go brakuje, zachowuje kopię zapory i nie dodaje drugi raz reguły portu 8080. Bez argumentu sam pobiera model przez `curl`.

Najważniejsze operacje wykonywane przez skrypt:

```bash
# Osobne konto systemowe bez logowania interaktywnego:
sudo useradd --system --user-group --no-create-home \
  --home-dir /var/lib/llamafile --shell /usr/sbin/nologin llamafile

# Program jest własnością roota, ale ma być uruchamiany przez konto usługi:
sudo install -d /opt/llamafile
sudo install -o root -g root -m 0755 model.llamafile /opt/llamafile/model.llamafile
sudo install -d -o llamafile -g llamafile -m 0750 /var/lib/llamafile
sudo install -m 0644 config/llamafile.service /etc/systemd/system/llamafile.service
sudo systemd-analyze verify /etc/systemd/system/llamafile.service
sudo systemctl daemon-reload
sudo systemctl enable --now llamafile
```

Powyższa lista wyjaśnia instalator; po uruchomieniu `install.sh` nie trzeba wykonywać jej ponownie. Zapis modelu jako `root:root` nie oznacza uruchamiania go jako root — o użytkowniku procesu decyduje `User=`.

### Jednostka systemd

Plik [config/llamafile.service](config/llamafile.service):

```ini
[Unit]
Description=Llamafile Bonsai-1.7B REST API (host-only)
After=network-online.target nftables.service
Wants=network-online.target

[Service]
Type=simple
User=llamafile
Group=llamafile
StateDirectory=llamafile
StateDirectoryMode=0750
WorkingDirectory=/var/lib/llamafile
Environment=HOME=/var/lib/llamafile
ExecStart=/bin/sh /opt/llamafile/model.llamafile --server --host 192.168.56.10 --port 8080 --gpu disable --ctx-size 2048 --threads 1 --parallel 1 --alias bonsai-lab
Restart=on-failure
RestartSec=3s
TimeoutStopSec=30s
MemoryAccounting=yes
LimitCORE=0
UMask=0027
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=multi-user.target
```

- `User=` i `Group=`: proces działa jako `llamafile`, nie root. W testowanej VM UID wynosił 999.
- `After=` / `Wants=`: start po przygotowaniu sieci.
- `StateDirectory=`: zapisywalny katalog danych `/var/lib/llamafile` dla cache i loadera APE.
- `/bin/sh`: uruchamia przenośny format wykonywalny llamafile na Linuksie.
- `--host 192.168.56.10`: nasłuchiwanie tylko na adresie host-only, bez `0.0.0.0`.
- `--gpu disable`, `--threads 1`, `--ctx-size 2048`: ustawienia małej VM bez GPU.
- `Restart=on-failure`: restart po awarii; `RestartSec=3s`: trzy sekundy przerwy.
- `WantedBy=multi-user.target` wraz z `enable`: uruchamianie przy starcie systemu.

Wersja 0.10.6 nie wymaga `--nobrowser` z szablonu zadania; użyto obsługiwanego trybu `--server`. Szczegóły są w [MODEL.md](MODEL.md).

### Zapora

Do łańcucha `input` w istniejącym `/etc/nftables.conf` instalator dodaje tylko:

```nft
iifname "host0" ip saddr 192.168.56.1 ip daddr 192.168.56.10 tcp dport 8080 counter accept
```

Następnie sprawdza plik i ładuje trwałą konfigurację:

```bash
sudo nft --check --file /etc/nftables.conf
sudo systemctl enable nftables
sudo systemctl restart nftables
```

Reguły z zadania 1 nadal odrzucają próby dostępu do adresu host-only przez inne karty. Połączenie ogranicza zarówno adres nasłuchiwania programu, jak i zapora. Nie dodano przekierowania portu NAT.

## 4. Zapytanie do API z gospodarza

W katalogu repozytorium w PowerShellu Windows:

```powershell
curl.exe --fail-with-body --header "Content-Type: application/json" `
  --data-binary "@examples/request.json" `
  http://192.168.56.10:8080/v1/chat/completions
```

Odpowiednik w terminalu Ubuntu, z katalogu repozytorium:

```bash
curl --fail-with-body -H 'Content-Type: application/json' \
  --data-binary @examples/request.json \
  http://192.168.56.10:8080/v1/chat/completions
```

Treść [examples/request.json](examples/request.json) pyta o stolicę Polski. Rzeczywista odpowiedź HTTP 200 z Windowsa, czas pierwszego żądania około 13,2 s:

```json
{
  "model": "bonsai-lab",
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Warsaw is the capital of Poland."
      }
    }
  ],
  "usage": {
    "completion_tokens": 9,
    "prompt_tokens": 39,
    "total_tokens": 48,
    "prompt_tokens_details": {
      "cached_tokens": 0
    }
  }
}
```

Wygenerowana odpowiedź modelu: **Warsaw is the capital of Poland.**. Pełne dane z tokenami i czasami są w [evidence/response.json](evidence/response.json).

## 5. Proces, port i pamięć — rzeczywiste wyniki

Polecenia w Ubuntu:

```bash
getent passwd llamafile
systemctl show llamafile -p User -p Group -p MainPID
sudo ss -tlnp
systemctl status llamafile --no-pager --full
journalctl -u llamafile -f
```

`journalctl -f` śledzi nowe wpisy; zakończ podgląd przez Ctrl+C. Wynik `ss -tlnp`:

```text
State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
LISTEN 0      4096   127.0.0.53%lo:53        0.0.0.0:*    users:(("systemd-resolve",pid=463,fd=15))
LISTEN 0      128    192.168.56.10:8080      0.0.0.0:*    users:((".ape-1.10",pid=2042,fd=3))
LISTEN 0      4096      127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=463,fd=17))
LISTEN 0      4096         0.0.0.0:22        0.0.0.0:*    users:(("sshd",pid=884,fd=3),("systemd",pid=1,fd=142))
LISTEN 0      4096            [::]:22           [::]:*    users:(("sshd",pid=884,fd=4),("systemd",pid=1,fd=144))
```

Port 8080 jest przypisany wyłącznie do `192.168.56.10`. Pozostałe wpisy dotyczą SSH i lokalnego DNS Ubuntu.

Fragment `systemctl status` po automatycznym odtworzeniu procesu:

```text
● llamafile.service - Llamafile Bonsai-1.7B REST API (host-only)
     Loaded: loaded (/etc/systemd/system/llamafile.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-10-26 22:20:38 CET; 5s ago
   Main PID: 2042 (.ape-1.10)
      Tasks: 10 (limit: 4606)
     Memory: 275.1M (peak: 275.4M)
        CPU: 3.585s
     CGroup: /system.slice/llamafile.service
             └─2042 /var/lib/llamafile/.ape-1.10 /opt/llamafile/model.llamafile --server --host 192.168.56.10 --port 8080 --gpu disable --ctx-size 2048 --threads 1 --parallel 1 --alias bonsai-lab

```

W tej próbce pamięć wynosiła **275,1 MiB**, szczyt **275,4 MiB**. Pamięć zmienia się w czasie i zależy od kontekstu/żądań. Zrzuty: [systemctl-status.txt](evidence/systemctl-status.txt), [systemctl-show.txt](evidence/systemctl-show.txt), [processes.txt](evidence/processes.txt).

## 6. Restart po zabiciu procesu

Gotowy test w Ubuntu:

```bash
sudo bash scripts/test-restart.sh ./evidence
```

Skrypt odczytuje `MainPID` i `NRestarts`, wykonuje `kill -KILL` wyłącznie dla procesu tej usługi i czeka na nowy PID oraz zdrowe API. Ręczny odpowiednik:

```bash
systemctl show llamafile -p MainPID -p NRestarts
sudo kill -KILL "$(systemctl show llamafile -p MainPID --value)"
sleep 10
systemctl show llamafile -p MainPID -p NRestarts
curl --fail http://192.168.56.10:8080/health
```

Użyto SIGKILL (`-KILL`, równoważnie `-9`), aby zasymulować awarię. Zwykły SIGTERM może być traktowany jako poprawne zakończenie przy `Restart=on-failure`. Celowe `systemctl stop` nie jest testem awarii i nie wywołuje automatycznego restartu.

Wynik wykonanego testu:

```text
Before: MainPID=1697 NRestarts=0
Command: kill -KILL 1697
{"status":"ok"}
After: MainPID=2042 NRestarts=1
PASS: systemd restarted the service and HTTP API is healthy.
```

## 7. Automatyczny start po restarcie VM

```bash
cat /proc/sys/kernel/random/boot_id
systemctl is-enabled llamafile
sudo reboot
```

Po ponownym połączeniu przez SSH:

```bash
cat /proc/sys/kernel/random/boot_id
systemctl is-active llamafile
curl --fail http://192.168.56.10:8080/health
```

W wykonanym teście identyfikator rozruchu zmienił się z `099fb61b-f256-4cab-8a04-6655541cf3a3` na `a5813368-f2c4-46cb-a42a-0966b9f367a0`. Usługa miała stan `enabled` i uruchomiła się bez ręcznego `start`; API zwróciło `{"status":"ok"}`. Dowody: [reboot-test.json](evidence/reboot-test.json), [after-reboot.txt](evidence/after-reboot.txt).

## 8. Ograniczenie dostępu do API

W PowerShellu Windows (ostatni adres zastąp aktualnym `lan0`):

```powershell
Test-NetConnection 192.168.56.10 -Port 8080 -InformationLevel Quiet
Test-NetConnection 10.0.2.15 -Port 8080 -InformationLevel Quiet
Test-NetConnection 10.224.25.184 -Port 8080 -InformationLevel Quiet
```

Oczekiwane i uzyskane wyniki: **True, False, False**. Możesz też uruchomić test standardowym Pythonem na Windowsie:

```powershell
python scripts/test-access.py 10.224.25.184
```

Wynik zapisuje się w [windows-access.json](evidence/windows-access.json). Dodatkowo wewnątrz VM próby HTTP do jej adresów NAT i LAN zakończyły się odmową połączenia — [guest-other-addresses.txt](evidence/guest-other-addresses.txt). Potwierdza to, że sam serwer nie nasłuchuje na pozostałych adresach.

## 9. Zapis dowodów i Git

W Ubuntu:

```bash
sudo bash scripts/collect-evidence.sh ./evidence
```

Skrypt zbiera m.in. jednostkę, `ss -tlnp`, stan systemd z pamięcią, użytkownika, zaporę i dziennik. Dokumentacja i zebrane wyniki są wersjonowane; duży model jest pomijany przez `.gitignore` i odtwarzany z przypiętego URL/SHA-256.

Pliki, które należy umieścić we własnym repozytorium: `README.md`, `ZADANIE.md`, `MODEL.md`, `.gitignore`, `.gitattributes`, katalogi `config/`, `scripts/`, `examples/`, `evidence/`, `docs/`. Repozytorium nie zawiera haseł ani kluczy SSH.

Po utworzeniu pustego repozytorium na własnym GitHub dodaj jego adres w PowerShellu, z katalogu tego projektu:

```powershell
git remote add origin <ADRES_WLASNEGO_REPOZYTORIUM>
git push -u origin main
```

GitHub jest osobnym krokiem publikacji. Samo lokalne `git init` nie wysyła plików do Internetu.
