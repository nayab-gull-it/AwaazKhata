import 'package:shared_preferences/shared_preferences.dart';

/// Locally stored shop login info for the demo.
///
/// There is no real authentication — the "login" is just the shop name
/// (and optional phone) saved on the device. When a shop name exists,
/// the app skips the login screen on launch.
class SessionService {
  const SessionService._();

  static const _shopNameKey = 'shop_name';
  static const _shopPhoneKey = 'shop_phone';

  /// True when a shop name has been saved on this device.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_shopNameKey) ?? '').isNotEmpty;
  }

  /// The saved shop name and phone (empty when never logged in).
  static Future<({String shopName, String shopPhone})> shopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      shopName: prefs.getString(_shopNameKey) ?? '',
      shopPhone: prefs.getString(_shopPhoneKey) ?? '',
    );
  }

  /// Saves the shop info, marking the user as logged in.
  static Future<void> saveShop({
    required String shopName,
    String? shopPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopNameKey, shopName);
    if (shopPhone == null || shopPhone.isEmpty) {
      await prefs.remove(_shopPhoneKey);
    } else {
      await prefs.setString(_shopPhoneKey, shopPhone);
    }
  }

  /// Clears the saved shop info, logging the user out.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopNameKey);
    await prefs.remove(_shopPhoneKey);
  }
}
