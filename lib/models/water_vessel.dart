import 'package:flutter/material.dart';

class WaterVessel {
  final String id;
  final String name;
  final int ml;
  final int iconCodePoint;

  const WaterVessel({
    required this.id,
    required this.name,
    required this.ml,
    required this.iconCodePoint,
  });

  IconData get icon => WaterVessel.availableIcons.firstWhere(
        (i) => i.codePoint == iconCodePoint,
        orElse: () => Icons.local_drink,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ml': ml,
    'icon': iconCodePoint,
  };

  factory WaterVessel.fromJson(Map<String, dynamic> json) => WaterVessel(
    id: json['id'] as String,
    name: json['name'] as String,
    ml: json['ml'] as int,
    iconCodePoint: json['icon'] as int,
  );

  static List<WaterVessel> get defaults => [
    WaterVessel(id: 'default_glass', name: 'Glass', ml: 250, iconCodePoint: Icons.local_drink.codePoint),
    WaterVessel(id: 'default_mug', name: 'Mug', ml: 350, iconCodePoint: Icons.free_breakfast.codePoint),
    WaterVessel(id: 'default_bottle', name: 'Bottle', ml: 500, iconCodePoint: Icons.liquor.codePoint),
  ];

  static const List<IconData> availableIcons = [
    // Tumblers / lidded cups (Stanley-style)
    Icons.takeout_dining,      // lidded cup with straw — closest to a Stanley
    Icons.local_drink,         // cup with straw / tumbler
    Icons.sports_bar,          // tall pint-style cup
    Icons.free_breakfast,      // wide mug
    // Hot drinks
    Icons.coffee,              // espresso cup
    Icons.local_cafe,          // cup with saucer
    Icons.emoji_food_beverage, // hot cup with steam
    Icons.coffee_maker,        // carafe / pour-over
    // Bottles
    Icons.liquor,              // tall slim bottle
    Icons.science,             // flask / wide-mouth bottle (Nalgene-style)
    Icons.water,               // water waves — general hydration
    Icons.water_drop,          // single drop
    // Bar / other vessels
    Icons.wine_bar,            // stemmed glass
    Icons.local_bar,           // cocktail glass
    Icons.blender,             // blender jar
    // Contextual / insulated
    Icons.thermostat,          // thermal / insulated (Stanley / Hydro Flask)
    Icons.fitness_center,      // gym / sports bottle context
    Icons.kitchen,             // kitchen jug
  ];
}
