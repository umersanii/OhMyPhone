import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyServerUrl = 'server_url';
  static const String _keySecret = 'secret';
  static const String _keyPollInterval = 'poll_interval';

  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? 'http://100.99.172.92:8080';
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
  }

  static Future<String> getSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySecret) ?? 'fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188';
  }

  static Future<void> setSecret(String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySecret, secret);
  }

  static Future<int> getPollInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPollInterval) ?? 15;
  }

  static Future<void> setPollInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPollInterval, seconds);
  }
}
