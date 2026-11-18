import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// TTF 의 cmap(format 4, 12)에서 글자 코드 목록을 읽는다.
Set<int> _readCmap(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  final numTables = d.getUint16(4);
  int? cmapOffset;
  for (int i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'cmap') cmapOffset = d.getUint32(rec + 8);
  }
  if (cmapOffset == null) throw StateError('cmap 없음');
  final codes = <int>{};
  final n = d.getUint16(cmapOffset + 2);
  for (int i = 0; i < n; i++) {
    final rec = cmapOffset + 4 + i * 8;
    final platform = d.getUint16(rec);
    final sub = cmapOffset + d.getUint32(rec + 4);
    final format = d.getUint16(sub);
    if (platform != 3 && platform != 0) continue;
    if (format == 4) {
      final segX2 = d.getUint16(sub + 6);
      final ends = sub + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final ranges = deltas + segX2;
      for (int s = 0; s < segX2 ~/ 2; s++) {
        final end = d.getUint16(ends + s * 2);
        final start = d.getUint16(starts + s * 2);
        final delta = d.getInt16(deltas + s * 2);
        final rangeOffset = d.getUint16(ranges + s * 2);
        for (int c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (rangeOffset == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final addr = ranges + s * 2 + rangeOffset + (c - start) * 2;
            glyph = d.getUint16(addr);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) codes.add(c);
        }
      }
    } else if (format == 12) {
      final groups = d.getUint32(sub + 12);
      for (int g = 0; g < groups; g++) {
        final rec2 = sub + 16 + g * 12;
        final start = d.getUint32(rec2);
        final end = d.getUint32(rec2 + 4);
        for (int c = start; c <= end; c++) {
          codes.add(c);
        }
      }
    }
  }
  return codes;
}

void main() {
  test('화면에 쓰는 글자는 모두 Jua 글꼴에 있다 (없으면 다른 글꼴로 그려져 어색해진다)', () {
    final cmap = _readCmap(File('assets/fonts/Jua-Regular.ttf').readAsBytesSync());
    expect(cmap.length, greaterThan(90));
    final literal = RegExp(r"'(?:[^'\\]|\\.)*'");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // 수식 글자(−, 가는 공백)는 Jua 가 아니라 수식 글꼴(STIX Two)로 그린다.
      if (f.path.endsWith('math_text.dart')) continue;
      final lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        final code = lines[i].split(' // ').first;
        for (final m in literal.allMatches(code)) {
          for (final r in m.group(0)!.runes) {
            if (r < 0x20 || r == 0x7F) continue;
            if (!cmap.contains(r)) {
              missing.add('${String.fromCharCode(r)} (U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}) ${f.path}:${i + 1}');
            }
          }
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
