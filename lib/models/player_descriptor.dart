/// Core identity interface representing any participant in the B-Ball system.
///
/// Unifies local user profiles, remote cloud players, friends, and active match participants
/// under a single contract.
abstract interface class PlayerDescriptor {
  /// Unique identifier (e.g. Firebase Auth UID or local session ID).
  String get id;

  /// User-visible gamer tag or display name.
  String get displayName;

  /// Asset path or identifier for the player's avatar.
  String get avatar;

  /// Canonical default avatar asset path across the entire application.
  static const String defaultAvatar = 'assets/avatars/dunk_heads (1).webp';
}
