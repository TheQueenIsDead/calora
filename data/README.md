# Calora — Food Data Pipeline

This directory contains the tooling used to build `assets/calora_seed.db` — the
bundled SQLite database shipped with the Calora app.

On first launch (or when the seed version changes) the app copies this file to its
private storage. It compares `user_version` against `_kFoodsVersion` in
`database_service.dart`; if the seed is newer the on-device copy is replaced.

**Current seed version: 4 — 77,952 foods**

---

## Data sources

### 1. AUSNUT 2023 — Food Standards Australia New Zealand
- **Download:** `task ausnut` (~11 MB zip)
- **Records:** ~3,720 Australian and NZ foods, per-100 g nutrient data
- **Source:** [FSANZ AUSNUT 2023](https://www.foodstandards.gov.au/science-data/food-nutrient-databases/ausnut/data-files)
- **Licence:** Creative Commons Attribution 3.0 Australia

### 2. NZ Food Composition Tables 14th Edition
- **Download:** `task nzfc`
- **Records:** ~1,266 NZ foods, per-100 g nutrient data
- **Source:** [Plant & Food Research NZ Food Composition Database](https://www.foodcomposition.co.nz/downloads/)
- **Licence:** Creative Commons Attribution 4.0 International

### 3. Open Food Facts — APAC (Parquet)
- **Download:** `task parquet` (~2 GB from HuggingFace)
- **Records:** ~72,590 NZ and AU barcoded/branded products
- **Source:** [Open Food Facts on HuggingFace](https://huggingface.co/datasets/openfoodfacts/product-database)
- **Licence:** Open Database Licence (ODbL)
- **Notes:** DuckDB filters to NZ/AU directly from the Parquet file. Nutriments are
  stored as a struct array (richer than the flat CSV export). Products tagged
  `en:nutriscore-missing-nutrition-data-energy` are excluded.

### 4. USDA Foundation Foods 2026
- **Download:** `task usda` (~32 MB)
- **Records:** ~377 foundational foods (raw ingredients, minimally processed)
- **Source:** [USDA FoodData Central](https://fdc.nal.usda.gov/download-datasets)
- **Licence:** Public domain (US government work)

---

## Building the database

Requires [uv](https://docs.astral.sh/uv/) and [Task](https://taskfile.dev).

```bash
cd data
task all        # download all sources + build
# or individually:
task ausnut     # download AUSNUT
task nzfc       # download NZ Food Composition
task parquet    # download OFF Parquet (~2 GB)
task usda       # download USDA Foundation Foods
task build      # build the seed DB
```

Each download task uses `status: test -f <file>` to skip if already present.
Re-run any task to force a fresh download by deleting the target file first.

Output: `../assets/calora_seed.db` (~21 MB)

### When to rebuild

Any time you add new data or change sources. Bump `PRAGMA user_version` in
`build.py` by 1 **and** update `_kFoodsVersion` in
`lib/services/database_service.dart` to match — the app will automatically
replace the on-device database on next launch.

### Schema migrations

SQL migrations live in `migrations/`. The build script applies any unapplied
`.sql` files (tracked via `schema_migrations` table) before importing data.
Add `001_add_column.sql` etc. for future schema changes.

### Incremental builds

The seed DB is maintained incrementally — existing records are preserved across
builds. AUSNUT/NZ/USDA use `INSERT OR REPLACE` (source corrections propagate);
OFF uses `INSERT OR IGNORE` (API-enriched records survive rebuilds). FTS5 and
vocabulary tables are always rebuilt from scratch at the end of each build.

---

## Directory structure

```
data/
  build.py              # main build script
  Taskfile.yml          # download + build tasks
  pyproject.toml        # Python deps (openpyxl, duckdb)
  migrations/           # SQL schema migrations
    000_create.sql
  ausnut/               # AUSNUT xlsx files (gitignored, task ausnut to download)
  nzfc/                 # NZ Food Composition xlsx (gitignored, task nzfc)
  off/                  # OFF Parquet file (gitignored, task parquet)
  usda/                 # USDA Foundation Foods CSV (gitignored, task usda)
```
