import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'pro_service.dart';

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // Entitlement identifier in RevenueCat dashboard
  static const String entitlementId = 'pro';

  // RevenueCat Public API Keys
  // Placeholder key: replace with your actual RevenueCat Google API key from dashboard
  static const String _revenueCatApiKeyGoogle = 'goog_placeholder_api_key';

  bool _isInitialized = false;
  Offerings? _offerings;
  bool _isLoading = false;

  bool get isInitialized => _isInitialized;
  Offerings? get offerings => _offerings;
  bool get isLoading => _isLoading;

  Package? get lifetimePackage {
    return _offerings?.current?.lifetime ?? _offerings?.current?.availablePackages.firstOrNull;
  }

  String get localizedPriceString {
    return lifetimePackage?.storeProduct.priceString ?? '\$9.99';
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Configure SDK if a real API key is present
      if (_revenueCatApiKeyGoogle.startsWith('goog_') &&
          _revenueCatApiKeyGoogle != 'goog_placeholder_api_key') {
        final configuration = PurchasesConfiguration(_revenueCatApiKeyGoogle);
        await Purchases.configure(configuration);
        _isInitialized = true;

        // Fetch latest customer info & sync entitlement
        await checkEntitlement();
        await fetchOfferings();

        // Listen for real-time customer info changes (e.g., refund, external restore)
        Purchases.addCustomerInfoUpdateListener((customerInfo) {
          _updateEntitlementFromCustomerInfo(customerInfo);
        });
      } else {
        debugPrint('[PurchaseService] Running in Sandbox/Dev mode (No production RevenueCat key provided yet).');
      }
    } catch (e) {
      debugPrint('[PurchaseService] Initialization failed: $e');
    }
  }

  Future<void> fetchOfferings() async {
    if (!_isInitialized) return;
    try {
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseService] Failed to fetch offerings: $e');
    }
  }

  Future<bool> checkEntitlement() async {
    if (!_isInitialized) return ProService.instance.isPro;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _updateEntitlementFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[PurchaseService] Error checking customer info: $e');
      return ProService.instance.isPro;
    }
  }

  bool _updateEntitlementFromCustomerInfo(CustomerInfo customerInfo) {
    final hasActiveEntitlement =
        customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    ProService.instance.setPro(hasActiveEntitlement);
    notifyListeners();
    return hasActiveEntitlement;
  }

  /// Triggers the purchase flow.
  /// In Sandbox / Dev mode (without live API key), simulates an instant successful purchase.
  Future<bool> purchasePro() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!_isInitialized || _revenueCatApiKeyGoogle == 'goog_placeholder_api_key') {
        // Dev / Simulation mode: unlock Pro directly
        await Future.delayed(const Duration(milliseconds: 600));
        await ProService.instance.setPro(true);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final packageToBuy = lifetimePackage;
      if (packageToBuy == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final purchaseResult = await Purchases.purchasePackage(packageToBuy);
      final isPro = _updateEntitlementFromCustomerInfo(purchaseResult);
      _isLoading = false;
      notifyListeners();
      return isPro;
    } catch (e) {
      debugPrint('[PurchaseService] Purchase error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Restores existing purchases across devices / reinstalls.
  Future<bool> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!_isInitialized || _revenueCatApiKeyGoogle == 'goog_placeholder_api_key') {
        // Simulation mode
        await Future.delayed(const Duration(milliseconds: 600));
        final current = ProService.instance.isPro;
        _isLoading = false;
        notifyListeners();
        return current;
      }

      final customerInfo = await Purchases.restorePurchases();
      final isPro = _updateEntitlementFromCustomerInfo(customerInfo);
      _isLoading = false;
      notifyListeners();
      return isPro;
    } catch (e) {
      debugPrint('[PurchaseService] Restore error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
