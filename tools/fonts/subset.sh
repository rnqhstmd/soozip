#!/usr/bin/env bash
# 번들 폰트 서브셋 재현 스크립트 (2026-08-10 확정)
#
# 왜 필요한가: 원본 5종은 합계 20MB로 기준(10MB)의 2배다. 용량의 본체는
# 한자가 아니라 **한글 음절 11,172자 자체**여서, 한자만 빼는 서브셋으로는
# 18MB까지밖에 못 줄인다(실측).
#
# 전략 — 폰트마다 다르게 자른다:
#   Pretendard  : 한글 11,172자 전부 유지 (OTF/CFF 압축이 좋아 1.3MB로 끝난다)
#                 기본 폰트이므로 어떤 글자를 쳐도 정상 표시되어야 한다.
#   감성 3종     : KS X 1001 2,350자로 제한 (각 1.2~1.4MB)
#                 '뷁·힣·똠' 같은 희귀 음절은 iOS가 시스템 폰트로 폴백한다.
#   Playfair    : 영문 전용이라 서브셋하지 않는다 (0.3MB, 가변 폰트 wght 400~900)
#
# 결과: 합계 5.2MB (기준의 52%)
#
# 사용법:
#   1) 원본을 Soozip/Resources/Fonts/ 에 내려받는다 (아래 URL 참조)
#   2) bash tools/fonts/subset.sh
#
# 원본 출처 (전부 SIL OFL — licenses/ 에 원문 보관):
#   Pretendard  https://github.com/orioncactus/pretendard/raw/main/packages/pretendard/dist/public/static/Pretendard-Regular.otf
#   고운바탕     https://github.com/google/fonts/raw/main/ofl/gowunbatang/GowunBatang-Regular.ttf
#   고운돋움     https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf
#   나눔손글씨   https://github.com/google/fonts/raw/main/ofl/nanumpenscript/NanumPenScript-Regular.ttf
#   Playfair    https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf

set -euo pipefail

FONTS_DIR="Soozip/Resources/Fonts"
KS_LIST="tools/fonts/ksx1001.txt"

# pyftsubset 경로 — 환경에 맞게 조정한다
PYFTSUBSET="${PYFTSUBSET:-pyftsubset}"

# 한글 음절 외에 항상 유지할 범위
#   U+0020-007E  ASCII
#   U+00A0-00FF  라틴-1 보충
#   U+2000-206F  일반 문장부호 (…, — 등)
#   U+3131-318E  한글 자모 (ㄱ, ㅏ 단독 입력)
#   U+FF00-FFEF  전각 형태
EXTRA='U+0020-007E,U+00A0-00FF,U+2000-206F,U+3131-318E,U+FF00-FFEF'
HANGUL_ALL='U+AC00-D7A3'

echo "[1/2] Pretendard — 한글 전체 유지"
"$PYFTSUBSET" "$FONTS_DIR/Pretendard-Regular.otf" \
  --unicodes="$EXTRA,$HANGUL_ALL" \
  --output-file="$FONTS_DIR/Pretendard-Regular.subset.otf" \
  --layout-features='*' --no-hinting
mv -f "$FONTS_DIR/Pretendard-Regular.subset.otf" "$FONTS_DIR/Pretendard-Regular.otf"

echo "[2/2] 감성 3종 — KS X 1001 2,350자"
for f in GowunBatang-Regular GowunDodum-Regular NanumPenScript-Regular; do
  "$PYFTSUBSET" "$FONTS_DIR/$f.ttf" \
    --text-file="$KS_LIST" \
    --unicodes="$EXTRA" \
    --output-file="$FONTS_DIR/$f.subset.ttf" \
    --layout-features='*' --no-hinting
  mv -f "$FONTS_DIR/$f.subset.ttf" "$FONTS_DIR/$f.ttf"
done

echo "--- 결과 ---"
du -ch "$FONTS_DIR"/*.ttf "$FONTS_DIR"/*.otf | tail -1
echo "기준: 10MB 이하"
