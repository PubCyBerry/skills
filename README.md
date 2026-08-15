# skills

Claude Code Agent Skills 모음.

## 구조

```
.
├── README.md
└── skills/
    └── repo-scaffold/     # 저장소를 에이전트 친화적으로 스캐폴딩
```

각 스킬은 `skills/<name>/SKILL.md` 를 진입점으로 갖는다. `SKILL.md` 의 front matter `name`, `description` 이 스킬 트리거 조건을 정의한다.

## 스킬 목록

| 스킬 | 설명 |
| --- | --- |
| [repo-scaffold](skills/repo-scaffold/SKILL.md) | AGENTS.md 문서 인덱스 자동 생성, `docs/` 계층과 front matter 규약, pre-commit 검증 훅(문서 규약 / `.env` 키 동기화 / 자격 증명 스캔), `.gitattributes`, `.editorconfig`, `.gitignore`, `.env.example`, `SECURITY.md` 를 세팅한다. |

## 설치

Claude Code 가 스킬을 인식하려면 `~/.claude/skills/` 아래에 두어야 한다.

```bash
git clone https://github.com/PubCyBerry/skills.git
ln -s "$(pwd)/skills/skills/repo-scaffold" ~/.claude/skills/repo-scaffold
```

프로젝트 단위로만 쓰려면 `~/.claude/skills` 대신 해당 저장소의 `.claude/skills/` 에 연결한다.

## 스킬 추가

1. `skills/<name>/SKILL.md` 를 만든다.
2. front matter 에 `name`, `description` 을 채운다. `description` 은 "언제 쓰는지 / 언제 쓰지 않는지" 를 함께 적어야 트리거 정확도가 오른다.
3. 위 스킬 목록 표에 한 줄 추가한다.
