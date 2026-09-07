import 'package:flutter/foundation.dart';
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
    // Force a re-read from disk so we never rely on a stale in-memory cache
    // when the app process restarts on Android.
    await prefs.reload();
    final shopName = prefs.getString(_shopNameKey) ?? '';
    debugPrint('[SessionService] isLoggedIn read key="$_shopNameKey" value="$shopName"');
    return shopName.isNotEmpty;
  }

  /// The saved shop name and phone (empty when never logged in).
  static Future<({String shopName, String shopPhone})> shopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final shopName = prefs.getString(_shopNameKey) ?? '';
    final shopPhone = prefs.getString(_shopPhoneKey) ?? '';
    debugPrint('[SessionService] shopInfo read name="$shopName" phone="$shopPhone"');
    return (shopName: shopName, shopPhone: shopPhone);
  }

  /// Saves the shop info, marking the user as logged in.
  static Future<void> saveShop({
    required String shopName,
    String? shopPhone,
  }) async {
    debugPrint('[SessionService] saveShop called name="$shopName" phone="$shopPhone"');
    final prefs = await SharedPreferences.getInstance();

    var ok = await prefs.setString(_shopNameKey, shopName);
    debugPrint('[SessionService] setString("$_shopNameKey") returned $ok');
    if (!ok) {
      debugPrint('[SessionService] retrying setString("$_shopNameKey")...');
      ok = await prefs.setString(_shopNameKey, shopName);
      debugPrint('[SessionService] retry returned $ok');
    }

    if (shopPhone == null || shopPhone.isEmpty) {
      await prefs.remove(_shopPhoneKey);
      debugPrint('[SessionService] removed "$_shopPhoneKey"');
    } else {
      await prefs.setString(_shopPhoneKey, shopPhone);
      debugPrint('[SessionService] setString("$_shopPhoneKey") done');
    }

    // Verify the write is visible in this instance immediately.
    await prefs.reload();
    final verify = prefs.getString(_shopNameKey) ?? '';
    debugPrint('[SessionService] saveShop verify read-back="$verify"');
  }

  /// Clears the saved shop info, logging the user out.
  static Future<void> clear() async {
    debugPrint('[SessionService] clear called');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopNameKey);
    await prefs.remove(_shopPhoneKey);
    debugPrint('[SessionService] cleared session keys');
  }
}
