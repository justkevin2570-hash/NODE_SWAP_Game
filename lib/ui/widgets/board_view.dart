import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_state.dart';
import '../../game/logic/board.dart';
import '../../game/logic/symmetry.dart';
import 'tile_view.dart';

/// 5×5 보드. 탭-탭 또는 드래그로 인접 타일을 바꾼다.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.tileIds,
    required this.target,
    required this.size,
    required this.onTapCell,
    required this.onSwap,
    this.selected,
    this.pairCell,
    this.hint,
    this.rotations = 0,
    this.enabled = true,
    this.dimmed = false,
    this.hideTiles = false,
  });

  final Board board;
  final List<int> tileIds;
  final SymmetryType target;
  final double size;
  final int? selected;

  /// 선택한 타일의 대칭 짝 칸 (표시만 함).
  final int? pairCell;
  final Hint? hint;
  final int rotations;
  final bool enabled;
  final bool dimmed;
  final bool hideTiles;
  final ValueChanged<int> onTapCell;
  final void Function(int a, int b) onSwap;

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  static const _padding = 12.0;
  static const _gap = 7.0;

  late final _rotate = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  int _seenRotations = 0;
  bool _instantLayout = false;
  final Map<int, int> _bump = {};
  final Map<int, int> _pulse = {};
  final Map<int, int> _nudge = {};
  int _celebrate = 0;
  final Set<int> _seenIds = {};

  int? _dragCell;
  Offset _dragDelta = Offset.zero;
  bool _dragUsed = false;

  /// 실제로 그려지는 보드 크기. 부모가 [BoardView.size] 보다 좁은 공간을 주면 그 크기에 맞춘다.
  /// (요청 크기와 실제 크기가 다르면 타일 격자와 대칭축의 중심이 어긋난다.)
  double _size = 0;

  double get _cell => (_size - _padding * 2 - _gap * 4) / 5;

  @override
  void initState() {
    super.initState();
    _seenRotations = widget.rotations;
    _rotate.value = 1;
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (widget.rotations != _seenRotations) {
      if (widget.rotations > _seenRotations) {
        // 새 배치를 -90° 돌린 상태에서 0° 로 돌아오면 이전 배치에서 자연스럽게 회전한 것처럼 보인다.
        _instantLayout = true;
        _rotate.forward(from: 0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _instantLayout = false);
      }
      _seenRotations = widget.rotations;
    }
    // 새 퍼즐(타일 id 가 바뀜)이면 이전 타일들의 연출 기록을 비워서 계속 쌓이지 않게 한다.
    if (!identical(widget.tileIds, old.tileIds)) {
      final current = widget.tileIds.toSet();
      if (!current.containsAll(old.tileIds)) {
        _seenIds.removeWhere((id) => !current.contains(id));
        _bump.removeWhere((id, _) => !current.contains(id));
        _pulse.removeWhere((id, _) => !current.contains(id));
        _nudge.removeWhere((id, _) => !current.contains(id));
      }
    }
    // 위치가 바뀐 타일은 말랑하게 찌그러뜨린다.
    if (!_instantLayout) {
      final oldPos = {for (int i = 0; i < 25; i++) old.tileIds[i]: i};
      for (int i = 0; i < 25; i++) {
        final id = widget.tileIds[i];
        final was = oldPos[id];
        if (was != null && was != i) _bump[id] = (_bump[id] ?? 0) + 1;
      }
    }
  }

  @override
  void dispose() {
    _rotate.dispose();
    _shake.dispose();
    _glow.dispose();
    super.dispose();
  }

  // ── 외부에서 부르는 연출 ───────────────────────────────────
  Offset cellCenterGlobal(int cell) {
    final box = context.findRenderObject() as RenderBox?;
    final local = _cellOffset(cell) + Offset(_cell / 2, _cell / 2);
    return box?.localToGlobal(local) ?? local;
  }

  Offset get centerGlobal {
    final box = context.findRenderObject() as RenderBox?;
    final c = Offset(_size / 2, _size / 2);
    return box?.localToGlobal(c) ?? c;
  }

  void pulseCells(Iterable<int> cells) {
    setState(() {
      for (final c in cells) {
        final id = widget.tileIds[c];
        _pulse[id] = (_pulse[id] ?? 0) + 1;
      }
    });
  }

  void nudge(int a, int b) {
    setState(() {
      for (final c in [a, b]) {
        final id = widget.tileIds[c];
        _nudge[id] = (_nudge[id] ?? 0) + 1;
      }
    });
  }

  void celebrate() {
    setState(() => _celebrate++);
    _glow.forward(from: 0);
  }

  void shake() => _shake.forward(from: 0);

  // ── 배치 ──────────────────────────────────────────────────
  Offset _cellOffset(int cell) {
    final r = cell ~/ 5;
    final c = cell % 5;
    return Offset(_padding + c * (_cell + _gap), _padding + r * (_cell + _gap));
  }

  int? _cellAt(Offset local) {
    final x = local.dx - _padding;
    final y = local.dy - _padding;
    if (x < 0 || y < 0) return null;
    final c = (x / (_cell + _gap)).floor();
    final r = (y / (_cell + _gap)).floor();
    if (r < 0 || r > 4 || c < 0 || c > 4) return null;
    return r * 5 + c;
  }

  Duration _waveDelay(int cell) {
    final r = cell ~/ 5;
    final c = cell % 5;
    final d = switch (widget.target) {
      SymmetryType.horizontal => (c - 2).abs().toDouble(),
      SymmetryType.vertical => (r - 2).abs().toDouble(),
      SymmetryType.point => sqrt(pow(r - 2, 2) + pow(c - 2, 2)),
      SymmetryType.diagonalUp => (r + c - 4).abs() / sqrt2,
      SymmetryType.diagonalDown => (r - c).abs() / sqrt2,
    };
    return Duration(milliseconds: (d * 70).round());
  }

  // ── 입력 ──────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    _dragCell = _cellAt(d.localPosition);
    _dragDelta = Offset.zero;
    _dragUsed = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragCell == null || _dragUsed || !widget.enabled) return;
    _dragDelta += d.delta;
    final threshold = _cell * 0.38;
    if (_dragDelta.distance < threshold) return;
    final from = _dragCell!;
    final r = from ~/ 5;
    final c = from % 5;
    int? to;
    if (_dragDelta.dx.abs() > _dragDelta.dy.abs()) {
      final nc = c + (_dragDelta.dx > 0 ? 1 : -1);
      if (nc >= 0 && nc < 5) to = r * 5 + nc;
    } else {
      final nr = r + (_dragDelta.dy > 0 ? 1 : -1);
      if (nr >= 0 && nr < 5) to = nr * 5 + c;
    }
    _dragUsed = true;
    if (to != null) widget.onSwap(from, to);
  }

  void _onTapUp(TapUpDetails d) {
    if (!widget.enabled) return;
    final cell = _cellAt(d.localPosition);
    if (cell != null) widget.onTapCell(cell);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = [widget.size, constraints.maxWidth, constraints.maxHeight].reduce(min);
      return _buildBoard(context);
    });
  }

  /// 테스트용: 보드가 몇 번 빌드됐는지.
  @visibleForTesting
  static int debugBuildCount = 0;

  /// 테스트용: 타일별 연출 기록의 크기 (퍼즐이 바뀌어도 25개를 넘지 않아야 한다).
  @visibleForTesting
  int get debugTrackedTiles => _seenIds.length;

  Widget _buildBoard(BuildContext context) {
    debugBuildCount++;
    final (light, deep) = Palette.forSymmetry(widget.target);
    final cell = _cell;
    final positionDuration = _instantLayout ? Duration.zero : const Duration(milliseconds: 210);

    final tiles = <Widget>[];
    for (int i = 0; i < 25; i++) {
      final id = widget.tileIds[i];
      final isNew = _seenIds.add(id);
      final o = _cellOffset(i);
      tiles.add(AnimatedPositioned(
        key: ValueKey(id),
        duration: positionDuration,
        curve: Curves.easeOutBack,
        left: o.dx,
        top: o.dy,
        width: cell,
        height: cell,
        child: TileView(
          value: widget.board[i],
          size: cell,
          light: light,
          deep: deep,
          selected: widget.selected == i,
          hinted: widget.hint?.covers(i) ?? false,
          pairMark: widget.pairCell == i && widget.selected != i,
          dimmed: widget.dimmed,
          entranceDelay: isNew ? Duration(milliseconds: 40 + ((i ~/ 5) + (i % 5)) * 28) : null,
          bumpToken: _bump[id] ?? 0,
          pulseToken: _pulse[id] ?? 0,
          nudgeToken: _nudge[id] ?? 0,
          celebrateToken: _celebrate,
          celebrateDelay: _waveDelay(i),
        ),
      ));
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_shake, _glow]),
      builder: (context, child) {
        final shakeX = sin(_shake.value * pi * 6) * (1 - _shake.value) * 12;
        final glow = sin(_glow.value * pi);
        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: deep.withValues(alpha: 0.18 + glow * 0.4),
                  blurRadius: 30 + glow * 30,
                  spreadRadius: glow * 6,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            // 테두리는 레이아웃 공간을 차지하지 않도록 전경에 그린다.
            // (decoration 의 border 는 안쪽 영역을 줄여서 대칭축과 타일 중심이 어긋난다.)
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _AxisPainter(widget.target, deep, behind: true)),
            ),
            AnimatedBuilder(
              animation: _rotate,
              builder: (context, child) {
                final t = Curves.easeOutBack.transform(_rotate.value);
                final angle = (t - 1) * pi / 2;
                final squash = 1 - sin(_rotate.value * pi) * 0.07;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateZ(angle)
                    ..rotateX(sin(_rotate.value * pi) * 0.25)
                    ..scaleByDouble(squash, squash, 1, 1),
                  child: child,
                );
              },
              child: SizedBox(
                width: _size,
                height: _size,
                child: AnimatedOpacity(
                  opacity: widget.hideTiles ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(children: tiles),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _AxisPainter(widget.target, deep, behind: false)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 대칭축 표시. 좌우 → 세로선, 상하 → 가로선, 점대칭 → 가운데 점과 고리.
class _AxisPainter extends CustomPainter {
  _AxisPainter(this.type, this.color, {required this.behind});

  final SymmetryType type;
  final Color color;
  final bool behind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (behind) {
      // 축을 따라 은은한 띠
      final band = Paint()..color = color.withValues(alpha: 0.10);
      final w = size.width * 0.2;
      switch (type) {
        case SymmetryType.horizontal:
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: size.height - 8),
                  const Radius.circular(24)),
              band);
        case SymmetryType.vertical:
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: size.width - 8, height: w),
                  const Radius.circular(24)),
              band);
        case SymmetryType.point:
          canvas.drawCircle(c, w * 0.75, band);
        case SymmetryType.diagonalUp:
        case SymmetryType.diagonalDown:
          // 대각선을 따라 45° 기울인 띠
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(type == SymmetryType.diagonalDown ? pi / 4 : -pi / 4);
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset.zero, width: size.width * sqrt2 - 40, height: w),
                  const Radius.circular(24)),
              band);
          canvas.restore();
      }
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 8.0, gap = 7.0;
    switch (type) {
      case SymmetryType.horizontal:
        for (double y = -6; y < size.height + 6; y += dash + gap) {
          canvas.drawLine(Offset(c.dx, y), Offset(c.dx, min(y + dash, size.height + 6)), paint);
        }
      case SymmetryType.vertical:
        for (double x = -6; x < size.width + 6; x += dash + gap) {
          canvas.drawLine(Offset(x, c.dy), Offset(min(x + dash, size.width + 6), c.dy), paint);
        }
      case SymmetryType.diagonalUp:
      case SymmetryType.diagonalDown:
        // y=−x(↘): 왼쪽 위 → 오른쪽 아래, y=x(↗): 왼쪽 아래 → 오른쪽 위.
        // 보드 모서리가 둥글어서 양 끝을 조금 안쪽에서 시작한다.
        const inset = 14.0;
        final down = type == SymmetryType.diagonalDown;
        final from = down ? Offset(inset, inset) : Offset(inset, size.height - inset);
        final to = down ? Offset(size.width - inset, size.height - inset) : Offset(size.width - inset, inset);
        final total = (to - from).distance;
        final dir = (to - from) / total;
        // 대시가 중심을 기준으로 대칭이 되도록 가운데 대시부터 바깥으로 그린다.
        canvas.drawLine(c - dir * (dash / 2), c + dir * (dash / 2), paint);
        for (double d = dash / 2 + gap; d < total / 2; d += dash + gap) {
          final e = min(d + dash, total / 2);
          canvas.drawLine(c + dir * d, c + dir * e, paint);
          canvas.drawLine(c - dir * d, c - dir * e, paint);
        }
      case SymmetryType.point:
        canvas.drawCircle(c, 7, Paint()..color = Colors.white);
        canvas.drawCircle(c, 5, paint);
        canvas.drawCircle(
            c,
            13,
            Paint()
              ..color = color.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) => old.type != type || old.color != color;
}
