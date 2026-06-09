# Calora — Food Data

This directory contains the tooling and raw data files used to build the bundled
SQLite database (`assets/calora_seed.db`) that is shipped with the Calora app.

On first launch (or whenever the seed version changes) the app copies this file
to its private storage directory. The app compares the `user_version` PRAGMA of
the on-device database against the seed version; if the seed is newer, the device
database is replaced automatically.

**Current seed version: 2**

---

## Data sources

### 1. AUSNUT 2023 — Food Standards Australia New Zealand
- **Files:** `ausnut/AUSNUT 2023 - All Files/AUSNUT 2023 - Food details.xlsx`
  and `AUSNUT 2023 - Food nutrient profiles.xlsx`
- **Records imported:** ~3,720 Australian and New Zealand foods, per-100 g nutrient data
- **Source:** [FSANZ AUSNUT 2023](https://www.foodstandards.gov.au/science-and-research/food-composition-program/ausnut-2023)
- **Licence:** Creative Commons Attribution 3.0 Australia

### 2. NZ Food Composition Tables 14th Edition
- **File:** `nz-food-composition/concise-14-edition.xlsx`
- **Records imported:** ~1,266 New Zealand foods, per-100 g nutrient data
- **Source:** [Plant & Food Research New Zealand Food Composition Database](https://www.plantandfood.com/en-nz/science-and-technical/tools-and-databases/new-zealand-food-composition-database/)
- **Licence:** Creative Commons Attribution 4.0 International

### 3. Open Food Facts — NZ filtered dump
- **File:** `open-food-facts-nz/nz_products.csv` (filtered from the full OFF export at
  `open-food-facts-nz/en.openfoodfacts.org.products.csv.gz`)
- **Records imported:** ~2,949 New Zealand barcoded/branded products
- **Source:** [Open Food Facts](https://world.openfoodfacts.org/data), filtered with `filter_nz.py`
- **Licence:** Open Database Licence (ODbL)

### 4. USDA Foundation Foods 2026
- **Files:** `usda/foundation/FoodData_Central_foundation_food_csv_2026-04-30/`
- **Records imported:** ~377 foundational foods (raw ingredients, minimally processed)
- **Source:** [USDA FoodData Central](https://fdc.nal.usda.gov/download-foods.html)
- **Licence:** Public domain (US government work)

---

## Database schema

The seed contains the full app schema so the Flutter app requires no migrations on
first install:

| Table | Purpose |
|-------|---------|
| `foods` | All food items (8,311 rows across all sources) |
| `diary_entries` | User diary (empty in seed) |
| `recipes` | User-created recipes (empty in seed) |
| `recipe_items` | Ingredients within recipes (empty in seed) |
| `vocabulary` | Unique word tokens for Levenshtein spell-correction (3,872 words) |
| `foods_fts` | FTS5 full-text search index over name + brand |

---

## Building the database

Requires [uv](https://docs.astral.sh/uv/).

```bash
cd data
uv sync          # install Python deps (openpyxl)
uv run python build_db.py
```

Output: `../assets/calora_seed.db` (~2.2 MB)

**When to rebuild:** any time you change data sources, add new foods, or change the
schema. Bump `PRAGMA user_version` in `build_db.py` by 1 and update `_kSeedVersion`
in `lib/services/database_service.dart` to match — the app will automatically
replace the on-device database on next launch.

---

## What is NOT loaded

- **AU Open Food Facts dump** (`open-food-facts-nz/au_products.csv`) — 73 k rows,
  adds significant DB size; can be added to `build_db.py`'s `main()` if needed
- **Full OFF global dump** (`open-food-facts-nz/en.openfoodfacts.org.products.csv.gz`) —
  not imported; far too large and contains primarily non-AU/NZ products