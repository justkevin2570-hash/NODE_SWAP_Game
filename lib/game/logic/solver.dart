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
class Solver {
  Solver(this.target)
      : _goals = {target, target.rotated}.toList(growable: false);

  final SymmetryType target;
  final List<SymmetryType> _goals;

  /// 휴리스틱: 한 번의 swap 은 대칭 쌍을 최대 2개까지만 고칠 수 있다.
  int _h(Board b) {
    var best = 1 << 30;
    for (final g in _goals) {
      final m = (b.mismatchCount(g) + 1) >> 1;
      if (m < best) best = m;
    }
    return best;
  }

  SymmetryType? _reachedGoal(Board b) {
    if (b.isSymmetric(target)) return target;
    for (final g in _goals) {
      if (b.isSymmetric(g)) return g;
    }
    return null;
  }

  Solution? solve(Board start, {int maxDepth = 10}) {
    var bound = _h(start);
    final path = <(int, int)>[];
    while (bound <= maxDepth) {
      final next = _search(start, 0, bound, path, -1);
      if (next < 0) {
        final goal = _reachedGoal(_apply(start, path))!;
        return Solution(List.of(path), needsRotation: goal != target);
      }
      if (next >= 1 << 30) return null;
      bound = next;
    }
    return null;
  }

  /// 음수 → 찾음, 그 외 → 다음 bound 후보.
  int _search(Board b, int g, int bound, List<(int, int)> path, int lastPair) {
    final f = g + _h(b);
    if (f > bound) return f;
    if (_reachedGoal(b) != null) return -1;
    var min = 1 << 30;
    final pairs = Board.adjacentPairs;
    for (int i = 0; i < pairs.length; i++) {
      if (i == lastPair) continue;
      final (a, c) = pairs[i];
      if (b[a] == b[c]) continue;
      path.add(pairs[i]);
      final t = _search(b.swap(a, c), g + 1, bound, path, i);
      if (t < 0) return -1;
      if (t < min) min = t;
      path.removeLast();
    }
    return min;
  }

  static Board _apply(Board b, List<(int, int)> swaps) {
    var out = b;
    for (final (a, c) in swaps) {
      out = out.swap(a, c);
    }
    return out;
  }
}
