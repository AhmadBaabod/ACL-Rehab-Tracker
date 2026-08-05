import 'dart:convert';

import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateRepository {
  AppStateRepository(this._stateBox, this._preferences);

  static const boxName = 'acl_rehab_state_box';
  static const _stateKey = 'app_state_v2';
  static const _legacyStorageKey = 'acl_rehab_app_state';
  static const _themeModeKey = 'theme_mode';
  static const _selectedIndexKey = 'selected_index';

  final Box<String> _stateBox;
  final SharedPreferences _preferences;

  Future<AppState> load() async {
    final raw = _stateBox.get(_stateKey);
    final legacyRaw = _preferences.getString(_legacyStorageKey);

    if ((raw == null || raw.isEmpty) &&
        legacyRaw != null &&
        legacyRaw.isNotEmpty) {
      final migrated = _decode(legacyRaw);
      await save(migrated);
      await _preferences.remove(_legacyStorageKey);
      return migrated;
    }

    final state = raw == null || raw.isEmpty ? const AppState() : _decode(raw);
    return state.copyWith(
      themeMode: _preferences.getString(_themeModeKey) ?? state.themeMode,
      selectedIndex:
          _preferences.getInt(_selectedIndexKey) ?? state.selectedIndex,
    );
  }

  Future<void> save(AppState state) async {
    await _stateBox.put(_stateKey, jsonEncode(state.toJson()));
    await _preferences.setString(_themeModeKey, state.themeMode);
    await _preferences.setInt(_selectedIndexKey, state.selectedIndex);
  }

  AppState _decode(String raw) {
    try {
      return AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppState();
    }
  }
}
