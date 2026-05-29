import 'package:injast_admin/local_cache/network_reachability.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سوئیچ حالت آفلاین / آنلاین (بدون درخواست به API اصناف در حالت آفلاین).
class OfflineModePrefs {
  static const _kPrefix = 'asnaf_offline_mode_v1_';
  static const _kAutoPrefix = 'asnaf_offline_auto_v1_';

  /// کاربر دستی آفلاین را روشن کرده است.
  Future<bool> isUserOffline(String codeCo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kPrefix$codeCo') ?? false;
  }

  Future<void> setUserOffline(String codeCo, bool offline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefix$codeCo', offline);
    if (!offline) {
      await prefs.setBool('$_kAutoPrefix$codeCo', false);
    }
  }

  /// سرور در دسترس نبود و اپ به‌صورت خودکار آفلاین شده است.
  Future<bool> isAutoOffline(String codeCo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kAutoPrefix$codeCo') ?? false;
  }

  Future<void> setAutoOffline(String codeCo, bool auto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kAutoPrefix$codeCo', auto);
    if (auto) {
      await prefs.setBool('$_kPrefix$codeCo', true);
    }
  }

  /// آفلاین مؤثر = دستی آفلاین یا قطع شبکه/سرور.
  Future<bool> isOfflineEffective(String codeCo) async {
    if (await isUserOffline(codeCo)) return true;
    if (await isAutoOffline(codeCo)) return true;
    final online = await NetworkReachability.instance.isServerReachableCached();
    if (!online) {
      await setAutoOffline(codeCo, true);
      return true;
    }
    return false;
  }

  /// پس از برقراری اتصال، فقط پرچم «خودکار» را برمی‌دارد (انتخاب دستی کاربر حفظ می‌شود).
  Future<void> clearAutoOfflineIfOnline(String codeCo) async {
    final online = await NetworkReachability.instance.isServerReachable();
    if (!online) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kAutoPrefix$codeCo', false);
  }

  Future<bool> isOffline(String codeCo) => isOfflineEffective(codeCo);

  Future<void> setOffline(String codeCo, bool offline) => setUserOffline(codeCo, offline);
}
