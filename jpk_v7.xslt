<?xml version="1.0" encoding="utf-8"?>
<!--
  Wizualizacja JPK_V7M / JPK_V7K (deklaracja + ewidencja) jako HTML.
  Szablon nie zależy od przestrzeni nazw (używa local-name()), więc działa
  dla kolejnych wersji schemy JPK_V7. Dla innych plików JPK pokazuje widok ogólny (drzewo).
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="utf-8" indent="no"/>

  <!-- parametry przekazywane z programu (XsltArgumentList) -->
  <xsl:param name="plik" select="''"/>
  <xsl:param name="wygenerowano" select="''"/>
  <!-- JPK_V7K: dane o pozostałych miesiącach kwartału (wylicza program, zob. JpkViewer.cs)
       kwartal      – 'pelny' (są pliki za wszystkie miesiące), 'niepelny' albo '' (nie sprawdzano)
       kwartalSumy  – sumy pól K_ z pozostałych miesięcy: |K_19=12500|K_20=2875|…|
       kwartalPliki – opis użytych plików, kwartalBrak – miesiące, dla których brak pliku -->
  <xsl:param name="kwartal" select="''"/>
  <xsl:param name="kwartalSumy" select="'|'"/>
  <xsl:param name="kwartalPliki" select="''"/>
  <xsl:param name="kwartalBrak" select="''"/>

  <xsl:decimal-format name="pl" decimal-separator="," grouping-separator="&#160;"/>

  <!-- pola K_ z wierszy ewidencji; faktury do paragonu (TypDokumentu=FP) nie wchodzą do deklaracji ani sum kontrolnych -->
  <xsl:key name="kpole" match="*[starts-with(local-name(), 'K_')][not(../*[local-name()='TypDokumentu'] = 'FP')]" use="local-name()"/>

  <!-- pola kwotowe ewidencji -->
  <xsl:variable name="sprzNetto" select="'|K_10|K_11|K_13|K_15|K_17|K_19|K_21|K_22|K_23|K_25|K_27|K_29|K_31|'"/>
  <xsl:variable name="sprzVatPlus" select="'|K_16|K_18|K_20|K_24|K_26|K_28|K_30|K_32|K_33|K_34|'"/>
  <xsl:variable name="sprzVatMinus" select="'|K_35|K_36|K_360|'"/>
  <xsl:variable name="zakNetto" select="'|K_40|K_42|'"/>
  <xsl:variable name="zakVat" select="'|K_41|K_43|K_44|K_45|K_46|K_47|'"/>
  <!-- pola wiersza, które nie są "oznaczeniami" (GTU, procedury, typy dokumentów) -->
  <xsl:variable name="polaPodstawowe" select="'|LpSprzedazy|LpZakupu|KodKrajuNadaniaTIN|NrKontrahenta|NazwaKontrahenta|NrDostawcy|NazwaDostawcy|DowodSprzedazy|DowodZakupu|DataWystawienia|DataSprzedazy|DataZakupu|DataWplywu|NrKSeF|SprzedazVAT_Marza|ZakupVAT_Marza|KorektaPodstawyOpodt|TerminPlatnosci|DataZaplatyNaleznosci|'"/>

  <xsl:variable name="ewidencja" select="/*/*[local-name()='Ewidencja']"/>
  <xsl:variable name="sprzedaz" select="$ewidencja/*[local-name()='SprzedazWiersz']"/>
  <xsl:variable name="sprzedazBezFP" select="$sprzedaz[not(*[local-name()='TypDokumentu'] = 'FP')]"/>
  <xsl:variable name="liczbaFP" select="count($sprzedaz) - count($sprzedazBezFP)"/>
  <xsl:variable name="zakupy" select="$ewidencja/*[local-name()='ZakupWiersz']"/>
  <xsl:variable name="deklaracja" select="/*/*[local-name()='Deklaracja']"/>
  <!-- deklaracja kwartalna (VAT-7K) obejmuje trzy miesiące, a ewidencja w pliku – tylko jeden;
       z ewidencją porównujemy ją tylko wtedy, gdy program znalazł pliki za cały kwartał -->
  <xsl:variable name="kwartalDekl" select="$deklaracja/*[local-name()='Naglowek']/*[local-name()='Kwartal']"/>
  <xsl:variable name="porownuj" select="not($kwartalDekl) or $kwartal = 'pelny'"/>

  <!-- ============================================================ -->
  <xsl:template match="/">
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
    <html lang="pl">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>
          <xsl:value-of select="/*/*[local-name()='Naglowek']/*[local-name()='KodFormularza']/@kodSystemowy"/>
          <xsl:text> – </xsl:text>
          <xsl:value-of select="$plik"/>
        </title>
        <style><xsl:call-template name="css"/></style>
      </head>
      <body>
        <xsl:choose>
          <xsl:when test="$ewidencja or $deklaracja">
            <xsl:call-template name="widokV7"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="widokOgolny"/>
          </xsl:otherwise>
        </xsl:choose>
        <script><xsl:call-template name="js"/></script>
      </body>
    </html>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Widok JPK_V7                                                 -->
  <!-- ============================================================ -->
  <xsl:template name="widokV7">
    <xsl:variable name="nag" select="/*/*[local-name()='Naglowek']"/>
    <xsl:variable name="ctrlS" select="$ewidencja/*[local-name()='SprzedazCtrl']"/>
    <xsl:variable name="ctrlZ" select="$ewidencja/*[local-name()='ZakupCtrl']"/>

    <xsl:variable name="sumaSprzNetto" select="sum($sprzedazBezFP/*[contains($sprzNetto, concat('|', local-name(), '|'))])"/>
    <xsl:variable name="sumaSprzVat" select="sum($sprzedazBezFP/*[contains($sprzVatPlus, concat('|', local-name(), '|'))]) - sum($sprzedazBezFP/*[contains($sprzVatMinus, concat('|', local-name(), '|'))])"/>
    <xsl:variable name="sumaZakNetto" select="sum($zakupy/*[contains($zakNetto, concat('|', local-name(), '|'))])"/>
    <xsl:variable name="sumaZakVat" select="sum($zakupy/*[contains($zakVat, concat('|', local-name(), '|'))])"/>

    <header>
      <div class="tytul">
        <h1>
          <xsl:value-of select="$nag/*[local-name()='KodFormularza']/@kodSystemowy"/>
          <span class="okres">
            <xsl:text>okres </xsl:text>
            <xsl:if test="$nag/*[local-name()='Miesiac']">
              <xsl:value-of select="format-number($nag/*[local-name()='Miesiac'], '00')"/>
              <xsl:text>/</xsl:text>
            </xsl:if>
            <xsl:if test="$nag/*[local-name()='Kwartal']">
              <xsl:text>Q</xsl:text><xsl:value-of select="$nag/*[local-name()='Kwartal']"/>
              <xsl:text>/</xsl:text>
            </xsl:if>
            <xsl:value-of select="$nag/*[local-name()='Rok']"/>
          </span>
        </h1>
        <div class="podtytul">
          <xsl:choose>
            <xsl:when test="$nag/*[local-name()='CelZlozenia'] = '2'"><span class="badge warn">Korekta</span></xsl:when>
            <xsl:otherwise><span class="badge">Złożenie</span></xsl:otherwise>
          </xsl:choose>
          <xsl:text> Plik: </xsl:text><b><xsl:value-of select="$plik"/></b>
        </div>
      </div>
      <nav>
        <a href="#podmiot">Podmiot</a>
        <xsl:if test="$deklaracja"><a href="#deklaracja">Deklaracja</a></xsl:if>
        <xsl:if test="$sprzedaz or $ctrlS"><a href="#sprzedaz">Sprzedaż (<xsl:value-of select="count($sprzedaz)"/>)</a></xsl:if>
        <xsl:if test="$zakupy or $ctrlZ"><a href="#zakupy">Zakupy (<xsl:value-of select="count($zakupy)"/>)</a></xsl:if>
        <a href="#kontrola">Kontrola</a>
      </nav>
    </header>

    <main>
      <!-- KPI -->
      <section class="kpi">
        <div class="tile"><span>Sprzedaż netto</span><b><xsl:value-of select="format-number($sumaSprzNetto, '#&#160;##0,00', 'pl')"/></b></div>
        <div class="tile"><span>VAT należny</span><b><xsl:value-of select="format-number($sumaSprzVat, '#&#160;##0,00', 'pl')"/></b></div>
        <div class="tile"><span>Zakupy netto</span><b><xsl:value-of select="format-number($sumaZakNetto, '#&#160;##0,00', 'pl')"/></b></div>
        <div class="tile"><span>VAT naliczony</span><b><xsl:value-of select="format-number($sumaZakVat, '#&#160;##0,00', 'pl')"/></b></div>
        <xsl:variable name="p51" select="$deklaracja//*[local-name()='P_51']"/>
        <xsl:variable name="p53" select="$deklaracja//*[local-name()='P_53']"/>
        <xsl:choose>
          <xsl:when test="number($p51) &gt; 0">
            <div class="tile accent"><span>Do wpłaty (P_51)</span><b><xsl:value-of select="format-number($p51, '#&#160;##0', 'pl')"/> zł</b></div>
          </xsl:when>
          <xsl:when test="number($p53) &gt; 0">
            <div class="tile accent"><span>Nadwyżka (P_53)</span><b><xsl:value-of select="format-number($p53, '#&#160;##0', 'pl')"/> zł</b></div>
          </xsl:when>
          <xsl:otherwise>
            <div class="tile"><span>Różnica VAT</span><b><xsl:value-of select="format-number($sumaSprzVat - $sumaZakVat, '#&#160;##0,00', 'pl')"/></b></div>
          </xsl:otherwise>
        </xsl:choose>
      </section>

      <!-- Podmiot + nagłówek -->
      <section id="podmiot" class="karty">
        <div class="karta">
          <h2>Podmiot</h2>
          <xsl:for-each select="/*/*[local-name()='Podmiot1']">
            <xsl:if test="@rola"><p class="muted"><xsl:value-of select="@rola"/></p></xsl:if>
            <dl><xsl:apply-templates select=".//*[not(*)]" mode="dl"/></dl>
          </xsl:for-each>
        </div>
        <div class="karta">
          <h2>Nagłówek</h2>
          <dl>
            <xsl:apply-templates select="$nag/*" mode="dl"/>
            <xsl:if test="$wygenerowano != ''">
              <dt>Wizualizacja</dt><dd><xsl:value-of select="$wygenerowano"/></dd>
            </xsl:if>
          </dl>
        </div>
      </section>

      <!-- Deklaracja -->
      <xsl:if test="$deklaracja">
        <section id="deklaracja">
          <div class="sekcja-nag">
            <h2>
              Deklaracja
              <xsl:value-of select="$deklaracja/*[local-name()='Naglowek']/*[local-name()='KodFormularzaDekl']/@kodSystemowy"/>
            </h2>
            <label class="przelacznik"><input type="checkbox" id="ukryjZera" checked="checked"/> ukryj pozycje zerowe</label>
          </div>
          <xsl:if test="$kwartalDekl">
            <xsl:variable name="okresKw" select="concat('Q', $kwartalDekl, '/', $nag/*[local-name()='Rok'])"/>
            <xsl:choose>
              <xsl:when test="$porownuj">
                <p class="info">
                  <xsl:text>Deklaracja kwartalna (</xsl:text><xsl:value-of select="$okresKw"/>
                  <xsl:text>) porównana z ewidencją z całego kwartału: </xsl:text>
                  <xsl:value-of select="$kwartalPliki"/><xsl:text>.</xsl:text>
                </p>
              </xsl:when>
              <xsl:otherwise>
                <p class="info warn">
                  <xsl:text>Deklaracja kwartalna (</xsl:text><xsl:value-of select="$okresKw"/>
                  <xsl:text>) obejmuje trzy miesiące, a ten plik zawiera ewidencję tylko za </xsl:text>
                  <xsl:value-of select="format-number($nag/*[local-name()='Miesiac'], '00')"/>/<xsl:value-of select="$nag/*[local-name()='Rok']"/>
                  <xsl:text>. Brak ewidencji za: </xsl:text>
                  <xsl:choose>
                    <xsl:when test="$kwartalBrak != ''"><xsl:value-of select="$kwartalBrak"/></xsl:when>
                    <xsl:otherwise>pozostałe miesiące kwartału</xsl:otherwise>
                  </xsl:choose>
                  <xsl:text>, więc zgodności deklaracji z ewidencją nie sprawdzono. Aby ją sprawdzić, umieść pliki JPK_V7K za pozostałe miesiące kwartału w tym samym folderze albo wybierz je razem z tym plikiem.</xsl:text>
                </p>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:if>
          <table class="dekl ukryj-zera" id="tabDekl">
            <thead>
              <tr>
                <th>Poz.</th><th>Opis</th><th class="num">Deklaracja</th>
                <th class="num">
                  <xsl:text>Suma z ewidencji</xsl:text>
                  <xsl:if test="$kwartalDekl">
                    <xsl:choose>
                      <xsl:when test="$porownuj"> (kwartał)</xsl:when>
                      <xsl:otherwise> (niepełna)</xsl:otherwise>
                    </xsl:choose>
                  </xsl:if>
                </th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="$deklaracja/*[local-name()='PozycjeSzczegolowe']/*">
                <xsl:variable name="nr" select="substring-after(local-name(), 'P_')"/>
                <xsl:variable name="sumaTxt"><xsl:call-template name="sumaK"><xsl:with-param name="nr" select="$nr"/></xsl:call-template></xsl:variable>
                <xsl:variable name="maK" select="string($sumaTxt) != ''"/>
                <xsl:variable name="suma" select="number($sumaTxt)"/>
                <xsl:variable name="czyLiczba" select="string(number(.)) != 'NaN'"/>
                <tr>
                  <xsl:if test="$czyLiczba and number(.) = 0 and not($maK and $suma != 0)">
                    <xsl:attribute name="class">zero</xsl:attribute>
                  </xsl:if>
                  <xsl:if test="$nr = '37' or $nr = '38' or $nr = '48' or $nr = '51' or $nr = '53'">
                    <xsl:attribute name="class">razem</xsl:attribute>
                  </xsl:if>
                  <td class="poz"><xsl:value-of select="local-name()"/></td>
                  <td class="opis">
                    <xsl:call-template name="opis"><xsl:with-param name="nazwa" select="local-name()"/></xsl:call-template>
                  </td>
                  <td class="num">
                    <xsl:choose>
                      <xsl:when test="$czyLiczba"><xsl:value-of select="format-number(., '#&#160;##0', 'pl')"/></xsl:when>
                      <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                    </xsl:choose>
                  </td>
                  <td class="num muted">
                    <xsl:if test="$maK">
                      <xsl:value-of select="format-number($suma, '#&#160;##0,00', 'pl')"/>
                    </xsl:if>
                  </td>
                  <td>
                    <xsl:if test="$maK">
                      <xsl:choose>
                        <xsl:when test="not($porownuj)"><span class="nd" title="Nie sprawdzono – brak ewidencji za część miesięcy kwartału">–</span></xsl:when>
                        <xsl:when test="round($suma) = number(.)"><span class="ok" title="Zgodne z ewidencją (po zaokrągleniu)">✓</span></xsl:when>
                        <xsl:otherwise><span class="blad" title="Niezgodne z sumą pól K_ w ewidencji">✗</span></xsl:otherwise>
                      </xsl:choose>
                    </xsl:if>
                  </td>
                </tr>
              </xsl:for-each>
              <xsl:for-each select="$deklaracja/*[local-name()!='Naglowek' and local-name()!='PozycjeSzczegolowe']">
                <tr>
                  <td class="poz"><xsl:value-of select="local-name()"/></td>
                  <td class="opis"><xsl:call-template name="opis"><xsl:with-param name="nazwa" select="local-name()"/></xsl:call-template></td>
                  <td class="num"><xsl:value-of select="."/></td>
                  <td colspan="2"></td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </section>
      </xsl:if>

      <!-- Sprzedaż -->
      <xsl:if test="$sprzedaz or $ctrlS">
        <section id="sprzedaz">
          <div class="sekcja-nag">
            <h2>Ewidencja sprzedaży</h2>
            <input type="search" class="szukaj" data-tabela="tabSprz" placeholder="Szukaj (kontrahent, NIP, dokument, KSeF, GTU…)"/>
            <span class="licznik" id="tabSprz-licznik"></span>
          </div>
          <div class="przewijanie">
            <table class="ew" id="tabSprz">
              <thead>
                <tr>
                  <th class="num" data-sort="n">Lp</th>
                  <th data-sort="t">Kontrahent</th>
                  <th data-sort="t">Dowód</th>
                  <th data-sort="t">Wystawiono</th>
                  <th data-sort="t">Sprzedaż</th>
                  <th data-sort="t">Nr KSeF</th>
                  <th data-sort="t">Oznaczenia</th>
                  <th class="num" data-sort="n">Netto</th>
                  <th class="num" data-sort="n">VAT</th>
                  <th>Pola K_</th>
                </tr>
              </thead>
              <tbody>
                <xsl:for-each select="$sprzedaz">
                  <xsl:variable name="netto" select="sum(*[contains($sprzNetto, concat('|', local-name(), '|'))])"/>
                  <xsl:variable name="vat" select="sum(*[contains($sprzVatPlus, concat('|', local-name(), '|'))]) - sum(*[contains($sprzVatMinus, concat('|', local-name(), '|'))])"/>
                  <tr>
                    <xsl:if test="*[local-name()='TypDokumentu'] = 'FP'">
                      <xsl:attribute name="class">fp</xsl:attribute>
                      <xsl:attribute name="title">Faktura do paragonu (FP) – nie wliczana do sum, deklaracji ani SprzedazCtrl</xsl:attribute>
                    </xsl:if>
                    <td class="num"><xsl:value-of select="*[local-name()='LpSprzedazy']"/></td>
                    <td>
                      <div class="nazwa"><xsl:value-of select="*[local-name()='NazwaKontrahenta']"/></div>
                      <div class="nip">
                        <xsl:if test="*[local-name()='KodKrajuNadaniaTIN']"><b><xsl:value-of select="*[local-name()='KodKrajuNadaniaTIN']"/></b><xsl:text> </xsl:text></xsl:if>
                        <xsl:value-of select="*[local-name()='NrKontrahenta']"/>
                      </div>
                    </td>
                    <td><xsl:value-of select="*[local-name()='DowodSprzedazy']"/></td>
                    <td class="data"><xsl:value-of select="*[local-name()='DataWystawienia']"/></td>
                    <td class="data"><xsl:value-of select="*[local-name()='DataSprzedazy']"/></td>
                    <td class="ksef"><xsl:value-of select="*[local-name()='NrKSeF']"/></td>
                    <td><xsl:call-template name="oznaczenia"/></td>
                    <td class="num" data-v="{$netto}"><xsl:value-of select="format-number($netto, '#&#160;##0,00', 'pl')"/></td>
                    <td class="num" data-v="{$vat}"><xsl:value-of select="format-number($vat, '#&#160;##0,00', 'pl')"/></td>
                    <td><xsl:call-template name="chipy"/></td>
                  </tr>
                </xsl:for-each>
              </tbody>
              <tfoot>
                <tr>
                  <td colspan="7">
                    <xsl:text>Razem (</xsl:text><xsl:value-of select="count($sprzedaz)"/><xsl:text> wierszy</xsl:text>
                    <xsl:if test="$liczbaFP &gt; 0">
                      <xsl:text>; faktury do paragonu (FP) niewliczone do sum: </xsl:text><xsl:value-of select="$liczbaFP"/>
                    </xsl:if>
                    <xsl:text>)</xsl:text>
                  </td>
                  <td class="num"><xsl:value-of select="format-number($sumaSprzNetto, '#&#160;##0,00', 'pl')"/></td>
                  <td class="num"><xsl:value-of select="format-number($sumaSprzVat, '#&#160;##0,00', 'pl')"/></td>
                  <td></td>
                </tr>
              </tfoot>
            </table>
          </div>
        </section>
      </xsl:if>

      <!-- Zakupy -->
      <xsl:if test="$zakupy or $ctrlZ">
        <section id="zakupy">
          <div class="sekcja-nag">
            <h2>Ewidencja zakupów</h2>
            <input type="search" class="szukaj" data-tabela="tabZak" placeholder="Szukaj (dostawca, NIP, dokument, KSeF…)"/>
            <span class="licznik" id="tabZak-licznik"></span>
          </div>
          <div class="przewijanie">
            <table class="ew" id="tabZak">
              <thead>
                <tr>
                  <th class="num" data-sort="n">Lp</th>
                  <th data-sort="t">Dostawca</th>
                  <th data-sort="t">Dowód</th>
                  <th data-sort="t">Zakup</th>
                  <th data-sort="t">Wpływ</th>
                  <th data-sort="t">Nr KSeF</th>
                  <th data-sort="t">Oznaczenia</th>
                  <th class="num" data-sort="n">Netto</th>
                  <th class="num" data-sort="n">VAT</th>
                  <th>Pola K_</th>
                </tr>
              </thead>
              <tbody>
                <xsl:for-each select="$zakupy">
                  <xsl:variable name="netto" select="sum(*[contains($zakNetto, concat('|', local-name(), '|'))])"/>
                  <xsl:variable name="vat" select="sum(*[contains($zakVat, concat('|', local-name(), '|'))])"/>
                  <tr>
                    <td class="num"><xsl:value-of select="*[local-name()='LpZakupu']"/></td>
                    <td>
                      <div class="nazwa"><xsl:value-of select="*[local-name()='NazwaDostawcy']"/></div>
                      <div class="nip">
                        <xsl:if test="*[local-name()='KodKrajuNadaniaTIN']"><b><xsl:value-of select="*[local-name()='KodKrajuNadaniaTIN']"/></b><xsl:text> </xsl:text></xsl:if>
                        <xsl:value-of select="*[local-name()='NrDostawcy']"/>
                      </div>
                    </td>
                    <td><xsl:value-of select="*[local-name()='DowodZakupu']"/></td>
                    <td class="data"><xsl:value-of select="*[local-name()='DataZakupu']"/></td>
                    <td class="data"><xsl:value-of select="*[local-name()='DataWplywu']"/></td>
                    <td class="ksef"><xsl:value-of select="*[local-name()='NrKSeF']"/></td>
                    <td><xsl:call-template name="oznaczenia"/></td>
                    <td class="num" data-v="{$netto}"><xsl:value-of select="format-number($netto, '#&#160;##0,00', 'pl')"/></td>
                    <td class="num" data-v="{$vat}"><xsl:value-of select="format-number($vat, '#&#160;##0,00', 'pl')"/></td>
                    <td><xsl:call-template name="chipy"/></td>
                  </tr>
                </xsl:for-each>
              </tbody>
              <tfoot>
                <tr>
                  <td colspan="7">Razem (<xsl:value-of select="count($zakupy)"/> wierszy)</td>
                  <td class="num"><xsl:value-of select="format-number($sumaZakNetto, '#&#160;##0,00', 'pl')"/></td>
                  <td class="num"><xsl:value-of select="format-number($sumaZakVat, '#&#160;##0,00', 'pl')"/></td>
                  <td></td>
                </tr>
              </tfoot>
            </table>
          </div>
        </section>
      </xsl:if>

      <!-- Kontrola -->
      <section id="kontrola">
        <h2>Kontrola sum</h2>
        <table class="kontrola">
          <thead><tr><th>Sprawdzenie</th><th class="num">Wartość w pliku</th><th class="num">Wyliczono</th><th></th></tr></thead>
          <tbody>
            <xsl:if test="$ctrlS">
              <xsl:call-template name="wierszKontroli">
                <xsl:with-param name="opis" select="'Liczba wierszy sprzedaży (SprzedazCtrl)'"/>
                <xsl:with-param name="wPliku" select="number($ctrlS/*[local-name()='LiczbaWierszySprzedazy'])"/>
                <xsl:with-param name="wyliczono" select="count($sprzedaz)"/>
                <xsl:with-param name="format" select="'#&#160;##0'"/>
              </xsl:call-template>
              <xsl:call-template name="wierszKontroli">
                <xsl:with-param name="opis" select="'Podatek należny (SprzedazCtrl)'"/>
                <xsl:with-param name="wPliku" select="number($ctrlS/*[local-name()='PodatekNalezny'])"/>
                <xsl:with-param name="wyliczono" select="$sumaSprzVat"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="$ctrlZ">
              <xsl:call-template name="wierszKontroli">
                <xsl:with-param name="opis" select="'Liczba wierszy zakupów (ZakupCtrl)'"/>
                <xsl:with-param name="wPliku" select="number($ctrlZ/*[local-name()='LiczbaWierszyZakupow'])"/>
                <xsl:with-param name="wyliczono" select="count($zakupy)"/>
                <xsl:with-param name="format" select="'#&#160;##0'"/>
              </xsl:call-template>
              <xsl:call-template name="wierszKontroli">
                <xsl:with-param name="opis" select="'Podatek naliczony (ZakupCtrl)'"/>
                <xsl:with-param name="wPliku" select="number($ctrlZ/*[local-name()='PodatekNaliczony'])"/>
                <xsl:with-param name="wyliczono" select="$sumaZakVat"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="$deklaracja">
              <tr>
                <td>
                  <xsl:text>Pozycje deklaracji zgodne z ewidencją </xsl:text>
                  <xsl:if test="$kwartalDekl">całego kwartału </xsl:if>
                  <xsl:text>(P_n = zaokr. Σ K_n)</xsl:text>
                </td>
                <xsl:choose>
                  <xsl:when test="not($porownuj)">
                    <td class="num muted" colspan="2">nie sprawdzono – deklaracja kwartalna, brak ewidencji za część miesięcy kwartału</td>
                    <td><span class="nd">–</span></td>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:variable name="lista">
                      <xsl:for-each select="$deklaracja/*[local-name()='PozycjeSzczegolowe']/*">
                        <xsl:variable name="sumaTxt"><xsl:call-template name="sumaK"><xsl:with-param name="nr" select="substring-after(local-name(), 'P_')"/></xsl:call-template></xsl:variable>
                        <xsl:if test="string($sumaTxt) != '' and round(number($sumaTxt)) != number(.)">
                          <xsl:value-of select="local-name()"/><xsl:text>, </xsl:text>
                        </xsl:if>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="niezgodne" select="substring(string($lista), 1, string-length(string($lista)) - 2)"/>
                    <td class="num" colspan="2">
                      <xsl:choose>
                        <xsl:when test="$niezgodne != ''">niezgodne: <xsl:value-of select="$niezgodne"/></xsl:when>
                        <xsl:otherwise>wszystkie zgodne</xsl:otherwise>
                      </xsl:choose>
                    </td>
                    <td><xsl:choose><xsl:when test="$niezgodne != ''"><span class="blad">✗</span></xsl:when><xsl:otherwise><span class="ok">✓</span></xsl:otherwise></xsl:choose></td>
                  </xsl:otherwise>
                </xsl:choose>
              </tr>
            </xsl:if>
          </tbody>
        </table>
      </section>
    </main>
    <footer>Wizualizacja wygenerowana lokalnie przez JpkViewer (XslCompiledTransform). Nie jest to oficjalny dokument.</footer>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- suma pól K_<nr> z ewidencji tego pliku i (dla deklaracji kwartalnej) pozostałych
       miesięcy kwartału; pusty wynik, gdy pole K_<nr> nigdzie nie występuje -->
  <xsl:template name="sumaK">
    <xsl:param name="nr"/>
    <xsl:variable name="kpola" select="key('kpole', concat('K_', $nr))"/>
    <xsl:variable name="inne" select="substring-before(substring-after($kwartalSumy, concat('|K_', $nr, '=')), '|')"/>
    <xsl:choose>
      <xsl:when test="$inne != ''"><xsl:value-of select="sum($kpola) + number($inne)"/></xsl:when>
      <xsl:when test="$kpola"><xsl:value-of select="sum($kpola)"/></xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="wierszKontroli">
    <xsl:param name="opis"/>
    <xsl:param name="wPliku"/>
    <xsl:param name="wyliczono"/>
    <xsl:param name="format" select="'#&#160;##0,00'"/>
    <xsl:variable name="roznica" select="$wPliku - $wyliczono"/>
    <tr>
      <td><xsl:value-of select="$opis"/></td>
      <td class="num"><xsl:value-of select="format-number($wPliku, $format, 'pl')"/></td>
      <td class="num"><xsl:value-of select="format-number($wyliczono, $format, 'pl')"/></td>
      <td>
        <xsl:choose>
          <xsl:when test="$roznica * $roznica &lt; 0.0001"><span class="ok">✓</span></xsl:when>
          <xsl:otherwise><span class="blad" title="różnica {$roznica}">✗</span></xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
  </xsl:template>

  <!-- oznaczenia: GTU_xx, procedury, typ dokumentu, BFK/OFF/DI itd. -->
  <xsl:template name="oznaczenia">
    <xsl:for-each select="*[not(starts-with(local-name(), 'K_')) and not(contains($polaPodstawowe, concat('|', local-name(), '|')))]">
      <span class="badge">
        <xsl:attribute name="title">
          <xsl:call-template name="opis"><xsl:with-param name="nazwa" select="local-name()"/></xsl:call-template>
          <xsl:variable name="ow"><xsl:call-template name="opisWartosci"><xsl:with-param name="kod" select="normalize-space(.)"/></xsl:call-template></xsl:variable>
          <xsl:if test="string($ow) != ''"><xsl:text>: </xsl:text><xsl:value-of select="$ow"/></xsl:if>
        </xsl:attribute>
        <xsl:value-of select="local-name()"/>
        <xsl:if test="normalize-space(.) != '1'">
          <xsl:text>: </xsl:text><xsl:value-of select="."/>
        </xsl:if>
      </span>
    </xsl:for-each>
  </xsl:template>

  <!-- niezerowe pola kwotowe wiersza -->
  <xsl:template name="chipy">
    <xsl:for-each select="*[(starts-with(local-name(), 'K_') or contains(local-name(), 'VAT_Marza')) and number(.) != 0]">
      <span class="chip">
        <xsl:attribute name="title">
          <xsl:call-template name="opis"><xsl:with-param name="nazwa" select="local-name()"/></xsl:call-template>
        </xsl:attribute>
        <xsl:value-of select="local-name()"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="format-number(., '#&#160;##0,00', 'pl')"/>
      </span>
    </xsl:for-each>
  </xsl:template>

  <!-- elementy proste jako lista definicji -->
  <xsl:template match="*" mode="dl">
    <dt>
      <xsl:variable name="o"><xsl:call-template name="opis"><xsl:with-param name="nazwa" select="local-name()"/></xsl:call-template></xsl:variable>
      <xsl:if test="string($o) != ''"><xsl:attribute name="title"><xsl:value-of select="$o"/></xsl:attribute></xsl:if>
      <xsl:value-of select="local-name()"/>
    </dt>
    <dd>
      <xsl:value-of select="."/>
      <xsl:for-each select="@*">
        <span class="muted"><xsl:text> [</xsl:text><xsl:value-of select="local-name()"/>=<xsl:value-of select="."/>]</span>
      </xsl:for-each>
    </dd>
  </xsl:template>

  <!-- OPISY-START: sekcja generowana skryptem aktualizuj_opisy.ps1 – nie edytuj ręcznie, zmieniaj skrypt.
       Pola P_/K_ i pozostałe – z adnotacji schemy (crd.gov.pl/wzor/2025/12/19/14090/schemat.xsd);
       GTU, oznaczenia procedur i typy dokumentów – wg § 10 rozporządzenia MF. -->
  <xsl:template name="opis">
    <xsl:param name="nazwa"/>
    <xsl:choose>
      <xsl:when test="$nazwa='KodFormularza'">Kod formularza (struktury JPK)</xsl:when>
      <xsl:when test="$nazwa='WariantFormularza'">Wariant formularza</xsl:when>
      <xsl:when test="$nazwa='CelZlozenia'">Cel złożenia: 1 – złożenie ewidencji/deklaracji, 2 – korekta</xsl:when>
      <xsl:when test="$nazwa='KodUrzedu'">Kod urzędu skarbowego</xsl:when>
      <xsl:when test="$nazwa='Rok'">Rok, którego dotyczy JPK</xsl:when>
      <xsl:when test="$nazwa='Miesiac'">Miesiąc, którego dotyczy JPK</xsl:when>
      <xsl:when test="$nazwa='Kwartal'">Kwartał, którego dotyczy deklaracja</xsl:when>
      <xsl:when test="$nazwa='Email'">Adres poczty elektronicznej</xsl:when>
      <xsl:when test="$nazwa='ImiePierwsze'">Pierwsze imię</xsl:when>
      <xsl:when test="$nazwa='Nazwisko'">Nazwisko</xsl:when>
      <xsl:when test="$nazwa='DataUrodzenia'">Data urodzenia</xsl:when>
      <xsl:when test="$nazwa='Pouczenia'">Potwierdzenie zapoznania się z pouczeniami i ich akceptacja (1 – tak)</xsl:when>
      <xsl:when test="$nazwa='GTU_01'">Dostawa napojów alkoholowych – alkoholu etylowego, piwa, wina, napojów fermentowanych i wyrobów pośrednich (w rozumieniu przepisów o podatku akcyzowym)</xsl:when>
      <xsl:when test="$nazwa='GTU_02'">Dostawa towarów, o których mowa w art. 103 ust. 5aa ustawy (paliwa)</xsl:when>
      <xsl:when test="$nazwa='GTU_03'">Dostawa oleju opałowego, olejów smarowych i pozostałych olejów (wybrane kody CN 2710 i 3403)</xsl:when>
      <xsl:when test="$nazwa='GTU_04'">Dostawa wyrobów tytoniowych, suszu tytoniowego, płynu do papierosów elektronicznych i wyrobów nowatorskich</xsl:when>
      <xsl:when test="$nazwa='GTU_05'">Dostawa odpadów – wyłącznie określonych w poz. 79–91 załącznika nr 15 do ustawy</xsl:when>
      <xsl:when test="$nazwa='GTU_06'">Dostawa urządzeń elektronicznych oraz części i materiałów do nich (wybrane pozycje załącznika nr 15 do ustawy), a także folii typu stretch</xsl:when>
      <xsl:when test="$nazwa='GTU_07'">Dostawa pojazdów oraz części samochodowych (CN 8701–8708 oraz CN 8708 10 10)</xsl:when>
      <xsl:when test="$nazwa='GTU_08'">Dostawa metali szlachetnych oraz nieszlachetnych (wybrane pozycje załączników nr 12 i 15 do ustawy)</xsl:when>
      <xsl:when test="$nazwa='GTU_09'">Dostawa leków, środków spożywczych specjalnego przeznaczenia żywieniowego oraz wyrobów medycznych objętych obowiązkiem zgłoszenia (art. 37av ust. 1 Prawa farmaceutycznego)</xsl:when>
      <xsl:when test="$nazwa='GTU_10'">Dostawa budynków, budowli i gruntów oraz ich części i udziałów w prawach do nich</xsl:when>
      <xsl:when test="$nazwa='GTU_11'">Świadczenie usług w zakresie przenoszenia uprawnień do emisji gazów cieplarnianych</xsl:when>
      <xsl:when test="$nazwa='GTU_12'">Świadczenie usług niematerialnych – wyłącznie doradczych, księgowych, prawnych, zarządczych, szkoleniowych, marketingowych, firm centralnych (head offices), reklamowych, badania rynku i opinii publicznej, badań naukowych i prac rozwojowych</xsl:when>
      <xsl:when test="$nazwa='GTU_13'">Świadczenie usług transportowych i gospodarki magazynowej (PKWiU 2015 sekcja H)</xsl:when>
      <xsl:when test="$nazwa='WSTO_EE'">Wewnątrzwspólnotowa sprzedaż towarów na odległość oraz usługi telekomunikacyjne, nadawcze i elektroniczne na rzecz konsumentów z innych państw UE (art. 28k ustawy)</xsl:when>
      <xsl:when test="$nazwa='IED'">Dostawa towarów, o której mowa w art. 7a ust. 1 i 2 ustawy, przez podatnika ułatwiającego tę dostawę (interfejs elektroniczny), poza procedurami szczególnymi</xsl:when>
      <xsl:when test="$nazwa='TP'">Istniejące powiązania między nabywcą a dokonującym dostawy towarów lub usługodawcą (art. 32 ust. 2 pkt 1 ustawy)</xsl:when>
      <xsl:when test="$nazwa='TT_WNT'">Wewnątrzwspólnotowe nabycie towarów przez drugiego w kolejności podatnika VAT w ramach wewnątrzwspólnotowej transakcji trójstronnej (procedura uproszczona)</xsl:when>
      <xsl:when test="$nazwa='TT_D'">Dostawa towarów poza terytorium kraju przez drugiego w kolejności podatnika VAT w ramach wewnątrzwspólnotowej transakcji trójstronnej (procedura uproszczona)</xsl:when>
      <xsl:when test="$nazwa='MR_T'">Świadczenie usług turystyki opodatkowane na zasadach marży (art. 119 ustawy)</xsl:when>
      <xsl:when test="$nazwa='MR_UZ'">Dostawa towarów używanych, dzieł sztuki, przedmiotów kolekcjonerskich i antyków opodatkowana na zasadach marży (art. 120 ustawy)</xsl:when>
      <xsl:when test="$nazwa='I_42'">Wewnątrzwspólnotowa dostawa towarów następująca po imporcie w ramach procedury celnej 42</xsl:when>
      <xsl:when test="$nazwa='I_63'">Wewnątrzwspólnotowa dostawa towarów następująca po imporcie w ramach procedury celnej 63</xsl:when>
      <xsl:when test="$nazwa='B_SPV'">Transfer bonu jednego przeznaczenia dokonany przez podatnika działającego we własnym imieniu (art. 8a ust. 1 ustawy)</xsl:when>
      <xsl:when test="$nazwa='B_SPV_DOSTAWA'">Dostawa towarów lub usług, których dotyczy bon jednego przeznaczenia, na rzecz podatnika, który wyemitował bon (art. 8a ust. 4 ustawy)</xsl:when>
      <xsl:when test="$nazwa='B_MPV_PROWIZJA'">Świadczenie usług pośrednictwa oraz innych usług dotyczących transferu bonu różnego przeznaczenia (art. 8b ust. 2 ustawy)</xsl:when>
      <xsl:when test="$nazwa='MPP'">Transakcja objęta obowiązkiem stosowania mechanizmu podzielonej płatności (oznaczenie z wcześniejszych wersji JPK_V7)</xsl:when>
      <xsl:when test="$nazwa='IMP'">Podatek naliczony z tytułu importu towarów, w tym importu towarów rozliczanego zgodnie z art. 33a ustawy</xsl:when>
      <xsl:when test="$nazwa='DataWytworzeniaJPK'">Data i czas sporządzenia JPK_VAT</xsl:when>
      <xsl:when test="$nazwa='NazwaSystemu'">Nazwa systemu, z którego pochodzą dane</xsl:when>
      <xsl:when test="$nazwa='NIP'">Identyfikator podatkowy NIP</xsl:when>
      <xsl:when test="$nazwa='PelnaNazwa'">Pełna nazwa</xsl:when>
      <xsl:when test="$nazwa='Telefon'">Numer telefonu kontaktowego</xsl:when>
      <xsl:when test="$nazwa='JPK'">Jednolity plik kontrolny dla ewidencji w zakresie rozliczenia podatku należnego i naliczonego oraz deklaracji VAT-7</xsl:when>
      <xsl:when test="$nazwa='Naglowek'">Nagłówek JPK_VAT</xsl:when>
      <xsl:when test="$nazwa='Deklaracja'">DEKLARACJA O PODATKU OD TOWARÓW I USŁUG</xsl:when>
      <xsl:when test="$nazwa='KodFormularzaDekl'">Kod formularza VAT-7</xsl:when>
      <xsl:when test="$nazwa='WariantFormularzaDekl'">Wariant formularza VAT-7</xsl:when>
      <xsl:when test="$nazwa='PozycjeSzczegolowe'">Dane niezbędne do obliczenia wysokości podatku należnego, obliczenia wysokości podatku naliczonego, obliczenia wysokości podatku lub zwrotu podatku wraz z oznaczeniem sposobu dokonania tego zwrotu</xsl:when>
      <xsl:when test="$nazwa='P_10'">Wysokość podstawy opodatkowania z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, zwolnionych od podatku</xsl:when>
      <xsl:when test="$nazwa='P_11'">Wysokość podstawy opodatkowania z tytułu dostawy towarów oraz świadczenia usług poza terytorium kraju</xsl:when>
      <xsl:when test="$nazwa='P_12'">Wysokość podstawy opodatkowania z tytułu świadczenia usług, o których mowa w art. 100 ust. 1 pkt 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_13'">Wysokość podstawy opodatkowania z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 0%</xsl:when>
      <xsl:when test="$nazwa='P_14'">Wysokość podstawy opodatkowania z tytułu dostawy towarów, o której mowa w art. 129 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_15'">Wysokość podstawy opodatkowania z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 5%, oraz korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_16'">Wysokość podatku należnego z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 5%, oraz korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_17'">Wysokość podstawy opodatkowania z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 7% albo 8%, oraz korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_18'">Wysokość podatku należnego z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 7% albo 8%, oraz korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_19'">Wysokość podstawy opodatkowania z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 22% albo 23%, oraz korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_20'">Wysokość podatku należnego z tytułu dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 22% albo 23%, oraz korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_21'">Wysokość podstawy opodatkowania z tytułu wewnątrzwspólnotowej dostawy towarów</xsl:when>
      <xsl:when test="$nazwa='P_22'">Wysokość podstawy opodatkowania z tytułu eksportu towarów</xsl:when>
      <xsl:when test="$nazwa='P_23'">Wysokość podstawy opodatkowania z tytułu wewnątrzwspólnotowego nabycia towarów</xsl:when>
      <xsl:when test="$nazwa='P_24'">Wysokość podatku należnego z tytułu wewnątrzwspólnotowego nabycia towarów</xsl:when>
      <xsl:when test="$nazwa='P_25'">Wysokość podstawy opodatkowania z tytułu importu towarów rozliczanego zgodnie z art. 33a ustawy</xsl:when>
      <xsl:when test="$nazwa='P_26'">Wysokość podatku należnego z tytułu importu towarów rozliczanego zgodnie z art. 33a ustawy</xsl:when>
      <xsl:when test="$nazwa='P_27'">Wysokość podstawy opodatkowania z tytułu importu usług, z wyłączeniem usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='P_28'">Wysokość podatku należnego z tytułu importu usług, z wyłączeniem usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='P_29'">Wysokość podstawy opodatkowania z tytułu importu usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='P_30'">Wysokość podatku należnego z tytułu importu usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='P_31'">Wysokość podstawy opodatkowania z tytułu dostawy towarów, dla których podatnikiem jest nabywca zgodnie z art. 17 ust. 1 pkt 5 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_32'">Wysokość podatku należnego z tytułu dostawy towarów, dla których podatnikiem jest nabywca zgodnie z art. 17 ust. 1 pkt 5 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_33'">Wysokość podatku należnego od towarów objętych spisem z natury, o którym mowa w art. 14 ust. 5 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_34'">Wysokość zwrotu odliczonej lub zwróconej kwoty wydanej na zakup kas rejestrujących, o którym mowa w art. 111 ust. 6 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_35'">Wysokość podatku należnego od wewnątrzwspólnotowego nabycia środków transportu, wykazana w wysokości podatku należnego z tytułu określonego w P_24, podlegająca wpłacie w terminie, o którym mowa w art. 103 ust. 3, w związku z ust. 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_36'">Wysokość podatku od wewnątrzwspólnotowego nabycia towarów, o których mowa w art. 103 ust. 5aa ustawy, podlegająca wpłacie w terminach, o których mowa w art. 103 ust. 5a i 5ac ustawy</xsl:when>
      <xsl:when test="$nazwa='P_360'">Wysokość podatku od niezwróconej kaucji pobranej za produkty w opakowaniach na napoje objęte systemem kaucyjnym, podlegająca wpłacie przez podmiot reprezentujący, o którym mowa w art. 17b ustawy</xsl:when>
      <xsl:when test="$nazwa='P_37'">Łączna wysokość podstawy opodatkowania. Suma kwot z P_10, P_11, P_13, P_15, P_17, P_19, P_21, P_22, P_23, P_25, P_27, P_29, P_31</xsl:when>
      <xsl:when test="$nazwa='P_38'">Łączna wysokość podatku należnego. Suma kwot z P_16, P_18, P_20, P_24, P_26, P_28, P_30, P_32, P_33, P_34 pomniejszona o kwotę z P_35, P_36 i P_360</xsl:when>
      <xsl:when test="$nazwa='P_39'">Wysokość nadwyżki podatku naliczonego nad należnym z poprzedniej deklaracji</xsl:when>
      <xsl:when test="$nazwa='P_40'">Wartość netto z tytułu nabycia towarów i usług zaliczanych u podatnika do środków trwałych</xsl:when>
      <xsl:when test="$nazwa='P_41'">Wysokość podatku naliczonego z tytułu nabycia towarów i usług zaliczanych u podatnika do środków trwałych</xsl:when>
      <xsl:when test="$nazwa='P_42'">Wartość netto z tytułu nabycia pozostałych towarów i usług</xsl:when>
      <xsl:when test="$nazwa='P_43'">Wysokość podatku naliczonego z tytułu nabycia pozostałych towarów i usług</xsl:when>
      <xsl:when test="$nazwa='P_44'">Wysokość podatku naliczonego z tytułu korekty podatku naliczonego od nabycia towarów i usług zaliczanych u podatnika do środków trwałych</xsl:when>
      <xsl:when test="$nazwa='P_45'">Wysokość podatku naliczonego z tytułu korekty podatku naliczonego od nabycia pozostałych towarów i usług</xsl:when>
      <xsl:when test="$nazwa='P_46'">Wysokość podatku naliczonego z tytułu korekty podatku naliczonego, o której mowa w art. 89b ust. 1 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_47'">Wysokość podatku naliczonego z tytułu korekty podatku naliczonego, o której mowa w art. 89b ust. 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_48'">Łączna wysokość podatku naliczonego do odliczenia. Suma kwot z P_39, P_41, P_43, P_44, P_45, P_46 i P_47</xsl:when>
      <xsl:when test="$nazwa='P_49'">Kwota wydana na zakup kas rejestrujących, do odliczenia w danym okresie rozliczeniowym pomniejszająca wysokość podatku należnego</xsl:when>
      <xsl:when test="$nazwa='P_50'">Wysokość podatku objęta zaniechaniem poboru</xsl:when>
      <xsl:when test="$nazwa='P_51'">Wysokość podatku podlegająca wpłacie do urzędu skarbowego</xsl:when>
      <xsl:when test="$nazwa='P_52'">Kwota wydana na zakup kas rejestrujących, do odliczenia w danym okresie rozliczeniowym przysługująca do zwrotu w danym okresie rozliczeniowym lub powiększająca wysokość podatku naliczonego do przeniesienia na następny okres rozliczeniowy</xsl:when>
      <xsl:when test="$nazwa='P_53'">Wysokość nadwyżki podatku naliczonego nad należnym</xsl:when>
      <xsl:when test="$nazwa='P_54'">Wysokość nadwyżki podatku naliczonego nad należnym do zwrotu na rachunek wskazany przez podatnika</xsl:when>
      <xsl:when test="$nazwa='P_540'">Zwrot na rachunek rozliczeniowy podatnika w terminie 15 dni: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_55'">Zwrot na rachunek VAT podatnika w terminie 25 dni: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_56'">Zwrot na rachunek rozliczeniowy podatnika w terminie 25 dni (art. 87 ust. 6 ustawy): 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_560'">Zwrot na rachunek rozliczeniowy podatnika w terminie 40 dni: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_58'">Zwrot na rachunek rozliczeniowy podatnika w terminie 180 dni: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_59'">Zaliczenie zwrotu podatku na poczet przyszłych zobowiązań podatkowych: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_60'">Wysokość zwrotu do zaliczenia na poczet przyszłych zobowiązań podatkowych</xsl:when>
      <xsl:when test="$nazwa='P_61'">Rodzaj przyszłego zobowiązania podatkowego</xsl:when>
      <xsl:when test="$nazwa='P_62'">Wysokość nadwyżki podatku naliczonego nad należnym do przeniesienia na następny okres rozliczeniowy</xsl:when>
      <xsl:when test="$nazwa='P_63'">Podatnik wykonywał w okresie rozliczeniowym czynności, o których mowa w art. 119 ustawy: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_64'">Podatnik wykonywał w okresie rozliczeniowym czynności, o których mowa w art. 120 ust. 4 lub 5 ustawy: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_65'">Podatnik wykonywał w okresie rozliczeniowym czynności, o których mowa w art. 122 ustawy: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_66'">Podatnik wykonywał w okresie rozliczeniowym czynności, o których mowa w art. 136 ustawy: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_660'">Podatnik ułatwiał w okresie rozliczeniowym dokonanie czynności, o których mowa w art. 109b ust. 4 ustawy: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_67'">Podatnik korzysta z obniżenia zobowiązania podatkowego, o którym mowa w art. 108d ustawy: 1 - tak</xsl:when>
      <xsl:when test="$nazwa='P_68'">Wysokość korekty podstawy opodatkowania, o której mowa w art. 89a ust. 1 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_69'">Wysokość korekty podatku należnego, o której mowa w art. 89a ust. 1 ustawy</xsl:when>
      <xsl:when test="$nazwa='P_ORDZU'">Uzasadnienie przyczyn złożenia korekty</xsl:when>
      <xsl:when test="$nazwa='Ewidencja'">Ewidencja zawierająca dane pozwalające na prawidłowe rozliczenie podatku należnego i podatku naliczonego</xsl:when>
      <xsl:when test="$nazwa='LpSprzedazy'">Lp. wiersza ewidencji w zakresie rozliczenia podatku należnego</xsl:when>
      <xsl:when test="$nazwa='KodKrajuNadaniaTIN'">Kod kraju nadania numeru, za pomocą którego nabywca, dostawca lub usługodawca jest zidentyfikowany na potrzeby podatku lub podatku od wartości dodanej</xsl:when>
      <xsl:when test="$nazwa='NrKontrahenta'">Numer, za pomocą którego nabywca, dostawca lub usługodawca jest zidentyfikowany na potrzeby podatku lub podatku od wartości dodanej (wyłącznie kod cyfrowo-literowy)</xsl:when>
      <xsl:when test="$nazwa='NazwaKontrahenta'">Imię i nazwisko lub nazwa nabywcy, dostawcy lub usługodawcy</xsl:when>
      <xsl:when test="$nazwa='DowodSprzedazy'">Numer dowodu</xsl:when>
      <xsl:when test="$nazwa='DataWystawienia'">Data wystawienia dowodu</xsl:when>
      <xsl:when test="$nazwa='DataSprzedazy'">Data dokonania lub zakończenia dostawy towarów lub wykonania usługi lub data otrzymania zapłaty, o której mowa w art. 106b ust. 1 pkt 4 ustawy, o ile taka data jest określona i różni się od daty wystawienia dowodu, a w przypadku, o którym mowa w art. 106e ust. 1a ustawy, datę dokonania lub zakończenia dostawy towarów lub wykonania usługi, jeżeli taka data jest określona i różni się od daty wystawienia faktury. W przeciwnym przypadku - pole puste</xsl:when>
      <xsl:when test="$nazwa='NrKSeF'">Numer identyfikujący fakturę w Krajowym Systemie e-Faktur</xsl:when>
      <xsl:when test="$nazwa='OFF'">Faktura, o której mowa w art. 106nf ust. 1 ustawy, która na dzień złożenia ewidencji nie posiada numeru identyfikującego tę fakturę w Krajowym Systemie e-Faktur</xsl:when>
      <xsl:when test="$nazwa='BFK'">Faktura elektroniczna lub faktura w postaci papierowej</xsl:when>
      <xsl:when test="$nazwa='DI'">Dowód inny niż faktura</xsl:when>
      <xsl:when test="$nazwa='TypDokumentu'">Oznaczenie dowodu sprzedaży</xsl:when>
      <xsl:when test="$nazwa='KorektaPodstawyOpodt'">Korekta podstawy opodatkowania oraz podatku należnego, o której mowa w art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='TerminPlatnosci'">Data upływu terminu płatności w przypadku korekt dokonanych zgodnie z art. 89a ust. 1 ustawy</xsl:when>
      <xsl:when test="$nazwa='DataZaplaty'">Data uregulowania lub zbycia należności w przypadku korekty dokonanej zgodnie z art. 89a ust. 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_10'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, zwolnionych od podatku</xsl:when>
      <xsl:when test="$nazwa='K_11'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów oraz świadczenia usług poza terytorium kraju</xsl:when>
      <xsl:when test="$nazwa='K_12'">Wysokość podstawy opodatkowania wynikająca ze świadczenia usług, o których mowa w art. 100 ust. 1 pkt 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_13'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 0%</xsl:when>
      <xsl:when test="$nazwa='K_14'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów, o której mowa w art. 129 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_15'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 5%, z uwzględnieniem korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_16'">Wysokość podatku należnego wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 5%, z uwzględnieniem korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_17'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 7% albo 8%, z uwzględnieniem korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_18'">Wysokość podatku należnego wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 7% albo 8%, z uwzględnieniem korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_19'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 22% albo 23%, z uwzględnieniem korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_20'">Wysokość podatku należnego wynikająca z dostawy towarów oraz świadczenia usług na terytorium kraju, opodatkowanych stawką 22% albo 23%, z uwzględnieniem korekty dokonanej zgodnie z art. 89a ust. 1 i 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_21'">Wysokość podstawy opodatkowania wynikająca z wewnątrzwspólnotowej dostawy towarów, o której mowa w art. 13 ust. 1 i 3 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_22'">Wysokość podstawy opodatkowania wynikająca z eksportu towarów</xsl:when>
      <xsl:when test="$nazwa='K_23'">Wysokość podstawy opodatkowania wynikająca z wewnątrzwspólnotowego nabycia towarów</xsl:when>
      <xsl:when test="$nazwa='K_24'">Wysokość podatku należnego wynikająca z wewnątrzwspólnotowego nabycia towarów</xsl:when>
      <xsl:when test="$nazwa='K_25'">Wysokość podstawy opodatkowania wynikająca z importu towarów rozliczanego zgodnie z art. 33a ustawy, potwierdzona zgłoszeniem celnym lub deklaracją importową, o której mowa w art. 33b ustawy</xsl:when>
      <xsl:when test="$nazwa='K_26'">Wysokość podatku należnego wynikająca z importu towarów rozliczanego zgodnie z art. 33a ustawy, potwierdzona zgłoszeniem celnym lub deklaracją importową, o której mowa w art. 33b ustawy</xsl:when>
      <xsl:when test="$nazwa='K_27'">Wysokość podstawy opodatkowania wynikająca z importu usług, z wyłączeniem usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='K_28'">Wysokość podatku należnego wynikająca z importu usług, z wyłączeniem usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='K_29'">Wysokość podstawy opodatkowania wynikająca z importu usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='K_30'">Wysokość podatku należnego wynikająca z importu usług nabywanych od podatników podatku od wartości dodanej, do których stosuje się art. 28b ustawy</xsl:when>
      <xsl:when test="$nazwa='K_31'">Wysokość podstawy opodatkowania wynikająca z dostawy towarów, dla których podatnikiem jest nabywca zgodnie z art. 17 ust. 1 pkt 5 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_32'">Wysokość podatku należnego wynikająca z dostawy towarów, dla których podatnikiem jest nabywca zgodnie z art. 17 ust. 1 pkt 5 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_33'">Wysokość podatku należnego od towarów objętych spisem z natury, o którym mowa w art. 14 ust. 5 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_34'">Wysokość zwrotu odliczonej lub zwróconej kwoty wydanej na zakup kas rejestrujących, o którym mowa w art. 111 ust. 6 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_35'">Wysokość podatku należnego od wewnątrzwspólnotowego nabycia środków transportu, wykazana w wysokości podatku należnego z tytułu wewnątrzwspólnotowego nabycia towarów, podlegająca wpłacie w terminie, o którym mowa w art. 103 ust. 3, w związku z ust. 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_36'">Wysokość podatku należnego od wewnątrzwspólnotowego nabycia towarów, o których mowa w art. 103 ust. 5aa ustawy, podlegająca wpłacie w terminie, o którym mowa w art. 103 ust. 5a i 5ac ustawy</xsl:when>
      <xsl:when test="$nazwa='K_360'">Wysokość podatku od niezwróconej kaucji pobranej za produkty w opakowaniach na napoje objęte systemem kaucyjnym, podlegająca wpłacie przez podmiot reprezentujący, o którym mowa w art. 17b ustawy</xsl:when>
      <xsl:when test="$nazwa='SprzedazVAT_Marza'">Wartość sprzedaży brutto dostawy towarów i świadczenia usług opodatkowanych na zasadach marży zgodnie z art. 119 i art. 120 ustawy</xsl:when>
      <xsl:when test="$nazwa='SprzedazCtrl'">Sumy kontrolne dla ewidencji w zakresie rozliczenia podatku należnego</xsl:when>
      <xsl:when test="$nazwa='LiczbaWierszySprzedazy'">Liczba wierszy ewidencji w zakresie rozliczenia podatku należnego w okresie, którego dotyczy JPK. Jeżeli ewidencja nie zawiera wierszy, należy wykazać 0</xsl:when>
      <xsl:when test="$nazwa='PodatekNalezny'">Podatek należny według ewidencji w okresie, którego dotyczy JPK - suma kwot z K_16, K_18, K_20, K_24, K_26, K_28, K_30, K_32, K_33 i K_34 pomniejszona o kwotę z K_35, K_36 i K_360, z wyłączeniem faktur oznaczonych FP. Jeżeli w ewidencji nie wypełniono żadnego ze wskazanych elementów, wówczas należy wykazać 0.00</xsl:when>
      <xsl:when test="$nazwa='LpZakupu'">Lp. wiersza ewidencji w zakresie rozliczenia podatku naliczonego</xsl:when>
      <xsl:when test="$nazwa='NrDostawcy'">Numer, za pomocą którego dostawca lub usługodawca jest zidentyfikowany na potrzeby podatku lub podatku od wartości dodanej (wyłącznie kod cyfrowo-literowy)</xsl:when>
      <xsl:when test="$nazwa='NazwaDostawcy'">Imię i nazwisko lub nazwa dostawcy lub usługodawcy</xsl:when>
      <xsl:when test="$nazwa='DowodZakupu'">Numer dowodu zakupu</xsl:when>
      <xsl:when test="$nazwa='DataZakupu'">Data wystawienia dowodu zakupu</xsl:when>
      <xsl:when test="$nazwa='DataWplywu'">Data otrzymania dowodu zakupu</xsl:when>
      <xsl:when test="$nazwa='DokumentZakupu'">Oznaczenie dowodu zakupu</xsl:when>
      <xsl:when test="$nazwa='K_40'">Wartość netto wynikająca z nabycia towarów i usług zaliczanych u podatnika do środków trwałych</xsl:when>
      <xsl:when test="$nazwa='K_41'">Wysokość podatku naliczonego przysługująca do odliczenia z podstaw określonych w art. 86 ust. 2 ustawy, na warunkach określonych w ustawie wynikająca z nabycia towarów i usług zaliczanych u podatnika do środków trwałych</xsl:when>
      <xsl:when test="$nazwa='K_42'">Wartość netto wynikająca z nabycia pozostałych towarów i usług</xsl:when>
      <xsl:when test="$nazwa='K_43'">Wysokość podatku naliczonego przysługująca do odliczenia z podstaw określonych w art. 86 ust. 2 ustawy, na warunkach określonych w ustawie wynikająca z nabycia pozostałych towarów i usług</xsl:when>
      <xsl:when test="$nazwa='K_44'">Wysokość podatku naliczonego wynikająca z korekt podatku naliczonego, o których mowa w art. 90a-90c oraz art. 91 ustawy, z tytułu nabycia towarów i usług zaliczanych u podatnika do środków trwałych</xsl:when>
      <xsl:when test="$nazwa='K_45'">Wysokość podatku naliczonego wynikająca z korekt podatku naliczonego, o których mowa w art. 90a-90c oraz art. 91 ustawy, z tytułu nabycia pozostałych towarów i usług</xsl:when>
      <xsl:when test="$nazwa='K_46'">Wysokość podatku naliczonego wynikająca z korekty podatku naliczonego, o której mowa w art. 89b ust. 1 ustawy</xsl:when>
      <xsl:when test="$nazwa='K_47'">Wysokość podatku naliczonego wynikająca z korekty podatku naliczonego, o której mowa w art. 89b ust. 4 ustawy</xsl:when>
      <xsl:when test="$nazwa='ZakupVAT_Marza'">Wartość nabycia towarów i usług nabytych od innych podatników dla bezpośredniej korzyści turysty albo wartość nabycia towarów używanych, dzieł sztuki, przedmiotów kolekcjonerskich i antyków związanych ze sprzedażą opodatkowaną na zasadach marży zgodnie z art. 120 ustawy</xsl:when>
      <xsl:when test="$nazwa='ZakupCtrl'">Sumy kontrolne dla ewidencji w zakresie rozliczenia podatku naliczonego</xsl:when>
      <xsl:when test="$nazwa='LiczbaWierszyZakupow'">Liczba wierszy ewidencji w zakresie rozliczenia podatku naliczonego w okresie, którego dotyczy JPK. Jeżeli ewidencja nie zawiera wierszy, należy wykazać 0</xsl:when>
      <xsl:when test="$nazwa='PodatekNaliczony'">Razem wysokość podatku naliczonego do odliczenia - suma kwot z K_41, K_43, K_44, K_45, K_46, K_47. Jeżeli w ewidencji nie wypełniono żadnego ze wskazanych elementów, wówczas należy wykazać 0.00</xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- opisy wartości TypDokumentu / DokumentZakupu -->
  <xsl:template name="opisWartosci">
    <xsl:param name="kod"/>
    <xsl:choose>
      <xsl:when test="$kod='RO'">Dokument zbiorczy wewnętrzny zawierający informacje o sprzedaży z kas rejestrujących</xsl:when>
      <xsl:when test="$kod='WEW'">Dokument wewnętrzny</xsl:when>
      <xsl:when test="$kod='FP'">Faktura do paragonu (art. 109 ust. 3d ustawy) – nie wlicza się do sumy kontrolnej ani do deklaracji</xsl:when>
      <xsl:when test="$kod='MK'">Faktura wystawiona przez dostawcę/usługodawcę rozliczającego się metodą kasową (art. 21 ustawy)</xsl:when>
      <xsl:when test="$kod='VAT_RR'">Faktura VAT RR (art. 116 ustawy) – zakup od rolnika ryczałtowego</xsl:when>
    </xsl:choose>
  </xsl:template>
  <!-- OPISY-KONIEC -->

  <!-- ============================================================ -->
  <!-- Widok ogólny – dla plików innych niż JPK_V7                  -->
  <!-- ============================================================ -->
  <xsl:template name="widokOgolny">
    <header>
      <div class="tytul">
        <h1><xsl:value-of select="local-name(/*)"/></h1>
        <div class="podtytul">Plik: <b><xsl:value-of select="$plik"/></b> – widok ogólny (struktura nierozpoznana jako JPK_V7)</div>
      </div>
    </header>
    <main class="drzewo">
      <xsl:apply-templates select="/*/*" mode="drzewo"/>
    </main>
  </xsl:template>

  <xsl:template match="*[*]" mode="drzewo">
    <details>
      <xsl:if test="count(ancestor::*) &lt; 2"><xsl:attribute name="open">open</xsl:attribute></xsl:if>
      <summary><xsl:value-of select="local-name()"/>
        <xsl:for-each select="@*"><span class="muted"><xsl:text> </xsl:text><xsl:value-of select="local-name()"/>=<xsl:value-of select="."/></span></xsl:for-each>
      </summary>
      <xsl:if test="*[not(*)]">
        <dl><xsl:apply-templates select="*[not(*)]" mode="dl"/></dl>
      </xsl:if>
      <xsl:apply-templates select="*[*]" mode="drzewo"/>
    </details>
  </xsl:template>

  <xsl:template match="*" mode="drzewo">
    <dl><xsl:apply-templates select="." mode="dl"/></dl>
  </xsl:template>

  <!-- ============================================================ -->
  <xsl:template name="css"><![CDATA[
:root{--bg:#f6f7f9;--karta:#fff;--tekst:#1d232b;--muted:#6b7480;--linia:#e3e6ea;--akcent:#1f5fbf;--ok:#1a7f37;--blad:#c62828;--warn:#b26a00}
*{box-sizing:border-box}
body{margin:0;font:14px/1.45 "Segoe UI",system-ui,sans-serif;background:var(--bg);color:var(--tekst)}
header{position:sticky;top:0;z-index:5;background:var(--karta);border-bottom:1px solid var(--linia);padding:12px 24px;display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between}
h1{font-size:20px;margin:0}
h1 .okres{font-weight:400;color:var(--muted);margin-left:10px}
h2{font-size:16px;margin:0 0 10px}
.podtytul{color:var(--muted);font-size:13px;margin-top:2px}
nav a{margin-left:16px;color:var(--akcent);text-decoration:none;font-weight:500}
nav a:hover{text-decoration:underline}
main{padding:20px 24px;max-width:1700px;margin:0 auto}
section{margin-bottom:28px;scroll-margin-top:80px}
.kpi{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}
.tile{background:var(--karta);border:1px solid var(--linia);border-radius:8px;padding:12px 16px}
.tile span{display:block;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em}
.tile b{font-size:20px;font-variant-numeric:tabular-nums}
.tile.accent{border-color:var(--akcent);box-shadow:inset 4px 0 0 var(--akcent)}
.karty{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:12px}
.karta{background:var(--karta);border:1px solid var(--linia);border-radius:8px;padding:14px 18px}
dl{display:grid;grid-template-columns:max-content 1fr;gap:3px 16px;margin:0}
dt{color:var(--muted)}dd{margin:0;word-break:break-word}
.muted{color:var(--muted)}
.sekcja-nag{display:flex;flex-wrap:wrap;align-items:center;gap:14px;margin-bottom:10px}
.sekcja-nag h2{margin:0}
.szukaj{flex:1;min-width:260px;max-width:480px;padding:7px 10px;border:1px solid var(--linia);border-radius:6px;font:inherit}
.licznik{color:var(--muted);font-size:13px}
.przelacznik{color:var(--muted);font-size:13px;cursor:pointer}
table{width:100%;border-collapse:collapse;background:var(--karta);border:1px solid var(--linia);border-radius:8px}
th,td{padding:6px 10px;border-bottom:1px solid var(--linia);text-align:left;vertical-align:top}
th{background:#eef1f5;font-size:12px;text-transform:uppercase;letter-spacing:.03em;color:#4a5360;position:sticky;top:0;white-space:nowrap}
th[data-sort]{cursor:pointer;user-select:none}
th[data-sort]:hover{color:var(--akcent)}
th.asc::after{content:" ▲"}th.desc::after{content:" ▼"}
.num{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
tbody tr:hover{background:#f3f7ff}
tfoot td{font-weight:600;background:#eef1f5}
.przewijanie{max-height:75vh;overflow:auto;border-radius:8px}
.ew td{font-size:13px}
.nazwa{font-weight:500}
.nip{color:var(--muted);font-size:12px}
.ksef{font-family:Consolas,monospace;font-size:11px;color:var(--muted);word-break:break-all;min-width:150px}
.data{white-space:nowrap}
.badge{display:inline-block;padding:1px 6px;margin:1px 2px;border-radius:4px;background:#e8eefb;color:#1d4f9e;font-size:11px;font-weight:600;white-space:nowrap}
.badge.warn{background:#fff1dc;color:var(--warn)}
.chip{display:inline-block;padding:1px 6px;margin:1px 2px;border-radius:4px;background:#f1f2f4;font-size:11px;white-space:nowrap;font-variant-numeric:tabular-nums;cursor:help}
.dekl .poz{font-family:Consolas,monospace;white-space:nowrap}
.dekl tr.razem td{font-weight:600;background:#f7f9fc}
.ukryj-zera tr.zero{display:none}
.dekl td.opis{font-size:13px;max-width:760px}
dt[title],.badge[title]{cursor:help}
dt[title]{text-decoration:underline dotted #b0b7c0}
tr.fp td{color:var(--muted);font-style:italic}
.ok{color:var(--ok);font-weight:700}.blad{color:var(--blad);font-weight:700}.nd{color:var(--muted);font-weight:700;cursor:help}
.info{margin:0 0 10px;padding:8px 12px;border:1px solid var(--linia);border-left:4px solid var(--akcent);border-radius:6px;background:var(--karta);font-size:13px}
.info.warn{border-left-color:var(--warn);background:#fffaf2}
.kontrola td:first-child{width:50%}
.drzewo details{margin-left:16px;border-left:2px solid var(--linia);padding-left:10px}
.drzewo summary{cursor:pointer;font-weight:600;padding:2px 0}
.drzewo dl{margin:4px 0 8px 16px}
footer{color:var(--muted);font-size:12px;text-align:center;padding:20px}
@media print{header{position:static}.szukaj,.przelacznik{display:none}.przewijanie{max-height:none;overflow:visible}th{position:static}}
]]></xsl:template>

  <xsl:template name="js"><![CDATA[
(function(){
  // wyszukiwanie w tabelach
  document.querySelectorAll('input.szukaj').forEach(function(inp){
    var tab=document.getElementById(inp.dataset.tabela); if(!tab) return;
    var wiersze=Array.prototype.slice.call(tab.tBodies[0].rows);
    var teksty=wiersze.map(function(r){return r.textContent.toLowerCase();});
    var licznik=document.getElementById(inp.dataset.tabela+'-licznik');
    function filtruj(){
      var q=inp.value.trim().toLowerCase(), n=0;
      wiersze.forEach(function(r,i){var w=!q||teksty[i].indexOf(q)>=0; r.style.display=w?'':'none'; if(w)n++;});
      if(licznik) licznik.textContent=q?('znaleziono: '+n+' z '+wiersze.length):('wierszy: '+wiersze.length);
    }
    var t; inp.addEventListener('input',function(){clearTimeout(t);t=setTimeout(filtruj,150);});
    filtruj();
  });
  // sortowanie po kliknięciu nagłówka
  document.querySelectorAll('th[data-sort]').forEach(function(th){
    th.addEventListener('click',function(){
      var tab=th.closest('table'), tb=tab.tBodies[0], idx=th.cellIndex, num=th.dataset.sort==='n';
      var asc=!th.classList.contains('asc');
      tab.querySelectorAll('th').forEach(function(h){h.classList.remove('asc','desc');});
      th.classList.add(asc?'asc':'desc');
      var w=Array.prototype.slice.call(tb.rows);
      function val(r){var c=r.cells[idx]; if(num) return parseFloat(c.dataset.v!==undefined?c.dataset.v:c.textContent.replace(/\s/g,'').replace(',','.'))||0; return c.textContent.trim().toLowerCase();}
      w.sort(function(a,b){var x=val(a),y=val(b); var r=num?x-y:x.localeCompare(y,'pl'); return asc?r:-r;});
      w.forEach(function(r){tb.appendChild(r);});
    });
  });
  // ukrywanie zerowych pozycji deklaracji
  var cb=document.getElementById('ukryjZera'), td=document.getElementById('tabDekl');
  if(cb&&td) cb.addEventListener('change',function(){td.classList.toggle('ukryj-zera',cb.checked);});
})();
]]></xsl:template>

</xsl:stylesheet>
