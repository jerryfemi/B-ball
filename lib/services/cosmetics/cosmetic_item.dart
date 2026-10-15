import 'package:flutter/material.dart';

/// Category of in-game cosmetic gear.
enum CosmeticType {
  ballSkin,
  commentary,
  netSfx,
  ballTrail,
}

/// Domain representation of a purchasable or unlockable cosmetic item.
class CosmeticItem {
  final String id;
  final String name;
  final String description;
  final CosmeticType type;
  final int priceNaira;
  final String? vatarProductId;
  final double skinIdFloat;
  final String? badge;
  final Color primaryColor;
  final Color accentColor;

  const CosmeticItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.priceNaira = 0,
    this.vatarProductId,
    this.skinIdFloat = 0.0,
    this.badge,
    required this.primaryColor,
    required this.accentColor,
  });

  bool get isFree => priceNaira == 0;
}

/// Central registry of all cosmetic products available across DunkVerse and Lagos Life.
abstract final class CosmeticCatalog {
  /// Default classic Wilson composite leather ball.
  static const CosmeticItem classicBall = CosmeticItem(
    id: 'classic_ball',
    name: 'Classic Pro Leather',
    description: 'Regulation Wilson composite microfiber with authentic recessed black rubber seams.',
    type: CosmeticType.ballSkin,
    priceNaira: 0,
    vatarProductId: null,
    skinIdFloat: 0.0,
    badge: 'DEFAULT',
    primaryColor: Color(0xFFD95A10),
    accentColor: Color(0xFF1F2937),
  );

  /// Iconic Lagos Danfo street bus edition ball.
  static const CosmeticItem danfoBall = CosmeticItem(
    id: 'danfo_ball',
    name: 'Danfo Street Edition',
    description: 'Vibrant Lagos Danfo yellow body with bold, pitch-black dual rubber stripes.',
    type: CosmeticType.ballSkin,
    priceNaira: 250,
    vatarProductId: 'danfo_ball',
    skinIdFloat: 1.0,
    badge: 'LAGOS STREET',
    primaryColor: Color(0xFFFACC15),
    accentColor: Color(0xFF09090B),
  );

  /// All currently supported ball skins.
  static const List<CosmeticItem> allBallSkins = [
    classicBall,
    danfoBall,
  ];

  /// Lookup helper by unique product ID.
  static CosmeticItem? findById(String id) {
    for (final item in allBallSkins) {
      if (item.id == id || item.vatarProductId == id) return item;
    }
    return null;
  }
}
