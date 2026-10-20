import 'package:flutter/material.dart';
import '../archery_constants.dart';

/// Specification for a single billboard object in 3D world space.
class BillboardSpec {
  /// Asset identifier/key (e.g. 'hills', 'hedge', 'tree_1', 'tree_2', 'tree_3').
  final String imageKey;

  /// World X coordinate in meters (0 = center line).
  final double x;

  /// World Y coordinate of the base on the ground (usually 0.0).
  final double baseY;

  /// World Z coordinate in meters downrange.
  final double z;

  /// Physical width in meters in the world.
  final double widthMeters;

  /// Whether to horizontally flip the sprite for visual variety.
  final bool flipX;

  /// Whether this object casts a ground contact shadow.
  final bool castShadow;

  /// Optional shadow scale multiplier relative to width.
  final double shadowScale;

  const BillboardSpec({
    required this.imageKey,
    required this.x,
    this.baseY = 0.0,
    required this.z,
    required this.widthMeters,
    this.flipX = false,
    this.castShadow = true,
    this.shadowScale = 1.6,
  });
}

/// Target style configuration for different venues.
enum TargetStyle {
  standardWorldArchery,
  kyudoDojo,
}

/// Complete environment description for an archery venue.
class VenueTheme {
  final String name;
  final String skyImage;
  final String grassDetailImage;
  final String shadowBlobImage;
  final Map<String, String> billboardImages;
  final List<BillboardSpec> billboards;
  final Color grassA;
  final Color grassB;
  final Color haze;
  final double hazeDist;
  final double stripeLen;
  final bool laneLines;
  final TargetStyle targetStyle;

  const VenueTheme({
    required this.name,
    required this.skyImage,
    required this.grassDetailImage,
    required this.shadowBlobImage,
    required this.billboardImages,
    required this.billboards,
    required this.grassA,
    required this.grassB,
    required this.haze,
    this.hazeDist = 45.0,
    this.stripeLen = 2.0,
    this.laneLines = true,
    this.targetStyle = TargetStyle.standardWorldArchery,
  });

  /// The standard daytime Park venue matching GamePigeon archery.
  static VenueTheme createParkTheme({double targetDistance = ArcheryK.distanceM}) {
    final double D = targetDistance;

    final billboards = <BillboardSpec>[
      // 1. Distant hills & mountain tree-mass strip at z ≈ 60m
      const BillboardSpec(
        imageKey: 'hills',
        x: 0.0,
        baseY: 0.0,
        z: 60.0,
        widthMeters: 140.0,
        castShadow: false,
      ),

      // 2. Hedge row behind target at z ≈ D + 4 (19.2m)
      BillboardSpec(
        imageKey: 'hedge',
        x: 0.0,
        baseY: 0.0,
        z: D + 4.2,
        widthMeters: 36.0,
        castShadow: false,
      ),

      // 3. Tree line behind target (z = D + 6 ... D + 16)
      BillboardSpec(imageKey: 'tree_1', x: -8.5, baseY: 0.0, z: D + 12.0, widthMeters: 8.5),
      BillboardSpec(imageKey: 'tree_2', x: -4.5, baseY: 0.0, z: D + 8.5, widthMeters: 6.8, flipX: true),
      BillboardSpec(imageKey: 'tree_3', x: -1.8, baseY: 0.0, z: D + 14.0, widthMeters: 7.2),
      BillboardSpec(imageKey: 'tree_1', x: 2.2, baseY: 0.0, z: D + 15.0, widthMeters: 8.0, flipX: true),
      BillboardSpec(imageKey: 'tree_2', x: 5.2, baseY: 0.0, z: D + 9.0, widthMeters: 7.0),
      BillboardSpec(imageKey: 'tree_3', x: 9.0, baseY: 0.0, z: D + 13.0, widthMeters: 7.8),

      // 4. Side trees along the lane (left side: x = -5.5 to -8.5, z = 3 to D + 3)
      const BillboardSpec(imageKey: 'tree_1', x: -5.8, baseY: 0.0, z: 3.2, widthMeters: 6.2),
      const BillboardSpec(imageKey: 'tree_2', x: -6.5, baseY: 0.0, z: 7.5, widthMeters: 5.8, flipX: true),
      BillboardSpec(imageKey: 'tree_3', x: -6.0, baseY: 0.0, z: 12.0, widthMeters: 6.5),
      BillboardSpec(imageKey: 'tree_1', x: -7.2, baseY: 0.0, z: D + 2.5, widthMeters: 7.0),

      // 5. Side trees along the lane (right side: x = +5.5 to +8.5, z = 4 to D + 3)
      const BillboardSpec(imageKey: 'tree_3', x: 6.2, baseY: 0.0, z: 4.5, widthMeters: 6.0, flipX: true),
      const BillboardSpec(imageKey: 'tree_1', x: 7.0, baseY: 0.0, z: 9.0, widthMeters: 6.8),
      BillboardSpec(imageKey: 'tree_2', x: 6.2, baseY: 0.0, z: 13.5, widthMeters: 5.6),
      BillboardSpec(imageKey: 'tree_3', x: 7.5, baseY: 0.0, z: D + 3.0, widthMeters: 6.6, flipX: true),
    ];

    // Sort back-to-front by Z descending for proper painter's algorithm rendering
    billboards.sort((a, b) => b.z.compareTo(a.z));

    return VenueTheme(
      name: 'Park',
      skyImage: 'assets/archery/park/sky_mountains.webp',
      grassDetailImage: 'assets/archery/park/grass_detail.webp',
      shadowBlobImage: 'assets/archery/shadow_blob.webp',
      billboardImages: const {
        'hills': 'assets/archery/park/hills.webp',
        'hedge': 'assets/archery/park/hedge.webp',
        'tree_1': 'assets/archery/park/tree_1.webp',
        'tree_2': 'assets/archery/park/tree_2.webp',
        'tree_3': 'assets/archery/park/tree_3.webp',
      },
      billboards: billboards,
      grassA: const Color(0xFF4E9A2E),
      grassB: const Color(0xFF3F8424),
      haze: const Color(0xFFBFD7E6),
      hazeDist: 45.0,
      stripeLen: 2.0,
      laneLines: true,
      targetStyle: TargetStyle.standardWorldArchery,
    );
  }
}
