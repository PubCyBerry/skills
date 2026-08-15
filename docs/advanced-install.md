---
title: "Advanced Installation"
description: "Install, update, and remove skills from this catalog with control over agent, scope, and non-interactive workflows."
---

# Advanced installation

Use this guide when you need more control than the [root README quickstart](../README.md#quickstart): non-interactive installs, specific agents, global vs. project scope, updates, removals, or a manual fallback.

## Requirements

- Node.js and npm on your `PATH`. The examples use `npx`, which ships with npm.
- A current `skills` CLI — **version 1.5.16 or newer**. `npx skills@latest` always resolves to the latest. Versions 1.5.15 and earlier do not create the Claude Code skills link, so installed skills never appear in Claude Code. Codex and other agents that read `.agents/skills/` directly are unaffected, which is why this failure looks agent-specific.
- Access to `https://github.com/PubCyBerry/skills`.
- An agent that supports Agent Skills — Claude Code, Codex, Antigravity, Cursor, Kiro, OpenCode, Windsurf, Gemini CLI, or another compatible client.

## List skills before installing

```bash
npx skills add pubcyberry/skills --list
```

Use this to inspect the catalog before committing to a skill.

## Install one skill

```bash
npx skills add pubcyberry/skills --skill repo-scaffold
```

The value for `--skill` is the `name:` field from that skill's `SKILL.md`. In this catalog the layout is flat — `skills/<name>/SKILL.md` — and `name` always matches the folder, so the folder name works as the skill name.

Install several in one call by repeating `--skill`:

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code
```

## Install to a specific agent

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code
npx skills add pubcyberry/skills --skill repo-scaffold --agent codex
npx skills add pubcyberry/skills --skill repo-scaffold --agent antigravity
npx skills add pubcyberry/skills --skill repo-scaffold --agent cursor
npx skills add pubcyberry/skills --skill repo-scaffold --agent kiro-cli
```

`--agent` can be passed more than once:

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code \
  --agent codex \
  --agent antigravity
```

For the full list of client targets, see the [`skills` CLI Supported Agents table](https://github.com/vercel-labs/skills#supported-agents).

## Choose project or global scope

Project scope is the default. It links the skill into the current project's agent-specific skills directory, so the skill travels with the repository.

```bash
npx skills add pubcyberry/skills --skill repo-scaffold
```

Global scope makes the skill available across every project for the selected agent:

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code \
  --global
```

| Scope | Flag | Use when |
| --- | --- | --- |
| Project | default | The skill encodes conventions of *this* repository, and you want teammates and CI agents to pick it up from the checkout. |
| Global | `--global` | The skill is part of how *you* work, in every repository. |

Avoid installing the same skill at both scopes. The two copies drift, and which one an agent prefers is client-specific — the symptom is an agent following instructions you already fixed.

## Non-interactive install

Use `--yes` when scripting setup or bootstrapping a dev environment. Without it the CLI prompts, which stalls in CI where there is no TTY to answer.

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code \
  --global \
  --yes
```

## Update or remove installed skills

```bash
# See installed skills
npx skills list

# Check for updates without applying them
npx skills check

# Update all installed skills
npx skills update

# Remove a skill
npx skills remove repo-scaffold
```

`update` re-fetches from the source repository and overwrites the installed copy, so local edits to an installed skill are lost. To modify a skill, fork this repository and install from the fork:

```bash
npx skills add <your-user>/skills --skill repo-scaffold --agent claude-code
```

`remove` operates on the scope you point it at. Removing without `--global` leaves a global copy in place, which reads as a skill that refuses to uninstall.

## Manual fallback

Prefer `npx skills add` — it resolves agent directories, handles project vs. global scope, and keeps skills updatable. Copy by hand only when Node.js or npm is unavailable, or when the CLI does not target your agent yet.

1. Open [`skills/`](../skills/) and find the directory containing `SKILL.md`.
2. Copy that whole directory — `SKILL.md` alone is not enough, since `assets/`, `references/`, and `tests/` are loaded after activation.
3. Place it in your agent's skills directory.

Common global locations:

| Agent | Global skills directory |
|-------|-------------------------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |

```bash
git clone https://github.com/PubCyBerry/skills.git
cp -r skills/skills/repo-scaffold ~/.claude/skills/repo-scaffold
```

To track the repository instead of freezing a copy, symlink it and `git pull` when you want updates:

```bash
git clone https://github.com/PubCyBerry/skills.git ~/src/skills
ln -s ~/src/skills/skills/repo-scaffold ~/.claude/skills/repo-scaffold
```

Windows needs Developer Mode or an elevated shell for symlinks; without either, use `cp -r` and re-copy after each pull.

Manual installs do not participate in `npx skills update`. Treat them as a fallback, not a default.

## Troubleshooting

### Installed skills don't appear in your agent

1. **Check the CLI version first.** Run `npx skills --version`. If it is older than **1.5.16**, re-run the install through `npx skills@latest ...`. Versions 1.5.15 and earlier fail to link skills into Claude Code's `.claude/skills/` directory — the files install, but the agent never sees them.
2. **Reload skills in your session.** In Claude Code, run `/reload-skills`, or restart the session, so newly installed skills are picked up.

### Verify your agent can see an installed skill

After installing `<skill-name>`, confirm it landed where your agent looks:

| Agent | Check |
|-------|-------|
| Claude Code | `.claude/skills/<skill-name>/SKILL.md` resolves (project) or `~/.claude/skills/<skill-name>/SKILL.md` (global); the skill also shows up in `/skills`. |
| Codex | `.agents/skills/<skill-name>/SKILL.md` resolves — Codex reads `.agents/skills/` directly, so no per-agent link is needed. |

If `.claude/skills/<skill-name>` is missing or empty on Claude Code, it is almost always the stale-CLI issue above: upgrade to 1.5.16+ and re-run the install.

### The skill is installed but never activates

This looks identical to a failed install from the outside, so rule out the checks above first. If the file is present and the agent lists it, the problem is the trigger, not the install: the `description` in `SKILL.md` is what the agent matches a prompt against. If the skill only fires when you name it directly, the description is too narrow — it needs the phrasings a user would actually type, plus the cases where the skill should *not* fire.
