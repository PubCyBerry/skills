# Advanced installation

The [README quickstart](../README.md#quickstart) covers the interactive path. This page covers everything else: scripted installs, global installs, updates, removals, and the manual fallback when the CLI is not an option.

## Non-interactive installs

Pass `--skill` and `--agent` so the CLI has nothing left to prompt for. Add `--yes` to accept the remaining defaults — required in CI, where there is no TTY to answer with.

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code \
  --yes
```

Install several skills in one call by repeating `--skill`:

```bash
npx skills add pubcyberry/skills \
  --skill repo-scaffold \
  --agent claude-code \
  --agent codex \
  --yes
```

## Project vs. global installs

A skill lands in one of two places, and the difference matters more than it looks.

| Scope | Flag | Destination (Claude Code) | Use when |
| --- | --- | --- | --- |
| Project | default | `.claude/skills/<name>/` | The skill encodes conventions of *this* repository, and you want it committed so teammates and CI agents get it too. |
| Global | `--global` | `~/.claude/skills/<name>/` | The skill is part of how *you* work, across every repository. |

```bash
# project — commit the result
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code

# global — applies everywhere for your user
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code --global
```

Other agents use their own directories (`.codex/skills/`, `.cursor/skills/`, and so on); the CLI resolves the right one from `--agent`.

Do not install the same skill both globally and per-project. Two copies drift, and which one wins is agent-specific — the failure shows up as an agent following instructions you already fixed.

## Updating

```bash
npx skills update                    # every installed skill
npx skills update --skill repo-scaffold
```

`update` re-fetches from the source repository and overwrites the installed copy. Local edits to an installed skill are lost. If you want to modify a skill, fork this repository and install from the fork instead:

```bash
npx skills add <your-user>/skills --skill repo-scaffold --agent claude-code
```

## Removing

```bash
npx skills remove repo-scaffold
npx skills remove repo-scaffold --global
```

Scope has to match the install. Removing without `--global` leaves a global copy in place, which then looks like a skill that refuses to uninstall.

## Listing what is installed

```bash
npx skills list                      # installed locally
npx skills add pubcyberry/skills --list   # available in this repository
```

## Manual installation

Use this when the CLI cannot run — an offline machine, a locked-down npm registry, or an agent the CLI does not target yet. A skill is a plain directory, so copying it is enough.

```bash
git clone https://github.com/PubCyBerry/skills.git
cp -r skills/skills/repo-scaffold ~/.claude/skills/repo-scaffold
```

To track the repository instead of freezing a copy, symlink it and pull when you want updates:

```bash
git clone https://github.com/PubCyBerry/skills.git ~/src/skills
ln -s ~/src/skills/skills/repo-scaffold ~/.claude/skills/repo-scaffold
```

Windows needs Developer Mode or an elevated shell for symlinks; without either, use `cp -r` and re-copy after `git pull`.

Restart the agent, or reload its skill list, after copying — most agents read the skill directory at startup.

## Verifying an install

Two things can go wrong, and they look identical from the outside: the skill is not installed, or it is installed but never triggers.

1. Confirm the file exists: `ls ~/.claude/skills/repo-scaffold/SKILL.md`
2. Confirm the agent sees it — in Claude Code, `/skills` lists what is loaded.
3. Confirm it activates from a realistic prompt, not from the skill's name. If it only fires when you say "repo-scaffold", the `description` is too narrow; broaden its trigger phrases.
