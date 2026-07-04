---
name: convention-mapper
description: Use when the user explicitly asks to map, extract, refresh, or (re)generate per-repo code-convention skills for a repository — e.g. "/convention-mapper", "map conventions for <repo>", "update the convention skills for <repo>". Manual invocation only, never automatic. Works on any repo; first target is a Next.js host with Vue web components.
---

# convention-mapper

## Overview
Meta-skill that generates and updates per-repo, per-domain code-convention skills
on demand. The generated skills make future Claude Code work in that repo more
assertive, faster, and cheaper in tokens.

**Core principle — divide by what each side is good at:**
- **Bash does the mechanical work:** list structure, count repeated patterns, locate
  example files per domain, flag emergent domains by evidence.
- **Claude does the judgment:** why a pattern exists, when to break it, what counts as
  an anti-pattern. Structure alone never decides a convention.

## When to use
- User runs `/convention-mapper` or asks to map/refresh convention skills for a repo.
- After large changes to a repo you have already mapped (re-run to update).

**Not** for: automatic/background runs, general code review, or one-off questions.
Only run when explicitly asked.

## Process

1. **Get the target repo path.** Use the argument; if absent, ask for it.
2. **Scan (mechanical):**
   ```
   bash ~/.claude/skills/convention-mapper/scripts/scan-repo.sh <repo-path>
   ```
   Capture the JSON. `repo.slug` is the skill prefix; `repo.path` is the base for the
   relative `examples` paths.
3. **Read real examples (judgment).** For each domain, read the files in its `examples`
   array. See [references/domain-guide.md](references/domain-guide.md) for what bash
   already found vs. what you must extract per domain.
4. **Decide the domain set:**
   - All six guaranteed domains: `componentes`, `rotas`, `data-fetching`,
     `dependency-sourcing`, `configuration-contract`, `testes`.
   - Each emergent domain (`state-management`, `estilizacao`, `build-config`, …) **only
     if** `detected: true` AND the examples confirm a repeated, verifiable pattern.
     Never infer a convention with no evidence in the code.
5. **Generate or update each skill** at `~/.claude/skills/{slug}-{domain}/SKILL.md`
   following [references/generated-skill-template.md](references/generated-skill-template.md):
   lean SKILL.md (rule + when-to-apply + one real example), extra examples in a sibling
   `examples.md`, mandatory anti-patterns & exceptions section, real code copied from the
   repo with `path` refs, **no comments in the copied code**.
6. **Idempotent update:** if `{slug}-{domain}/SKILL.md` already exists, edit it in place —
   refresh rules and examples, do not create a duplicate or a `-v2`.
7. **Report** which skills were created vs. updated, and which emergent domains were
   skipped for lack of repeated evidence.

## Division of work

| Mechanical (bash / scan) | Judgment (Claude) |
|---|---|
| List folder structure, prune noise | Why the structure is shaped this way |
| Count repeated patterns per domain | Which count means "this is the convention" |
| Locate example files by domain | Read them; pick the representative one |
| Flag emergent domains by threshold | Confirm it is a real repeated pattern |
| Detect stack (Next router, Vue, monorepo) | Cross-framework boundary conventions |

## Design guidance for generated skills
Apply progressive disclosure, token economy, and composition — the principles from
`superpowers:writing-skills`. (The `skill-architect` skill named in the original brief
is not installed here; `writing-skills` is the equivalent design guide.) Every generated
skill must earn its tokens: if a section does not change what a future agent writes, cut
it.

## Common mistakes
- Generating an emergent-domain skill from a single occurrence. → Repeated evidence or nothing.
- Abstract descriptions instead of copied real code. → Always paste from the repo.
- Fat SKILL.md with every edge case inline. → Push extras to `examples.md`.
- Duplicating a skill on re-run instead of editing it. → Update in place (step 6).
- Leaving comments in the pasted example code. → Strip them; prose explains.

## Naming convention

Domain names, skill names, and folder names always in English, regardless of the language used in the conversation or in the scanned repo's source code comments.

Example: domain "components" stays `components`, not `componentes`. Generated skill is `astro-components`, not `astro-componentes`.

SKILL.md body content (explanation, rule, example) can be in any language. Only the identifier (folder name, `name` field in frontmatter) locks to English.
