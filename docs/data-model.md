# Data Model (Supabase / Postgres)

## categories
- id (uuid, PK)
- name (text, unique)
- sort_order (int)
- emoji (text, nullable)
- freezer_months (int, default)
- created_at (timestamptz)

Beispiel: "🍞 Brot & Brötchen" (6 Monate), "🍰 Kuchen & Süßes" (4 Monate)

## locations
- id (uuid, PK)
- name (text)
- parent_id (uuid, nullable)
- sort_order (int)
- created_at (timestamptz)

## products (EAN-Stammdaten)
- ean (text, PK)
- name (text)
- category_id (uuid, nullable)
- default_weight_g (int, nullable)
- photo_url (text, nullable)
- created_at, updated_at (timestamptz)

## freezer_units (Inventar)
Eine Zeile = eine Einheit, die einzeln entnommen werden kann.

- id (uuid, PK)
- code_type: 'EAN' | 'CODE128'
- code_value (text)              // EAN oder Sticker-String
- product_ean (text, nullable FK products.ean)
- name_override (text, nullable)
- category_id (uuid, nullable FK categories.id)
- frozen_at (date, nullable; in Praxis default heute)
- best_before (date, nullable)   // optionales echtes Datum; meist leer
- weight_g (int, nullable)
- location_id (uuid, FK locations.id)
- note (text, nullable)
- photo_path (text, nullable)    // Storage bucket 'photos'
- status (text)                  // active|consumed|trashed
- consumed_at (timestamptz, nullable)
- attention_reason (text, nullable) // mhd_2|mhd_7|frozen_180
- attention_since (date, nullable)
- created_by (uuid, nullable FK auth.users.id)
- created_at, updated_at

Constraint:
- CODE128: code_value unique where code_type='CODE128'

## v_units_display (View)
- display_name = coalesce(name_override, products.name)
- resolved_category_id = coalesce(unit.category_id, product.category_id, fallback 'Sonstiges')
- recommended_until = frozen_at + category.freezer_months
- due_date = coalesce(best_before, recommended_until)
- days_left = due_date - current_date
- joins: categories, locations, products

## device_tokens (Push)
- id (uuid, PK)
- user_id (uuid, FK auth.users)
- platform (text, default 'ios')
- token (text, unique)
- created_at, last_seen_at

RLS: User darf nur eigene Tokens verwalten.

## notifications_sent (Dedup daily summary)
- id (uuid, PK)
- kind (text)              // 'daily_summary'
- sent_for_date (date)
- created_at

unique(kind, sent_for_date)
RLS: keine Policies (nur Service role / Cronjob)
