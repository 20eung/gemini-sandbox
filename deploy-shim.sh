#!/bin/bash
# deploy-shim.sh — SHIM_EOF 마커 자동 감지 후 원격 서버에 shim 배포
#
# 사용법:
#   ./deploy-shim.sh
#   ./deploy-shim.sh --dry-run    # 추출만 하고 복사는 생략
#   ./deploy-shim.sh --check      # 문법 검사만

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/basic_setup_ec2_gemini.sh"
TMP="/tmp/claude_shim_extracted.py"
REMOTE_HOST="gemini_sandbox"
REMOTE_PATH="~/.local/bin/claude"
DRY_RUN=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --check)   CHECK_ONLY=true ;;
    esac
done

# 1. SHIM_EOF 마커 위치 동적 탐색
START_LINE=$(grep -n "cat > \"\$CLAUDE_WRAPPER\" << 'SHIM_EOF'" "$SRC" | head -1 | cut -d: -f1)
END_LINE=$(grep -n "^SHIM_EOF$" "$SRC" | tail -1 | cut -d: -f1)

if [[ -z "$START_LINE" || -z "$END_LINE" ]]; then
    echo "ERROR: SHIM_EOF 마커를 찾을 수 없습니다." >&2
    exit 1
fi

SHIM_START=$((START_LINE + 1))
SHIM_END=$((END_LINE - 1))
echo "SHIM 범위: 라인 $SHIM_START ~ $SHIM_END ($(( SHIM_END - SHIM_START + 1 ))줄)"

# 2. 추출
sed -n "${SHIM_START},${SHIM_END}p" "$SRC" > "$TMP"

# 3. Python 문법 검사
if ! python3 -c "import ast; ast.parse(open('$TMP').read())" 2>&1; then
    echo "ERROR: Python 문법 오류가 있습니다." >&2
    exit 1
fi
echo "문법 검사: OK ($(wc -l < "$TMP")줄)"

[[ "$CHECK_ONLY" == true ]] && echo "CHECK_ONLY 모드 — 배포 생략" && exit 0
[[ "$DRY_RUN"   == true ]] && echo "DRY_RUN 모드 — 복사 생략 (파일: $TMP)" && exit 0

# 4. 원격 서버에 복사
scp "$TMP" "${REMOTE_HOST}:${REMOTE_PATH}"
ssh "$REMOTE_HOST" "chmod +x ${REMOTE_PATH}"
echo "배포 완료: ${REMOTE_HOST}:${REMOTE_PATH}"

# 5. 원격 서버에서 GEMINI_BIN 확인
ssh "$REMOTE_HOST" 'python3 -c "
exec(open(__import__(\"os\").path.expanduser(\"~/.local/bin/claude\")).read().split(\"if __name__\")[0])
print(\"GEMINI_BIN:\", GEMINI_BIN)
"'
