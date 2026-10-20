/// Native platform fallback for archery audio.
class ArcheryAudioImpl {
  void init() {}
  void unlock() {}
  void playDrawCreak() {}
  void playFullDrawClick() {}
  void playReleaseTwang() {}
  void playImpact({
    required double distance,
    required bool isX,
    required bool hitBoss,
    required bool hitGround,
  }) {}
  void dispose() {}
}

ArcheryAudioImpl createAudioImpl() => ArcheryAudioImpl();
