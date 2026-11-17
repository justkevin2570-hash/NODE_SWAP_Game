import 'symmetry.dart';

/// 5×5 이진 보드. 칸 값은 0 또는 1이며 25비트 정수 하나로 저장한다.
/// index = row * 5 + col
class Board {
  const Board(this.bits);

  static const int size = 5;
  static const int cellCount = 25;

  final int bits;

  factory Board.fromRows(List<List<int>> rows) {
    var bits = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (rows[r][c] != 0) bits |= 1 << (r * size + c);
      }
    }
    return Board(bits);
  }

  int operator [](int index) => (bits >> index) & 1;

  int at(int row, int col) => this[row * size + col];

  List<List<int>> toRows() => [
        for (int r = 0; r < size; r++)
          [for (int c = 0; c < size; c++) at(r, c)],
      ];

  // ── 대칭 ────────────────────────────────────────────────
  bool isSymmetric(SymmetryType type) => mismatchCount(type) == 0;

  /// 값이 서로 다른 대칭 쌍의 개수.
  int mismatchCount(SymmetryType type) {
    var count = 0;
    for (final (a, b) in type.pairs) {
      if (this[a] != this[b]) count++;
    }
    return count;
  }

  /// 0.0 ~ 1.0 : 맞춰진 대칭 쌍의 비율.
  double symmetryProgress(SymmetryType type) {
    final total = type.pairs.length;
    return (total - mismatchCount(type)) / total;
  }

  /// 짝과 값이 같은 칸들의 집합 (짝이 자기 자신인 축 위 칸 포함).
  Set<int> matchedCells(SymmetryType type) => {
        for (int i = 0; i < cellCount; i++)
          if (this[i] == this[type.partnerOf(i)]) i,
      };

  // ── 이동 ────────────────────────────────────────────────
  static bool isAdjacent(int a, int b) {
    final dr = (a ~/ size - b ~/ size).abs();
    final dc = (a % size - b % size).abs();
    return dr + dc == 1;
  }

  Board swap(int a, int b) {
    if (this[a] == this[b]) return this;
    return Board(bits ^ (1 << a) ^ (1 << b));
  }

  /// 인접한 모든 칸 쌍 (40개).
  static final List<(int, int)> adjacentPairs = [
    for (int r = 0; r < size; r++)
      for (int c = 0; c < size; c++) ...[
        if (c + 1 < size) (r * size + c, r * size + c + 1),
        if (r + 1 < size) (r * size + c, (r + 1) * size + c),
      ],
  ];

  /// 시계방향 90° 회전 후 index 가 이동하는 위치.
  /// (r, c) → (c, 4 - r)
  static int rotatedIndex(int index) {
    final r = index ~/ size;
    final c = index % size;
    return c * size + (size - 1 - r);
  }

  Board rotateCW() {
    var out = 0;
    for (int i = 0; i < cellCount; i++) {
      if (this[i] == 1) out |= 1 << rotatedIndex(i);
    }
    return Board(out);
  }

  @override
  bool operator ==(Object other) => other is Board && other.bits == bits;

  @override
  int get hashCode => bits.hashCode;

  @override
  String toString() =>
      toRows().map((row) => row.map((v) => v == 1 ? '■' : '□').join()).join('\n');
}
