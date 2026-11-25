# JpkViewer – wizualizacja plików JPK_V7

JpkViewer zamienia plik JPK_V7M lub JPK_V7K (`.xml`) w czytelną stronę HTML i otwiera ją w przeglądarce. Na stronie są deklaracja VAT-7, ewidencja sprzedaży i zakupów oraz kontrola sum.

Program **nie wymaga instalacji**. Korzysta z .NET Framework 4.x, który jest częścią Windows 10 i 11. Plik jest przetwarzany wyłącznie lokalnie i nic nie jest wysyłane do internetu.

## Jak używać

Plik JPK można otworzyć na trzy sposoby:

- kliknij dwukrotnie `JpkViewer.exe` i wybierz plik (można zaznaczyć kilka naraz),
- przeciągnij plik `.xml` na `JpkViewer.exe`,
- uruchom program z wiersza poleceń:

  ```
  JpkViewer.exe plik.xml [plik2.xml ...]
  JpkViewer.exe /nie-otwieraj plik.xml     – tylko zapisuje HTML, bez otwierania przeglądarki
  ```

Plik HTML zapisuje się obok pliku XML, pod tą samą nazwą z rozszerzeniem `.html`. Jeśli ten folder jest tylko do odczytu, plik trafia do folderu tymczasowego (`%TEMP%`).

## Co pokazuje strona

| Sekcja | Zawartość |
|---|---|
| Podsumowanie | Sprzedaż netto, VAT należny, zakupy netto, VAT naliczony, kwota do wpłaty (P_51) albo nadwyżka (P_53) |
| Podmiot, Nagłówek | Dane podatnika i nagłówka pliku; opis pola pokazuje się po najechaniu na jego nazwę |
| Deklaracja | Pozycje P_ z pełnymi opisami, wartość z deklaracji, suma odpowiednich pól K_ z ewidencji i znak zgodności ✓/✗; pozycje zerowe można ukryć |
| Ewidencja sprzedaży i zakupów | Tabele z wyszukiwarką i sortowaniem po kliknięciu nagłówka, oznaczeniami (GTU, procedury, typ dokumentu, BFK/OFF/DI) i niezerowymi polami K_; opisy pokazują się po najechaniu myszą |
| Kontrola sum | Liczba wierszy i podatek z `SprzedazCtrl` / `ZakupCtrl` porównane z wartościami wyliczonymi z wierszy; zgodność pozycji deklaracji z ewidencją (P_n = zaokrąglona suma K_n) |

W JPK_V7K deklaracja za cały kwartał jest w pliku za ostatni miesiąc kwartału, a ewidencja w tym pliku dotyczy tylko jednego miesiąca. Program szuka więc plików JPK_V7K za pozostałe miesiące tego samego kwartału: wśród plików wybranych razem z nim i w folderze, w którym leży. Bierze tylko pliki z tym samym NIP-em i rokiem, a gdy za ten sam miesiąc jest kilka plików (np. korekta), używa najnowszego według `DataWytworzeniaJPK`. Jeśli znajdzie komplet, porównuje deklarację z ewidencją z całego kwartału i wypisuje, z których plików skorzystał. Jeśli któregoś miesiąca brakuje, pokazuje sumę z dostępnych miesięcy, ale zgodności nie ocenia (znak – zamiast ✓/✗) i podaje, których miesięcy brakuje.

Faktury do paragonu (`TypDokumentu = FP`) są w tabeli wyszarzone i nie wchodzą do sum ani do porównania z deklaracją, zgodnie ze schemą JPK_V7.

Inne pliki JPK, np. JPK_FA, program pokaże jako drzewo elementów, bez tabel i kontroli.

Strona nadaje się do wydruku: przy drukowaniu tabele pokazują się w całości. Nie jest to jednak oficjalny dokument ani urzędowa wizualizacja deklaracji.

## Pliki w projekcie

| Plik | Do czego służy |
|---|---|
| `JpkViewer.exe` | Gotowy program |
| `JpkViewer.cs` | Kod źródłowy programu (C#, `System.Xml.Xsl.XslCompiledTransform`) |
| `jpk_v7.xslt` | Szablon XSLT, który zamienia XML na HTML; zawiera też style CSS i skrypt strony |
| `build.bat` | Kompiluje `JpkViewer.exe` kompilatorem `csc.exe` wbudowanym w Windows |
| `aktualizuj_opisy.ps1` | Uzupełnia opisy pól w `jpk_v7.xslt` na podstawie oficjalnej schemy XSD |
| `aktualizuj_opisy.bat` | Uruchamia `aktualizuj_opisy.ps1`, a potem `build.bat` |
| `LICENSE` | Licencja MIT |

## Zmiana wyglądu strony

Szablon `jpk_v7.xslt` jest wkompilowany w `JpkViewer.exe`. Jeśli jednak plik `jpk_v7.xslt` leży w tym samym folderze co program, **program używa tej wersji zamiast wbudowanej**. Dzięki temu zmiany w szablonie widać od razu, bez kompilowania.

Gdy chcesz rozesłać sam `.exe` z nowym szablonem, przebuduj go poleceniem `build.bat`.

## Opisy pól i nowe wersje schemy

Opisy pochodzą z dwóch źródeł:

- **Pola P_ i K_ oraz pozostałe elementy** – z adnotacji oficjalnej schemy XSD JPK_V7M(3):
  `http://crd.gov.pl/wzor/2025/12/19/14090/schemat.xsd`.
- **GTU_01–13, oznaczenia procedur (TP, MR_T, WSTO_EE…), IMP i typy dokumentów (RO, WEW, FP, MK, VAT_RR)** – schema ich nie opisuje, więc są wpisane ręcznie w `aktualizuj_opisy.ps1` według § 10 rozporządzenia MF. Opisy GTU_03, 06 i 08 są skrócone: zamiast pełnej listy kodów CN zawierają odesłanie do załączników ustawy.

Opisy trafiają do sekcji `jpk_v7.xslt` między komentarzami `OPISY-START` i `OPISY-KONIEC`. **Nie edytuj tej sekcji ręcznie**, bo skrypt ją nadpisuje. Zmiany wprowadzaj w `aktualizuj_opisy.ps1`.

Aby zaktualizować opisy, uruchom `aktualizuj_opisy.bat`. Domyślnie pobiera schemę JPK_V7M(3). Dla nowej wersji schemy podaj jej adres. Jest to przestrzeń nazw z nagłówka nowego pliku JPK (atrybut `xmlns:tns`) z dopisanym `schemat.xsd`:

```
aktualizuj_opisy.bat -Xsd http://crd.gov.pl/wzor/RRRR/MM/DD/NNNNN/schemat.xsd
```

Zamiast adresu można podać ścieżkę do pobranego pliku XSD.

Sam szablon nie zależy od przestrzeni nazw, bo elementy rozpoznaje po nazwach (`local-name()`). Nowe wersje JPK_V7 o tej samej strukturze powinny więc wyświetlać się poprawnie bez żadnych zmian.

## Rozwiązywanie problemów

- **„Nie znaleziono csc.exe”** przy `build.bat` – w systemie brakuje .NET Framework 4.x. Włącz go w *Panel sterowania → Programy → Włącz lub wyłącz funkcje systemu Windows*.
- **Komunikat o błędzie przetwarzania pliku** – plik nie jest poprawnym XML-em, np. jest uszkodzony albo niekompletny. Program nie sprawdza zgodności pliku ze schemą. Pokazuje to, co jest w pliku, a niezgodności sum oznacza ✗ w sekcji Kontrola.
- **Windows blokuje uruchomienie `.ps1`** – użyj `aktualizuj_opisy.bat`, który uruchamia skrypt z `-ExecutionPolicy Bypass`.
- **Strona otwiera się wolno przy bardzo dużych plikach** – tabele z kilkudziesięcioma tysiącami wierszy przeglądarka renderuje kilka sekund. Samo przekształcenie trwa krótko: plik 2,6 MB z ok. 3 000 wierszy przetwarza się w ok. 150 ms.

## Licencja

Projekt jest udostępniony na licencji MIT – szczegóły w pliku [LICENSE](LICENSE).
