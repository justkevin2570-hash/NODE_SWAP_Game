import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/game_state.dart';
import '../../game/logic/rules.dart';
import '../widgets/bubbly.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/particles.dart';
import '../widgets/pastel_background.dart';
import 'game_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.session});

  final GameSession session;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _particles = GlobalKey<ParticleFieldState>();
  int _shownStars = 0;

  GameSession get s => widget.session;
  bool get _good => s.mode == GameMode.rush ? s.cleared > 0 : s.won;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      audio.setMusic(Music.menu, fade: const Duration(milliseconds: 1200));
      if (s.newRecord || (s.mode == GameMode.classic && s.won)) {
        audio.play(Sfx.fanfare);
      }
      if (s.newRecord) {
        _particles.currentState?.confetti(count: 110);
        audio.haptic(HapticKind.heavy);
      }
      // 별을 하나씩 띄운다
      for (int i = 0; i < s.stars; i++) {
        await Future.delayed(Duration(milliseconds: i == 0 ? 700 : 380));
        if (!mounted) return;
        setState(() => _shownStars = i + 1);
        audio.play(Sfx.star(i));
        audio.haptic(HapticKind.light);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    final best = s.mode == GameMode.rush ? records.rushBestScore : (records.classicBest[s.difficulty] ?? 0);
    final title = switch (s.mode) {
      GameMode.rush => s.newRecord ? '신기록!' : (s.expired ? '게임 종료' : 'TIME UP!'),
      GameMode.classic => s.won ? 'CLEAR!' : '아쉬워요!',
    };
    final titleColor = s.newRecord
        ? Palette.pinkDeep
        : _good
            ? Palette.lavenderDeep
            : Palette.peachDeep;

    return Scaffold(
      body: PastelBackground(
        tint: s.newRecord ? Palette.butter : null,
        child: ParticleField(
          key: _particles,
          child: SafeArea(
            child: PhoneColumn(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const Spacer(),
                    Text(
                      s.mode == GameMode.rush ? '러시 모드' : '클래식 | ${s.difficulty.label}',
                      style: TextStyles.caption.copyWith(fontSize: 16),
                    ).animate().fadeIn(),
                    const SizedBox(height: 8),
                    Text(title, style: TextStyles.display.copyWith(fontSize: 60, color: titleColor))
                        .animate()
                        .scaleXY(begin: 0.3, duration: 700.ms, curve: Curves.elasticOut)
                        .fadeIn(duration: 200.ms),
                    const SizedBox(height: 18),
                    if (s.mode == GameMode.classic && s.won) ...[
                      _Stars(shown: _shownStars),
                      const SizedBox(height: 16),
                    ],
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      child: Column(
                        children: [
                          Text('SCORE', style: TextStyles.caption),
                          RollingNumber(
                            value: s.score,
                            duration: const Duration(milliseconds: 1400),
                            style: TextStyles.number.copyWith(fontSize: 56, color: Palette.ink),
                          ),
                          if (s.newRecord)
                            Pill(
                              color: Palette.butter,
                              child: Text('★ 최고 기록 갱신 ★',
                                  style: TextStyles.body.copyWith(color: Palette.ink)),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleXY(end: 1.08, duration: 600.ms),
                          const SizedBox(height: 18),
                          Row(
                            children: _stats(best),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),
                    const Spacer(),
                    ..._playButtons(context),
                    const SizedBox(height: 14),
                    BubblyButton(
                      label: '홈으로',
                      icon: Icons.home_rounded,
                      color: Palette.white,
                      deep: Palette.inkFaint,
                      width: double.infinity,
                      height: 54,
                      fontSize: 19,
                      onPressed: () => Navigator.of(context).pop(),
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.4),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _go(Widget page) => Navigator.of(context).pushReplacement(softRoute(page));

  /// 다시 하기 버튼들.
  /// - 러시: 한 번 더
  /// - 클래식 클리어: [다음 퍼즐] 크게, [같은 퍼즐 다시] 작게 (별을 더 받고 싶을 때)
  /// - 클래식 실패: [같은 퍼즐 다시] 크게, [새 퍼즐] 작게
  List<Widget> _playButtons(BuildContext context) {
    Widget big(String label, IconData icon, VoidCallback onTap) => BubblyButton(
          label: label,
          icon: icon,
          color: Palette.pink,
          deep: Palette.pinkDeep,
          width: double.infinity,
          height: 66,
          fontSize: 24,
          glow: true,
          onPressed: onTap,
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.4);
    Widget small(String label, IconData icon, VoidCallback onTap) => BubblyButton(
          label: label,
          icon: icon,
          color: Palette.sky,
          deep: Palette.skyDeep,
          width: double.infinity,
          height: 54,
          fontSize: 19,
          onPressed: onTap,
        ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.4);

    void samePuzzle() => _go(GameScreen(mode: s.mode, difficulty: s.difficulty, puzzle: s.puzzle));
    void newPuzzle() => _go(GameScreen(mode: s.mode, difficulty: s.difficulty));

    if (s.mode == GameMode.rush) {
      return [big('한 번 더!', Icons.replay_rounded, newPuzzle)];
    }
    if (s.won) {
      return [
        big('다음 퍼즐', Icons.arrow_forward_rounded, newPuzzle),
        const SizedBox(height: 12),
        small('같은 퍼즐 다시', Icons.replay_rounded, samePuzzle),
      ];
    }
    return [
      big('같은 퍼즐 다시', Icons.replay_rounded, samePuzzle),
      const SizedBox(height: 12),
      small('새 퍼즐', Icons.refresh_rounded, newPuzzle),
    ];
  }

  List<Widget> _stats(int best) {
    final items = s.mode == GameMode.rush
        ? [
            ('푼 퍼즐', '${s.cleared}', Palette.mintDeep),
            ('최대 콤보', '${s.maxCombo}', Palette.pinkDeep),
            ('최고 기록', RollingNumber.formatInt(best), Palette.lavenderDeep),
          ]
        : [
            ('이동', s.won ? '${s.movesUsed} / 최소 ${s.puzzle.par}' : '-', Palette.mintDeep),
            ('남은 시간', s.won ? '${(s.remainingMs / 1000).ceil()}초' : '-', Palette.skyDeep),
            ('최고 기록', RollingNumber.formatInt(best), Palette.lavenderDeep),
          ];
    return [
      for (final (label, value, color) in items)
        Expanded(
          child: Column(
            children: [
              Text(value, style: TextStyles.number.copyWith(fontSize: 20, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyles.caption),
            ],
          ),
        ),
    ];
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.shown});

  final int shown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0, left: 4, right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                child: RotationTransition(turns: Tween(begin: -0.2, end: 0.0).animate(a), child: child),
              ),
              child: Icon(
                Icons.star_rounded,
                key: ValueKey(i < shown),
                size: i == 1 ? 76 : 60,
                color: i < shown ? Palette.butterDeep : Palette.inkFaint.withValues(alpha: 0.5),
                shadows: i < shown
                    ? [Shadow(color: Palette.butterDeep.withValues(alpha: 0.6), blurRadius: 18)]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
