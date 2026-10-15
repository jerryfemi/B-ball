import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vatar/vatar_bridge.dart';
import 'cosmetic_item.dart';

/// Central inventory and cosmetic gear service.
///
/// Tracks unlocked skins, equipped ball models, and synchronizes
/// purchases with Lagos Life and local persistent storage.
class InventoryService {
  static final InventoryService instance = InventoryService._internal();
  InventoryService._internal();

  static const String _prefKeyEquippedSkin = 'bball_equipped_skin';
  static const String _prefKeyUnlockedItems = 'bball_unlocked_items';
  static const String _prefKeyLastPurchaseId = 'bball_last_purchase_id';

  /// Most recent confirmed purchaseId (used for server verification in sandbox).
  String? lastPurchaseId;

  /// Currently equipped ball skin identifier.
  final ValueNotifier<String> equippedBallSkinNotifier =
      ValueNotifier<String>(CosmeticCatalog.classicBall.id);

  /// Set of unlocked cosmetic item identifiers.
  final ValueNotifier<Set<String>> unlockedItemsNotifier =
      ValueNotifier<Set<String>>({CosmeticCatalog.classicBall.id});

  /// The active uniform float passed directly to the 3D basketball GPU fragment shader.
  double get activeSkinIdFloat {
    final item = CosmeticCatalog.findById(equippedBallSkinNotifier.value);
    return item?.skinIdFloat ?? 0.0;
  }

  /// Whether the shop / locker room is visible in the UI.
  ///
  /// In debug mode, this returns true to allow local web development and visual inspection.
  /// In production releases, this is strictly gated to players inside the Lagos Life phone frame.
  bool get isShopVisible => VatarBridge.instance.isInsideVatar || kDebugMode;

  /// Loads saved inventory from persistent storage on startup.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lastPurchaseId = prefs.getString(_prefKeyLastPurchaseId);

      final savedUnlocked = prefs.getStringList(_prefKeyUnlockedItems);
      if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
        final set = savedUnlocked.toSet();
        set.add(CosmeticCatalog.classicBall.id);
        unlockedItemsNotifier.value = set;
      }

      final savedEquipped = prefs.getString(_prefKeyEquippedSkin);
      if (savedEquipped != null && isUnlocked(savedEquipped)) {
        equippedBallSkinNotifier.value = savedEquipped;
      }
    } catch (e) {
      debugPrint('[InventoryService] Error restoring inventory: $e');
    }
  }

  /// Checks if an item is unlocked.
  bool isUnlocked(String itemId) {
    if (itemId == CosmeticCatalog.classicBall.id) return true;
    return unlockedItemsNotifier.value.contains(itemId);
  }

  /// Checks if an item is currently equipped.
  bool isEquipped(String itemId) {
    return equippedBallSkinNotifier.value == itemId;
  }

  /// Equips an item if unlocked.
  Future<void> equipItem(String itemId) async {
    if (!isUnlocked(itemId)) return;
    equippedBallSkinNotifier.value = itemId;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyEquippedSkin, itemId);
    } catch (e) {
      debugPrint('[InventoryService] Failed to persist equipped skin: $e');
    }
  }

  /// Marks an item as unlocked and saves to disk.
  Future<void> unlockItem(String itemId) async {
    final current = Set<String>.from(unlockedItemsNotifier.value);
    current.add(itemId);
    unlockedItemsNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKeyUnlockedItems, current.toList());
    } catch (e) {
      debugPrint('[InventoryService] Failed to persist unlocked items: $e');
    }
  }

  /// Initiates the purchase flow through the Lagos Life Vatar SDK.
  ///
  /// On success, automatically unlocks and equips the purchased cosmetic.
  Future<String?> purchaseItem(CosmeticItem item) async {
    final productId = item.vatarProductId ?? item.id;
    debugPrint('[InventoryService] Initiating purchase for productId: $productId');

    final purchaseId = await VatarBridge.instance.purchase(productId);
    if (purchaseId != null) {
      lastPurchaseId = purchaseId;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyLastPurchaseId, purchaseId);
      } catch (_) {}
      debugPrint('[InventoryService] Purchase confirmed! purchaseId: $purchaseId');
      await unlockItem(item.id);
      await equipItem(item.id);
      return purchaseId;
    }

    return null;
  }
}
