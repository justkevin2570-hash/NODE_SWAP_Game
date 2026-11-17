import 'board.dart';
import 'symmetry.dart';

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
    title: '바꿔서 맞추기',
    body: '반짝이는 두 타일을 차례로 눌러 자리를 바꿔 보세요.\n점선을 기준으로 왼쪽과 오른쪽이 똑같아지면 성공!',
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
    title: '돌려서 맞추기',
    body: '위아래는 이미 똑같아요. 회전 버튼으로 보드를 돌리면\n좌우 대칭이 완성돼요. 회전은 공짜예요!',
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
    title: '밀어서 맞추기',
    body: '타일을 옆으로 쭉 밀어도 바로 바뀌어요.\n점대칭은 가운데 점을 중심으로 180° 돌려도 똑같은 모양이에요.',
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
    title: '대각선으로 맞추기',
    body: '대각선 점선을 접는 선이라고 생각해 보세요.\n반짝이는 두 타일을 바꾸면 ↘ 대각선(y=−x) 대칭이 완성돼요!',
    target: SymmetryType.diagonalDown,
    board: Board.fromRows(const [
      [1, 0, 1, 1, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 1, 0],
      [1, 0, 1, 1, 1],
      [0, 1, 0, 1, 0],
    ]),
  ),
];
