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

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

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
    Icons.local_drink,
    Icons.coffee,
    Icons.emoji_food_beverage,
    Icons.free_breakfast,
    Icons.local_cafe,
    Icons.sports_bar,
    Icons.liquor,
    Icons.wine_bar,
    Icons.local_bar,
    Icons.water_drop,
    Icons.blender,
    Icons.kitchen,
  ];
}
