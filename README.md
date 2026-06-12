# Calora

A Flutter calorie and nutrition tracking app for iOS and Android. Log meals, track water intake, scan barcodes, build recipes, and monitor trends — all stored locally with no account required.

## Features

- **Daily diary** — log food across Breakfast, Lunch, Dinner, and Snacks with drag-to-reorder between meals
- **Calorie ring** — at-a-glance progress toward your daily calorie goal with macro breakdown (carbs, protein, fat)
- **Barcode scanning** — scan packaged food and pull nutrition data from [Open Food Facts](https://world.openfoodfacts.org/)
- **Food search** — cross-field search across 77,000+ NZ/AU/AUSNUT/USDA foods with FTS5 full-text index
- **Water tracking** — log intake with customisable vessels (glass, bottle, mug, etc.) and a daily target
- **Recipes** — save any meal as a recipe with configurable servings; add recipes back to the diary
- **BMR / TDEE calculator** — estimate daily calorie needs from body stats
- **Trends** — calorie and macro charts with a 500 kcal-snapped Y-axis
- **Day locking** — past days lock automatically; tap the lock icon to unlock
- **Data export / import** — full JSON backup and restore
- **Android home screen widgets** — interactive water tracker and calorie ring
- **Light and dark theme** — follows system appearance via Material 3

## Colour palette

| Role            | Colour      | Hex       |
| --------------- | ----------- | --------- |
| Seed / Primary  | Vivid Green | `#42C750` |
| Water indicator | Sky Blue    | `#29B6F6` |
| Carbohydrates   | Blue        | `#2196F3` |
| Protein         | Orange      | `#FF9800` |
| Fat             | Purple      | `#9C27B0` |

## Tech stack

| Layer             | Library                                                        |
| ----------------- | -------------------------------------------------------------- |
| UI framework      | Flutter 3.44, Material 3                                       |
| State management  | `provider` (DiaryProvider + SettingsProvider)                  |
| Local database    | `sqflite` (seed food catalogue + user diary/recipes/water)     |
| Preferences       | `shared_preferences`                                           |
| Barcode scanning  | `mobile_scanner`                                               |
| Nutrition API     | Open Food Facts v2 (`http`)                                    |
| Charts            | `fl_chart`                                                     |
| Home screen widgets | `home_widget` (Android RemoteViews)                          |
| Icons             | Material Icons, `flutter_svg`                                  |

## Project structure

```
lib/
  main.dart                    # App entry, providers, widget services
  models/                      # DiaryEntry, FoodItem, WaterVessel
  providers/
    diary_provider.dart        # Day-specific state: entries, water, lock
    settings_provider.dart     # Persistent settings: goals, BMR, vessels, recipes
  screens/
    home_screen.dart           # Diary + water card + week strip
    trends_screen.dart         # Calorie & macro charts
    settings_screen.dart       # Goals, water, recipes, BMR, export/import
    recipes_screen.dart        # Recipe detail + servings editor
    add_food_screen.dart       # Search + barcode entry point
    food_detail_screen.dart
    barcode_scan_screen.dart
    bmr_calculator_screen.dart
    water_vessels_screen.dart
  services/
    database_service.dart      # SQLite: seed foods DB + user DB
    food_lookup_service.dart   # Open Food Facts API
    water_widget_service.dart  # Android water widget bridge
    calorie_widget_service.dart # Android calorie ring widget
    export_service.dart        # JSON backup / restore
  widgets/
    calorie_ring.dart
    meal_section.dart
assets/
  calora_seed.db               # Bundled food catalogue (77,952 foods, v4)
  logo.svg / logo.png
data/                          # Seed DB build pipeline (see data/README.md)
```

## Getting started

**Prerequisites:** Flutter 3.44 stable, uv (for data pipeline)

```bash
flutter pub get
flutter run
```

## Seed database

The bundled food catalogue is built from AUSNUT 2023, NZ Food Composition, Open Food Facts APAC (Parquet), and USDA Foundation Foods. See [`data/README.md`](data/README.md) for the full pipeline.

```bash
cd data
task all    # download all sources + build calora_seed.db
```

## CI

GitHub Actions runs `dart analyze --fatal-infos` and `flutter test --concurrency=1` on every push and pull request to `main`. The Flutter version is pinned via `pubspec.yaml`.
