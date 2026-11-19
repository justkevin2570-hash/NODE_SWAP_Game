import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../online/leaderboard.dart';
import '../widgets/bubbly.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/pastel_background.dart';

/// 러시 최고 점수 랭킹 (Play 게임즈).
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

enum _Status { loading, ready, needSignIn, failed }

class _RankingScreenState extends ConsumerState<RankingScreen> {
  RankPeriod _period = RankPeriod.weekly;
  _Status _status = _Status.loading;
  List<RankEntry> _top = const [];
  RankEntry? _me;
  int _request = 0;

  LeaderboardService get _service => ref.read(leaderboardProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final req = ++_request;
    setState(() => _status = _Status.loading);
    if (!await _service.signIn()) {
      if (mounted && req == _request) {
        setState(() => _status = _Status.needSignIn);
      }
      return;
    }
    await ref.read(scoreUploaderProvider).flush();
    final top = await _service.top(_period);
    final me = await _service.me(_period);
    if (!mounted || req != _request) return;
    setState(() {
      _top = top ?? const [];
      _me = me;
      _status = top == null ? _Status.failed : _Status.ready;
    });
  }

  void _select(RankPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: PhoneColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('러시 랭킹', style: TextStyles.title),
                      ),
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Palette.butterDeep,
                        size: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PeriodTabs(selected: _period, onSelect: _select),
                  const SizedBox(height: 14),
                  Expanded(child: _body()),
                  if (_me != null && _status == _Status.ready) ...[
                    const SizedBox(height: 10),
                    _RankRow(entry: _me!, highlight: true, label: '내 순위'),
                  ],
                  const SizedBox(height: 12),
                  BubblyButton(
                    label: 'Google Play 게임즈에서 보기',
                    icon: Icons.open_in_new_rounded,
                    color: Palette.white,
                    deep: Palette.inkFaint,
                    width: double.infinity,
                    height: 50,
                    fontSize: 16,
                    onPressed: () => _service.showNative(_period),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _Status.loading:
        return const Center(
          child: CircularProgressIndicator(color: Palette.lavenderDeep),
        );
      case _Status.needSignIn:
        return _Message(
          icon: Icons.sports_esports_rounded,
          text: 'Google Play 게임즈에 로그인하면\n다른 사람들과 점수를 겨룰 수 있어요',
          button: '로그인',
          onPressed: _load,
        );
      case _Status.failed:
        return _Message(
          icon: Icons.wifi_off_rounded,
          text: '랭킹을 불러오지 못했어요\n인터넷 연결을 확인해 주세요',
          button: '다시 시도',
          onPressed: _load,
        );
      case _Status.ready:
        if (_top.isEmpty) {
          return _Message(
            icon: Icons.emoji_events_outlined,
            text: _period == RankPeriod.weekly
                ? '이번 주에는 아직 기록이 없어요\n첫 번째 주인공이 되어 보세요!'
                : '아직 기록이 없어요',
          );
        }
        return ListView.separated(
          itemCount: _top.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _RankRow(entry: _top[i], highlight: _top[i].isMe)
                  .animate(delay: (i * 30).ms)
                  .fadeIn(duration: 250.ms)
                  .slideX(begin: 0.08, curve: Curves.easeOut),
        );
    }
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});

  final RankPeriod selected;
  final ValueChanged<RankPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        children: [
          for (final p in RankPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: p == selected
                        ? Palette.lavender
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.label,
                    style: TextStyles.body.copyWith(
                      color: p == selected ? Palette.ink : Palette.inkSoft,
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

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, this.highlight = false, this.label});

  final RankEntry entry;
  final bool highlight;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final medal = switch (entry.rank) {
      1 => Palette.butterDeep,
      2 => const Color(0xFFB8B8C8),
      3 => Palette.peachDeep,
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? Palette.pink.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? Palette.pinkDeep.withValues(alpha: 0.6)
              : Colors.white,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal ?? Palette.mist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '${entry.rank}',
                  style: TextStyles.number.copyWith(
                    fontSize: 18,
                    color: medal != null ? Colors.white : Palette.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) Text(label!, style: TextStyles.caption),
                // 플레이어 이름은 어떤 글자든 올 수 있어서 앱 글꼴(필요한 글자만 남긴 Jua) 대신
                // 기기 기본 글꼴로 그린다. 이름 안에서 글꼴이 섞이지 않게.
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    color: Palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            RollingNumber.formatInt(entry.score),
            style: TextStyles.number.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.button,
    this.onPressed,
  });

  final IconData icon;
  final String text;
  final String? button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Palette.inkFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyles.body.copyWith(
              color: Palette.inkSoft,
              height: 1.5,
            ),
          ),
          if (button != null) ...[
            const SizedBox(height: 18),
            BubblyButton(
              label: button!,
              color: Palette.lavender,
              deep: Palette.lavenderDeep,
              width: 180,
              height: 50,
              fontSize: 18,
              onPressed: onPressed,
            ),
          ],
        ],
      ),
    );
  }
}
