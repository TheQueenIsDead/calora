import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:home_widget/home_widget.dart';

import '../models/water_vessel.dart';
import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import 'database_service.dart';

/// Bridges Flutter water state to the Android home screen widget.
///
/// Button taps (add/remove/toggle) are handled entirely in Kotlin so the
/// widget works without starting a Flutter isolate. On app open, any water
/// added via the widget while the app was closed is synced back to SQLite.
class WaterWidgetService {
  WaterWidgetService._();
  static final instance = WaterWidgetService._();

  static const _androidWidget = 'WaterWidgetProvider';

  /// Read the widget's cached water value before anything else runs.
  /// Call this as the very first thing in main() so diary.init() can't
  /// overwrite the widget's value before we've had a chance to read it.
  static Future<int?> snapshotWidgetWater() async {
    try {
      return await HomeWidget.getWidgetData<int>('water_ml');
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize(
    DiaryProvider diary,
    SettingsProvider settings,
    int? widgetSnapshot,
  ) async {
    // If the widget has a higher value than SQLite (user added water while
    // app was closed), sync it to SQLite now.
    if (widgetSnapshot != null && widgetSnapshot > diary.waterMl) {
      await DatabaseService.instance.setWaterMlForDate(
          DateTime.now(), widgetSnapshot);
      await diary.refreshCurrentDay();
    }
    await _push(diary.waterMl, settings.waterTargetMl, settings.vessels);
    diary.addListener(
      () => _push(diary.waterMl, settings.waterTargetMl, settings.vessels),
    );
    settings.addListener(
      () => _push(diary.waterMl, settings.waterTargetMl, settings.vessels),
    );
  }

  Future<void> _push(
    int waterMl,
    int targetMl,
    List<WaterVessel> vessels,
  ) async {
    await HomeWidget.saveWidgetData<int>('water_ml', waterMl);
    await HomeWidget.saveWidgetData<int>('water_target_ml', targetMl);
    final count = vessels.length.clamp(1, 3);
    await HomeWidget.saveWidgetData<int>('vessel_count', count);
    for (var i = 0; i < count; i++) {
      await HomeWidget.saveWidgetData<String>('vessel_${i}_name', vessels[i].name);
      await HomeWidget.saveWidgetData<int>('vessel_${i}_ml', vessels[i].ml);
      await _renderVesselIcon(vessels[i], i);
    }
    await HomeWidget.updateWidget(androidName: _androidWidget);
  }

  /// Renders the vessel icon to a PNG file the widget can load as a Bitmap.
  Future<void> _renderVesselIcon(WaterVessel vessel, int index) async {
    try {
      // Render white so Kotlin can apply any color filter on top cleanly.
      final widget = vessel.isSvgIcon && vessel.svgAsset != null
          ? SvgPicture.asset(
              vessel.svgAsset!,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            )
          : Icon(vessel.icon, size: 24, color: Colors.white);

      await HomeWidget.renderFlutterWidget(
        widget,
        logicalSize: const Size(24, 24),
        key: 'vessel_${index}_icon_path',
      );
    } catch (_) {
      // Icon rendering is best-effort — widget has a fallback drawable.
    }
  }
}
