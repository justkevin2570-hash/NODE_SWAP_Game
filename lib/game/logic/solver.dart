import 'dart:typed_data';

import 'board.dart';
import 'symmetry.dart';

/// 최적 풀이 결과.
class Solution {
  const Solution(this.swaps, {required this.needsRotation});

  /// 순서대로 실행할 swap 목록.
  final List<(int, int)> swaps;

  /// swap 을 마친 뒤 90° 회전이 한 번 필요한지.
  final bool needsRotation;

  int get moveCount => swaps.length;
}

/// IDA* 로 "최소 swap 수" 풀이를 찾는다.
///
/// 회전은 무료이므로 좌우/상하 목표는 "좌우 또는 상하 대칭이면 도착"으로 본다.
/// (상하 대칭인 보드는 한 번 회전하면 좌우 대칭이 되기 때문.)
/// 점대칭은 회전해도 변하지 않으므로 목표가 하나뿐이다.
///
/// 큰 판(9×9)에서도 빠르도록 보드 하나를 제자리에서 바꿨다 되돌리며 탐색하고,
/// 어긋난 쌍 개수는 swap 마다 바뀐 부분만 다시 센다. 그래도 "남은 이동으로는 못 푼다"를 증명하는 데
/// 오래 걸리는 판이 있어서, 게임 중에는 [solve] 의 maxNodes 로 탐색량을 제한한다.
class Solver {
  Solver(this.target) : _goals = {target, target.rotated}.toList(growable: false);

  final SymmetryType target;
  final List<SymmetryType> _goals;

  // 탐색 중 상태
  late Uint8List _cells;
  late List<Int16List> _partner; // 목표별 짝
  late Int32List _mism; // 목표별 어긋난 쌍 수
  late List<(int, int)> _pairs;
  late Int16List _pa, _pb;
  final List<int> _path = [];
  int _budget = 0; // 남은 탐색 노드 수 (0 이하가 되면 포기)
  bool _gaveUp = false;

  /// 마지막 [solve] 가 [maxNodes] 를 다 써서 포기했는지.
  bool get gaveUp => _gaveUp;

  /// [maxDepth] 이하의 swap 으로 풀 수 없으면 null.
  /// [maxNodes] 를 주면 그만큼만 탐색한다 (그래도 못 찾으면 null, [gaveUp] = true).
  Solution? solve(Board start, {int maxDepth = 10, int? maxNodes}) {
    final grid = start.grid;
    _cells = start.cells;
    _partner = [for (final g in _goals) grid.partners(g)];
    _mism = Int32List.fromList([for (final g in _goals) start.mismatchCount(g)]);
    _pairs = grid.adjacentPairs;
    _pa = Int16List.fromList([for (final p in _pairs) p.$1]);
    _pb = Int16List.fromList([for (final p in _pairs) p.$2]);
    _path.clear();
    _budget = maxNodes ?? 0x7fffffff;
    _gaveUp = false;

    var bound = _h();
    while (bound <= maxDepth) {
      final next = _search(0, bound, -1);
      if (next < 0) {
        final swaps = [for (final i in _path) _pairs[i]];
        // 목표 대칭(회전 없이)을 먼저 확인한다.
        return Solution(swaps, needsRotation: _mism[0] != 0);
      }
      if (_gaveUp || next >= 1 << 30) return null;
      bound = next;
    }
    return null;
  }

  /// 휴리스틱: 한 번의 swap 은 대칭 쌍을 최대 2개까지만 고칠 수 있다.
  int _h() {
    var best = 1 << 30;
    for (int g = 0; g < _mism.length; g++) {
      final m = (_mism[g] + 1) >> 1;
      if (m < best) best = m;
    }
    return best;
  }

  bool get _atGoal {
    for (int g = 0; g < _mism.length; g++) {
      if (_mism[g] == 0) return true;
    }
    return false;
  }

  /// 칸 a, b 를 맞바꾸고 목표별 어긋난 쌍 수를 갱신한다 (같은 호출로 되돌릴 수 있다).
  void _swap(int a, int b) {
    for (int g = 0; g < _partner.length; g++) {
      final p = _partner[g];
      final pa = p[a], pb = p[b];
      // 영향을 받는 쌍: {a, pa}, {b, pb} (같은 쌍이면 한 번만)
      final samePair = pa == b;
      var before = 0;
      if (_cells[a] != _cells[pa]) before++;
      if (!samePair && _cells[b] != _cells[pb]) before++;
      final t = _cells[a];
      _cells[a] = _cells[b];
      _cells[b] = t;
      var after = 0;
      if (_cells[a] != _cells[pa]) after++;
      if (!samePair && _cells[b] != _cells[pb]) after++;
      // 다음 목표를 위해 되돌려 둔다
      _cells[b] = _cells[a];
      _cells[a] = t;
      _mism[g] += after - before;
    }
    final t = _cells[a];
    _cells[a] = _cells[b];
    _cells[b] = t;
  }

  /// 음수 → 찾음, 그 외 → 다음 bound 후보.
  int _search(int g, int bound, int last) {
    final f = g + _h();
    if (f > bound) return f;
    if (_atGoal) return -1;
    if (--_budget <= 0) {
      _gaveUp = true;
      return 1 << 30;
    }
    var min = 1 << 30;
    final la = last >= 0 ? _pa[last] : -1, lb = last >= 0 ? _pb[last] : -1;
    for (int i = 0; i < _pairs.length; i++) {
      if (i == last) continue;
      final a = _pa[i], b = _pb[i];
      if (_cells[a] == _cells[b]) continue;
      // 서로 겹치지 않는 두 swap 은 순서를 바꿔도 결과가 같다 → 번호가 커지는 순서만 본다.
      if (i < last && a != la && a != lb && b != la && b != lb) continue;
      _path.add(i);
      _swap(a, b);
      final t = _search(g + 1, bound, i);
      if (t < 0) return -1; // 찾음: 보드를 목표 상태로 남겨 둔다
      _swap(a, b);
      _path.removeLast();
      if (_gaveUp) return 1 << 30;
      if (t < min) min = t;
    }
    return min;
  }
}
