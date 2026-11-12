import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat wrapper. Keys come in through --dart-define at build time
/// (REVENUECAT_APPLE_KEY / REVENUECAT_GOOGLE_KEY), like BijbelQuiz.
/// Without a key (local runs, web) every call is a quiet no-op.
class PurchaseService {
  static const entitlement = 'premium';
  static const _appleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const _googleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

  static bool _ready = false;
  static bool get available => _ready;

  static String get _key {
    if (kIsWeb) return '';
    return defaultTargetPlatform == TargetPlatform.iOS ? _appleKey : _googleKey;
  }

  static Future<void> init() async {
    final key = _key;
    if (key.isEmpty) return;
    try {
      await Purchases.configure(PurchasesConfiguration(key));
      _ready = true;
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
    }
  }

  static Future<bool> isPremium() async {
    if (!_ready) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlement);
    } catch (_) {
      return false;
    }
  }

  static Future<Offering?> currentOffering() async {
    if (!_ready) return null;
    try {
      return (await Purchases.getOfferings()).current;
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the purchase unlocked Premium. A cancelled purchase
  /// returns false without an error.
  static Future<bool> buy(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active.containsKey(entitlement);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  static Future<bool> restore() async {
    if (!_ready) return false;
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(entitlement);
  }
}
