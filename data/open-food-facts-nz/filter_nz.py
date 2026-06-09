#!/usr/bin/env python3
"""
Streams through the full Open Food Facts CSV dump and extracts NZ (and AU) products.
Keeps only nutrition-relevant columns. Outputs nz_products.csv and au_products.csv.
"""
import gzip
import csv
import sys
import os

csv.field_size_limit(sys.maxsize)

_HERE = os.path.dirname(os.path.abspath(__file__))
INPUT = os.path.join(_HERE, "en.openfoodfacts.org.products.csv.gz")
OUT_DIR = _HERE

KEEP_COLS = [
    "code", "product_name", "abbreviated_product_name", "quantity", "serving_size",
    "serving_quantity", "brands", "brand_owner",
    "countries_tags",
    "image_url", "image_small_url",
    "energy-kcal_100g", "energy-kj_100g",
    "fat_100g", "saturated-fat_100g", "trans-fat_100g",
    "carbohydrates_100g", "sugars_100g", "added-sugars_100g",
    "fiber_100g", "proteins_100g",
    "salt_100g", "sodium_100g",
]

def main():
    nz_rows = []
    au_rows = []
    total = 0
    col_indices = None
    headers_out = None

    print("Streaming through full OFF dump...")
    with gzip.open(INPUT, "rt", encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f, delimiter="\t")
        all_headers = next(reader)

        col_indices = []
        headers_out = []
        for col in KEEP_COLS:
            if col in all_headers:
                col_indices.append(all_headers.index(col))
                headers_out.append(col)

        countries_idx = all_headers.index("countries_tags")

        for row in reader:
            total += 1
            if total % 500_000 == 0:
                print(f"  {total:,} rows scanned, {len(nz_rows)} NZ, {len(au_rows)} AU so far...")

            if len(row) <= countries_idx:
                continue

            countries = row[countries_idx].lower()
            is_nz = "new-zealand" in countries
            is_au = "australia" in countries

            if not (is_nz or is_au):
                continue

            filtered = [row[i] if i < len(row) else "" for i in col_indices]
            if is_nz:
                nz_rows.append(filtered)
            if is_au:
                au_rows.append(filtered)

    print(f"\nDone. Scanned {total:,} total rows.")
    print(f"  NZ products: {len(nz_rows)}")
    print(f"  AU products: {len(au_rows)}")

    for name, rows in [("nz_products.csv", nz_rows), ("au_products.csv", au_rows)]:
        path = os.path.join(OUT_DIR, name)
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(headers_out)
            writer.writerows(rows)
        print(f"Saved {path} ({len(rows)} rows)")

if __name__ == "__main__":
    main()