#!/bin/bash
#
# soozip 전체 테스트 — SPM 패키지 3종 + 앱 타깃
#
# 이 저장소는 테스트 표면이 둘로 나뉘어 있다.
#   · Packages/{SoozipGeometry,SoozipLayout,SoozipDraft} — `swift test` (플랫폼 독립)
#   · SoozipTests — `xcodebuild test` (시뮬레이터 필요)
# 한쪽만 돌리면 다른 쪽 회귀를 놓치므로 둘을 함께 돈다.
#
# 시뮬레이터는 사용 가능한 첫 iPhone을 자동으로 고른다.
# 특정 기기를 쓰려면: SOOZIP_TEST_DEST='platform=iOS Simulator,name=iPhone 17' ./scripts/test.sh

set -euo pipefail
cd "$(dirname "$0")/.."

FAILED=0

echo "=== SPM 패키지 ==="
for p in SoozipGeometry SoozipLayout SoozipDraft; do
    printf '%-16s ' "$p"
    if OUT=$(cd "Packages/$p" && swift test 2>&1); then
        echo "$OUT" | grep -oE "Test run with [0-9]+ tests.*passed" || echo "통과 (요약 파싱 실패)"
    else
        echo "FAILED"
        echo "$OUT" | grep -E "error:|✘" | head -20
        FAILED=1
    fi
done

echo
echo "=== 앱 타깃 ==="
DEST="${SOOZIP_TEST_DEST:-}"
if [ -z "$DEST" ]; then
    SIM=$(xcrun simctl list devices available \
          | sed -n 's/^ *\(iPhone [^(]*\) (.*/\1/p' \
          | sed 's/ *$//' | head -1)
    if [ -z "$SIM" ]; then
        echo "사용 가능한 iPhone 시뮬레이터가 없습니다."
        exit 1
    fi
    DEST="platform=iOS Simulator,name=$SIM"
fi
echo "destination: $DEST"

if OUT=$(xcodebuild test -scheme Soozip -destination "$DEST" 2>&1); then
    echo "$OUT" | grep -oE "Test run with [0-9]+ tests.*passed" || echo "통과 (요약 파싱 실패)"
else
    echo "FAILED"
    echo "$OUT" | grep -E "error:|✘|Testing failed" | head -20
    FAILED=1
fi

echo
echo "=== 릴리스 빌드 ==="
# **Debug만 돌리면 릴리스 전용 컴파일 실패를 못 잡는다.** 실제로 `#if DEBUG`로
# 감싼 툴바 항목 때문에 릴리스가 통째로 깨진 적이 있는데, Debug 빌드도 테스트도
# 전부 초록이었다 — 코드 리뷰가 아니었으면 심사 직전에야 드러났을 것이다.
if OUT=$(xcodebuild build -scheme Soozip -configuration Release -destination "$DEST" 2>&1); then
    echo "빌드 성공"
else
    echo "FAILED"
    echo "$OUT" | grep -E "error:" | head -10
    FAILED=1
fi

echo
if [ "$FAILED" -ne 0 ]; then
    echo "테스트 실패"
    exit 1
fi
echo "전체 통과"
