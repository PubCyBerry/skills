# 기여 가이드

이 저장소는 **카탈로그**다. 스킬 원본은 각자의 소스 저장소에 있고, 여기 `skills/` 는 미러다.

```
소스 저장소 (원본)  ──sync──▶  이 저장소 skills/  ──▶  npx skills add / 플러그인 / skills.sh
   여기서 고친다                자동 생성. 손대지 않는다
```

`skills/` 아래를 직접 고치면 다음 sync 에 덮어써진다. 스킬 내용 변경은 소스 저장소에서 한다.

## 무엇을 어디서 고치나

| 하려는 일 | 고칠 곳 |
| --- | --- |
| 스킬 내용, 트리거, 자산 | 소스 저장소의 `skills/<name>/` |
| 새 소스 저장소 등록 | 이 저장소의 `components.d/<slug>.yml` |
| 카탈로그 그룹 추가·변경 | `.github/scripts/skill-groups.yml` |
| 플러그인 메타데이터 | `plugins.d/<plugin>.yml`, `plugins.d/_defaults.yml` |
| 등록 없이 남겨야 하는 디렉터리 | `catalog-exceptions.yml` |
| README 표, `skills.sh.json`, `plugins/`, `marketplace.json` | **직접 고치지 않는다.** 생성물이다 |

## 새 스킬 온보딩

1. 소스 저장소에 스킬을 만든다. 필수 산출물 세 가지를 갖춘다.

   | 파일 | 없으면 |
   | --- | --- |
   | `SKILL.md` | 스킬이 아니다 |
   | `skill-card.md` | 설치하는 쪽이 소유자·라이선스·위험을 알 수 없다 |
   | `evals/evals.json` | 발동 정확도에 대한 증거가 없다 |

2. 이 저장소에 `components.d/<slug>.yml` 을 추가한다. 스키마는 [components.d/README.md](components.d/README.md).
3. PR 을 연다. CI 가 등록 파일을 검증하고, 다음 sync 가 스킬을 끌어온다.

sync 는 세 산출물 중 하나라도 없는 스킬을 **드롭한다.** 조용히 넘어가지 않고 PR 본문에 이유를 남긴다.

## `description` 작성 규칙

발동 정확도는 전부 `description` 에서 결정된다. 무엇을 하는 스킬인지만 적으면 반드시 오발동한다.
세 가지를 모두 담는다.

| 요소 | 이유 |
| --- | --- |
| 무엇을 하는가 | 후보에 오르기 위해 |
| **언제 발동하는가** | 스킬 이름을 말하지 않는 실제 문장을 그대로 넣는다. 한국어와 영어 둘 다 |
| **언제 발동하지 않는가** | 인접한 요청을 명시적으로 다른 곳으로 보낸다. 이게 없으면 과발동한다 |

1024자를 넘기지 않는다. `validate-skills.sh` 가 검사한다.

## frontmatter 필수 필드

```yaml
---
name: <디렉터리 이름과 정확히 같은 kebab-case>
description: >-
  <위 규칙대로>
license: MIT
compatibility: >-
  <전제 조건. OS, 필요한 CLI, 네트워크 사용 여부>
metadata:
  kind: workflow | library | reference
  language: ko | en
  group: <.github/scripts/skill-groups.yml 의 key>
  summary: <카탈로그 표에 들어갈 한 줄>
  tags: [<검색용>]
---
```

`metadata.group` 이 `skill-groups.yml` 에 없는 key 면 카탈로그 생성이 실패한다.
새 그룹이 필요하면 `skill-groups.yml` 에 먼저 추가한다.

## `evals/evals.json`

```json
{
  "skill_name": "<디렉터리 이름>",
  "evals": [
    {
      "id": "<skill>.<kind>.<lang>.vN",
      "prompt": "실제 사용자가 칠 법한 문장",
      "expected_skill": "<skill>",
      "expected_output": "기대 동작 한 문장",
      "assertions": ["검증 가능한 진술"]
    }
  ]
}
```

- `expected_skill: null` = **발동하면 안 되는** 케이스. 최소 1개 필수. CI 가 검사한다.
- positive 는 명시 호출 하나로 끝내지 않는다. 스킬 이름을 말하지 않는 암묵 표현을 언어별로 넣는다.

negative 케이스가 요점이다. positive 만 있는 태스크셋은 과발동을 영원히 못 잡는다.

## PR 전 검증

```bash
bash .github/scripts/validate-skills.sh
bash .github/scripts/gen-catalog.sh --check
bash .github/scripts/build-plugins.sh --check
```

생성물이 `--check` 에서 걸리면 `--check` 없이 다시 돌려 결과를 같은 커밋에 포함한다.

의존: `bash`, `git`, [`yq`](https://github.com/mikefarah/yq) v4, `jq`.

## 커밋

Conventional Commits 를 쓴다.

```
feat: onboard <product> skills
fix: correct the catalog_dir for <skill>
chore: sync skills (<component>)
docs: clarify the eval task set contract
```
