import 'board.dart';
import 'symmetry.dart';
import '../../core/l10n.dart';

/// 튜토리얼 한 단계.
class Lesson {
  const Lesson({
    required this.title,
    required this.body,
    required this.target,
    required this.board,
    this.showHint = true,
    this.focusRotate = false,
  });

  final String title;
  final String body;
  final SymmetryType target;
  final Board board;
  final bool showHint;
  final bool focusRotate;
}

final lessons = <Lesson>[
  Lesson(
    title: tr('바꿔서 맞추기'),
    body: tr('반짝이는 두 타일을 차례로 눌러\n자리를 바꿔 보세요.\n점선 양쪽이 똑같아지면 성공!'),
    target: SymmetryType.horizontal,
    board: Board.fromRows(const [
      [1, 0, 1, 0, 1],
      [1, 1, 0, 0, 1],
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0],
    ]),
  ),
  Lesson(
    title: tr('돌려서 맞추기'),
    body: tr('위아래는 이미 똑같아요.\n회전 버튼으로 보드를 돌리면\n좌우 대칭이 완성돼요. 회전은 공짜!'),
    target: SymmetryType.horizontal,
    focusRotate: true,
    showHint: false,
    board: Board.fromRows(const [
      [1, 1, 0, 0, 0],
      [0, 1, 1, 0, 1],
      [1, 0, 0, 1, 0],
      [0, 1, 1, 0, 1],
      [1, 1, 0, 0, 0],
    ]),
  ),
  Lesson(
    title: tr('점대칭'),
    body: tr('180도 돌려도 똑같으면 점대칭이에요.\n점 {(x, y)}는 {(-x, -y)}로 옮겨져요.\n타일은 밀어서 바꿔도 돼요!'),
    target: SymmetryType.point,
    board: Board.fromRows(const [
      [1, 0, 0, 1, 1],
      [0, 0, 1, 0, 0],
      [1, 0, 1, 0, 1],
      [0, 0, 0, 1, 0],
      [1, 1, 0, 0, 1],
    ]),
  ),
  Lesson(
    title: tr('{y = -x} 대칭'),
    body: tr('오른쪽 아래로 가는 대각선이 접는 선이에요.\n점 {(x, y)}는 {(-y, -x)}로 옮겨져요.'),
    target: SymmetryType.diagonalDown,
    board: Board.fromRows(const [
      [1, 0, 1, 1, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 1, 0],
      [1, 0, 1, 1, 1],
      [0, 1, 0, 1, 0],
    ]),
  ),
  Lesson(
    title: tr('{y = x} 대칭'),
    body: tr('오른쪽 위로 가는 대각선이 접는 선이에요.\n점 {(x, y)}는 {(y, x)}로 옮겨져요.\n{x}와 {y}가 서로 바뀌죠!'),
    target: SymmetryType.diagonalUp,
    board: Board.fromRows(const [
      [1, 0, 1, 0, 0],
      [1, 1, 0, 1, 0],
      [1, 0, 0, 0, 1],
      [0, 1, 0, 0, 1],
      [1, 0, 1, 1, 1],
    ]),
  ),
];
