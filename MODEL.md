# Model i źródła

- Model: **Bonsai-1.7B**, przygotowany przez Prism ML, kwantyzacja Q1_0.
- Gotowy pakiet silnika i wag: **Mozilla.ai llamafile 0.10.6** (wersja odczytana z pobranego pliku przez `--version`).
- Plik: `Bonsai-1.7B.llamafile`, 292 242 025 bajtów.
- Repozytorium dystrybucji: <https://huggingface.co/mozilla-ai/llamafile_0.10>.
- Przypięta rewizja: `8c9e234f2068fa6a6f3ed171926b367e65cef160`.
- SHA-256: `5a05fc2c47ecf2bc2ca44b87477f0e454076a90e03e0e38fdf12a290a81a924a`.
- Licencja modelu według karty wydawcy: Apache 2.0.
- Karta modelu: <https://huggingface.co/prism-ml/Bonsai-1.7B-gguf>.

Model jest mały i służy tutaj do demonstracji uruchomienia usługi. Nie jest wymagane GPU. Kontekst ograniczono do 2048 tokenów, jeden wątek CPU i jedno równoczesne żądanie, odpowiednio do VM z 4 GB RAM i jednym CPU.

Przesłane `llamafile-main.zip` zawiera kod źródłowy projektu oraz mały model testowy GGUF. Nie jest gotowym plikiem wykonywalnym z docelowym modelem. Do wykonania zadania pobrano gotowy plik wskazany powyżej; nie kompilowano archiwum ZIP.

Nie dołączamy binarnego modelu do Git. Adres i suma kontrolna są w `config/model.env`; skrypt instalacyjny pobiera dokładnie ten sam plik lub sprawdza plik wcześniej przesłany przez `scp`.

Dokumentacja techniczna:

- Llamafile: <https://github.com/mozilla-ai/llamafile>.
- Tryb serwera: <https://docs.mozilla.ai/llamafile/using-llamafile/running_llamafile>.
- Argumenty: <https://docs.mozilla.ai/llamafile/reference/cli_arguments>.
- Zarządzanie usługami i `Restart=`: <https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html>.

Wersja 0.10.6 obsługuje `--server`, `--host` i `--port`. W jej pomocy nie występuje `--nobrowser`, dlatego użyto trybu serwera bez tego parametru. `/bin/sh` w jednostce uruchamia przenośny plik wykonywalny APE na Linuksie bez wymagania rejestracji dodatkowego loadera w systemie. Jest to nadal jeden plik zawierający silnik oraz wagi modelu.

Karta zbiorcza wydawcy podczas pobierania opisywała pakiety jako 0.10.5, natomiast ten konkretny plik zgłaszał 0.10.6. Do odtworzenia używamy przypiętej rewizji i SHA-256 pliku, zamiast polegać na ogólnej etykiecie strony.
