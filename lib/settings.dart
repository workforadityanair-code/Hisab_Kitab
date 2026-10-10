import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settingsKey = 'hk3_settings';

const accentColors = <Color>[
  Color(0xFF0E7C66),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFC2185B),
  Color(0xFFE65100),
  Color(0xFFC62828),
  Color(0xFF283593),
  Color(0xFF2E7D32),
];

class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool useDynamicColor = true;
  int accentIndex = 0;
  bool appLock = false;
  int lockAfterSeconds = 30;
  double defaultTax = 0;
  bool defaultExactSplit = false;
  String signature = '';

  Color get accent =>
      accentColors[accentIndex.clamp(0, accentColors.length - 1)];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == map['themeMode'],
        orElse: () => ThemeMode.system,
      );
      useDynamicColor = (map['useDynamicColor'] ?? true) as bool;
      accentIndex = (map['accentIndex'] ?? 0) as int;
      appLock = (map['appLock'] ?? false) as bool;
      lockAfterSeconds = (map['lockAfterSeconds'] ?? 30) as int;
      defaultTax = ((map['defaultTax'] ?? 0) as num).toDouble();
      defaultExactSplit = (map['defaultExactSplit'] ?? false) as bool;
      signature = (map['signature'] ?? '') as String;
    } catch (_) {
      return;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settingsKey,
      jsonEncode({
        'themeMode': themeMode.name,
        'useDynamicColor': useDynamicColor,
        'accentIndex': accentIndex,
        'appLock': appLock,
        'lockAfterSeconds': lockAfterSeconds,
        'defaultTax': defaultTax,
        'defaultExactSplit': defaultExactSplit,
        'signature': signature,
      }),
    );
  }

  void update(void Function(AppSettings s) change) {
    change(this);
    notifyListeners();
    _save();
  }
}

final appSettings = AppSettings();
