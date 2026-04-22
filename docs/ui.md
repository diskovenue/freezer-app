# UI / Design Direction

## Stil-Referenzen
- Apple Music
- Erinnerungen
- Notizen
- Apple News

## Grundprinzipien
- Native SwiftUI, systemnahe Typografie
- Dark Mode via system colors (keine hardcoded Background/Text Farben)
- NavigationStack + Large Titles
- Listen mit Sections + Swipe Actions
- Sheets für Create/Edit

## Tabs (MVP)
1) Bestand
2) Scan
3) Fällig
4) Einstellungen

## Bestand
- Gruppierung: primär nach Kategorie (Kategorie zeigt Emoji + Name)
- List rows:
  - Title: display_name
  - Subtitle: Ort + "Empfohlen bis" (due_date) + days_left + optional Gewicht
  - Thumbnail, wenn Foto vorhanden
- Swipe Actions: Entnehmen, Bearbeiten

## Scan
- Fullscreen Scanner (AVFoundation)
- Scan EAN oder CODE128
- Ergebnis:
  - existiert → Detail
  - neu → Create Sheet / EAN Batch Flow

## Fällig
- basiert auf freezer_units.attention_reason (gesetzt durch täglichen Job)
- Sections:
  - mhd_2 (≤ 2 Tage)
  - mhd_7 (≤ 7 Tage)
  - frozen_180 optional
- optional Badge am Tab

## Einstellungen (MVP)
- Orte verwalten (locations)
- Kategorien verwalten (categories: Name, Emoji, freezer_months)
- Logout
