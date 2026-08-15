<!-- SPDX-License-Identifier: MIT -->

# `components.d/` — 소스 저장소 등록부

스킬의 **원본은 각자의 저장소**에 있고, 이 카탈로그는 미러다.
여기에 파일을 하나 추가하면 [sync 워크플로](../.github/workflows/sync-skills.yml)가
매일 그 저장소에서 스킬을 끌어와 `skills/<catalog_dir>/` 에 넣는다.

```
pubcyberry/<source-repo>          components.d/<slug>.yml        이 저장소
  skills/<skill>/     ──등록──▶      path + catalog_dir    ──sync──▶  skills/<catalog_dir>/
  (여기서 편집)                                                        (자동 생성. 손대지 않는다)
```

**컴포넌트 하나에 파일 하나**인 이유는 동시 온보딩 PR 이 같은 파일을 건드리지 않게 하기 위해서다.
공유 파일 하나에 몰아넣으면 등록이 늘수록 충돌이 난다.

## 새 소스 저장소 등록

1. `components.d/<slug>.yml` 을 만든다. `<slug>` 는 소문자 kebab-case.
2. 아래 필드를 채운다.
3. PR 을 연다. 다음 sync 부터 자동으로 끌어온다.

## 필수 필드

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | README 에 표시될 이름 |
| `repo` | string | GitHub 저장소 (`owner/repo`) |
| `description` | string | 한 줄 설명 |
| `skills` | list | 스킬 소스 위치. 스킬 하나당 한 항목 |

`skills:` 의 각 항목:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `path` | string | 소스 저장소에서 `SKILL.md` 를 루트에 가진 디렉터리 |
| `catalog_dir` | string | 이 카탈로그의 `skills/` 아래 디렉터리 이름. 전체에서 유일해야 한다 |

## 선택 필드

| 필드 | 기본값 | 설명 |
| --- | --- | --- |
| `ref` | `main` | 동기화할 브랜치 |
| `links.contributing` | `CONTRIBUTING.md` | 소스 저장소의 기여 가이드 경로 |
| `links.security` | `true` | 소스 저장소에 `SECURITY.md` 가 없으면 `false` |

## 예시

```yaml
# components.d/my-product.yml
name: My Product
repo: pubcyberry/my-product
description: 한 줄 설명.
skills:
  - path: skills/my-product-setup/
    catalog_dir: my-product-setup
  - path: skills/my-product-deploy/
    catalog_dir: my-product-deploy
```

`path` 는 **스킬 하나**를 가리킨다. 부모 디렉터리를 가리켜 여러 스킬을 한꺼번에 담지 않는다.
스킬마다 카탈로그 최상위 디렉터리를 하나씩 갖는 편이 검색과 설치 양쪽에서 낫다.

## 동기화되려면 갖춰야 하는 것

sync 는 아래를 모두 갖춘 스킬만 카탈로그에 넣는다. 하나라도 없으면 그 스킬은 드롭되고,
PR 본문에 이유가 남는다.

| 산출물 | 이유 |
| --- | --- |
| `SKILL.md` | 스킬의 정의. 없으면 스킬이 아니다 |
| `skill-card.md` | 소유자, 라이선스, 알려진 위험. 설치하는 쪽이 판단할 근거 |
| eval 태스크셋 | `evals/*.json`, `eval/*.json`, `benchmark/evals.json` 중 하나. 발동 정확도의 증거 |

## 등록 해제

`components.d/<slug>.yml` 에서 항목을 지우면 다음 sync 때 `skills/<catalog_dir>/` 도 삭제된다
([prune-orphans.sh](../.github/scripts/prune-orphans.sh)).
등록 없이 카탈로그에 남아야 하는 디렉터리는 루트의 [`catalog-exceptions.yml`](../catalog-exceptions.yml)에
사유와 함께 적는다. 그러지 않으면 정리 대상이 된다.
