# Fahrschule Reinig – Website (Modern Redesign)

Moderne, responsive Neugestaltung der Website der **Fahrschule Reinig** in
Wald-Michelbach. Reines HTML/CSS/JS – kein Build-Schritt nötig.

## Öffnen / Ansehen

Einfach `index.html` im Browser öffnen, oder lokal servieren:

```bash
python3 -m http.server 8000
# dann http://localhost:8000 aufrufen
```

## Aufbau

| Datei | Zweck |
|-------|-------|
| `index.html` | Struktur & Inhalte (eine Seite, mit Anker-Navigation) |
| `styles.css` | Design-System, Layout, Responsive |
| `script.js` | Mobile-Menü, Scroll-Reveal, Jahr im Footer |
| `assets/img/` | Bilder / Favicon |

## Echte Fotos einsetzen

Die Originalfotos der Website konnten in der Build-Umgebung nicht geladen
werden (Netzwerk gesperrt). Aktuell werden stimmige **SVG-/CSS-Platzhalter**
verwendet. Zum Austauschen einfach echte Bilder in `assets/img/` ablegen und
an diesen im HTML markierten Stellen einsetzen:

- **Hero** (`<div class="hero-visual">`): Foto vom Fahrschulauto oder Team.
- **Über uns** (`<div class="about-visual">`): Team-/Fahrschulfoto (Klaus &
  Vanessa). Die Avatar-Karten können bleiben oder durch echte Porträts ersetzt
  werden.

Beispiel:

```html
<div class="hero-visual">
  <img src="assets/img/fahrschulauto.jpg" alt="Fahrschulauto der Fahrschule Reinig" />
</div>
```

## Inhalte (recherchiert)

- **Standort:** Ludwigstraße 113, 69483 Wald-Michelbach
- **Telefon:** (06207) 2331 · Mobil: 0176 61560938
- **E-Mail:** info@fahrschule-reinig.de
- **Anmeldung & Theorie:** dienstags 18:00–19:30 Uhr
- **Team:** Klaus & Vanessa · seit über 25 Jahren
- **Klassen:** PKW (B, BF17, B197) · Motorrad (A1, A2, A, 196) · AM/AM15/Moped ·
  Anhänger (B96, BE)

> Hinweis: Bitte Kontaktdaten, Öffnungszeiten und Klassen vor dem
> Live-Gang noch einmal mit der Fahrschule abgleichen. **Impressum** und
> **Datenschutz** müssen vor Veröffentlichung ergänzt werden (Footer-Links
> sind aktuell Platzhalter).
