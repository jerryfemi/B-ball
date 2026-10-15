import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/cosmetics/inventory_service.dart';
import '../common/app_colors.dart';
import 'locker_room_sheet.dart';

/// Reusable entry button for opening the Locker Room modal.
///
/// Automatically hides itself (`SizedBox.shrink()`) if the player is
/// not running inside Lagos Life and not in local debug mode.
class LockerRoomButton extends StatelessWidget {
  /// Whether to render as an expanded full-width banner button (for menus)
  /// or a compact pill (for footers and overlays).
  final bool isCompact;

  const LockerRoomButton({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!InventoryService.instance.isShopVisible) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            LockerRoomSheet.show(context);
          },
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
            decoration: BoxDecoration(
              color: const Color(0x22FACC15),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: const Color(0x66FACC15),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.checkroom_rounded,
                  size: 16.0,
                  color: Color(0xFFFACC15),
                ),
                SizedBox(width: 6.0),
                Text(
                  'LOCKER ROOM',
                  style: TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 46.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x180284C7),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: const Color(0x5538BDF8),
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              LockerRoomSheet.show(context);
            },
            borderRadius: BorderRadius.circular(16.0),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.checkroom_rounded,
                  size: 18.0,
                  color: AppColors.accentElectricSky,
                ),
                SizedBox(width: 8.0),
                Text(
                  'LOCKER ROOM • BALL SKINS',
                  style: TextStyle(
                    color: AppColors.accentElectricSky,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(width: 8.0),
                // Lagos Danfo Yellow dot accent
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFACC15),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 6.0, height: 6.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
