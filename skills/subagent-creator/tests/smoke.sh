#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# 이 스킬이 배포하는 검증기의 스모크 테스트.
#
# 두 가지를 확인한다.
#   1. 검증기가 정상 정의를 통과시키고, 형식 오류를 종류별로 잡는다.
#   2. SKILL.md 와 references/agent-format.md 의 필드·도구 표가 검증기의
#      상수 집합과 어긋나지 않는다. 문서와 검증기가 갈리면 스킬은 존재하지
#      않는 필드를 권하게 되고, 그건 잘못된 정의보다 고치기 어렵다.

set -euo pipefail

# 마지막 단계가 scripts/ 에서 agent_validator 를 import 한다. 기본값이면 그
# 옆에 __pycache__ 가 생겨서, 테스트를 한 번 돌린 것만으로 스킬 디렉터리가
# 더러워지고 카탈로그 미러에도 따라 들어간다.
export PYTHONDONTWRITEBYTECODE=1

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$SKILL_DIR/scripts/validate_subagent.py"
FORMAT_DOC="$SKILL_DIR/references/agent-format.md"
SKILL_MD="$SKILL_DIR/SKILL.md"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# 검증기는 Python 과 PyYAML 을 요구한다. uv 로 격리 실행해 호스트 환경을
# 건드리지 않는다. 로컬에 uv 가 없으면 SKIP 이지만 CI 에서는 실패다.
if ! command -v uv > /dev/null 2>&1; then
    [ -z "${CI:-}" ] || fail "uv 가 없다. CI 에서는 검증기를 반드시 실행해야 한다"
    echo "SKIP uv 가 없어 검증기 테스트를 건너뜀"
    exit 0
fi
RUN=(uv run --quiet --with pyyaml --python 3.11)

# 픽스처를 stdin 으로 받아 파일로 쓰고 검증기를 돌린다.
#   $1 파일명(검증기가 name 과 대조하므로 stem 이 곧 기대 name 이다)
#   $2 기대 결과 — pass 또는 fail
check() {
    local name="$1" expect="$2" path
    path="$TMP_ROOT/$1"
    cat > "$path"

    if "${RUN[@]}" "$VALIDATOR" "$path" > "$TMP_ROOT/out.log" 2>&1; then
        [ "$expect" = pass ] || {
            sed 's/^/    /' "$TMP_ROOT/out.log"
            fail "$name 은 FAIL 이어야 하는데 통과함"
        }
    else
        [ "$expect" = fail ] || {
            sed 's/^/    /' "$TMP_ROOT/out.log"
            fail "$name 은 PASS 여야 하는데 실패함"
        }
    fi
    echo "  ✓ $name ($expect)"
}

echo "── 검증기: 통과해야 하는 정의"

check full-featured.md pass << 'EOF'
---
name: full-featured
description: 마이그레이션 리뷰 전문가. 스키마 변경을 적용하기 전에 proactively 사용한다.
tools: Read, Grep, Glob, Bash
model: sonnet
effort: high
maxTurns: 12
skills:
  - repo-scaffold
isolation: worktree
permissionMode: default
memory: project
background: false
color: blue
---

너는 마이그레이션 리뷰 전문가다. 되돌릴 수 없는 변경을 먼저 찾는다.
EOF

check minimal.md pass << 'EOF'
---
name: minimal
description: 필수 필드만 가진 정의. tools 를 생략하면 메인 스레드의 도구를 상속한다.
---

너는 무엇이든 하는 에이전트다.
EOF

check tools-as-list.md pass << 'EOF'
---
name: tools-as-list
description: tools 를 YAML 목록으로도 쓸 수 있다.
tools:
  - Read
  - Grep
  - mcp__linear__list_issues
---

너는 읽기 전용 조사자다.
EOF

echo "── 검증기: 잡아야 하는 오류"

check no-frontmatter.md fail << 'EOF'
# 그냥 마크다운

frontmatter 블록이 없다.
EOF

check broken-yaml.md fail << 'EOF'
---
name: broken-yaml
description: "닫히지 않은 따옴표
tools: Read
---

본문.
EOF

check name-mismatch.md fail << 'EOF'
---
name: some-other-name
description: name 이 파일명 stem 과 다르다.
---

본문.
EOF

check not-kebab.md fail << 'EOF'
---
name: NotKebab
description: name 이 kebab-case 가 아니다.
---

본문.
EOF

check unknown-key.md fail << 'EOF'
---
name: unknown-key
description: tool 은 오타다. 실제 필드는 tools 다.
tool: Read
---

본문.
EOF

check unknown-tool.md fail << 'EOF'
---
name: unknown-tool
description: Search 라는 도구는 없다.
tools: Read, Search
---

본문.
EOF

check bad-effort.md fail << 'EOF'
---
name: bad-effort
description: effort enum 밖의 값.
effort: extreme
---

본문.
EOF

check bad-permission-mode.md fail << 'EOF'
---
name: bad-permission-mode
description: permissionMode enum 밖의 값.
permissionMode: yolo
---

본문.
EOF

check bad-max-turns.md fail << 'EOF'
---
name: bad-max-turns
description: maxTurns 는 1 이상의 정수여야 한다.
maxTurns: 0
---

본문.
EOF

check empty-body.md fail << 'EOF'
---
name: empty-body
description: 시스템 프롬프트 본문이 없다.
---
EOF

check no-description.md fail << 'EOF'
---
name: no-description
tools: Read
---

본문.
EOF

echo "── 문서와 검증기 상수 집합의 일치"

cat > "$TMP_ROOT/consistency.py" << 'PY'
"""문서의 필드·도구 표가 검증기의 상수 집합과 어긋나지 않는지 확인한다."""

import re
import sys
from pathlib import Path

format_doc, skill_md, scripts_dir = sys.argv[1:4]
sys.path.insert(0, scripts_dir)
import agent_validator as av  # noqa: E402

errors: list[str] = []


def rows(path: str, heading: str) -> list[str]:
    """heading 바로 뒤에 오는 마크다운 표의 행들을 돌려준다."""
    text = Path(path).read_text(encoding="utf-8")
    if heading not in text:
        errors.append(f"{path} 에 '{heading}' 절이 없다")
        return []
    collected: list[str] = []
    for line in text.split(heading, 1)[1].splitlines():
        if line.startswith("|"):
            collected.append(line)
        elif collected:
            break
    return collected


def first_code_cells(lines: list[str]) -> set[str]:
    """각 행의 첫 백틱 셀만 모은다. 표의 좌열이 필드/분류 이름이다."""
    found = set()
    for line in lines:
        match = re.match(r"\|\s*`([^`]+)`", line)
        if match:
            found.add(match.group(1))
    return found


doc_fields = first_code_cells(rows(format_doc, "## frontmatter 필드"))
missing = av.CLAUDE_KEYS - doc_fields
extra = doc_fields - av.CLAUDE_KEYS
if missing:
    errors.append(f"agent-format.md 필드 표에 빠진 키: {sorted(missing)}")
if extra:
    errors.append(f"agent-format.md 필드 표에만 있고 검증기가 모르는 키: {sorted(extra)}")

skill_fields = first_code_cells(rows(skill_md, "## subagent 정의 형식"))
unknown_skill_fields = skill_fields - av.CLAUDE_KEYS
if unknown_skill_fields:
    errors.append(f"SKILL.md 필드 표에 검증기가 모르는 키: {sorted(unknown_skill_fields)}")

doc_tools = {
    name
    for line in rows(format_doc, "## 대표 tools 이름")
    for name in re.findall(r"`([^`]+)`", line)
    if not name.startswith("mcp__")
}
unknown_tools = doc_tools - av.CORE_TOOLS
if unknown_tools:
    errors.append(f"agent-format.md 도구 표에 검증기가 모르는 도구: {sorted(unknown_tools)}")

for error in errors:
    print(f"  [error] {error}")
sys.exit(1 if errors else 0)
PY

"${RUN[@]}" "$TMP_ROOT/consistency.py" "$FORMAT_DOC" "$SKILL_MD" "$SKILL_DIR/scripts" \
    || fail "문서의 표와 검증기의 상수 집합이 어긋난다"
echo "  ✓ 필드·도구 표가 검증기와 일치"

echo
echo "PASS — smoke"
