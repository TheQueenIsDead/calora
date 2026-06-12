import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class ExportService {
  static const _version = 1;

  Future<void> export() async {
    final tables = await DatabaseService.instance.exportUserTables();
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, dynamic>{
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      ...tables,
      'preferences': {for (final key in prefs.getKeys()) key: prefs.get(key)},
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/calora_backup_$date.json');
    await file.writeAsString(json);

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: 'Calora backup $date');
  }

  /// Returns true if data was restored, false if the user cancelled.
  /// Throws on version mismatch or parse/DB error.
  Future<bool> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return false;

    final raw = await File(result.files.single.path!).readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;

    if (data['version'] != _version) {
      throw Exception('Unsupported backup version ${data['version']}');
    }

    await DatabaseService.instance.importUserTables(data);

    final prefs = await SharedPreferences.getInstance();
    final prefData = data['preferences'] as Map<String, dynamic>? ?? {};
    for (final entry in prefData.entries) {
      final v = entry.value;
      if (v is int) {
        await prefs.setInt(entry.key, v);
      } else if (v is double) {
        await prefs.setDouble(entry.key, v);
      } else if (v is bool) {
        await prefs.setBool(entry.key, v);
      } else if (v is String) {
        await prefs.setString(entry.key, v);
      } else if (v is List) {
        await prefs.setStringList(entry.key, v.cast<String>());
      }
    }
    return true;
  }
}
