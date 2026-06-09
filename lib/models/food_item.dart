class FoodItem {
  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final double caloriesPer100g;
  final double fatPer100g;
  final double saturatedFatPer100g;
  final double carbsPer100g;
  final double sugarsPer100g;
  final double fiberPer100g;
  final double proteinPer100g;
  final double sodiumPer100g;
  final String? servingSize;
  final double? servingGrams;
  final String? imageUrl;
  final String source;

  const FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.caloriesPer100g,
    this.fatPer100g = 0,
    this.saturatedFatPer100g = 0,
    this.carbsPer100g = 0,
    this.sugarsPer100g = 0,
    this.fiberPer100g = 0,
    this.proteinPer100g = 0,
    this.sodiumPer100g = 0,
    this.servingSize,
    this.servingGrams,
    this.imageUrl,
    this.source = 'custom',
  });

  double caloriesForGrams(double grams) => caloriesPer100g * grams / 100;
  double fatForGrams(double grams) => fatPer100g * grams / 100;
  double carbsForGrams(double grams) => carbsPer100g * grams / 100;
  double proteinForGrams(double grams) => proteinPer100g * grams / 100;

  /// "Apple, red skin, raw" → "Apple (Red Skin, Raw)"
  static String formatName(String raw) {
    String titleWord(String w) =>
        w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
    String titleCase(String s) => s.trim().split(' ').map(titleWord).join(' ');

    final i = raw.indexOf(',');
    if (i == -1) return titleCase(raw);
    return '${titleCase(raw.substring(0, i))} (${titleCase(raw.substring(i + 1))})';
  }

  String get formattedName => formatName(name);
  String get displayName =>
      brand != null ? '$formattedName ($brand)' : formattedName;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'calories_per_100g': caloriesPer100g,
    'fat_per_100g': fatPer100g,
    'saturated_fat_per_100g': saturatedFatPer100g,
    'carbs_per_100g': carbsPer100g,
    'sugars_per_100g': sugarsPer100g,
    'fiber_per_100g': fiberPer100g,
    'protein_per_100g': proteinPer100g,
    'sodium_per_100g': sodiumPer100g,
    'serving_size': servingSize,
    'serving_grams': servingGrams,
    'image_url': imageUrl,
    'source': source,
  };

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
    id: m['id'] as String,
    name: m['name'] as String,
    brand: m['brand'] as String?,
    barcode: m['barcode'] as String?,
    caloriesPer100g: (m['calories_per_100g'] as num).toDouble(),
    fatPer100g: (m['fat_per_100g'] as num? ?? 0).toDouble(),
    saturatedFatPer100g: (m['saturated_fat_per_100g'] as num? ?? 0).toDouble(),
    carbsPer100g: (m['carbs_per_100g'] as num? ?? 0).toDouble(),
    sugarsPer100g: (m['sugars_per_100g'] as num? ?? 0).toDouble(),
    fiberPer100g: (m['fiber_per_100g'] as num? ?? 0).toDouble(),
    proteinPer100g: (m['protein_per_100g'] as num? ?? 0).toDouble(),
    sodiumPer100g: (m['sodium_per_100g'] as num? ?? 0).toDouble(),
    servingSize: m['serving_size'] as String?,
    servingGrams: (m['serving_grams'] as num?)?.toDouble(),
    imageUrl: m['image_url'] as String?,
    source: m['source'] as String? ?? 'custom',
  );

  factory FoodItem.fromOpenFoodFacts(Map<String, dynamic> json) {
    final n = json['nutriments'] as Map<String, dynamic>? ?? {};
    final code = json['code'] as String? ?? '';
    return FoodItem(
      id: 'off_$code',
      name: json['product_name'] as String? ?? 'Unknown',
      brand: json['brands'] as String?,
      barcode: code,
      caloriesPer100g: _num(n['energy-kcal_100g'] ?? n['energy_100g']),
      fatPer100g: _num(n['fat_100g']),
      saturatedFatPer100g: _num(n['saturated-fat_100g']),
      carbsPer100g: _num(n['carbohydrates_100g']),
      sugarsPer100g: _num(n['sugars_100g']),
      fiberPer100g: _num(n['fiber_100g']),
      proteinPer100g: _num(n['proteins_100g']),
      sodiumPer100g: _num(n['sodium_100g']),
      servingSize: json['serving_size'] as String?,
      imageUrl: json['image_front_url'] as String?,
      source: 'off',
    );
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
