// 클래식 스테이지 퍼즐(판 크기별 100탄)을 미리 만들어 lib/game/logic/stages_data.dart 에 저장한다.
//
//   dart run tool/generate_stages.dart
//
// 시드가 고정이라 다시 실행해도 같은 퍼즐이 나온다. 이미 출시한 뒤에는 다시 만들지 말 것
// (사용자가 깬 탄의 퍼즐이 바뀐다).
import 'dart:io';
import 'dart:math';

import 'package:node_swap_game/game/logic/generator.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/symmetry.dart';

void main() {
  final out = StringBuffer()
    ..writeln('// 자동 생성 파일: tool/generate_stages.dart 로 만든다. 직접 고치지 말 것.')
    ..writeln("// 각 항목: (보드 — 행 순서대로 '0'·'1', 목표 대칭, 최소 이동 수)")
    ..writeln()
    ..writeln("import 'rules.dart';")
    ..writeln()
    ..writeln('const Map<BoardSize, List<(String, String, int)>> stageData = {');
  for (final b in BoardSize.values) {
    final rng = Random(20261121 + b.size * 7919);
    final gen = PuzzleGenerator(rng);
    final seen = <String>{};
    out.writeln('  BoardSize.${b.name}: [');
    SymmetryType? last;
    final sw = Stopwatch()..start();
    for (int stage = 1; stage <= Rules.stageCount; stage++) {
      final c = Rules.stageCurve(b, stage);
      final par = Rules.stagePar(b, stage);
      // 새 대칭을 소개하는 탄이면 그 대칭, 아니면 같은 대칭이 연달아 나오지 않게 고른다
      final intro = Rules.stageIntroType(stage);
      final choices = c.types.where((t) => t != last || c.types.length == 1).toList();
      final type = intro ?? choices[rng.nextInt(choices.length)];
      // 정해진 최소 이동 수와 정확히 같은 퍼즐이 나올 때까지 만든다
      Puzzle? p;
      for (int tries = 0; tries < 2000; tries++) {
        final cand = gen.generate(
          PuzzleSpec(scrambleSwaps: par, slack: 0, types: [type], size: b.size),
          forcedType: type,
        );
        final key = '${cand.board.code}:${cand.target.name}';
        if (cand.par == par && !seen.contains(key)) {
          seen.add(key);
          p = cand;
          break;
        }
      }
      if (p == null) throw StateError('${b.label} $stage탄을 만들지 못함');
      last = type;
      out.writeln("    ('${p.board.code}', '${p.target.name}', ${p.par}), // $stage");
    }
    out.writeln('  ],');
    stdout.writeln('${b.label}: ${sw.elapsedMilliseconds}ms');
  }
  out.writeln('};');
  File('lib/game/logic/stages_data.dart').writeAsStringSync(out.toString());
  stdout.writeln('wrote lib/game/logic/stages_data.dart');
}
