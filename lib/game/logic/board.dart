import 'dart:typed_data';

import 'symmetry.dart';

/// N×N 판의 칸 배치 (크기별로 한 번만 만들어 공유한다).
/// index = row * size + col
class Grid {
  Grid._(this.size)
      : cellCount = size * size,
        adjacentPairs = List.unmodifiable([
          for (int r = 0; r < size; r++)
            for (int c = 0; c < size; c++) ...[
              if (c + 1 < size) (r * size + c, r * size + c + 1),
              if (r + 1 < size) (r * size + c, (r + 1) * size + c),
            ],
        ]);

  static final Map<int, Grid> _cache = {};

  /// [size]×[size] 판. 홀수만 쓴다 (축 위에 칸이 있어야 어떤 판이든 대칭을 만들 수 있다).
  factory Grid.of(int size) => _cache.putIfAbsent(size, () => Grid._(size));

  final int size;
  final int cellCount;

  /// 인접한 모든 칸 쌍 (5×5 는 40개).
  final List<(int, int)> adjacentPairs;

  bool isAdjacent(int a, int b) {
    if (a < 0 || b < 0 || a >= cellCount || b >= cellCount) return false;
    final dr = (a ~/ size - b ~/ size).abs();
    final dc = (a % size - b % size).abs();
    return dr + dc == 1;
  }

  /// 시계방향 90° 회전 후 index 가 이동하는 위치. (r, c) → (c, n-1-r)
  int rotatedIndex(int index) {
    final r = index ~/ size;
    final c = index % size;
    return c * size + (size - 1 - r);
  }

  /// [type] 대칭에서 [index] 칸의 짝.
  int partnerOf(SymmetryType type, int index) => partners(type)[index];

  /// 칸마다 대칭 짝 인덱스.
  Int16List partners(SymmetryType type) => _partners[type.index] ??= Int16List.fromList([
        for (int i = 0; i < cellCount; i++) type.partnerAt(i ~/ size, i % size, size),
      ]);
  final List<Int16List?> _partners = List.filled(SymmetryType.values.length, null);

  /// 서로 다른 두 칸으로 이루어진 대칭 쌍 목록 (각 쌍은 한 번씩).
  List<(int, int)> pairs(SymmetryType type) => _pairs[type.index] ??= List.unmodifiable([
        for (int i = 0; i < cellCount; i++)
          if (partnerOf(type, i) > i) (i, partnerOf(type, i)),
      ]);
  final List<List<(int, int)>?> _pairs = List.filled(SymmetryType.values.length, null);
}

/// N×N 이진 보드 (기본 5×5). 칸 값은 0 또는 1. 바꿀 수 없는(immutable) 값이다.
class Board {
  Board._(this.grid, this._cells);

  /// 5×5 보드를 25비트 정수로 만든다 (테스트·튜토리얼용).
  factory Board(int bits, {int size = 5}) {
    final g = Grid.of(size);
    return Board._(g, Uint8List.fromList([for (int i = 0; i < g.cellCount; i++) (bits >> i) & 1]));
  }

  factory Board.fromRows(List<List<int>> rows) {
    final g = Grid.of(rows.length);
    return Board._(g, Uint8List.fromList([for (final row in rows) for (final v in row) v != 0 ? 1 : 0]));
  }

  factory Board.fromCells(int size, List<int> cells) {
    final g = Grid.of(size);
    assert(cells.length == g.cellCount);
    return Board._(g, Uint8List.fromList([for (final v in cells) v != 0 ? 1 : 0]));
  }

  /// '0'·'1' 문자열 (행 순서대로, 길이 n²) 에서 만든다. 스테이지 데이터용.
  factory Board.parse(String code) {
    var n = 1;
    while (n * n < code.length) {
      n++;
    }
    if (n * n != code.length) throw FormatException('보드 길이가 정사각형이 아님', code);
    return Board._(Grid.of(n), Uint8List.fromList([for (int i = 0; i < code.length; i++) code.codeUnitAt(i) == 0x31 ? 1 : 0]));
  }

  final Grid grid;
  final Uint8List _cells;

  int get size => grid.size;
  int get cellCount => grid.cellCount;

  /// 칸 값 복사본.
  Uint8List get cells => Uint8List.fromList(_cells);

  /// '0'·'1' 문자열. [Board.parse] 의 반대.
  String get code => String.fromCharCodes([for (final v in _cells) 0x30 + v]);

  int operator [](int index) => _cells[index];

  int at(int row, int col) => _cells[row * size + col];

  int get onesCount => _cells.fold(0, (a, b) => a + b);

  List<List<int>> toRows() => [
        for (int r = 0; r < size; r++) [for (int c = 0; c < size; c++) at(r, c)],
      ];

  // ── 대칭 ────────────────────────────────────────────────
  bool isSymmetric(SymmetryType type) => mismatchCount(type) == 0;

  /// 값이 서로 다른 대칭 쌍의 개수.
  int mismatchCount(SymmetryType type) {
    var count = 0;
    for (final (a, b) in grid.pairs(type)) {
      if (_cells[a] != _cells[b]) count++;
    }
    return count;
  }

  /// 0.0 ~ 1.0 : 맞춰진 대칭 쌍의 비율.
  double symmetryProgress(SymmetryType type) {
    final total = grid.pairs(type).length;
    return (total - mismatchCount(type)) / total;
  }

  /// 짝과 값이 같은 칸들의 집합 (짝이 자기 자신인 축 위 칸 포함).
  Set<int> matchedCells(SymmetryType type) {
    final p = grid.partners(type);
    return {
      for (int i = 0; i < cellCount; i++)
        if (_cells[i] == _cells[p[i]]) i,
    };
  }

  // ── 이동 ────────────────────────────────────────────────
  bool isAdjacent(int a, int b) => grid.isAdjacent(a, b);

  Board swap(int a, int b) {
    if (_cells[a] == _cells[b]) return this;
    final out = Uint8List.fromList(_cells);
    out[a] = _cells[b];
    out[b] = _cells[a];
    return Board._(grid, out);
  }

  Board rotateCW() {
    final out = Uint8List(cellCount);
    for (int i = 0; i < cellCount; i++) {
      out[grid.rotatedIndex(i)] = _cells[i];
    }
    return Board._(grid, out);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Board || other.size != size) return false;
    for (int i = 0; i < cellCount; i++) {
      if (other._cells[i] != _cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(size, Object.hashAll(_cells));

  @override
  String toString() =>
      toRows().map((row) => row.map((v) => v == 1 ? '#' : '.').join()).join('\n');
}
