<#
  Aktualizuje opisy pól w szablonie jpk_v7.xslt (szablony XSLT "opis" i "opisWartosci").

  - Opisy pól P_/K_ i pozostałych elementów pochodzą z adnotacji oficjalnej schemy XSD JPK_V7.
  - Opisy GTU, oznaczeń procedur i typów dokumentów są wpisane niżej ręcznie
    (§ 10 rozporządzenia MF – schema ich nie zawiera). Opisy ręczne mają pierwszeństwo.

  Użycie (lub przez aktualizuj_opisy.bat):
    .\aktualizuj_opisy.ps1                       # pobiera schemę JPK_V7M(3) z crd.gov.pl
    .\aktualizuj_opisy.ps1 -Xsd <URL lub plik>   # inna wersja schemy (adres = przestrzeń nazw z pliku JPK + "schemat.xsd")
    .\aktualizuj_opisy.ps1 -Xslt <ścieżka>       # inny plik szablonu

  Po aktualizacji uruchom build.bat, aby wkompilować nowy szablon w JpkViewer.exe
  (albo zostaw jpk_v7.xslt obok programu – ma pierwszeństwo przed wbudowanym).
#>
param(
  [string]$Xsd = 'http://crd.gov.pl/wzor/2025/12/19/14090/schemat.xsd',
  [string]$Xslt = (Join-Path $PSScriptRoot 'jpk_v7.xslt')
)
$ErrorActionPreference = 'Stop'
function Esc([string]$s) { [Security.SecurityElement]::Escape($s) }

# 1) opisy ręczne (z rozporządzenia) – mają pierwszeństwo
$reczne = [ordered]@{
  'KodFormularza'='Kod formularza (struktury JPK)'
  'WariantFormularza'='Wariant formularza'
  'CelZlozenia'='Cel złożenia: 1 – złożenie ewidencji/deklaracji, 2 – korekta'
  'KodUrzedu'='Kod urzędu skarbowego'
  'Rok'='Rok, którego dotyczy JPK'
  'Miesiac'='Miesiąc, którego dotyczy JPK'
  'Kwartal'='Kwartał, którego dotyczy deklaracja'
  'Email'='Adres poczty elektronicznej'
  'ImiePierwsze'='Pierwsze imię'
  'Nazwisko'='Nazwisko'
  'DataUrodzenia'='Data urodzenia'
  'Pouczenia'='Potwierdzenie zapoznania się z pouczeniami i ich akceptacja (1 – tak)'
  'GTU_01'='Dostawa napojów alkoholowych – alkoholu etylowego, piwa, wina, napojów fermentowanych i wyrobów pośrednich (w rozumieniu przepisów o podatku akcyzowym)'
  'GTU_02'='Dostawa towarów, o których mowa w art. 103 ust. 5aa ustawy (paliwa)'
  'GTU_03'='Dostawa oleju opałowego, olejów smarowych i pozostałych olejów (wybrane kody CN 2710 i 3403)'
  'GTU_04'='Dostawa wyrobów tytoniowych, suszu tytoniowego, płynu do papierosów elektronicznych i wyrobów nowatorskich'
  'GTU_05'='Dostawa odpadów – wyłącznie określonych w poz. 79–91 załącznika nr 15 do ustawy'
  'GTU_06'='Dostawa urządzeń elektronicznych oraz części i materiałów do nich (wybrane pozycje załącznika nr 15 do ustawy), a także folii typu stretch'
  'GTU_07'='Dostawa pojazdów oraz części samochodowych (CN 8701–8708 oraz CN 8708 10 10)'
  'GTU_08'='Dostawa metali szlachetnych oraz nieszlachetnych (wybrane pozycje załączników nr 12 i 15 do ustawy)'
  'GTU_09'='Dostawa leków, środków spożywczych specjalnego przeznaczenia żywieniowego oraz wyrobów medycznych objętych obowiązkiem zgłoszenia (art. 37av ust. 1 Prawa farmaceutycznego)'
  'GTU_10'='Dostawa budynków, budowli i gruntów oraz ich części i udziałów w prawach do nich'
  'GTU_11'='Świadczenie usług w zakresie przenoszenia uprawnień do emisji gazów cieplarnianych'
  'GTU_12'='Świadczenie usług niematerialnych – wyłącznie doradczych, księgowych, prawnych, zarządczych, szkoleniowych, marketingowych, firm centralnych (head offices), reklamowych, badania rynku i opinii publicznej, badań naukowych i prac rozwojowych'
  'GTU_13'='Świadczenie usług transportowych i gospodarki magazynowej (PKWiU 2015 sekcja H)'
  'WSTO_EE'='Wewnątrzwspólnotowa sprzedaż towarów na odległość oraz usługi telekomunikacyjne, nadawcze i elektroniczne na rzecz konsumentów z innych państw UE (art. 28k ustawy)'
  'IED'='Dostawa towarów, o której mowa w art. 7a ust. 1 i 2 ustawy, przez podatnika ułatwiającego tę dostawę (interfejs elektroniczny), poza procedurami szczególnymi'
  'TP'='Istniejące powiązania między nabywcą a dokonującym dostawy towarów lub usługodawcą (art. 32 ust. 2 pkt 1 ustawy)'
  'TT_WNT'='Wewnątrzwspólnotowe nabycie towarów przez drugiego w kolejności podatnika VAT w ramach wewnątrzwspólnotowej transakcji trójstronnej (procedura uproszczona)'
  'TT_D'='Dostawa towarów poza terytorium kraju przez drugiego w kolejności podatnika VAT w ramach wewnątrzwspólnotowej transakcji trójstronnej (procedura uproszczona)'
  'MR_T'='Świadczenie usług turystyki opodatkowane na zasadach marży (art. 119 ustawy)'
  'MR_UZ'='Dostawa towarów używanych, dzieł sztuki, przedmiotów kolekcjonerskich i antyków opodatkowana na zasadach marży (art. 120 ustawy)'
  'I_42'='Wewnątrzwspólnotowa dostawa towarów następująca po imporcie w ramach procedury celnej 42'
  'I_63'='Wewnątrzwspólnotowa dostawa towarów następująca po imporcie w ramach procedury celnej 63'
  'B_SPV'='Transfer bonu jednego przeznaczenia dokonany przez podatnika działającego we własnym imieniu (art. 8a ust. 1 ustawy)'
  'B_SPV_DOSTAWA'='Dostawa towarów lub usług, których dotyczy bon jednego przeznaczenia, na rzecz podatnika, który wyemitował bon (art. 8a ust. 4 ustawy)'
  'B_MPV_PROWIZJA'='Świadczenie usług pośrednictwa oraz innych usług dotyczących transferu bonu różnego przeznaczenia (art. 8b ust. 2 ustawy)'
  'MPP'='Transakcja objęta obowiązkiem stosowania mechanizmu podzielonej płatności (oznaczenie z wcześniejszych wersji JPK_V7)'
  'IMP'='Podatek naliczony z tytułu importu towarów, w tym importu towarów rozliczanego zgodnie z art. 33a ustawy'
}

# opisy wartości TypDokumentu / DokumentZakupu
$wartosci = [ordered]@{
  'RO'='Dokument zbiorczy wewnętrzny zawierający informacje o sprzedaży z kas rejestrujących'
  'WEW'='Dokument wewnętrzny'
  'FP'='Faktura do paragonu (art. 109 ust. 3d ustawy) – nie wlicza się do sumy kontrolnej ani do deklaracji'
  'MK'='Faktura wystawiona przez dostawcę/usługodawcę rozliczającego się metodą kasową (art. 21 ustawy)'
  'VAT_RR'='Faktura VAT RR (art. 116 ustawy) – zakup od rolnika ryczałtowego'
}

# 2) wczytanie schemy (URL lub plik)
if ($Xsd -match '^https?://') {
  Write-Host "Pobieranie schemy: $Xsd"
  $wc = New-Object Net.WebClient
  $wc.Encoding = [Text.Encoding]::UTF8
  $tekstXsd = $wc.DownloadString($Xsd)
} else {
  $tekstXsd = [IO.File]::ReadAllText((Resolve-Path $Xsd), [Text.Encoding]::UTF8)
}
$x = New-Object Xml.XmlDocument
$x.LoadXml($tekstXsd)
$ns = New-Object Xml.XmlNamespaceManager $x.NameTable
$ns.AddNamespace('xsd', 'http://www.w3.org/2001/XMLSchema')

$opisy = [ordered]@{}
foreach ($k in $reczne.Keys) { $opisy[$k] = $reczne[$k] }
$zeSchemy = 0
foreach ($e in $x.SelectNodes('//xsd:element[@name]', $ns)) {
  $d = $e.SelectSingleNode('xsd:annotation/xsd:documentation', $ns)
  if ($d -and -not $opisy.Contains($e.name)) {
    $opisy[$e.name] = ($d.InnerText -replace '\s+', ' ').Trim()
    $zeSchemy++
  }
}
if ($zeSchemy -eq 0) { throw 'Schema nie zawiera żadnych opisów elementów – czy to właściwy plik XSD?' }

# 3) zbudowanie szablonów XSLT
$zrodlo = if ($Xsd -match '^https?://') { $Xsd -replace '^https?://', '' } else { [IO.Path]::GetFileName($Xsd) }
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('  <!-- OPISY-START: sekcja generowana skryptem aktualizuj_opisy.ps1 – nie edytuj ręcznie, zmieniaj skrypt.')
[void]$sb.AppendLine("       Pola P_/K_ i pozostałe – z adnotacji schemy ($(Esc $zrodlo));")
[void]$sb.AppendLine('       GTU, oznaczenia procedur i typy dokumentów – wg § 10 rozporządzenia MF. -->')
[void]$sb.AppendLine('  <xsl:template name="opis">')
[void]$sb.AppendLine('    <xsl:param name="nazwa"/>')
[void]$sb.AppendLine('    <xsl:choose>')
foreach ($k in $opisy.Keys) {
  [void]$sb.AppendLine(("      <xsl:when test=""`$nazwa='{0}'"">{1}</xsl:when>" -f $k, (Esc $opisy[$k])))
}
[void]$sb.AppendLine('    </xsl:choose>')
[void]$sb.AppendLine('  </xsl:template>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('  <!-- opisy wartości TypDokumentu / DokumentZakupu -->')
[void]$sb.AppendLine('  <xsl:template name="opisWartosci">')
[void]$sb.AppendLine('    <xsl:param name="kod"/>')
[void]$sb.AppendLine('    <xsl:choose>')
foreach ($k in $wartosci.Keys) {
  [void]$sb.AppendLine(("      <xsl:when test=""`$kod='{0}'"">{1}</xsl:when>" -f $k, (Esc $wartosci[$k])))
}
[void]$sb.AppendLine('    </xsl:choose>')
[void]$sb.AppendLine('  </xsl:template>')
[void]$sb.AppendLine('  <!-- OPISY-KONIEC -->')
[void]$sb.AppendLine('')

# 4) podmiana sekcji w pliku XSLT (między znacznikami; obsługa też starszego formatu sekcji)
$t = [IO.File]::ReadAllText($Xslt, [Text.Encoding]::UTF8)
$start = $t.IndexOf('  <!-- OPISY-START')
if ($start -lt 0) { $start = $t.IndexOf('  <!-- opisy elementów: pola P_/K_') }
if ($start -lt 0) { $start = $t.IndexOf('  <!-- opisy pozycji VAT-7') }
$m = [regex]::Match($t, '  <!-- OPISY-KONIEC -->\r?\n(\r?\n)?')
if ($m.Success) { $koniec = $m.Index + $m.Length }
else { $koniec = [regex]::Match($t, '  <!-- =+ -->\r?\n  <!-- Widok ogólny').Index }
if ($start -lt 0 -or $koniec -le $start) { throw "Nie znaleziono sekcji opisów w pliku $Xslt" }

$nowy = $t.Substring(0, $start) + $sb.ToString() + $t.Substring($koniec)
# kontrola poprawności – czy wynik nadal jest poprawnym arkuszem XSLT
$test = New-Object System.Xml.Xsl.XslCompiledTransform
$test.Load((New-Object Xml.XmlTextReader (New-Object IO.StringReader $nowy)))

[IO.File]::WriteAllText($Xslt, $nowy, (New-Object Text.UTF8Encoding $false))
Write-Host "Zaktualizowano $Xslt"
Write-Host "Opisy: $zeSchemy ze schemy + $($reczne.Count) ręcznych, wartości: $($wartosci.Count)"
Write-Host 'Uruchom build.bat, aby wkompilować nowy szablon w JpkViewer.exe.'
