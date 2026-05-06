import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static String savedIp = '';

  static String get baseUrl {
    final ip = savedIp.isEmpty ? '10.0.2.2' : savedIp;
    // TODO: Revert suffix to single '/Teryaqi-main' before sharing or deploying.
    return 'http://$ip/Teryaqi-main';
  }

  static Future<void> setHostIp(String ip) async {
    savedIp = ip.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teryaqi_host_ip', savedIp);
  }
}
