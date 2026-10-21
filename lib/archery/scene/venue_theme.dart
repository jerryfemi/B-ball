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

  /// If true, [z] is relative to the 50 ft target and the object moves back
  /// with the target for longer sets (see BillboardRenderer.setTargetDistance).
  final bool followTarget;

  const BillboardSpec({
    required this.imageKey,
    required this.x,
    this.baseY = 0.0,
    required this.z,
    required this.widthMeters,
    this.flipX = false,
    this.castShadow = true,
    this.shadowScale = 1.6,
    this.followTarget = false,
  });
}

/// Target style configuration for different venues.
enum TargetStyle { standardWorldArchery, kyudoDojo }

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
  static VenueTheme createParkTheme({
    double targetDistance = ArcheryK.distanceM,
  }) {
    final double D = targetDistance;

    // Trees behind the target are placed relative to it (followTarget) so the
    // backdrop moves back with the target for the 100 ft and 150 ft sets.
    // Lane trees are fixed and run the full 150 ft so longer sets stay framed.
    final billboards = <BillboardSpec>[
      // Distant hills strip
      const BillboardSpec(
        imageKey: 'hills',
        x: 0.0,
        z: 60.0,
        widthMeters: 140.0,
        castShadow: false,
      ),

      // Behind the target (z relative to the target)
      BillboardSpec(imageKey: 'tree_2', x: -2.6, z: D + 5.0, widthMeters: 5.5, flipX: true, followTarget: true),
      BillboardSpec(imageKey: 'tree_3', x: 2.9, z: D + 6.0, widthMeters: 6.0, followTarget: true),
      BillboardSpec(imageKey: 'tree_1', x: -6.0, z: D + 9.0, widthMeters: 7.5, followTarget: true),
      BillboardSpec(imageKey: 'tree_1', x: 6.4, z: D + 8.0, widthMeters: 7.2, flipX: true, followTarget: true),
      BillboardSpec(imageKey: 'tree_3', x: 0.4, z: D + 13.0, widthMeters: 7.0, followTarget: true),
      BillboardSpec(imageKey: 'tree_2', x: -9.5, z: D + 12.0, widthMeters: 6.5, followTarget: true),
      BillboardSpec(imageKey: 'tree_3', x: 9.8, z: D + 11.0, widthMeters: 7.0, flipX: true, followTarget: true),

      // Left side of the lane (fixed)
      const BillboardSpec(imageKey: 'tree_1', x: -3.3, z: 7.0, widthMeters: 4.8),
      const BillboardSpec(imageKey: 'tree_2', x: -4.0, z: 12.0, widthMeters: 5.8, flipX: true),
      const BillboardSpec(imageKey: 'tree_3', x: -3.8, z: 19.0, widthMeters: 6.0),
      const BillboardSpec(imageKey: 'tree_1', x: -4.4, z: 27.0, widthMeters: 6.5, flipX: true),
      const BillboardSpec(imageKey: 'tree_3', x: -4.2, z: 36.0, widthMeters: 6.6),
      const BillboardSpec(imageKey: 'tree_2', x: -4.8, z: 44.0, widthMeters: 7.0, flipX: true),

      // Right side of the lane (fixed)
      const BillboardSpec(imageKey: 'tree_3', x: 3.4, z: 8.0, widthMeters: 5.0, flipX: true),
      const BillboardSpec(imageKey: 'tree_1', x: 4.1, z: 13.5, widthMeters: 5.6),
      const BillboardSpec(imageKey: 'tree_2', x: 3.9, z: 21.0, widthMeters: 6.2, flipX: true),
      const BillboardSpec(imageKey: 'tree_3', x: 4.5, z: 29.0, widthMeters: 6.4),
      const BillboardSpec(imageKey: 'tree_1', x: 4.3, z: 38.0, widthMeters: 6.8, flipX: true),
      const BillboardSpec(imageKey: 'tree_2', x: 4.9, z: 46.0, widthMeters: 7.0),
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
