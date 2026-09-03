import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/unlumen/murkot_theme_transition.dart';

enum AppLanguage { ru, en }

enum AppTextSize { small, normal, large }

class PersonalizationKeys {
  static const online = 'online';
  static const offline = 'offline';
  static const typing = 'typing';
  static const chats = 'chats';
  static const groups = 'groups';
  static const channels = 'channels';
  static const createChat = 'createChat';
  static const createGroup = 'createGroup';
  static const createChannel = 'createChannel';
  static const message = 'message';
  static const info = 'info';
  static const profile = 'profile';
  static const settings = 'settings';
  static const circleVideo = 'circleVideo';
  static const stickers = 'stickers';
  static const gif = 'gif';
  static const emoji = 'emoji';
  static const voiceNote = 'voiceNote';
}

class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs) {
    _themeMode = ThemeMode.values[_prefs.getInt(_themeKey) ?? 0];
    _language = AppLanguage.values[_prefs.getInt(_languageKey) ?? 0];
    _textSize = AppTextSize.values[_prefs.getInt(_textSizeKey) ?? 1];
    _notificationsEnabled = _prefs.getBool(_notificationsKey) ?? true;
    _floatingTooltips = _prefs.getBool(_floatingTooltipsKey) ?? true;
    _authSpotlight = _prefs.getBool(_authSpotlightKey) ?? true;
    _smoothTheme = _prefs.getBool(_smoothThemeKey) ?? true;
    _guest = _prefs.getBool(_guestKey) ?? false;
    _profileNudgeDismissed = _prefs.getBool(_profileNudgeKey) ?? false;
    _loadPersonalization();
  }

  static const _themeKey = 'settings_theme';
  static const _languageKey = 'settings_language';
  static const _textSizeKey = 'settings_text_size';
  static const _notificationsKey = 'settings_notifications';
  static const _floatingTooltipsKey = 'settings_floating_tooltips';
  static const _authSpotlightKey = 'settings_auth_spotlight';
  static const _smoothThemeKey = 'settings_smooth_theme';
  static const _personalizationKey = 'settings_personalization';
  static const _guestKey = 'settings_guest_mode';
  static const _profileNudgeKey = 'settings_profile_nudge_dismissed';

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late AppLanguage _language;
  late AppTextSize _textSize;
  late bool _notificationsEnabled;
  late bool _floatingTooltips;
  late bool _authSpotlight;
  late bool _smoothTheme;
  late bool _guest;
  late bool _profileNudgeDismissed;
  Map<String, String> _personalization = {};

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  AppTextSize get textSize => _textSize;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get floatingTooltips => _floatingTooltips;
  bool get authSpotlight => _authSpotlight;
  bool get smoothTheme => _smoothTheme;
  bool get isGuest => _guest;
  bool get profileNudgeDismissed => _profileNudgeDismissed;
  Map<String, String> get personalization => Map.unmodifiable(_personalization);

  Locale get locale =>
      _language == AppLanguage.ru ? const Locale('ru') : const Locale('en');

  double get textScaleFactor => switch (_textSize) {
        AppTextSize.small => 0.9,
        AppTextSize.normal => 1.0,
        AppTextSize.large => 1.15,
      };

  String label(String key, String defaultValue) {
    final custom = _personalization[key]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return defaultValue;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;

    bool nextIsDark(ThemeMode m) {
      if (m == ThemeMode.dark) return true;
      if (m == ThemeMode.light) return false;
      // system — approximate from platform; host may refine.
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }

    Future<void> apply() async {
      _themeMode = mode;
      await _prefs.setInt(_themeKey, mode.index);
      notifyListeners();
    }

    if (_smoothTheme) {
      await MurkotThemeTransition.instance.run(
        apply,
        next: mode,
        nextIsDark: nextIsDark(mode),
      );
    } else {
      await apply();
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _prefs.setInt(_languageKey, language.index);
    notifyListeners();
  }

  Future<void> setTextSize(AppTextSize size) async {
    _textSize = size;
    await _prefs.setInt(_textSizeKey, size.index);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _prefs.setBool(_notificationsKey, enabled);
    notifyListeners();
  }

  Future<void> setFloatingTooltips(bool enabled) async {
    _floatingTooltips = enabled;
    await _prefs.setBool(_floatingTooltipsKey, enabled);
    notifyListeners();
  }

  Future<void> setAuthSpotlight(bool enabled) async {
    _authSpotlight = enabled;
    await _prefs.setBool(_authSpotlightKey, enabled);
    notifyListeners();
  }

  Future<void> setSmoothTheme(bool enabled) async {
    _smoothTheme = enabled;
    await _prefs.setBool(_smoothThemeKey, enabled);
    notifyListeners();
  }

  Future<void> setGuest(bool enabled) async {
    _guest = enabled;
    await _prefs.setBool(_guestKey, enabled);
    notifyListeners();
  }

  Future<void> dismissProfileNudge() async {
    _profileNudgeDismissed = true;
    await _prefs.setBool(_profileNudgeKey, true);
    notifyListeners();
  }

  Future<void> setPersonalizationLabel(String key, String value) async {
    if (value.trim().isEmpty) {
      _personalization.remove(key);
    } else {
      _personalization[key] = value.trim();
    }
    await _prefs.setString(_personalizationKey, jsonEncode(_personalization));
    notifyListeners();
  }

  Future<void> resetPersonalization() async {
    _personalization.clear();
    await _prefs.remove(_personalizationKey);
    notifyListeners();
  }

  void _loadPersonalization() {
    final raw = _prefs.getString(_personalizationKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _personalization = map.map((k, v) => MapEntry(k, v as String));
  }

  // ── Conversation wallpaper (local, per-device) ────────────────────────────

  static String _convWallpaperKey(String conversationId) =>
      'conv_wallpaper_$conversationId';

  /// Returns the preset wallpaper id for a conversation, or null (= default).
  String? getConversationWallpaperId(String conversationId) =>
      _prefs.getString(_convWallpaperKey(conversationId));

  Future<void> setConversationWallpaperId(
      String conversationId, String? wallpaperId) async {
    final key = _convWallpaperKey(conversationId);
    if (wallpaperId == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, wallpaperId);
    }
    notifyListeners();
  }
}
