import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_state_provider.dart';
import '../models/game_state.dart';

class ComboFlashWidget extends ConsumerStatefulWidget {
  const ComboFlashWidget({super.key});

  @override
  ConsumerState<ComboFlashWidget> createState() => _ComboFlashWidgetState();
}

class _ComboFlashWidgetState extends ConsumerState<ComboFlashWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  int _displayedCombo = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 2),
    ]).animate(_controller);
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _comboColor(int combo) {
    if (combo >= 5) return Colors.purple;
    if (combo >= 4) return Colors.deepOrange;
    if (combo >= 3) return Colors.orange;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameStateProvider, (prev, next) {
      if (next.comboCount >= 2 &&
          next.comboCount != (prev?.comboCount ?? 0) &&
          next.phase == GamePhase.playing) {
        _displayedCombo = next.comboCount;
        _controller.forward(from: 0);
      }
    });

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context2, child2) {
          if (_controller.value == 0) return const SizedBox.shrink();
          return Stack(
            children: [
              // 전화면 컬러 오버레이
              Positioned.fill(
                child: Container(
                  color: _comboColor(_displayedCombo)
                      .withValues(alpha: _fadeAnim.value),
                ),
              ),
              // 콤보 텍스트
              Center(
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Opacity(
                    opacity: (_fadeAnim.value * 4).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _displayedCombo >= 5
                            ? 'MAX COMBO x$_displayedCombo!'
                            : 'COMBO x$_displayedCombo',
                        style: TextStyle(
                          color: _comboColor(_displayedCombo),
                          fontSize: _displayedCombo >= 5 ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
