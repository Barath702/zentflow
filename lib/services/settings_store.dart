import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _kDeviceName = 'deviceName';
  static const _kPeerId = 'peerId';
  static const _kDownloadDir = 'downloadDir';

  Future<String?> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceName);
  }

  Future<void> setDeviceName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceName, value);
  }

  Future<String?> getPeerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPeerId);
  }

  Future<void> setPeerId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPeerId, value);
  }

  Future<String?> getDownloadDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDownloadDir);
  }

  Future<void> setDownloadDir(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDownloadDir, value);
  }
}

