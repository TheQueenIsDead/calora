#!/usr/bin/env python3
"""
Filters the Open Food Facts dump to NZ and AU products using DuckDB.
Multi-threaded, vectorised, column-pruned — significantly faster than
the csv streaming approach on large files.

Output: apac.en.openfoodfacts.org.products.csv (same directory as this script)
"""
import os

import duckdb

_HERE = os.path.dirname(os.path.abspath(__file__))
_OFF_DIR = os.path.join(_HERE, "off")

# Accept .gz or plain .csv — DuckDB handles both natively
for _ext in [".csv.gz", ".csv"]:
    _candidate = os.path.join(_OFF_DIR, f"en.openfoodfacts.org.products{_ext}")
    if os.path.exists(_candidate):
        INPUT = _candidate
        break
else:
    raise FileNotFoundError(
        "OFF dump not found. Run: task off"
    )

# Columns with hyphens must be quoted as SQL identifiers
KEEP_COLS = [
    "code", "product_name", "quantity", "serving_size", "serving_quantity",
    "brands", "brand_owner", "countries_tags",
    "image_url", "image_small_url",
    '"energy-kcal_100g"', '"energy-kj_100g"',
    "fat_100g", '"saturated-fat_100g"',
    "carbohydrates_100g", "sugars_100g",
    "fiber_100g", "proteins_100g",
    "salt_100g", "sodium_100g",
]

OUTPUT = os.path.join(_OFF_DIR, "apac.en.openfoodfacts.org.products.csv")


def main() -> None:
    col_list = ", ".join(KEEP_COLS)
    con = duckdb.connect()

    print(f"Filtering NZ + AU → {os.path.basename(OUTPUT)} ...")
    con.execute(f"""
        COPY (
            SELECT {col_list}
            FROM read_csv(
                '{INPUT}',
                delim = '\t',
                quote = '"',
                ignore_errors = true,
                header = true
            )
            WHERE countries_tags LIKE '%new-zealand%'
               OR countries_tags LIKE '%australia%'
        ) TO '{OUTPUT}' (HEADER, DELIMITER ',')
    """)
    count = con.execute(
        f"SELECT COUNT(*) FROM read_csv('{OUTPUT}', header=true)"
    ).fetchone()[0]
    print(f"  {count:,} rows written")

    con.close()


if __name__ == "__main__":
    main()
