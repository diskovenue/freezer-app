# TODO / Next Steps (Freezer App)

## Status (Stand heute)
- Supabase self-hosted läuft auf VPS
- Domains:
  - API: https://api.freezer.andreasgoessl.de
  - Studio: https://studio.freezer.andreasgoessl.de
- Tabellen vorhanden:
  - categories (emoji, freezer_months)
  - locations
  - products
  - freezer_units (attention_reason/attention_since)
  - device_tokens
  - notifications_sent
- View vorhanden:
  - v_units_display (display_name, due_date, days_left, fallback category "Sonstiges")
- Storage Bucket:
  - photos (angelegt)
- Konzept: "Empfohlen bis" (due_date) statt MHD-Pflicht, v.a. für EAN

---

## Kurzfristig (ohne Apple Dev Account / ohne iOS Build)
### Backend / Daten
- [ ] Prüfen, dass Kategorien (Brot & Brötchen / Kuchen & Süßes etc.) korrekt in categories stehen
- [ ] 5–10 Test-Einträge in freezer_units anlegen (CODE128 + EAN) und v_units_display prüfen (due_date/days_left)
- [ ] Storage Policies für Bucket `photos` prüfen/setzen (authenticated read/write)

### Cronjob (Dry Run)
- [ ] Node 20 LTS auf VPS installieren
- [ ] /opt/freezer-notify vorbereiten:
  - run.js
  - .env (nur Postgres-Teil)
- [ ] Dry-run: Job setzt/cleart attention_reason basierend auf due_date (ohne APNs Versand)
- [ ] Cron (10:00) einrichten, zunächst nur Dry-run logging

### Doku
- [ ] docs/user-flows.md aktuell halten
- [ ] docs/data-model.md aktuell halten
- [ ] docs/ui.md aktuell halten

---

## Sobald Apple Developer Account aktiv ist
### Apple Daten sammeln (für APNs)
Benötigt:
- [ ] APNS_TEAM_ID (Team ID)
- [ ] APNS_KEY_ID (Key ID)
- [ ] APNS_BUNDLE_ID (Bundle Identifier der App)
- [ ] AuthKey_<KEYID>.p8 Datei

### VPS Setup für Push
- [ ] .p8 Datei nach /opt/freezer-notify/ kopieren
- [ ] Rechte setzen: chmod 600 AuthKey_*.p8
- [ ] /opt/freezer-notify/.env um APNs Werte ergänzen
- [ ] Node Script run.js: APNs Versand aktivieren
- [ ] Manuell testen: node run.js (soll Push an registrierte Geräte senden)
- [ ] Cron 10:00 scharf schalten (Summary Push an alle device_tokens)

### iOS App (Push Token Registration)
- [ ] iOS: Push permission request + APNs device token erhalten
- [ ] Token in device_tokens upserten (user_id=auth.uid)
- [ ] Push payload handling:
  - payload { screen: "attention" } -> App öffnet Tab "Fällig"

---

## iOS App Umsetzung (wenn Mac/Xcode verfügbar)
### Milestone 1: Auth + Basisdaten
- [ ] Xcode Projekt (SwiftUI) anlegen
- [ ] Supabase Swift SDK via SPM einbinden
- [ ] Login Screen (Email/Passwort), Session persistiert
- [ ] Locations laden & anzeigen (Test)

### Milestone 2: Bestand + Fällig
- [ ] Bestand: Query v_units_display (group by category)
- [ ] Fällig: Query freezer_units (status=active AND attention_reason not null) + join via view oder separate query

### Milestone 3: Scan + Create
- [ ] Scanner via AVFoundation (EAN + CODE128)
- [ ] Lookup freezer_units by (code_type, code_value)
- [ ] CODE128 create/edit
- [ ] EAN flow:
  - OpenFoodFacts fetch (optional)
  - products upsert
  - create N freezer_units (ohne best_before Eingabe; frozen_at default heute; category default Sonstiges)

### Milestone 4: Fotos
- [ ] Foto aufnehmen/auswählen
- [ ] Upload to Storage bucket `photos`
- [ ] photo_path in freezer_units speichern

---

## Open Questions
- [ ] Wollen wir pro Kategorie emoji + freezer_months in der Settings-UI editierbar machen (ja/nein)?
- [ ] Wollen wir zusätzlich einen "Snooze" pro Unit (
