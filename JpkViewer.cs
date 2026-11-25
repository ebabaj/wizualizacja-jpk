// JpkViewer – wizualizacja pliku JPK (.xml) jako strony HTML.
// Wykorzystuje System.Xml.Xsl.XslCompiledTransform (.NET Framework 4.x – wbudowany w Windows).
//
// Użycie:
//   JpkViewer.exe                      -> okno wyboru pliku(ów)
//   JpkViewer.exe plik1.xml [plik2...] -> przetwarza wskazane pliki (działa też "przeciągnij i upuść" na .exe)
//   JpkViewer.exe /nie-otwieraj ...    -> tylko zapisuje HTML, bez otwierania przeglądarki
//
// Szablon XSLT jest wkompilowany w .exe. Jeśli obok programu leży plik jpk_v7.xslt,
// używany jest on zamiast wbudowanego (można go edytować bez ponownej kompilacji).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;
using System.Xml;
using System.Xml.Xsl;

static class JpkViewer
{
    const string NazwaSzablonu = "jpk_v7.xslt";

    [STAThread]
    static int Main(string[] args)
    {
        bool otwieraj = true;
        List<string> pliki = new List<string>();
        foreach (string a in args)
        {
            if (a.Equals("/nie-otwieraj", StringComparison.OrdinalIgnoreCase)) otwieraj = false;
            else pliki.Add(a);
        }

        if (pliki.Count == 0)
        {
            using (OpenFileDialog dlg = new OpenFileDialog())
            {
                dlg.Title = "Wybierz plik JPK do wizualizacji";
                dlg.Filter = "Pliki JPK (*.xml)|*.xml|Wszystkie pliki (*.*)|*.*";
                dlg.Multiselect = true;
                if (dlg.ShowDialog() != DialogResult.OK) return 0;
                pliki.AddRange(dlg.FileNames);
            }
        }

        XslCompiledTransform xslt;
        try
        {
            xslt = WczytajSzablon();
        }
        catch (Exception ex)
        {
            Blad("Nie udało się wczytać szablonu XSLT:\n\n" + ex.Message);
            return 2;
        }

        int bledy = 0;
        foreach (string plik in pliki)
        {
            try
            {
                string html = Przeksztalc(xslt, Path.GetFullPath(plik), pliki);
                if (otwieraj)
                {
                    ProcessStartInfo psi = new ProcessStartInfo(html);
                    psi.UseShellExecute = true;
                    Process.Start(psi);
                }
            }
            catch (Exception ex)
            {
                bledy++;
                Blad("Błąd przetwarzania pliku:\n" + plik + "\n\n" + ex.Message);
            }
        }
        return bledy == 0 ? 0 : 1;
    }

    static XslCompiledTransform WczytajSzablon()
    {
        XslCompiledTransform xslt = new XslCompiledTransform();
        // Ustawienia domyślne: bez funkcji document() i bez skryptów w XSLT (bezpieczniej).
        XsltSettings ustawienia = XsltSettings.Default;

        string obok = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, NazwaSzablonu);
        Stream s = File.Exists(obok)
            ? (Stream)File.OpenRead(obok)
            : Assembly.GetExecutingAssembly().GetManifestResourceStream(NazwaSzablonu);
        if (s == null) throw new FileNotFoundException("Brak szablonu " + NazwaSzablonu);

        using (s)
        using (XmlReader r = XmlReader.Create(s))
        {
            xslt.Load(r, ustawienia, null);
        }
        return xslt;
    }

    static XmlReaderSettings UstawieniaCzytnika()
    {
        XmlReaderSettings rs = new XmlReaderSettings();
        rs.DtdProcessing = DtdProcessing.Prohibit;
        rs.XmlResolver = null;
        rs.IgnoreComments = true;
        rs.IgnoreWhitespace = true;
        return rs;
    }

    static string Przeksztalc(XslCompiledTransform xslt, string plikXml, List<string> wskazane)
    {
        XsltArgumentList argumenty = new XsltArgumentList();
        argumenty.AddParam("plik", "", Path.GetFileName(plikXml));
        argumenty.AddParam("wygenerowano", "", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        DodajDaneKwartalu(argumenty, plikXml, wskazane);

        XmlReaderSettings rs = UstawieniaCzytnika();

        string html = Path.ChangeExtension(plikXml, ".html");
        try
        {
            Zapisz(xslt, plikXml, rs, argumenty, html);
        }
        catch (UnauthorizedAccessException)
        {
            // katalog tylko do odczytu – zapis do folderu tymczasowego
            html = Path.Combine(Path.GetTempPath(), Path.GetFileNameWithoutExtension(plikXml) + ".html");
            Zapisz(xslt, plikXml, rs, argumenty, html);
        }
        return html;
    }

    static void Zapisz(XslCompiledTransform xslt, string plikXml, XmlReaderSettings rs,
                       XsltArgumentList argumenty, string html)
    {
        using (XmlReader wejscie = XmlReader.Create(plikXml, rs))
        using (FileStream wyjscie = new FileStream(html, FileMode.Create, FileAccess.Write))
        {
            // Przeciążenie ze Stream korzysta z ustawień <xsl:output> (method="html", utf-8).
            xslt.Transform(wejscie, argumenty, wyjscie);
        }
    }

    // ---------------------------------------------------------------
    // JPK_V7K: deklaracja jest tylko w pliku za ostatni miesiąc kwartału i dotyczy
    // całego kwartału, a ewidencja w tym pliku – tylko jednego miesiąca. Żeby porównać
    // deklarację z ewidencją, szukamy plików za pozostałe miesiące kwartału wśród
    // wskazanych plików i w folderze pliku (ten sam NIP i rok; przy kilku wersjach
    // pliku za ten sam miesiąc – najnowsza wg DataWytworzeniaJPK). Do szablonu trafiają
    // sumy pól K_ z tych plików oraz informacja, czy kwartał jest kompletny.

    class InfoJpk
    {
        public string Sciezka;
        public bool V7K;
        public int Rok, Miesiac;
        public int Kwartal;               // > 0 tylko gdy plik zawiera deklarację kwartalną
        public string Nip = "";
        public string DataWytworzenia = "";
    }

    static void DodajDaneKwartalu(XsltArgumentList argumenty, string plikXml, List<string> wskazane)
    {
        InfoJpk ten = CzytajNaglowek(plikXml);
        if (ten == null || !ten.V7K || ten.Kwartal < 1 || ten.Kwartal > 4 || ten.Rok == 0) return;
        int pierwszy = (ten.Kwartal - 1) * 3 + 1;

        List<string> kandydaci = new List<string>();
        HashSet<string> byly = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        byly.Add(plikXml);
        foreach (string p in wskazane)
        {
            string pelna = Path.GetFullPath(p);
            if (byly.Add(pelna)) kandydaci.Add(pelna);
        }
        try
        {
            foreach (string p in Directory.GetFiles(Path.GetDirectoryName(plikXml), "*.xml"))
                if (byly.Add(p)) kandydaci.Add(p);
        }
        catch (Exception) { /* folder niedostępny – zostają pliki wskazane */ }

        Dictionary<int, InfoJpk> wybrane = new Dictionary<int, InfoJpk>();
        foreach (string p in kandydaci)
        {
            InfoJpk i = CzytajNaglowek(p);
            if (i == null || !i.V7K || i.Rok != ten.Rok || i.Nip != ten.Nip) continue;
            if (i.Miesiac < pierwszy || i.Miesiac > pierwszy + 2 || i.Miesiac == ten.Miesiac) continue;
            InfoJpk dotychczasowy;
            if (!wybrane.TryGetValue(i.Miesiac, out dotychczasowy)
                || string.CompareOrdinal(i.DataWytworzenia, dotychczasowy.DataWytworzenia) > 0)
                wybrane[i.Miesiac] = i;
        }

        Dictionary<string, decimal> sumy = new Dictionary<string, decimal>();
        List<string> pliki = new List<string>();
        List<string> brak = new List<string>();
        for (int m = pierwszy; m < pierwszy + 3; m++)
        {
            string okres = m.ToString("00") + "/" + ten.Rok;
            if (m == ten.Miesiac) { pliki.Add(okres + " – ten plik"); continue; }
            InfoJpk i;
            if (!wybrane.TryGetValue(m, out i)) { brak.Add(okres); continue; }
            Dictionary<string, decimal> sumyPliku;
            try { sumyPliku = SumujPolaK(i.Sciezka); }
            catch (Exception) { brak.Add(okres + " (błąd odczytu pliku " + Path.GetFileName(i.Sciezka) + ")"); continue; }
            foreach (KeyValuePair<string, decimal> kv in sumyPliku)
            {
                decimal s;
                sumy.TryGetValue(kv.Key, out s);
                sumy[kv.Key] = s + kv.Value;
            }
            pliki.Add(okres + " – " + Path.GetFileName(i.Sciezka));
        }

        StringBuilder sb = new StringBuilder("|");
        foreach (KeyValuePair<string, decimal> kv in sumy)
            sb.Append(kv.Key).Append('=').Append(kv.Value.ToString(CultureInfo.InvariantCulture)).Append('|');

        argumenty.AddParam("kwartal", "", brak.Count == 0 ? "pelny" : "niepelny");
        argumenty.AddParam("kwartalSumy", "", sb.ToString());
        argumenty.AddParam("kwartalPliki", "", string.Join("; ", pliki.ToArray()));
        argumenty.AddParam("kwartalBrak", "", string.Join(", ", brak.ToArray()));
    }

    // Czyta nagłówek, NIP podatnika i kwartał deklaracji – bez wczytywania ewidencji.
    static InfoJpk CzytajNaglowek(string plik)
    {
        try
        {
            InfoJpk info = new InfoJpk();
            info.Sciezka = plik;
            using (XmlReader r = XmlReader.Create(plik, UstawieniaCzytnika()))
            {
                while (!r.EOF)
                {
                    if (r.NodeType == XmlNodeType.Element)
                    {
                        string n = r.LocalName;
                        if (n == "Ewidencja") break;
                        if (n == "KodFormularza")
                        {
                            info.V7K = (r.GetAttribute("kodSystemowy") ?? "").StartsWith("JPK_V7K", StringComparison.OrdinalIgnoreCase);
                        }
                        else if (n == "Rok" || n == "Miesiac" || n == "Kwartal" || n == "DataWytworzeniaJPK" || n == "NIP")
                        {
                            string w = r.ReadElementContentAsString().Trim();
                            int liczba;
                            int.TryParse(w, NumberStyles.None, CultureInfo.InvariantCulture, out liczba);
                            if (n == "Rok" && info.Rok == 0) info.Rok = liczba;
                            else if (n == "Miesiac" && info.Miesiac == 0) info.Miesiac = liczba;
                            else if (n == "Kwartal" && info.Kwartal == 0) info.Kwartal = liczba;
                            else if (n == "DataWytworzeniaJPK" && info.DataWytworzenia == "") info.DataWytworzenia = w;
                            else if (n == "NIP" && info.Nip == "") info.Nip = w;
                            continue;   // ReadElementContentAsString przesunął już czytnik
                        }
                    }
                    r.Read();
                }
            }
            return info;
        }
        catch (Exception)
        {
            return null;   // nie XML albo uszkodzony – pomijamy
        }
    }

    // Sumy pól K_ z wierszy ewidencji; faktury do paragonu (FP) pomijane, jak w szablonie.
    static Dictionary<string, decimal> SumujPolaK(string plik)
    {
        Dictionary<string, decimal> sumy = new Dictionary<string, decimal>();
        using (XmlReader r = XmlReader.Create(plik, UstawieniaCzytnika()))
        {
            Dictionary<string, decimal> wiersz = null;
            bool fp = false;
            while (!r.EOF)
            {
                if (r.NodeType == XmlNodeType.Element)
                {
                    string n = r.LocalName;
                    if (n == "SprzedazWiersz" || n == "ZakupWiersz")
                    {
                        wiersz = r.IsEmptyElement ? null : new Dictionary<string, decimal>();
                        fp = false;
                    }
                    else if (wiersz != null && n.StartsWith("K_"))
                    {
                        decimal d;
                        if (decimal.TryParse(r.ReadElementContentAsString().Trim(),
                                NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint,
                                CultureInfo.InvariantCulture, out d))
                        {
                            decimal s;
                            wiersz.TryGetValue(n, out s);
                            wiersz[n] = s + d;
                        }
                        continue;
                    }
                    else if (wiersz != null && n == "TypDokumentu")
                    {
                        fp = r.ReadElementContentAsString().Trim() == "FP";
                        continue;
                    }
                }
                else if (r.NodeType == XmlNodeType.EndElement && wiersz != null
                         && (r.LocalName == "SprzedazWiersz" || r.LocalName == "ZakupWiersz"))
                {
                    if (!fp)
                        foreach (KeyValuePair<string, decimal> kv in wiersz)
                        {
                            decimal s;
                            sumy.TryGetValue(kv.Key, out s);
                            sumy[kv.Key] = s + kv.Value;
                        }
                    wiersz = null;
                }
                r.Read();
            }
        }
        return sumy;
    }

    static void Blad(string tekst)
    {
        MessageBox.Show(tekst, "JpkViewer", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
