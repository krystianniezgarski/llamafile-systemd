# Pracownia specjalistyczna 2 — uruchomienie usługi na Linuksie

Źródło polecenia: [strona zajęć](https://cez.wi.pb.edu.pl/course/section.php?id=5877), treść przekazana przez prowadzącego i użytkownika.

Każdy członek grupy zamieszcza zadanie wraz z poleceniami w swoim repozytorium Git.

Definicja ukończenia:

- Uruchomienie gotowego modelu uczenia maszynowego na systemie Linuksowym.
- Na maszynie wirtualnej z poprzedniego zadania uruchomienie gotowego modelu językowego jako pliku `llamafile` i usługi `systemd`.
- Jeden plik wykonywalny zawiera wagi modelu, silnik uruchomieniowy oraz serwer HTTP z REST API.
- Model przesłany z gospodarza przez `scp`/`rsync` albo pobrany na VM przez `curl`.
- Usługa działa jako osobny użytkownik systemowy, nie jako root.
- Jednostka `systemd` uruchamia usługę automatycznie po restarcie maszyny.
- Po zabiciu procesu poleceniem `kill` systemd sam uruchamia usługę ponownie.
- REST API jest osiągalne z gospodarza przez adres host-only i nieosiągalne przez pozostałe adresy VM.
- Dokumentacja zawiera jednostkę, wynik `ss -tlnp`, przykładowe zapytanie `curl` z odpowiedzią modelu i zużycie pamięci odczytane z `systemctl status` lub `top`.
- Instrukcja pozwala innej osobie powtórzyć zadanie na nowej VM.

Szablon z polecenia:

```ini
[Unit]
Description=unit
After=network-online.target
Wants=network-online.target

[Service]
User=llamafile
ExecStart=/opt/llamafile/model.llamafile --server --nobrowser --host <adres-host-only> --port 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Pomocnicze polecenia z polecenia zadania:

```bash
sudo useradd --system --no-create-home llamafile
sudo systemctl daemon-reload
journalctl -u llamafile -f
ps aux | grep llamafile
ss -tlnp
```

Zastosowana i przetestowana jednostka jest w `config/llamafile.service`; różnice względem szablonu i kompletna procedura są opisane w `README.md` i `MODEL.md`.
