# Domain guide — what bash detected vs. what you must judge

The scan (`scripts/scan-repo.sh`) does the mechanical work: it counts patterns, locates
example files per domain, and flags emergent domains by concrete evidence. It does NOT
decide *why* a pattern exists, *when* to break it, or what is an anti-pattern. That is
your job — read the `examples` the scan lists and extract judgment.

For each domain: read every file in its `examples` array (paths are relative to
`repo.path`), plus adjacent files if a pattern is unclear. Then write the skill.

## Guaranteed domains (always generate a skill)

### componentes
- **Scan gives:** vue file count, react component count, example component paths.
- **You judge:** file/folder naming, one-component-per-file vs. barrel, props typing
  style, how the Next.js host consumes the Vue web components (the cross-framework
  boundary is the highest-value convention here), composition patterns, when a new
  component is warranted vs. extending one.

### rotas
- **Scan gives:** router type (`app` / `pages` / both), route file paths, API routes.
- **You judge:** file conventions per route (`page`/`layout`/`route`), colocation of
  loaders/actions, route grouping, params/metadata handling, server vs. client route
  boundaries.

### data-fetching
- **Scan gives:** counts for SSP/SSG, server actions, SWR, React Query, axios, fetch,
  Vue composables; example files.
- **You judge:** the default fetching strategy and the decision rule between them
  (server component vs. hook vs. action), where fetch logic lives, error/loading
  conventions, caching. Name the anti-pattern (usually "bare fetch in a component").

### dependency-sourcing
- **Scan gives:** tsconfig path aliases present, `.npmrc` present, scoped package names,
  monorepo tool, package.json count.
- **You judge:** where dependencies come from — internal registry vs. workspace vs.
  public npm; the internal scope (e.g. `@acme/*`) and how to consume workspace packages;
  import-alias rules (`@/` vs. relative); when to add a dep vs. reuse an internal one.

### configuration-contract
- **Scan gives:** env file list, `process.env` usage count, env-schema presence,
  config file paths.
- **You judge:** how config/env is accessed and validated (direct `process.env` vs. a
  typed schema module), the contract for adding a new config value, server-only vs.
  public boundaries, where secrets are forbidden.

### testes
- **Scan gives:** test file count, frameworks, colocated-test count.
- **You judge:** what gets tested and what does not, colocation vs. `__tests__`, naming,
  the standard test shape (render/query helpers), mocking conventions, when tests are
  required for a change.

## Emergent domains (generate ONLY with verifiable repeated evidence)

The scan reports `state-management`, `estilizacao`, `build-config` under `emergent`,
each with a `detected` boolean from conservative thresholds. **Generate a skill only if
`detected: true` AND the example files confirm a repeated, consistent pattern.** Never
infer a convention that is not visibly repeated in the code. One store file, one styled
component, one config → not a convention yet; note it and move on.

- **state-management:** which lib, store file layout, selector/action patterns, what
  belongs in global state vs. local.
- **estilizacao:** the styling system (Tailwind / CSS modules / scoped Vue styles /
  CSS-in-JS), token usage, when to reach for each.
- **build-config:** monorepo task pipeline, per-package build conventions, config that
  agents must not hand-edit.

If the scan surfaces evidence of a domain not listed here (visible in file names or
counts you inspect), you may add it — but the same rule holds: repeated verifiable
pattern or nothing.
