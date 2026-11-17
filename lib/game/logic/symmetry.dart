/// 목표 대칭의 종류.
enum SymmetryType {
  horizontal('좌우 대칭', '왼쪽과 오른쪽을 똑같이'),
  vertical('상하 대칭', '위와 아래를 똑같이'),
  point('점대칭', '180° 돌려도 똑같이');

  const SymmetryType(this.label, this.description);

  final String label;
  final String description;

  /// 보드를 90° 회전했을 때 이 대칭이 바뀌는 대칭.
  /// 좌우 ↔ 상하, 점대칭은 회전해도 점대칭 그대로다.
  SymmetryType get rotated => switch (this) {
        SymmetryType.horizontal => SymmetryType.vertical,
        SymmetryType.vertical => SymmetryType.horizontal,
        SymmetryType.point => SymmetryType.point,
      };

  /// (row, col) 칸의 대칭 짝 인덱스.
  int partnerOf(int index) {
    final r = index ~/ 5;
    final c = index % 5;
    return switch (this) {
      SymmetryType.horizontal => r * 5 + (4 - c),
      SymmetryType.vertical => (4 - r) * 5 + c,
      SymmetryType.point => (4 - r) * 5 + (4 - c),
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
