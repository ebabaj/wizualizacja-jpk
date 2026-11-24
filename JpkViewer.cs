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
using System.IO;
using System.Reflection;
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
                string html = Przeksztalc(xslt, Path.GetFullPath(plik));
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

    static string Przeksztalc(XslCompiledTransform xslt, string plikXml)
    {
        XsltArgumentList argumenty = new XsltArgumentList();
        argumenty.AddParam("plik", "", Path.GetFileName(plikXml));
        argumenty.AddParam("wygenerowano", "", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));

        XmlReaderSettings rs = new XmlReaderSettings();
        rs.DtdProcessing = DtdProcessing.Prohibit;
        rs.XmlResolver = null;

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

    static void Blad(string tekst)
    {
        MessageBox.Show(tekst, "JpkViewer", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
