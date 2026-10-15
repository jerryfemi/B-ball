import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../services/cosmetics/cosmetic_item.dart';
import '../../../services/cosmetics/inventory_service.dart';
import '../common/app_colors.dart';
import '../common/app_modal_sheet.dart';

/// The Locker Room modal bottom sheet where players preview, equip, and unlock ball skins.
class LockerRoomSheet extends HookWidget {
  const LockerRoomSheet({super.key});

  /// Presents the Locker Room modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return AppModalSheet.show<void>(
      context: context,
      builder: (ctx) => const LockerRoomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = InventoryService.instance;

    // Listen to reactive inventory notifiers
    final equippedId = useListenable(inventory.equippedBallSkinNotifier).value;
    final unlockedSet = useListenable(inventory.unlockedItemsNotifier).value;

    final initialItem = useMemoized(
      () => CosmeticCatalog.findById(equippedId) ?? CosmeticCatalog.classicBall,
      const [],
    );
    final selectedItem = useState<CosmeticItem>(initialItem);
    final isPurchasing = useState<bool>(false);

    final isSelectedUnlocked = unlockedSet.contains(selectedItem.value.id) ||
        selectedItem.value.isFree;
    final isSelectedEquipped = equippedId == selectedItem.value.id;

    return AppModalSheet(
      heightFactor: 0.78,
      title: 'LOCKER ROOM',
      subtitle: 'CUSTOMIZE YOUR BALL & STREET GEAR',
      child: Column(
        children: [
          // 1. Interactive 3D/2D Visual Ball Preview Showcase
          _buildPreviewShowcase(selectedItem.value),
          const SizedBox(height: 20.0),

          // 2. Skin Selection Carousel / Cards
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'BALL SKINS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10.0),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: CosmeticCatalog.allBallSkins.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10.0),
              itemBuilder: (context, index) {
                final item = CosmeticCatalog.allBallSkins[index];
                final isItemUnlocked =
                    unlockedSet.contains(item.id) || item.isFree;
                final isItemEquipped = equippedId == item.id;
                final isItemSelected = selectedItem.value.id == item.id;

                return _buildSkinTile(
                  context: context,
                  item: item,
                  isUnlocked: isItemUnlocked,
                  isEquipped: isItemEquipped,
                  isSelected: isItemSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    selectedItem.value = item;
                  },
                );
              },
            ),
          ),

          // 3. Primary Bottom CTA Action Button
          const SizedBox(height: 14.0),
          _buildActionButton(
            context: context,
            item: selectedItem.value,
            isUnlocked: isSelectedUnlocked,
            isEquipped: isSelectedEquipped,
            isPurchasing: isPurchasing,
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }

  /// Big visual showcase banner previewing the selected ball and its authentic details.
  Widget _buildPreviewShowcase(CosmeticItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceTile,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: item.primaryColor.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: item.primaryColor.withValues(alpha: 0.18),
            blurRadius: 24.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Spherical preview badge
          Container(
            width: 72.0,
            height: 72.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                radius: 0.9,
                colors: [
                  item.primaryColor,
                  item.primaryColor.withValues(alpha: 0.75),
                  item.accentColor,
                ],
              ),
              border: Border.all(
                color: item.accentColor.withValues(alpha: 0.8),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Curved seam representation
                CustomPaint(
                  size: const Size(72, 72),
                  painter: _BallSeamPainter(seamColor: item.accentColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18.0),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.badge != null) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7.0,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: item.primaryColor.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: item.primaryColor.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          item.badge!,
                          style: TextStyle(
                            color: item.primaryColor,
                            fontSize: 9.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6.0),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.0,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Individual item tile in the gear list.
  Widget _buildSkinTile({
    required BuildContext context,
    required CosmeticItem item,
    required bool isUnlocked,
    required bool isEquipped,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor = isSelected
        ? AppColors.accentNeonCyan
        : (isEquipped
            ? AppColors.accentEmerald.withValues(alpha: 0.4)
            : AppColors.borderSubtle);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B2336) : AppColors.surfaceTile,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentNeonCyan.withValues(alpha: 0.16),
                    blurRadius: 12.0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Circular color preview dot
            Container(
              width: 38.0,
              height: 38.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: [item.primaryColor, item.accentColor],
                ),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentNeonCyan
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: CustomPaint(
                painter: _BallSeamPainter(seamColor: item.accentColor),
              ),
            ),
            const SizedBox(width: 14.0),

            // Item Name & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                      fontSize: 14.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    item.isFree ? 'FREE DEFAULT' : '₦${item.priceNaira}',
                    style: TextStyle(
                      color: item.isFree
                          ? AppColors.accentEmerald
                          : AppColors.accentAmber,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            if (isEquipped)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.accentEmerald.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppColors.accentEmerald.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13.0,
                      color: AppColors.accentEmerald,
                    ),
                    SizedBox(width: 4.0),
                    Text(
                      'EQUIPPED',
                      style: TextStyle(
                        color: AppColors.accentEmerald,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            else if (isUnlocked)
              const Icon(
                Icons.radio_button_unchecked_rounded,
                size: 20.0,
                color: AppColors.textSubtle,
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 13.0,
                      color: AppColors.accentAmber,
                    ),
                    SizedBox(width: 4.0),
                    Text(
                      'LOCKED',
                      style: TextStyle(
                        color: AppColors.accentAmber,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Context-aware action button (EQUIP / EQUIPPED / UNLOCK).
  Widget _buildActionButton({
    required BuildContext context,
    required CosmeticItem item,
    required bool isUnlocked,
    required bool isEquipped,
    required ValueNotifier<bool> isPurchasing,
  }) {
    // 1. Already equipped
    if (isEquipped) {
      return Container(
        width: double.infinity,
        height: 48.0,
        decoration: BoxDecoration(
          color: const Color(0x1822C55E),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: AppColors.accentEmerald.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: const Center(
          child: Text(
            'CURRENTLY EQUIPPED',
            style: TextStyle(
              color: AppColors.accentEmerald,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    // 2. Unlocked but not currently equipped -> EQUIP
    if (isUnlocked) {
      return SizedBox(
        width: double.infinity,
        height: 48.0,
        child: ElevatedButton(
          onTap: () {
            HapticFeedback.mediumImpact();
            InventoryService.instance.equipItem(item.id);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentNeonCyan,
            foregroundColor: AppColors.buttonDarkText,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
          child: const Text(
            'EQUIP BALL SKIN',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
      );
    }

    // 3. Locked -> UNLOCK THROUGH LAGOS LIFE (₦250)
    final isShopActive = InventoryService.instance.isShopVisible;

    if (!isShopActive) {
      return Container(
        width: double.infinity,
        height: 48.0,
        decoration: BoxDecoration(
          color: AppColors.surfaceTile,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        ),
        child: const Center(
          child: Text(
            'LAGOS LIFE EXCLUSIVE SKIN',
            style: TextStyle(
              color: AppColors.textSubtle,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          ),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.35),
              blurRadius: 14.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isPurchasing.value
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    isPurchasing.value = true;
                    try {
                      final purchaseId =
                          await InventoryService.instance.purchaseItem(item);
                      if (purchaseId != null && context.mounted) {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surfaceDialog,
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.accentEmerald,
                                  size: 18.0,
                                ),
                                const SizedBox(width: 10.0),
                                Text(
                                  '${item.name} unlocked & equipped!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } finally {
                      isPurchasing.value = false;
                    }
                  },
            borderRadius: BorderRadius.circular(16.0),
            child: Center(
              child: isPurchasing.value
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18.0,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'UNLOCK WITH LAGOS LIFE • ₦${item.priceNaira}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter to draw authentic basketball seam lines on circular preview badges.
class _BallSeamPainter extends CustomPainter {
  final Color seamColor;
  const _BallSeamPainter({required this.seamColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = seamColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Horizontal equator seam
    canvas.drawLine(
      Offset(center.dx - r + 2, center.dy),
      Offset(center.dx + r - 2, center.dy),
      paint,
    );

    // Vertical meridian seam
    canvas.drawLine(
      Offset(center.dx, center.dy - r + 2),
      Offset(center.dx, center.dy + r - 2),
      paint,
    );

    // Dynamic curved side ribs
    final path = Path();
    path.moveTo(center.dx - r * 0.7, center.dy - r * 0.7);
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx + r * 0.7,
      center.dy - r * 0.7,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BallSeamPainter oldDelegate) =>
      oldDelegate.seamColor != seamColor;
}
