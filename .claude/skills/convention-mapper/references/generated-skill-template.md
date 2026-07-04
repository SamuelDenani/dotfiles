# Template for generated `{repo}-{domain}` skills

Every generated skill is one directory: `~/.claude/skills/{repo}-{domain}/SKILL.md`.
Flat namespace with a repo prefix — Claude Code does not discover skills nested in
subdirectories, so never nest `{repo}/{domain}/`.

`{repo}` = `repo.slug` from the scan. `{domain}` = the domain key
(`componentes`, `rotas`, `data-fetching`, `dependency-sourcing`,
`configuration-contract`, `testes`, or a detected emergent key).

## SKILL.md shape

```markdown
---
name: {repo}-{domain}
description: Use when {doing X} in the {repo} codebase — {concrete triggers: file globs, dirs, task types}. Repo-specific.
---

# {repo} — {domain, human readable}

## Rule
{1-3 conventions as imperatives. The pattern and the reason it exists.}

## When to apply
{Triggers a future agent can match: which dirs, file types, and task shapes.}

## Pattern
{One real example copied verbatim from the repo, with a `path:line` reference.
Never an abstract paraphrase. If the example is long or there are several, keep the
shortest representative one here and move the rest to examples.md.}

## Anti-patterns & exceptions
{What NOT to do in this repo, and the cases where the rule is legitimately broken —
observed in the actual code, not invented.}

## More
{Only if it exists:} See [examples.md](examples.md) for edge cases and longer samples.
```

## Rules for the generated content

- **description**: third person, starts with "Use when", lists concrete triggers,
  ends with a repo marker. Never summarize the skill's steps in the description.
- **Real examples only.** Copy from the files the scan pointed to. Include the source
  `path` so it stays verifiable. No invented or generic snippets.
- **No comments in copied code.** Strip explanatory comments from the pasted example;
  the surrounding prose explains it.
- **Lean SKILL.md.** Rule + when-to-apply + one example. Extra examples and edge cases
  go in `examples.md` in the same directory, loaded only when the agent opens it.
- **Anti-patterns are mandatory** — a convention with no stated failure mode or
  exception is usually under-observed. Go back to the code if you have none.
- **Token economy is the point.** These skills exist so a future agent spends fewer
  tokens rediscovering the convention. If a section does not change what the agent
  writes, cut it.

## Filled example (illustrative — yours must come from the real repo)

```markdown
---
name: acme-host-data-fetching
description: Use when fetching data in the acme-host Next.js app — Server Components, server actions, or React Query hooks under src/. Repo-specific.
---

# acme-host — Data fetching

## Rule
Fetch server-side in async Server Components by default. Mutations go through
server actions (`"use server"`) in `src/lib/`. Client-side reads use React Query
hooks (`useX`) — never bare `fetch` in a component.

## When to apply
Any component under `src/app/**` or hook under `src/lib/**` that reads or writes data.

## Pattern
`src/app/dashboard/page.tsx` — server component reads directly:
    export default async function DashboardPage() {
      const users = await getUsers()
      return <div>{users.length}</div>
    }

`src/lib/queries.ts` — client reads via React Query:
    export function useUsers() {
      return useQuery({ queryKey: ["users"], queryFn: () => fetch("/api/users").then(r => r.json()) })
    }

## Anti-patterns & exceptions
- Do not call `fetch` directly inside a client component — wrap it in a `useX` hook.
- Exception: `route.ts` handlers under `src/app/**/api` fetch inline; they are the
  server boundary, not consumers.
```
