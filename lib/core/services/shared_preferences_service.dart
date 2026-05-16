import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_setup_model.dart';

class SharedPreferencesService {
  static SharedPreferencesService? _instance;
  static SharedPreferences? _preferences;

  SharedPreferencesService._internal();

  static Future<SharedPreferencesService> getInstance() async {
    if (_instance == null) {
      _instance = SharedPreferencesService._internal();
      _preferences = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Keys
  static const String _defaultCurrency = 'default_currency';
  static const String _defaultCurrencyId = 'default_currency_id';
  static const String _defaultCurrencyCode = 'default_currency_code';
  static const String _isOpenFirstPage = 'is_open_first_page';
  static const String _userName = "user_name";
  static const String _userSetup = "user_setup";
  static const String _isDarkMode = "is_dark_mode";
  static const String _isPro = "is_pro";

  // String operations
  Future<void> setString(String key, String value) async {
    await _preferences?.setString(key, value);
  }

  String? getString(String key) {
    return _preferences?.getString(key);
  }

  // Boolean operations
  Future<void> setBoolean(String key, bool value) async {
    await _preferences?.setBool(key, value);
  }

  bool? getBoolean(String key) {
    return _preferences?.getBool(key);
  }

  // Double operations
  Future<void> setDouble(String key, double value) async {
    await _preferences?.setDouble(key, value);
  }

  double? getDouble(String key) {
    return _preferences?.getDouble(key);
  }

  // Integer operations
  Future<void> setInt(String key, int value) async {
    await _preferences?.setInt(key, value);
  }

  int? getInt(String key) {
    return _preferences?.getInt(key);
  }

  // JSON operations
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _preferences?.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final jsonString = _preferences?.getString(key);
    if (jsonString != null) {
      return jsonDecode(jsonString);
    }
    return null;
  }

  // Remove preference
  Future<void> remove(String key) async {
    await _preferences?.remove(key);
  }

  // Clear all preferences
  Future<void> clear() async {
    await _preferences?.clear();
  }

  // Check if preference exists
  bool contains(String key) {
    return _preferences?.containsKey(key) ?? false;
  }

  // Specific getters/setters for app preferences
  Future<void> setUserName(String name) async {
    await setString(_userName, name);
  }

  String? getUserName() {
    return getString(_userName);
  }

  Future<void> setUserSetup(Map<String, dynamic> setup) async {
    await setJson(_userSetup, setup);
  }

  Map<String, dynamic>? getUserSetup() {
    return getJson(_userSetup);
  }

  Future<void> setDefaultCurrency(CurrencyModel currency) async {
    await setJson(_defaultCurrency, currency.toMap());
    await setInt(_defaultCurrencyId, currency.id);
    await setString(_defaultCurrencyCode, currency.currencyCode);
  }

  CurrencyModel? getDefaultCurrency() {
    final currencyJson = getJson(_defaultCurrency);
    if (currencyJson != null) {
      return CurrencyModel.fromMap(currencyJson);
    }
    return null;
  }

  Future<void> setFirstPageCompleted() async {
    await setBoolean(_isOpenFirstPage, true);
  }

  bool isFirstPageCompleted() {
    return getBoolean(_isOpenFirstPage) ?? false;
  }

  // Theme persistence
  Future<void> setDarkMode(bool isDark) async {
    await setBoolean(_isDarkMode, isDark);
  }

  bool isDarkMode() {
    return getBoolean(_isDarkMode) ?? false;
  }

  Future<void> setIsPro(bool isPro) async {
    await setBoolean(_isPro, isPro);
  }

  bool isPro() {
    return getBoolean(_isPro) ?? false;
  }

  Future<void> clearAppSetup() async {
    await remove(_isOpenFirstPage);
    await remove(_userSetup);
    await remove(_userName);
    await remove(_defaultCurrency);
    await remove(_defaultCurrencyId);
    await remove(_defaultCurrencyCode);
  }
}
