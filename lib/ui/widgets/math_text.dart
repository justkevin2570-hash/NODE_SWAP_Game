import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 수식용 글꼴 (STIX Two 에서 필요한 글자만 남긴 것).
const kMathFont = 'STIXTwoMath';

/// "y = -x" 같은 식을 교과서 수식처럼 그린다.
/// - 변수(알파벳)는 세리프 이탤릭
/// - '-' 는 수학 빼기 기호(−), '=' 와 '+' 앞뒤로 같은 간격
List<InlineSpan> mathSpans(String formula, {required double fontSize, required Color color}) {
  final variable = TextStyle(
    fontFamily: kMathFont,
    fontStyle: FontStyle.italic,
    fontSize: fontSize,
    color: color,
    height: 1.0,
  );
  final symbol = variable.copyWith(fontStyle: FontStyle.normal);
  final spans = <InlineSpan>[];
  final chars = formula.replaceAll(' ', '').split('');
  for (int i = 0; i < chars.length; i++) {
    final ch = chars[i];
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      // 이탤릭 글자는 오른쪽으로 기울어서 뒤 글자와 붙어 보이므로 아주 살짝 띄운다.
      spans.add(TextSpan(text: ch, style: variable));
      spans.add(TextSpan(text: ' ', style: symbol.copyWith(fontSize: fontSize * 0.25)));
    } else if (ch == '=' || ch == '+') {
      spans.add(TextSpan(text: ' $ch ', style: symbol));
    } else if (ch == '-') {
      // 앞에 피연산자가 없으면 부호(−x), 있으면 빼기(a − b)
      final binary = i > 0 && RegExp(r'[A-Za-z0-9)]').hasMatch(chars[i - 1]);
      spans.add(TextSpan(text: binary ? ' − ' : '−', style: symbol));
    } else {
      spans.add(TextSpan(text: ch, style: symbol));
    }
  }
  return spans;
}

/// 문장 속 `{y = -x}` 부분만 수식으로 그리는 텍스트.
/// 예: '6스테이지부터 {y = x}, {y = -x} 대칭도 나와요.'
class MathRichText extends StatelessWidget {
  const MathRichText(this.text, {super.key, required this.style, this.mathColor, this.textAlign = TextAlign.start});

  final String text;
  final TextStyle style;
  final Color? mathColor;
  final TextAlign textAlign;

  static final _token = RegExp(r'\{([^}]*)\}');

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    final size = style.fontSize ?? 16;
    for (final m in _token.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.addAll(mathSpans(m.group(1)!, fontSize: size * 1.18, color: mathColor ?? style.color ?? Colors.black));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      style: style.copyWith(fontFamily: style.fontFamily ?? kFont),
    );
  }
}
