-- Initial schema for calora_seed.db
-- Tracked in schema_migrations so future migrations run only once.

CREATE TABLE IF NOT EXISTS schema_migrations (
    version    TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS foods (
    id                     TEXT PRIMARY KEY,
    name                   TEXT NOT NULL,
    brand                  TEXT,
    barcode                TEXT,
    calories_per_100g      REAL NOT NULL,
    fat_per_100g           REAL DEFAULT 0,
    saturated_fat_per_100g REAL DEFAULT 0,
    carbs_per_100g         REAL DEFAULT 0,
    sugars_per_100g        REAL DEFAULT 0,
    fiber_per_100g         REAL DEFAULT 0,
    protein_per_100g       REAL DEFAULT 0,
    sodium_per_100g        REAL DEFAULT 0,
    serving_size           TEXT,
    serving_grams          REAL,
    image_url              TEXT,
    source                 TEXT DEFAULT 'custom'
);

CREATE INDEX IF NOT EXISTS idx_foods_barcode ON foods (barcode);
CREATE INDEX IF NOT EXISTS idx_foods_name    ON foods (LOWER(name));
