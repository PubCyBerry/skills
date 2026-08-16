# Skill Card — `subagent-creator`

## Description

Claude Code 의 subagent 정의 파일(`.claude/agents/<name>.md`)을 설계해 쓰고 형식을 검증한다.
위임 트리거가 되는 `description`, 최소 권한 `tools`, 모델 선택, 시스템 프롬프트를 순서대로 정한 뒤
정의 파일을 쓰고 검증기로 형식 오류를 잡는다.

This skill is ready for commercial and non-commercial use under the MIT license.

## Owner

PubCyBerry — <https://github.com/pubcyberry>

## License / Terms of Use

MIT. See [LICENSE](../../LICENSE).

## Use Case

반복 작업을 subagent 로 떼어내려는 Claude Code 사용자. 목표는 "동작하는 정의 파일"이 아니라
**의도한 순간에 실제로 위임되는** 정의 파일이다. `description` 이 부실하면 파일은 유효해도
영원히 호출되지 않으므로, 절차의 무게가 거기에 실려 있다.

## Deployment Geography

Global.

## Requirements / Dependencies

- 정의 파일 작성 자체는 의존성이 없다. Markdown 파일 하나를 쓴다.
- 검증 단계만: Python 3.11+ 와 PyYAML. 문서화된 호출은 `uv run --with pyyaml --python 3.11` 이라
  호스트 환경에 아무것도 설치하지 않는다. `uv` 나 Python 이 없으면 검증은 SKIP 이고,
  스킬은 건너뛴 사실을 사용자에게 알린다.
- **Requires API key or external credential:** No
- **Credential type(s):** None

프롬프트, 로그, 출력에 비밀값을 넣지 않는다.

## Known Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| 같은 이름의 기존 정의 파일을 덮어쓸 수 있다 | 절차 4단계가 쓰기 전 기존 파일 확인을 요구한다 |
| 전역(`~/.claude/agents/`)에 써서 모든 프로젝트에 영향을 준다 | 기본값은 프로젝트 범위다. 전역은 사용자가 명시할 때만 |
| 생성된 subagent 에 과한 도구 권한이 실린다 | `tools` 최소 권한이 절차와 모범 사례 양쪽에 명시되어 있다. 생략 시 전체 상속이라는 점도 경고한다 |
| 필드·도구 표가 Claude Code 릴리스보다 낡는다 | 검증기의 상수 집합이 단일 출처다. `tests/smoke.sh` 가 표와 검증기의 불일치를 잡는다 |
| 검증기가 없어 형식 오류가 그대로 남는다 | 검증 SKIP 은 조용히 넘어가지 않고 사용자에게 보고된다 |
| 생성된 시스템 프롬프트가 위임받은 컨텍스트에서 임의 지시를 수행한다 | 절차 3단계가 "경계"(범위 밖의 일)를 필수 항목으로 요구한다 |

## References

- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code tools reference](https://code.claude.com/docs/en/tools-reference)
- [Agent Skills specification](https://agentskills.io/specification)
- [`skills` CLI](https://github.com/vercel-labs/skills)

## Skill Output

- **Output type(s):** 생성된 Markdown 정의 파일, 터미널 검증 리포트(PASS/FAIL)
- **Output format:** `<scope>/.claude/agents/<name>.md` 파일 + `validate_subagent.py` 의 PASS/FAIL 출력
- **Side effects:** 사용자가 지정한 범위(프로젝트 기본, 전역은 명시 시)에만 파일을 쓴다.
  검증은 읽기 전용이다

## Evaluation

- **Task set:** [`evals/evals.json`](evals/evals.json) — 6 tasks (4 positive activation, 2 negative activation)
- **Automated tests:** [`tests/smoke.sh`](tests/smoke.sh) — 검증기가 정상 정의를 통과시키고
  frontmatter 누락, 이름 불일치, 알 수 없는 키/도구, enum 밖의 값, 빈 본문을 각각 잡는지 확인.
  CI 에서 매 PR 실행
- **Live agent benchmark:** 아직 실행하지 않았다. `BENCHMARK.md` 가 없는 이유이며, 태스크셋은
  평가 러너가 붙는 즉시 돌릴 수 있도록 미리 넣어 두었다. 성능 수치를 인용하지 말 것.

## Skill Version

소스 커밋 SHA 로 추적한다 — `git log -1 --format=%h -- skills/subagent-creator`.
