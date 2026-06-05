import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'database_service.dart';

class FoodLookupService {
  static const _offApiBase = 'https://world.openfoodfacts.org/api/v2';
  static const _userAgent = 'Calora/1.0 (calorie tracker)';

  Future<FoodItem?> lookupBarcode(String barcode) async {
    // Check local cache first
    final cached = await DatabaseService.instance.getFoodByBarcode(barcode);
    if (cached != null) return cached;

    // Fetch from Open Food Facts
    try {
      final uri = Uri.parse('$_offApiBase/product/$barcode?fields=code,product_name,brands,serving_size,nutriments,image_front_url');
      final resp = await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>;
      final food = FoodItem.fromOpenFoodFacts(product);

      // Cache it locally
      await DatabaseService.instance.saveFood(food);
      return food;
    } catch (e) {
      print('[FoodLookup] barcode lookup error: $e');
      return null;
    }
  }

  Future<List<FoodItem>> search(String query) {
    return DatabaseService.instance.searchFoods(query);
  }
}