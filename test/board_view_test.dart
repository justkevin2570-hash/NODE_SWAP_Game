import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/game/logic/board.dart';
import 'package:node_swap_game/game/logic/symmetry.dart';
import 'package:node_swap_game/ui/widgets/board_view.dart';
import 'package:node_swap_game/ui/widgets/tile_view.dart';

void main() {
  // 두 번째 경우: 요청한 크기(362)보다 부모가 좁은 공간(358)을 줄 때 (실제 게임 화면에서 생긴 문제)
  for (final (requested, available) in [(320.0, 400.0), (362.0, 358.0)]) {
    for (final type in SymmetryType.values) {
      testWidgets(
        '대칭축(${type.label})은 타일 격자의 정가운데에 있다 (요청 $requested, 공간 $available)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: available,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BoardView(
                        board: const Board(0x1F0F0F1),
                        tileIds: List.generate(25, (i) => i),
                        target: type,
                        size: requested,
                        onTapCell: (_) {},
                        onSwap: (_, _) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 2));

          final board = tester.getRect(find.byType(BoardView));
          final tiles = find.byType(TileView);
          final first = tester.getRect(tiles.at(0)); // (0,0)
          final last = tester.getRect(tiles.at(24)); // (4,4)
          final gridCenter = Rect.fromPoints(
            first.topLeft,
            last.bottomRight,
          ).center;

          // 축과 점은 보드 영역 전체(Positioned.fill)의 중심에 그려진다.
          final axisLayers = find.descendant(
            of: find.byType(BoardView),
            matching: find.byType(CustomPaint),
          );
          final axisRects = axisLayers
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget)))
              .where(
                (r) =>
                    (r.width - board.width).abs() < 0.01 &&
                    (r.height - board.height).abs() < 0.01,
              )
              .toList();
          expect(axisRects, isNotEmpty);
          for (final r in axisRects) {
            expect(r.center.dx, moreOrLessEquals(gridCenter.dx, epsilon: 0.01));
            expect(r.center.dy, moreOrLessEquals(gridCenter.dy, epsilon: 0.01));
          }
          expect(
            gridCenter.dx,
            moreOrLessEquals(board.center.dx, epsilon: 0.01),
          );
          expect(
            gridCenter.dy,
            moreOrLessEquals(board.center.dy, epsilon: 0.01),
          );
          // 타일 격자가 보드 테두리 밖으로 나가지 않는다.
          expect(first.left, greaterThan(board.left));
          expect(last.right, lessThan(board.right));
        },
      );
    }
  }
}
