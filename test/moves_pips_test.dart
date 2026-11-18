import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/ui/widgets/hud.dart';

void main() {
  testWidgets('남은 이동: 허용 5, 사용 2 → 칸 5개 중 3개 채움, 2개 테두리만', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: MovesPips(used: 2, max: 5, color: Colors.pink))),
    ));
    final tiles = tester.widgetList<MoveTile>(find.byType(MoveTile)).toList();
    expect(tiles.length, 5);
    expect(tiles.where((t) => t.filled).length, 3);
    expect(tiles.where((t) => !t.filled).length, 2);
    // 쓴 칸도 크기는 같다 (줄이 흔들리지 않게)
    final sizes = find.byType(MoveTile).evaluate().map((e) => tester.getSize(find.byWidget(e.widget))).toSet();
    expect(sizes.length, 1);
  });
}
