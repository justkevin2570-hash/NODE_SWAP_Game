import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/logic/rules.dart';
import '../widgets/bubbly.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';

Future<T?> _showGlassSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.ink.withValues(alpha: 0.25),
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: PhoneColumn(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: GlassCard(
            opacity: 0.9,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Palette.inkFaint, borderRadius: BorderRadius.circular(4)),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ── 클래식 난이도 선택 ──────────────────────────────────────────
Future<Difficulty?> showClassicSheet(BuildContext context) =>
    _showGlassSheet<Difficulty>(context, const _ClassicSheet());

class _ClassicSheet extends ConsumerWidget {
  const _ClassicSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final rows = [
      (Difficulty.easy, Palette.mint, Palette.mintDeep, '여유 이동 +2 · 90초'),
      (Difficulty.normal, Palette.sky, Palette.skyDeep, '여유 이동 +1 · 60초'),
      (Difficulty.hard, Palette.pink, Palette.pinkDeep, '최소 이동만 · 45초'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('클래식 모드', style: TextStyles.title),
        const SizedBox(height: 4),
        Text('한 판씩 차분하게, 최소 이동에 도전!', style: TextStyles.caption.copyWith(fontSize: 15)),
        const SizedBox(height: 18),
        for (final (d, light, deep, desc) in rows) ...[
          BubblyButton(
            label: d.label,
            subtitle: desc,
            color: light,
            deep: deep,
            width: double.infinity,
            height: 70,
            fontSize: 24,
            onPressed: () => Navigator.of(context).pop(d),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Icon(Icons.star_rounded,
                      size: 18,
                      color: i < (records.classicStars[d] ?? 0) ? Palette.butterDeep : Palette.inkFaint),
                const SizedBox(width: 8),
                Text('최고 ${RollingNumber.formatInt(records.classicBest[d] ?? 0)}점', style: TextStyles.caption),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── 설정 ──────────────────────────────────────────────────────
Future<void> showSettingsSheet(BuildContext context) => _showGlassSheet<void>(context, const _SettingsSheet());

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final audio = ref.read(audioProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('설정', style: TextStyles.title),
        const SizedBox(height: 16),
        _SliderRow(
          icon: Icons.music_note_rounded,
          label: '배경음악',
          value: s.musicVolume,
          onChanged: n.setMusicVolume,
        ),
        _SliderRow(
          icon: Icons.volume_up_rounded,
          label: '효과음',
          value: s.sfxVolume,
          onChanged: n.setSfxVolume,
          onChangeEnd: (_) => audio.play(Sfx.match3),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.vibration_rounded, color: Palette.inkSoft),
              const SizedBox(width: 10),
              const Text('진동', style: TextStyles.body),
              const Spacer(),
              Switch(
                value: s.haptics,
                onChanged: (v) {
                  n.setHaptics(v);
                  if (v) audio.haptic(HapticKind.medium);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BubblyButton(
          label: '기록 초기화',
          icon: Icons.delete_outline_rounded,
          color: Palette.white,
          deep: Palette.inkFaint,
          height: 48,
          fontSize: 17,
          width: double.infinity,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Palette.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Text('기록을 지울까요?', style: TextStyles.title),
                content: const Text('최고 점수와 별 기록이 모두 사라져요.', style: TextStyles.body),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기')),
                ],
              ),
            );
            if (ok == true) ref.read(recordsProvider.notifier).reset();
          },
        ),
        const SizedBox(height: 14),
        Text('음악과 효과음은 모두 직접 합성한 오리지널 사운드예요.',
            textAlign: TextAlign.center, style: TextStyles.caption.copyWith(fontSize: 12)),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Palette.inkSoft),
        const SizedBox(width: 10),
        SizedBox(width: 70, child: Text(label, style: TextStyles.body)),
        Expanded(child: Slider(value: value, onChanged: onChanged, onChangeEnd: onChangeEnd)),
        SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}', textAlign: TextAlign.right, style: TextStyles.caption),
        ),
      ],
    );
  }
}
