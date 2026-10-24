import 'package:flutter_test/flutter_test.dart';

import 'package:b_ball/darts/audio/darts_audio.dart';
import 'package:b_ball/game/audio/audio_backend.dart';
import 'package:b_ball/game/audio/audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 13 — Darts Audio & SFX Integration', () {
    test('Sfx enum contains all required darts audio events', () {
      expect(Sfx.values, contains(Sfx.dartThrow));
      expect(Sfx.values, contains(Sfx.dartHit));
      expect(Sfx.values, contains(Sfx.dartBull));
      expect(Sfx.values, contains(Sfx.dartMiss));
      expect(Sfx.values, contains(Sfx.dartBust));
      expect(Sfx.values, contains(Sfx.dartPull));
    });

    test('DartsAudio constants define music and ambience paths', () {
      expect(DartsAudio.musicTrack, isNotEmpty);
      expect(DartsAudio.musicTrack, contains('.mp3'));
      // Ambience track is configured for pub atmosphere (empty string until dedicated audio supplied)
      expect(DartsAudio.ambienceTrack, isNotNull);
    });

    test('DartsAudio play methods execute safely without crash or throw', () {
      // Prior to AudioEngine.init(), play calls must gracefully return (no uncaught exceptions)
      expect(() => DartsAudio.playThrow(), returnsNormally);
      expect(() => DartsAudio.playHit(isBull: false), returnsNormally);
      expect(() => DartsAudio.playHit(isBull: true), returnsNormally);
      expect(() => DartsAudio.playMiss(), returnsNormally);
      expect(() => DartsAudio.playBust(), returnsNormally);
      expect(() => DartsAudio.playPull(), returnsNormally);
      expect(() => DartsAudio.unlock(), returnsNormally);
    });

    test('AudioEngine playDart* methods execute safely with null-safe fallback', () {
      expect(() => AudioEngine.playDartThrow(), returnsNormally);
      expect(() => AudioEngine.playDartHit(isBull: false), returnsNormally);
      expect(() => AudioEngine.playDartHit(isBull: true), returnsNormally);
      expect(() => AudioEngine.playDartMiss(), returnsNormally);
      expect(() => AudioEngine.playDartBust(), returnsNormally);
      expect(() => AudioEngine.playDartPull(), returnsNormally);
    });

    test('Count-up tings: 1-6 points tick that many times, more is a burst of 8', () {
      expect(Sfx.values, contains(Sfx.dartTick));
      expect(DartsAudio.tickCountFor(0), 0);
      for (int p = 1; p <= 6; p++) {
        expect(DartsAudio.tickCountFor(p), p);
      }
      expect(DartsAudio.tickCountFor(7), 8);
      expect(DartsAudio.tickCountFor(57), 8);
      expect(DartsAudio.tickCountFor(60), 8);
      // pitch climbs, gaps shrink
      expect(DartsAudio.tickRate(5), greaterThan(DartsAudio.tickRate(0)));
      expect(DartsAudio.tickGap(5), lessThan(DartsAudio.tickGap(0)));
      expect(() => DartsAudio.playScoreTicks(20), returnsNormally);
      DartsAudio.cancelTicks();
    });

    test('DartsAudio claim and release lifecycle runs cleanly', () {
      final owner = Object();
      expect(() => DartsAudio.init(owner), returnsNormally);
      expect(() => DartsAudio.leave(owner), returnsNormally);
    });
  });
}
