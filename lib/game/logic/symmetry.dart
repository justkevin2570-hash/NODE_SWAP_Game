/// 목표 대칭의 종류.
enum SymmetryType {
  horizontal('좌우 대칭', '왼쪽과 오른쪽을 똑같이'),
  vertical('상하 대칭', '위와 아래를 똑같이'),
  point('점대칭', '180도 돌려도 똑같이'),

  /// y = x : 왼쪽 아래 → 오른쪽 위 대각선(↗)
  diagonalUp('y = x 대칭', '오른쪽 위로 가는 대각선을 기준으로 똑같이'),

  /// y = −x : 왼쪽 위 → 오른쪽 아래 대각선(↘)
  diagonalDown('y = -x 대칭', '오른쪽 아래로 가는 대각선을 기준으로 똑같이');

  const SymmetryType(this.label, this.description);

  final String label;
  final String description;

  /// 보드를 90° 회전했을 때 이 대칭이 바뀌는 대칭.
  /// 좌우 ↔ 상하, y=x ↔ y=−x, 점대칭은 회전해도 점대칭 그대로다.
  SymmetryType get rotated => switch (this) {
        SymmetryType.horizontal => SymmetryType.vertical,
        SymmetryType.vertical => SymmetryType.horizontal,
        SymmetryType.point => SymmetryType.point,
        SymmetryType.diagonalUp => SymmetryType.diagonalDown,
        SymmetryType.diagonalDown => SymmetryType.diagonalUp,
      };

  /// 대각선 대칭의 식 부분 ("y = x" 등). 대각선이 아니면 null.
  /// 글꼴(Jua)에 없는 수학 기호(−, ↗, ↘)는 쓰지 않는다. 대신 다른 글꼴로 그려져서 어색해 보인다.
  String? get formula => switch (this) {
        SymmetryType.diagonalUp => 'y = x',
        SymmetryType.diagonalDown => 'y = -x',
        _ => null,
      };

  /// 대각선 대칭인지.
  bool get isDiagonal => this == diagonalUp || this == diagonalDown;

  /// (row, col) 칸의 대칭 짝 인덱스.
  int partnerOf(int index) {
    final r = index ~/ 5;
    final c = index % 5;
    return switch (this) {
      SymmetryType.horizontal => r * 5 + (4 - c),
      SymmetryType.vertical => (4 - r) * 5 + c,
      SymmetryType.point => (4 - r) * 5 + (4 - c),
      SymmetryType.diagonalUp => (4 - c) * 5 + (4 - r),
      SymmetryType.diagonalDown => c * 5 + r,
    };
  }

  /// 서로 다른 두 칸으로 이루어진 대칭 쌍 목록 (각 쌍은 한 번씩).
  List<(int, int)> get pairs => _pairs[this]!;

  static final Map<SymmetryType, List<(int, int)>> _pairs = {
    for (final t in SymmetryType.values)
      t: [
        for (int i = 0; i < 25; i++)
          if (t.partnerOf(i) > i) (i, t.partnerOf(i)),
      ],
  };
}
