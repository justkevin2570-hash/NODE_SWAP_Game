#!/usr/bin/env python3
"""앱에 넣는 한글 글꼴(Jua)을 실제로 쓰는 글자만 남겨 줄인다.

원본(모든 한글 음절, 약 2.1MB)은 tools/fonts/Jua-Regular.full.ttf 에 두고,
lib/ 의 문자열에 나오는 글자 + 영문/숫자/기본 기호만 남겨
assets/fonts/Jua-Regular.ttf 로 저장한다.

화면 문구를 바꾸거나 추가했으면 다시 실행하세요:
    pip install fonttools
    python3 tools/subset_fonts.py
빠뜨린 글자가 있으면 test/font_coverage_test.dart 가 실패해서 알려준다.
"""
import glob
import os
import re

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "tools", "fonts", "Jua-Regular.full.ttf")
OUT = os.path.join(ROOT, "assets", "fonts", "Jua-Regular.ttf")

LITERAL = re.compile(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"")


def used_chars() -> set[str]:
    chars = {chr(c) for c in range(0x20, 0x7F)}  # 영문, 숫자, 기본 기호 (점수·숫자 표시용)
    for path in glob.glob(os.path.join(ROOT, "lib", "**", "*.dart"), recursive=True):
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.lstrip().startswith("//"):
                    continue
                for m in LITERAL.finditer(line):
                    chars.update(m.group(0))
    return chars


def main() -> None:
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    chars = {c for c in used_chars() if ord(c) in cmap}
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(text="".join(sorted(chars)))
    sub.subset(font)
    font.save(OUT)
    print(f"글자 {len(chars)}개 → {os.path.getsize(OUT) / 1024:.0f}KB (원본 {os.path.getsize(SRC) / 1024:.0f}KB)")


if __name__ == "__main__":
    main()
