# User Flows (MVP)

## Grundannahmen
- Es gibt zwei Arten von Inventar-Einträgen:
  - CODE128 (Sticker): 1 Sticker = 1 Eintrag in freezer_units (unique)
  - EAN (gekaufte Produkte): jede Packung = 1 Eintrag in freezer_units (EAN darf mehrfach)
- Bei gekauften Produkten wird i.d.R. **kein Packungs-MHD** erfasst.
- Stattdessen nutzt die App eine **Gefrierfrist** pro Kategorie:
  - due_date = coalesce(best_before, frozen_at + category.freezer_months)
  - UI-Text: "Empfohlen bis" / "Beste Qualität bis" (nicht "MHD")
- "Fällig" bleibt sichtbar, bis status != active (oder User entnimmt/archiviert).

---

## Flow: App Start
1. App prüft gespeicherte Supabase Session
2. Falls Session vorhanden → direkt in App
3. Falls keine Session → Login Screen

---

## Flow: Scan (CODE128 Sticker)
1. User öffnet Tab "Scan"
2. App scannt Barcode (CODE128) → code_value
3. Lookup:
   - freezer_units where code_type=CODE128 AND code_value=<scan>
4. Ergebnis:
   - Found → Unit Detail
   - Not Found → Create Unit Sheet
     - Felder: Bezeichnung, Kategorie, Ort, Einfrierdatum (Default heute), Gewicht (optional), Foto (optional), Notiz (optional)
     - Speichern → INSERT freezer_units

---

## Flow: Scan (EAN gekauft)
1. Scan erkennt EAN → code_value = EAN
2. Produkt-Autofill (optional):
   - App fragt Open Food Facts an (EAN → Name/Bild etc.)
   - App upsertet products(ean, name, photo_url, default_weight_g, category_id optional)
3. App fragt:
   - Menge (N Stück)
   - Ort (Truhe)
   - Kategorie (Default: aus Produkt/zuletzt genutzt; sonst "Sonstiges")
   - Einfrierdatum (Default heute, meistens unverändert)
4. App erstellt N Zeilen in freezer_units:
   - code_type='EAN'
   - code_value=ean
   - product_ean=ean
   - frozen_at=today
   - category_id optional (wenn bekannt), sonst null -> View/Logik nutzt Fallback "Sonstiges"
   - location_id=...
5. App zeigt danach Bestand oder die neu angelegten Einträge.

---

## Flow: Bestand ansehen
- Default: gruppiert nach Kategorie (Emoji + Name)
- Suche über display_name (name_override oder products.name)
- Filter:
  - Ort (Truhe)
  - Status (active/consumed/trashed)
  - Kategorie

---

## Flow: Unit Detail / Bearbeiten
- Anzeige:
  - Name (name_override oder products.name)
  - Kategorie (inkl. Emoji)
  - Ort
  - "Empfohlen bis" (due_date aus View) + days_left
  - optional: echtes Datum best_before (nur wenn gesetzt)
  - Gewicht, Notiz, Foto
- Actions:
  - Bearbeiten → PATCH freezer_units
  - Entnehmen → PATCH freezer_units {status='consumed', consumed_at=now}
  - (Optional) Löschen/Trash → status='trashed'

---

## Flow: "Fällig" (Attention)
- Quelle: freezer_units.attention_reason (gesetzt durch täglichen Job)
- Query: status='active' AND attention_reason is not null
- Sections:
  - mhd_2 (≤ 2 Tage bis due_date)
  - mhd_7 (≤ 7 Tage bis due_date)
  - frozen_180 (optional/fallback)
- Ziel: bleibt prominent sichtbar, bis entnommen.

---

## Flow: Fotos
1. User wählt Foto (Camera / Photo Library)
2. App lädt Bild in Supabase Storage Bucket `photos` hoch
   - Pfad z.B.: units/<unit-id>.jpg
3. App speichert freezer_units.photo_path = dieser Pfad

---

## Flow: Push Notifications (Server)
- Täglich 10:00 Job auf VPS:
  - berechnet due_date (via View) und setzt attention_reason/attention_since
  - berechnet Counts
  - sendet Summary Push an alle device_tokens
- Tap auf Push öffnet App → navigiert zum Tab "Fällig" (payload z.B. screen=attention)
