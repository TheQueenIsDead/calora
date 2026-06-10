"""
Builds the pre-populated Calora SQLite database from NZ/AU food datasets.

Sources:
  - AUSNUT 2023 (Food Standards Australia New Zealand)
  - NZ Food Composition Tables 14th edition (Plant & Food Research)
  - Open Food Facts NZ filtered dump (barcodes + branded products)

Output: ../assets/calora_seed.db  (copied to app on first launch)

Run from the data/ directory:
    uv run python build_db.py
"""

import csv
import re
import sqlite3
import sys
import uuid
from pathlib import Path

import openpyxl

ROOT = Path(__file__).parent
OUT = ROOT.parent / "assets" / "calora_seed.db"

KJ_TO_KCAL = 1 / 4.184


def _f(v) -> float:
    """Coerce a cell value to float, returning 0 on failure."""
    if v is None:
        return 0.0
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _create_schema(conn: sqlite3.Connection) -> None:
    # Seed DB contains only food-reference data — no user tables.
    # User data (diary, recipes) lives in a separate calora_user.db on-device.
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS foods (
            id                    TEXT PRIMARY KEY,
            name                  TEXT NOT NULL,
            brand                 TEXT,
            barcode               TEXT,
            calories_per_100g     REAL NOT NULL,
            fat_per_100g          REAL DEFAULT 0,
            saturated_fat_per_100g REAL DEFAULT 0,
            carbs_per_100g        REAL DEFAULT 0,
            sugars_per_100g       REAL DEFAULT 0,
            fiber_per_100g        REAL DEFAULT 0,
            protein_per_100g      REAL DEFAULT 0,
            sodium_per_100g       REAL DEFAULT 0,
            serving_size          TEXT,
            serving_grams         REAL,
            image_url             TEXT,
            source                TEXT DEFAULT 'custom'
        );
        CREATE INDEX IF NOT EXISTS idx_foods_barcode ON foods (barcode);
        CREATE INDEX IF NOT EXISTS idx_foods_name    ON foods (LOWER(name));
    """)


def _insert(conn: sqlite3.Connection, row: dict) -> None:
    conn.execute(
        """
        INSERT OR IGNORE INTO foods
            (id, name, brand, barcode, calories_per_100g,
             fat_per_100g, saturated_fat_per_100g, carbs_per_100g,
             sugars_per_100g, fiber_per_100g, protein_per_100g,
             sodium_per_100g, serving_size, serving_grams, image_url, source)
        VALUES
            (:id, :name, :brand, :barcode, :calories_per_100g,
             :fat_per_100g, :saturated_fat_per_100g, :carbs_per_100g,
             :sugars_per_100g, :fiber_per_100g, :protein_per_100g,
             :sodium_per_100g, :serving_size, :serving_grams, :image_url, :source)
        """,
        row,
    )


# ---------------------------------------------------------------------------
# AUSNUT 2023
# ---------------------------------------------------------------------------

def import_ausnut(conn: sqlite3.Connection) -> int:
    base = ROOT / "ausnut"

    # --- food details: Survey ID → food name ---
    wb_details = openpyxl.load_workbook(base / "AUSNUT 2023 - Food details.xlsx", read_only=True)
    ws_details = wb_details["Food details"]
    names: dict[int, str] = {}
    for i, row in enumerate(ws_details.iter_rows(values_only=True)):
        if i < 3:  # skip title rows + header row (0-indexed row 2 = header)
            continue
        survey_id = row[0]
        food_name = row[4]
        if survey_id and food_name:
            names[int(survey_id)] = str(food_name)
    wb_details.close()

    # --- nutrient profiles: one row per food ---
    wb_nutr = openpyxl.load_workbook(base / "AUSNUT 2023 - Food nutrient profiles.xlsx", read_only=True)
    ws_nutr = wb_nutr["Food nutrient profiles"]

    count = 0
    for i, row in enumerate(ws_nutr.iter_rows(values_only=True)):
        if i < 3:
            continue
        survey_id = row[0]
        if not survey_id:
            continue
        sid = int(survey_id)
        name = str(row[3]) if row[3] else names.get(sid, "")
        if not name:
            continue

        energy_kj = _f(row[4])
        if energy_kj <= 0:
            continue

        _insert(conn, {
            "id": f"ausnut_{sid}",
            "name": name,
            "brand": None,
            "barcode": None,
            "calories_per_100g": round(energy_kj * KJ_TO_KCAL, 2),
            "protein_per_100g": _f(row[7]),
            "fat_per_100g": _f(row[8]),
            "saturated_fat_per_100g": _f(row[49]),
            "carbs_per_100g": _f(row[9]),
            "sugars_per_100g": _f(row[12]),
            "fiber_per_100g": _f(row[15]),
            "sodium_per_100g": round(_f(row[25]) / 1000, 4),  # mg → g
            "serving_size": None,
            "serving_grams": None,
            "image_url": None,
            "source": "ausnut",
        })
        count += 1

    wb_nutr.close()
    return count


# ---------------------------------------------------------------------------
# NZ Food Composition Tables 14th Edition
# ---------------------------------------------------------------------------

def import_nz_composition(conn: sqlite3.Connection) -> int:
    path = ROOT / "nzfc" / "concise-14-edition.xlsx"
    wb = openpyxl.load_workbook(path, read_only=True)
    ws = wb.active

    count = 0
    for i, row in enumerate(ws.iter_rows(values_only=True)):
        if i < 5:  # rows 0-4: header, blank, units, blank, first category
            continue
        food_id = row[0]
        # Skip None rows (per-serving alternates) and single-letter category headers
        if not food_id:
            continue
        food_id_str = str(food_id).strip()
        if len(food_id_str) <= 1 or not any(c.isdigit() for c in food_id_str):
            continue

        name = str(row[1]).strip() if row[1] else ""
        if not name:
            continue

        energy_kj = _f(row[4])
        if energy_kj <= 0:
            continue

        _insert(conn, {
            "id": f"nz_{food_id_str}",
            "name": name,
            "brand": None,
            "barcode": None,
            "calories_per_100g": round(energy_kj * KJ_TO_KCAL, 2),
            "protein_per_100g": _f(row[6]),
            "fat_per_100g": _f(row[7]),
            "saturated_fat_per_100g": _f(row[12]),
            "carbs_per_100g": _f(row[8]),
            "sugars_per_100g": _f(row[10]),
            "fiber_per_100g": _f(row[9]),
            "sodium_per_100g": round(_f(row[18]) / 1000, 4),  # mg → g
            "serving_size": None,
            "serving_grams": _f(row[2]) or None,
            "image_url": None,
            "source": "nz",
        })
        count += 1

    wb.close()
    return count


# ---------------------------------------------------------------------------
# Open Food Facts NZ (filtered CSV with barcodes)
# ---------------------------------------------------------------------------

def import_off_apac(conn: sqlite3.Connection) -> int:
    path = ROOT / "off" / "apac.en.openfoodfacts.org.products.csv"
    if not path.exists():
        raise FileNotFoundError(f"{path}\n  Run: task off && task filter")
    count = 0
    csv.field_size_limit(sys.maxsize)

    with open(path, encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = (row.get("product_name") or "").strip()
            barcode = (row.get("code") or "").strip()
            if not name or not barcode:
                continue

            kcal_str = row.get("energy-kcal_100g", "").strip()
            if not kcal_str:
                # fall back to kJ
                kj_str = row.get("energy-kj_100g", "").strip()
                try:
                    kcal = float(kj_str) * KJ_TO_KCAL if kj_str else 0.0
                except ValueError:
                    kcal = 0.0
            else:
                try:
                    kcal = float(kcal_str)
                except ValueError:
                    kcal = 0.0

            if kcal <= 0:
                continue

            def _csv_f(key: str) -> float:
                v = row.get(key, "").strip()
                try:
                    return float(v) if v else 0.0
                except ValueError:
                    return 0.0

            serving_size = (row.get("serving_size") or "").strip() or None
            serving_grams_str = (row.get("serving_quantity") or "").strip()
            try:
                serving_grams = float(serving_grams_str) if serving_grams_str else None
            except ValueError:
                serving_grams = None

            _insert(conn, {
                "id": f"off_{barcode}",
                "name": name,
                "brand": (row.get("brands") or "").strip() or None,
                "barcode": barcode,
                "calories_per_100g": round(kcal, 2),
                "protein_per_100g": _csv_f("proteins_100g"),
                "fat_per_100g": _csv_f("fat_100g"),
                "saturated_fat_per_100g": _csv_f("saturated-fat_100g"),
                "carbs_per_100g": _csv_f("carbohydrates_100g"),
                "sugars_per_100g": _csv_f("sugars_100g"),
                "fiber_per_100g": _csv_f("fiber_100g"),
                "sodium_per_100g": _csv_f("sodium_100g"),  # already g/100g in OFF
                "serving_size": serving_size,
                "serving_grams": serving_grams,
                "image_url": (row.get("image_url") or "").strip() or None,
                "source": "off_nz",
            })
            count += 1

    return count


# ---------------------------------------------------------------------------
# USDA Foundation Foods 2026
# ---------------------------------------------------------------------------

def import_usda(conn: sqlite3.Connection) -> int:
    base = ROOT / "usda"
    if not (base / "food.csv").exists():
        raise FileNotFoundError(f"{base / 'food.csv'}\n  Run: task usda")

    # nutrient_id → field name (prefer 1008 "Energy KCAL", fall back to Atwater)
    ENERGY_IDS   = {'1008', '2047', '2048'}
    NUTRIENT_MAP = {
        '1003': 'protein_per_100g',
        '1004': 'fat_per_100g',
        '1005': 'carbs_per_100g',
        '1079': 'fiber_per_100g',
        '1093': 'sodium_mg',       # mg — convert later
        '1258': 'saturated_fat_per_100g',
        '2000': 'sugars_per_100g',
    }

    # fdc_id → description
    foods: dict[str, str] = {}
    with open(base / "food.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            foods[row['fdc_id']] = row['description']

    # fdc_id → {field: value}
    nutrients: dict[str, dict] = {fid: {} for fid in foods}
    with open(base / "food_nutrient.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            fid = row['fdc_id']
            nid = row['nutrient_id']
            amt = _f(row['amount'])
            if fid not in nutrients:
                continue
            if nid in ENERGY_IDS and 'calories_per_100g' not in nutrients[fid]:
                nutrients[fid]['calories_per_100g'] = amt
            elif nid in NUTRIENT_MAP:
                field = NUTRIENT_MAP[nid]
                if field not in nutrients[fid]:
                    nutrients[fid][field] = amt

    count = 0
    for fid, name in foods.items():
        n = nutrients.get(fid, {})
        kcal = n.get('calories_per_100g', 0)
        if not name or kcal <= 0:
            continue
        sodium_g = round(n.get('sodium_mg', 0) / 1000, 4)
        _insert(conn, {
            'id': f'usda_{fid}',
            'name': name,
            'brand': None,
            'barcode': None,
            'calories_per_100g': round(kcal, 2),
            'protein_per_100g': n.get('protein_per_100g', 0),
            'fat_per_100g': n.get('fat_per_100g', 0),
            'saturated_fat_per_100g': n.get('saturated_fat_per_100g', 0),
            'carbs_per_100g': n.get('carbs_per_100g', 0),
            'sugars_per_100g': n.get('sugars_per_100g', 0),
            'fiber_per_100g': n.get('fiber_per_100g', 0),
            'sodium_per_100g': sodium_g,
            'serving_size': None,
            'serving_grams': None,
            'image_url': None,
            'source': 'usda',
        })
        count += 1
    return count


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _counts(db_path: Path) -> dict[str, int]:
    """Return per-source row counts from an existing DB, or empty dict."""
    if not db_path.exists():
        return {}
    try:
        c = sqlite3.connect(db_path)
        rows = c.execute("SELECT source, COUNT(*) FROM foods GROUP BY source").fetchall()
        c.close()
        return {source: count for source, count in rows}
    except Exception:
        return {}


def _print_diff(before: dict[str, int], after: dict[str, int]) -> None:
    sources = sorted(set(before) | set(after))
    total_before = sum(before.values())
    total_after  = sum(after.values())
    print("\n── Record counts ─────────────────────────────")
    print(f"  {'Source':<20} {'Before':>8}  {'After':>8}  {'Δ':>8}")
    print(f"  {'─'*20}  {'─'*8}  {'─'*8}  {'─'*8}")
    for src in sources:
        b, a = before.get(src, 0), after.get(src, 0)
        delta = a - b
        flag  = "  +" if delta > 0 else ("  -" if delta < 0 else "")
        print(f"  {src:<20} {b:>8,}  {a:>8,}  {delta:>+8,}{flag}")
    print(f"  {'─'*20}  {'─'*8}  {'─'*8}  {'─'*8}")
    print(f"  {'TOTAL':<20} {total_before:>8,}  {total_after:>8,}  {total_after - total_before:>+8,}")
    print("──────────────────────────────────────────────")


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    before = _counts(OUT)
    if OUT.exists():
        OUT.unlink()

    conn = sqlite3.connect(OUT)
    conn.execute("PRAGMA journal_mode=WAL")

    _create_schema(conn)

    print("Importing AUSNUT 2023 …", end=" ", flush=True)
    n = import_ausnut(conn)
    conn.commit()
    print(f"{n:,} rows")

    print("Importing NZ Food Composition …", end=" ", flush=True)
    n = import_nz_composition(conn)
    conn.commit()
    print(f"{n:,} rows")

    print("Importing Open Food Facts APAC …", end=" ", flush=True)
    n = import_off_apac(conn)
    conn.commit()
    print(f"{n:,} rows")

    print("Importing USDA Foundation Foods …", end=" ", flush=True)
    n = import_usda(conn)
    conn.commit()
    print(f"{n:,} rows")

    after = dict(conn.execute("SELECT source, COUNT(*) FROM foods GROUP BY source").fetchall())
    _print_diff(before, after)

    print("Building vocabulary …", end=" ", flush=True)
    tokens: set[str] = set()
    for (name, brand) in conn.execute("SELECT name, COALESCE(brand,'') FROM foods"):
        for word in re.findall(r'[a-z]{3,}', f"{name} {brand}".lower()):
            tokens.add(word)
    conn.execute("CREATE TABLE vocabulary (word TEXT PRIMARY KEY)")
    conn.executemany("INSERT OR IGNORE INTO vocabulary (word) VALUES (?)", [(w,) for w in tokens])
    conn.commit()
    print(f"{len(tokens):,} tokens")

    print("Building FTS5 index …", end=" ", flush=True)
    conn.execute("""
        CREATE VIRTUAL TABLE foods_fts USING fts5(
            name,
            brand,
            content=foods,
            content_rowid=rowid,
            tokenize='unicode61 remove_diacritics 2'
        )
    """)
    conn.execute("INSERT INTO foods_fts(foods_fts) VALUES('rebuild')")
    conn.commit()
    print("done")

    print(f"Output: {OUT}")
    conn.execute("PRAGMA optimize")
    conn.execute("PRAGMA user_version = 3")  # bump when schema or data changes
    conn.execute("VACUUM")
    conn.close()


if __name__ == "__main__":
    main()