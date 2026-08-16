# Agent Skills

**Agent Skills for Claude Code, Codex and other coding agents.**

[![Agent Skills Spec](https://img.shields.io/badge/Agent%20Skills-Specification-blue)](https://agentskills.io)

## Quickstart

Install skills with the default [`skills` CLI](https://github.com/vercel-labs/skills) flow:

```bash
npx skills add pubcyberry/skills
```

The CLI runs through npx and prompts you to choose a skill and install destination. You do not need to clone this repo or copy skill folders by hand.

Requires `skills` CLI **1.5.16 or newer** — earlier versions install the files but never link them into Claude Code. Use `npx skills@latest add ...` if you are unsure which version you have.

### Install for a Specific Agent

Use `--agent` to target a specific AI coding agent. Initially, we'll support common client targets, expanding the list over time. For the full list of clients supported by the spec, see the [`skills` CLI Supported Agents table](https://github.com/vercel-labs/skills#supported-agents).

**Claude Code**

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code
```

**Codex**

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent codex
```

**Antigravity**

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent antigravity
```

**Cursor**

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent cursor
```

**Kiro**

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent kiro-cli
```

Use `--agent` more than once to install the same skill into multiple agents.

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code \
  --agent codex \
  --agent antigravity \
  --agent cursor \
  --agent kiro-cli
```

### Keep Skills Up to Date

New skills land continuously, and existing ones are revised, renamed, or consolidated as the catalog evolves. Refresh what you have installed with:

```bash
npx skills update
```

### Browse the Catalog

Use this when you want to see the skills available in this repository before installing anything.

```bash
npx skills add pubcyberry/skills --list
```

### Install as a Plugin

Every skill in this catalog is also packaged as a plugin, which installs them together instead of one at a time.

**Claude Code**

```
/plugin marketplace add pubcyberry/skills
/plugin install pubcyberry-skills@pubcyberry
```

**Codex**

```bash
codex plugin marketplace add pubcyberry/skills
codex plugin add pubcyberry-skills
```

The plugin tree under [`plugins/`](plugins/) is generated from `plugins.d/`; the skills inside it are copies of the canonical ones under `skills/`.

For non-interactive installs, global installs, agent-specific installs, updates, removals, and fallback manual copying, see [Advanced installation](docs/advanced-install.md).

---

## Skill Catalog

<!-- skills-table-start -->
| Skill | Group | Kind | Lang | Summary |
|-------|-------|------|------|---------|
| [`repo-scaffold`](skills/repo-scaffold/SKILL.md) | Repository Tooling | workflow | ko | 에이전트가 문서로 저장소를 탐색하게 만드는 구조를 세우고 커밋 훅으로 고정한다. |
| [`subagent-creator`](skills/subagent-creator/SKILL.md) | Agent Authoring | workflow | ko | Claude Code subagent 정의 파일을 위임 트리거부터 시스템 프롬프트까지 설계해 쓰고 형식을 검증한다. |
<!-- skills-table-end -->

The table between the `skills-table` markers is **generated** from each skill's `SKILL.md` frontmatter by `.github/scripts/gen-catalog.sh`. Do not edit it by hand — CI fails the PR when it drifts from the skills it describes.

## How This Catalog Works

Each skill's source of truth is its own repository. This repo is a distribution surface: it mirrors registered skills daily, checks that each one carries the artifacts a user needs in order to judge it, and republishes them through every install channel.

```
pubcyberry/<source-repo>       components.d/<slug>.yml        this repo
  skills/<skill>/     ──register──▶   path + catalog_dir  ──sync──▶  skills/<catalog_dir>/
  (edited here)                                                       (generated — do not edit)
                                                                            │
                                          ┌─────────────────────────────────┼─────────────────────┐
                                          ▼                                 ▼                     ▼
                                    npx skills add                    plugin install         skills.sh
                                  (reads skills/)                 (reads plugins/)      (reads skills.sh.json)
```

A skill is mirrored only when it ships all three of these. Anything missing one is dropped by the sync, with the reason recorded in the sync PR:

| Artifact | Why it is required |
|---|---|
| `SKILL.md` | The skill itself. Its `name` and `description` decide when an agent activates it |
| `skill-card.md` | Owner, license, use case, known risks and mitigations, output shape — what a reviewer needs before installing |
| `evals/evals.json` | Activation task set. Must include at least one negative case, or nothing measures over-triggering |

## Repository Structure

```
.
├── README.md                     # Skill Catalog table is generated
├── skills.sh.json                # generated — skills.sh marketplace grouping
├── catalog-exceptions.yml        # skills/ dirs allowed to exist unregistered
├── components.d/                 # source-repo registry — one file per repo
│   ├── README.md                 # schema and onboarding
│   └── <slug>.yml
├── plugins.d/                    # plugin build config
│   ├── _defaults.yml             # fields shared by every plugin
│   ├── _marketplace.yml          # marketplace-level metadata
│   └── <plugin>.yml
├── plugins/                      # generated — plugin distribution tree
│   └── pubcyberry-skills/
├── .claude-plugin/               # generated — Claude Code marketplace
├── .cursor-plugin/               # generated — Cursor marketplace
├── .agents/plugins/              # generated — spec-compliant agent marketplace
├── docs/
│   └── advanced-install.md       # non-interactive, global, and manual installs
├── skills/                       # mirrored skills — edit at the source repo
│   ├── repo-scaffold/
│   └── subagent-creator/
└── .github/
    ├── scripts/                  # gen-catalog.sh, build-plugins.sh,
    │                             # prune-orphans.sh, validate-skills.sh
    └── workflows/                # validate.yml, sync-skills.yml
```

Every skill is a self-contained directory under `skills/`, entered through its `SKILL.md`. The `name` and `description` in that file's frontmatter are what an agent matches against to decide whether to activate the skill, so `description` carries the trigger phrases — and, just as importantly, the cases where the skill should *not* fire.

Anything beyond `SKILL.md` is loaded only after activation. Keep `SKILL.md` short and push detail into `references/`; that is what the progressive disclosure model below buys you.

### Generated files

Four surfaces are generated from the skills and the config in `components.d/` and `plugins.d/`. Regenerate them with:

```bash
bash .github/scripts/gen-catalog.sh      # README table + skills.sh.json
bash .github/scripts/build-plugins.sh    # plugins/ + the three marketplace.json files
```

Both take `--check`, which reports drift and changes nothing. That is what CI runs.

## Standards & Compatibility

This repository adheres to the [Agent Skills specification](https://agentskills.io/specification):

- Skills are portable directories with a `SKILL.md` file at their root.
- Metadata uses YAML frontmatter with required `name` and `description` fields.
- Skills follow a progressive disclosure model — lightweight metadata loads at startup, full instructions load on activation.
- Validate your skill using the [`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref) reference library.

## Adding a Skill

Skills are authored in their own repository, not here. Onboarding is one file:

1. In the source repo, put the skill at `skills/<name>/` with `SKILL.md`, `skill-card.md`, and `evals/evals.json`.
2. In this repo, add `components.d/<slug>.yml` pointing at that repo and path — see [`components.d/README.md`](components.d/README.md).
3. Open a PR. The next sync mirrors the skill and regenerates every catalog surface.

`skills/` here is a mirror. A change made to it directly is overwritten on the next sync.

Details on writing the `description`, the eval task set, and the required artifacts are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Validating Locally

```bash
bash .github/scripts/validate-skills.sh    # frontmatter, artifacts, registrations
bash .github/scripts/gen-catalog.sh --check
bash .github/scripts/build-plugins.sh --check
```

Dependencies: `bash`, `git`, [`yq`](https://github.com/mikefarah/yq) v4, `jq`.

## License

MIT. See [LICENSE](LICENSE).
