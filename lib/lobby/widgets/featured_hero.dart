import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../game_catalog.dart';
import '../lobby_style.dart';
import 'pressable.dart';

/// The banner at the top of the lobby: one slide per game, featured game
/// first. Swipe (or drag with a mouse) to move between them; it also moves
/// on by itself, staying longer on the featured game.
///
/// Auto-advance stops while the pointer is over it, after a swipe or tap
/// (it waits longer before moving again), when the tab is in the
/// background, and entirely when the device asks for reduced motion.
class HeroCarousel extends HookWidget {
  final List<LobbyGame> games;
  final ValueChanged<LobbyGame> onPlay;

  /// "Challenge a friend" on the featured slide; null hides it.
  final VoidCallback? onChallenge;

  const HeroCarousel({
    super.key,
    required this.games,
    required this.onPlay,
    this.onChallenge,
  });

  static const Duration _featuredDwell = Duration(seconds: 9);
  static const Duration _dwell = Duration(seconds: 6);
  static const Duration _afterTouch = Duration(seconds: 12);
  static const Duration _slide = Duration(milliseconds: 650);

  /// The page view is "endless": it starts far from page 0 and wraps by
  /// index, so the last slide moves forward to the first.
  static const int _loopStart = 3000;

  @override
  Widget build(BuildContext context) {
    final int n = games.length;
    final int start = n * (_loopStart ~/ n);
    final controller = usePageController(initialPage: start);
    final page = useState(start);
    final touched = useState(0); // bumps on every touch: restarts the wait
    final hovering = useState(false);
    final lifecycle = useAppLifecycleState();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final bool auto = n > 1 &&
        !reduceMotion &&
        !hovering.value &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);

    // Decode every slide's art up front so a slide never appears blank.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        for (final g in games) {
          precacheImage(AssetImage(g.heroImage), context);
          if (g.heroImageNarrow != g.heroImage) {
            precacheImage(AssetImage(g.heroImageNarrow), context);
          }
        }
      });
      return null;
    }, const []);

    useEffect(() {
      if (!auto) return null;
      final bool onFeatured = page.value % n == 0;
      final Duration wait = touched.value > 0
          ? _afterTouch
          : (onFeatured ? _featuredDwell : _dwell);
      final timer = Timer(wait, () {
        if (!controller.hasClients) return;
        touched.value = 0;
        controller.animateToPage(
          page.value + 1,
          duration: _slide,
          curve: Curves.easeInOutCubic,
        );
      });
      return timer.cancel;
    }, [auto, page.value, touched.value]);

    void goTo(int index) {
      final int current = page.value;
      final int target = current + (index - current % n);
      touched.value++;
      controller.animateToPage(target, duration: _slide, curve: Curves.easeInOutCubic);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final bool narrow = w < 600;
        final double radius = narrow ? 24 : 28;
        // Scales with the window between sensible limits.
        final double height = narrow
            ? (w * 1.42).clamp(460.0, 580.0)
            : (w * 0.38).clamp(360.0, 460.0);
        final double titleSize = narrow ? 54 : (w * 0.068).clamp(56.0, 76.0);

        return MouseRegion(
          onEnter: (_) => hovering.value = true,
          onExit: (_) => hovering.value = false,
          child: Listener(
            onPointerDown: (_) => touched.value++,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ScrollConfiguration(
                      behavior: const _DragAnything(),
                      child: PageView.builder(
                        controller: controller,
                        onPageChanged: (p) => page.value = p,
                        itemBuilder: (context, p) {
                          final g = games[p % n];
                          return _HeroSlide(
                            game: g,
                            narrow: narrow,
                            titleSize: titleSize,
                            onPlay: () => onPlay(g),
                            onChallenge: g.featured ? onChallenge : null,
                          );
                        },
                      ),
                    ),
                    // Hairline edge so the banner reads as a surface.
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(color: const Color(0x17FFFFFF)),
                        ),
                      ),
                    ),
                    if (n > 1)
                      Positioned(
                        right: narrow ? 14 : 28,
                        top: narrow ? 14 : null,
                        bottom: narrow ? null : 28,
                        child: _Dots(
                          games: games,
                          active: page.value % n,
                          onTap: goTo,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lets a mouse or trackpad drag the banner too (Flutter web only drags
/// pages with touch by default).
class _DragAnything extends MaterialScrollBehavior {
  const _DragAnything();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// One pill per slide; the current one is long and in that game's colour.
class _Dots extends StatelessWidget {
  final List<LobbyGame> games;
  final int active;
  final ValueChanged<int> onTap;

  const _Dots({required this.games, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x590A0E1A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < games.length; i++)
            Semantics(
              button: true,
              selected: i == active,
              label: 'Show ${games[i].title}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: i == active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == active ? games[i].accent : const Color(0x66FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One game's slide. Wide screens: text on the left over a dark side fade.
/// Phones: a tall poster with the text at the bottom.
class _HeroSlide extends StatelessWidget {
  final LobbyGame game;
  final bool narrow;
  final double titleSize;
  final VoidCallback onPlay;
  final VoidCallback? onChallenge;

  const _HeroSlide({
    required this.game,
    required this.narrow,
    required this.titleSize,
    required this.onPlay,
    required this.onChallenge,
  });

  static const LinearGradient _sideFade = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xF00A0E1A), Color(0xB30A0E1A), Color(0x000A0E1A)],
    stops: [0.0, 0.34, 0.62],
  );
  static const LinearGradient _bottomShade = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0x990A0E1A), Color(0x000A0E1A)],
    stops: [0.0, 0.4],
  );
  static const LinearGradient _posterFade = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xF70A0E1A), Color(0xBF0A0E1A), Color(0x000A0E1A)],
    stops: [0.0, 0.42, 0.72],
  );

  /// Greys out games that aren't playable yet.
  static const ColorFilter _dim = ColorFilter.matrix(<double>[
    0.45, 0.35, 0.05, 0, -14, //
    0.15, 0.65, 0.05, 0, -14,
    0.15, 0.35, 0.35, 0, -14,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final g = game;
    Widget art = Image.asset(
      narrow ? g.heroImageNarrow : g.heroImage,
      fit: BoxFit.cover,
      alignment: narrow ? g.heroAlignmentNarrow : g.heroAlignment,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (!g.available) art = ColorFiltered(colorFilter: _dim, child: art);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: LobbyStyle.ink, child: art),
        if (narrow)
          const DecoratedBox(decoration: BoxDecoration(gradient: _posterFade))
        else ...const [
          DecoratedBox(decoration: BoxDecoration(gradient: _sideFade)),
          DecoratedBox(decoration: BoxDecoration(gradient: _bottomShade)),
        ],
        Positioned(
          left: narrow ? 22 : 48,
          right: narrow ? 22 : null,
          bottom: narrow ? 24 : 44,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (g.heroLabel.isNotEmpty) ...[
                  Text(
                    g.heroLabel,
                    style: LobbyStyle.text(
                      size: 14,
                      weight: 600,
                      color: g.available ? g.accent : LobbyStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  g.title,
                  style: LobbyStyle.display(
                    titleSize,
                    color: g.available ? Colors.white : const Color(0xCCFFFFFF),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  g.pitch,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: LobbyStyle.text(
                    size: narrow ? 16 : 17,
                    color: LobbyStyle.soft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (g.available)
                      LobbyPillButton(
                        label: 'Play',
                        accent: g.accent,
                        showPlayIcon: true,
                        style: LobbyStyle.button,
                        onTap: onPlay,
                      )
                    else
                      LobbyPillButton(
                        label: 'Take a look',
                        style: LobbyStyle.text(size: 15, weight: 600),
                        onTap: onPlay,
                      ),
                    if (g.available && onChallenge != null)
                      LobbyPillButton(
                        label: 'Challenge a friend',
                        style: LobbyStyle.text(size: 15, weight: 600),
                        onTap: onChallenge!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
