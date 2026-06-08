import 'package:flutter/material.dart';

// Sentinel code point indicating this vessel uses an SVG asset icon.
const int kSvgIconCodePoint = -1;

class WaterVessel {
  final String id;
  final String name;
  final int ml;

  // Either a Material Icons code point, or kSvgIconCodePoint for SVG.
  final int iconCodePoint;

  // The SVG asset path to use when iconCodePoint == kSvgIconCodePoint.
  final String? svgAsset;

  const WaterVessel({
    required this.id,
    required this.name,
    required this.ml,
    required this.iconCodePoint,
    this.svgAsset,
  });

  bool get isSvgIcon => iconCodePoint == kSvgIconCodePoint;

  IconData get icon {
    if (isSvgIcon) return Icons.local_drink;
    return availableIcons
            .where((i) => !i.isSvg)
            .map((i) => i.iconData!)
            .firstWhere(
              (d) => d.codePoint == iconCodePoint,
              orElse: () => Icons.local_drink,
            );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ml': ml,
        'icon': iconCodePoint,
        if (svgAsset != null) 'svg_asset': svgAsset,
      };

  factory WaterVessel.fromJson(Map<String, dynamic> json) => WaterVessel(
        id: json['id'] as String,
        name: json['name'] as String,
        ml: json['ml'] as int,
        iconCodePoint: json['icon'] as int,
        svgAsset: json['svg_asset'] as String?,
      );

  static List<WaterVessel> get defaults => [
        WaterVessel(
            id: 'default_glass',
            name: 'Glass',
            ml: 250,
            iconCodePoint: Icons.local_drink.codePoint),
        WaterVessel(
            id: 'default_mug',
            name: 'Mug',
            ml: 350,
            iconCodePoint: Icons.free_breakfast.codePoint),
        WaterVessel(
            id: 'default_bottle',
            name: 'Bottle',
            ml: 500,
            iconCodePoint: kSvgIconCodePoint,
            svgAsset: 'assets/icons/water_bottle.svg'),
      ];

  // Ordered list of icon options shown in the vessel editor.
  static const List<VesselIconOption> availableIcons = [
    // SVG (Material Symbols)
    VesselIconOption.svg('assets/icons/water_bottle.svg', label: 'Water bottle'),
    // Cups & mugs
    VesselIconOption.material(Icons.local_drink, label: 'Cup / tumbler'),
    VesselIconOption.material(Icons.takeout_dining, label: 'Lidded cup'),
    VesselIconOption.material(Icons.sports_bar, label: 'Pint glass'),
    VesselIconOption.material(Icons.free_breakfast, label: 'Mug'),
    VesselIconOption.material(Icons.coffee, label: 'Espresso'),
    VesselIconOption.material(Icons.local_cafe, label: 'Cup & saucer'),
    VesselIconOption.material(Icons.emoji_food_beverage, label: 'Hot drink'),
    // Bottles & decanters
    VesselIconOption.material(Icons.liquor, label: 'Bottle'),
    VesselIconOption.material(Icons.coffee_maker, label: 'Carafe / pour-over'),
    VesselIconOption.material(Icons.thermostat, label: 'Insulated flask'),
    // Stemware & bar
    VesselIconOption.material(Icons.wine_bar, label: 'Stemmed glass'),
    VesselIconOption.material(Icons.local_bar, label: 'Cocktail glass'),
    VesselIconOption.material(Icons.blender, label: 'Blender jar'),
    // Generic
    VesselIconOption.material(Icons.water_drop, label: 'Drop'),
  ];
}

// Represents a single selectable icon in the vessel icon picker.
class VesselIconOption {
  final IconData? iconData;
  final String? svgPath;
  final String label;

  const VesselIconOption.material(IconData icon, {required this.label})
      : iconData = icon,
        svgPath = null;

  const VesselIconOption.svg(String path, {required this.label})
      : svgPath = path,
        iconData = null;

  bool get isSvg => svgPath != null;

  int get codePoint => isSvg ? kSvgIconCodePoint : iconData!.codePoint;
}
