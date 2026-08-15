# Agent Skills

**Agent Skills for Claude Code, Codex and other coding agents.**

[![Agent Skills Spec](https://img.shields.io/badge/Agent%20Skills-Specification-blue)](https://agentskills.io)

## Quickstart

Install skills with the default [`skills` CLI](https://github.com/vercel-labs/skills) flow:

```bash
npx skills add pubcyberry/skills
```

The CLI runs through npx and prompts you to choose a skill and install destination. You do not need to clone this repo or copy skill folders by hand.

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

For non-interactive installs, global installs, agent-specific installs, updates, removals, and fallback manual copying, see [Advanced installation](docs/advanced-install.md).

---

## Skill Catalog

<!-- skills-table-start -->
| Skill | Description | Language |
|-------|-------------|----------|
| [`repo-scaffold`](skills/repo-scaffold/SKILL.md) | Scaffolds a repository so agents navigate it by reading its docs instead of guessing. Generates the `AGENTS.md` document index, the `docs/` hierarchy (`standards` / `guides` / `references` / `generated`) with a front matter convention, and pre-commit hooks that keep it from rotting (doc convention, `.env` key sync, credential scan). Also drops in `.gitattributes`, `.editorconfig`, `.gitignore`, `.env.example`, and `SECURITY.md`. | Korean |
<!-- skills-table-end -->

The table between the `skills-table` markers is the source of truth for the catalog. Update it in the same commit that adds or renames a skill.

## Repository Structure

```
.
├── README.md
├── docs/
│   └── advanced-install.md     # non-interactive, global, and manual installs
└── skills/
    └── repo-scaffold/
        ├── SKILL.md            # entry point — frontmatter + instructions
        ├── assets/             # files the skill copies into a target repo
        ├── references/         # detail docs loaded on demand
        └── tests/              # smoke test for the skill
```

Every skill is a self-contained directory under `skills/`, entered through its `SKILL.md`. The `name` and `description` in that file's frontmatter are what an agent matches against to decide whether to activate the skill, so `description` carries the trigger phrases — and, just as importantly, the cases where the skill should *not* fire.

Anything beyond `SKILL.md` is loaded only after activation. Keep `SKILL.md` short and push detail into `references/`; that is what the progressive disclosure model below buys you.

## Standards & Compatibility

This repository adheres to the [Agent Skills specification](https://agentskills.io/specification):

- Skills are portable directories with a `SKILL.md` file at their root.
- Metadata uses YAML frontmatter with required `name` and `description` fields.
- Skills follow a progressive disclosure model — lightweight metadata loads at startup, full instructions load on activation.
- Validate your skill using the [`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref) reference library.

## Adding a Skill

1. Create `skills/<name>/SKILL.md`. Use the directory name as `name` — kebab-case, matching the folder exactly.
2. Write the `description` as *when to use this / when not to use this*. Trigger accuracy comes from that pairing; a description that only states what the skill does will misfire.
3. Put anything long — reference tables, worked examples, per-scenario detail — under `references/` and link to it from `SKILL.md`.
4. Add a smoke test under `tests/` if the skill ships scripts.
5. Add one row to the Skill Catalog table above.

Before opening a PR, validate the skill with `skills-ref` and confirm the agent activates it from a realistic prompt, not just from the skill name.

## License

MIT. See [LICENSE](LICENSE).
