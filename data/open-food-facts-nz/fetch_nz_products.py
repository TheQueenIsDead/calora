#!/usr/bin/env python3
"""
Fetches all NZ products from Open Food Facts API and saves as CSV.
14,800+ products, ~15 pages at page_size=1000.
"""
import json
import csv
import time
import urllib.request
import urllib.parse

API_BASE = "https://world.openfoodfacts.org/api/v2/search"
FIELDS = ",".join([
    "code", "product_name", "brands", "quantity", "serving_size",
    "nutriments", "image_front_url", "categories_tags", "stores_tags"
])
PAGE_SIZE = 200
OUTPUT_CSV = "nz_products.csv"
OUTPUT_JSON = "nz_products.json"

CSV_COLUMNS = [
    "barcode", "product_name", "brand", "quantity", "serving_size",
    "energy_kcal_100g", "fat_100g", "saturated_fat_100g",
    "carbohydrates_100g", "sugars_100g", "fiber_100g",
    "proteins_100g", "sodium_100g", "salt_100g",
    "image_url", "categories",
]


def fetch_page(page: int) -> dict:
    params = urllib.parse.urlencode({
        "countries_tags": "en:new-zealand",
        "page_size": PAGE_SIZE,
        "page": page,
        "fields": FIELDS,
    })
    url = f"{API_BASE}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": "CalorieTrackerApp/1.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read())
        except Exception as e:
            wait = 2 ** attempt * 2
            print(f"  Attempt {attempt + 1} failed ({e}), retrying in {wait}s...")
            time.sleep(wait)
    raise RuntimeError(f"Failed to fetch page {page} after 5 attempts")


def extract_row(p: dict) -> dict:
    n = p.get("nutriments", {})
    return {
        "barcode": p.get("code", ""),
        "product_name": p.get("product_name", ""),
        "brand": p.get("brands", ""),
        "quantity": p.get("quantity", ""),
        "serving_size": p.get("serving_size", ""),
        "energy_kcal_100g": n.get("energy-kcal_100g", n.get("energy_100g", "")),
        "fat_100g": n.get("fat_100g", ""),
        "saturated_fat_100g": n.get("saturated-fat_100g", ""),
        "carbohydrates_100g": n.get("carbohydrates_100g", ""),
        "sugars_100g": n.get("sugars_100g", ""),
        "fiber_100g": n.get("fiber_100g", ""),
        "proteins_100g": n.get("proteins_100g", ""),
        "sodium_100g": n.get("sodium_100g", ""),
        "salt_100g": n.get("salt_100g", ""),
        "image_url": p.get("image_front_url", ""),
        "categories": "|".join(p.get("categories_tags", [])),
    }


def main():
    all_products = []
    page = 1

    print("Fetching page 1 to get total count...")
    first = fetch_page(1)
    total = first.get("count", 0)
    total_pages = (total + PAGE_SIZE - 1) // PAGE_SIZE
    # Use page_count from API response (reflects actual server-side page_size)
    actual_page_count = first.get("page_count", total_pages)
    print(f"Total NZ products: {total} ({actual_page_count} pages at server page_size)")

    all_products.extend(first.get("products", []))

    for page in range(2, actual_page_count + 1):
        print(f"Fetching page {page}/{actual_page_count} ({len(all_products)} products so far)...")
        data = fetch_page(page)
        products = data.get("products", [])
        if not products:
            break
        all_products.extend(products)
        time.sleep(0.3)  # polite rate limiting

    print(f"\nDownloaded {len(all_products)} products total")

    # Save CSV
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        for p in all_products:
            writer.writerow(extract_row(p))
    print(f"Saved {OUTPUT_CSV}")

    # Save raw JSON for reference
    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(all_products, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Saved {OUTPUT_JSON}")


if __name__ == "__main__":
    main()