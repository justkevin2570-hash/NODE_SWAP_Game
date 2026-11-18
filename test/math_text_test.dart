import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/game/logic/symmetry.dart';
import 'package:node_swap_game/ui/widgets/math_text.dart';

String _plain(List<InlineSpan> spans) => spans.map((s) => (s as TextSpan).text).join();

void main() {
  test('변수는 수식 글꼴 이탤릭, 부호 빼기는 수학 기호(−)로 붙여 쓴다', () {
    final spans = mathSpans('y = -x', fontSize: 20, color: Colors.black).cast<TextSpan>();
    final y = spans.firstWhere((s) => s.text == 'y');
    final x = spans.firstWhere((s) => s.text == 'x');
    for (final v in [x, y]) {
      expect(v.style!.fontFamily, kMathFont);
      expect(v.style!.fontStyle, FontStyle.italic);
    }
    final minus = spans.firstWhere((s) => s.text!.contains('−'));
    expect(minus.text, '−'); // −x 처럼 붙는다
    expect(minus.style!.fontStyle, FontStyle.normal);
    expect(_plain(spans).contains('-'), isFalse); // 하이픈은 남지 않는다
    expect(_plain(spans).contains(' = '), isTrue);
  });

  test('a - b 처럼 앞에 피연산자가 있으면 빼기 앞뒤를 띄운다', () {
    final spans = mathSpans('a-b', fontSize: 20, color: Colors.black).cast<TextSpan>();
    expect(spans.any((s) => s.text == ' − '), isTrue);
  });

  test('대각선 대칭만 식을 가진다', () {
    expect(SymmetryType.diagonalUp.formula, 'y = x');
    expect(SymmetryType.diagonalDown.formula, 'y = -x');
    expect(SymmetryType.horizontal.formula, isNull);
  });

  testWidgets('문장 속 {식} 부분만 수식으로 그린다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MathRichText('6스테이지부터 {y = x}, {y = -x} 대칭도 나와요.', style: TextStyle(fontSize: 16)),
    ));
    final rich = tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText();
    expect(rich.startsWith('6스테이지부터 y'), isTrue);
    expect(rich.contains('{'), isFalse);
    expect(rich.contains('−x'), isTrue);
  });
}
