# Sprawdzenie definicji ukończenia

Testy wykonano 26.10.2026 na Linux-Lab. Każdy punkt poniżej odsyła do konfiguracji lub rzeczywistego wyniku, a nie do przykładowego zrzutu.

| Wymaganie | Wynik i dowód |
|---|---|
| Gotowy model językowy uruchomiony na Linuksie | Bonsai-1.7B; [wersja programu](evidence/model-version.txt), [dziennik ładowania wag](evidence/journal.txt), [odpowiedź modelu](evidence/response.json) |
| Jeden plik zawiera silnik i wagi | Gotowy pakiet Mozilla.ai; [źródło, rozmiar i SHA-256](MODEL.md), [suma pliku na VM](evidence/model-sha256.txt); dziennik wskazuje model `/zip/Bonsai-1.7B.gguf` wewnątrz pakietu |
| Model przesłany przez scp albo pobrany przez curl | Podczas wdrożenia użyto `scp` z Windowsa; [polecenia transferu i alternatywnego pobrania](README.md#2-przeniesienie-projektu-i-modelu), [powtarzalny instalator](scripts/install.sh) |
| Osobny użytkownik systemowy, nie root | `llamafile`, UID 999; [konto](evidence/service-user.txt), [użytkownik procesu](evidence/processes.txt), [User=llamafile](evidence/systemctl-show.txt) |
| Jednostka systemd i automatyczny start po restarcie VM | [Jednostka](config/llamafile.service), [zmienione identyfikatory rozruchu i zdrowe API](evidence/reboot-test.json), [stan po restarcie](evidence/after-reboot.txt), [odpowiedź modelu po restarcie](evidence/response-after-reboot.json) |
| Automatyczne odtworzenie po kill | [Test SIGKILL](evidence/restart-after-kill.txt): PID 1697 → 2042, licznik restartów 0 → 1, API ponownie zdrowe |
| API dostępne tylko przez host-only | [Test z gospodarza](evidence/windows-access.json): host-only tak, NAT i LAN nie; [ss -tlnp](evidence/ss-tlnp.txt): nasłuch tylko na 192.168.56.10:8080; [próby na innych adresach wewnątrz VM](evidence/guest-other-addresses.txt) |
| Jednostka, ss, curl z odpowiedzią oraz pamięć w dokumentacji | Wszystkie są w [README](README.md); oryginalne wyniki w [evidence/](evidence/) |
| Odtworzenie na nowej VM | [Przygotowanie VM i sieci](docs/VM-network.md), [instalacja usługi, testy i objaśnienia](README.md), [skrypty](scripts/) |

Model binarny nie jest przechowywany w Git. Jest odtwarzany ze wskazanego w repozytorium URL i weryfikowany SHA-256. Repozytorium nie wymaga dołączania całego kodu źródłowego llamafile ani kluczy SSH.
