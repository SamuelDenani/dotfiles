#!/usr/bin/env bash
set -u

REPO_ARG=${1:-}
if [ -z "$REPO_ARG" ]; then
  echo "usage: scan-repo.sh <repo-path>" >&2
  exit 1
fi
REPO=$(cd "$REPO_ARG" 2>/dev/null && pwd) || { echo "not a directory: $REPO_ARG" >&2; exit 1; }

CAP=6

PRUNE=( -name node_modules -o -name .git -o -name .next -o -name dist -o -name build \
        -o -name coverage -o -name .turbo -o -name .cache -o -name out -o -name .output \
        -o -name .nuxt -o -name .svelte-kit -o -name vendor -o -name .venv )

CODE_EXT=( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
           -o -name '*.mjs' -o -name '*.cjs' -o -name '*.vue' )

LIST=$(mktemp)
PKGLIST=$(mktemp)
trap 'rm -f "$LIST" "$PKGLIST"' EXIT

find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f \( "${CODE_EXT[@]}" \) -print0 \) > "$LIST"
find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f -name package.json -print0 \) > "$PKGLIST"

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

rel_array() {
  local first=1 line
  printf '['
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    line=${line#"$REPO"/}
    if [ "$first" -eq 1 ]; then first=0; else printf ', '; fi
    printf '"%s"' "$(json_escape "$line")"
  done
  printf ']'
}

files_matching() {
  xargs -0 -r grep -lIE -e "$1" < "$LIST" 2>/dev/null | sort || true
}

lines_matching() {
  local n
  n=$(xargs -0 -r grep -hIE -e "$1" < "$LIST" 2>/dev/null | wc -l | tr -d ' ' || true)
  printf '%s' "${n:-0}"
}

pkg_has() {
  xargs -0 -r grep -lIF -e "\"$1\"" < "$PKGLIST" >/dev/null 2>&1 && printf true || printf false
}

find_named() {
  find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f \( "$@" \) -print \) 2>/dev/null | sort || true
}

count_named() {
  find_named "$@" | grep -c . || true
}

path_files() {
  find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f \( "${CODE_EXT[@]}" \) -path "$1" -print \) 2>/dev/null | sort || true
}

count_stream() { grep -c . || true; }

no_tests() { grep -vE '\.(test|spec|stories|d)\.[jt]sx?$' || true; }

repo_name=$(basename "$REPO")
repo_slug=$(printf '%s' "$repo_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//')

pkg_name=""
if [ -f "$REPO/package.json" ]; then
  pkg_name=$(grep -m1 -E '"name"[[:space:]]*:' "$REPO/package.json" 2>/dev/null | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)
fi

next_present=$(pkg_has "next")
vue_present=$(pkg_has "vue")

TSCONFIGS=$(find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f -name 'tsconfig*.json' -print \) 2>/dev/null | sort || true)
ts_present=false
{ [ -n "$TSCONFIGS" ] || printf '%s\n' "$(find_named -name '*.ts' -o -name '*.tsx')" | grep -q .; } && ts_present=true

app_routes=$(path_files '*/app/*' | grep -E '/(page|layout|route|template|loading|error|not-found)\.[jt]sx?$' | sort || true)
[ -n "$app_routes" ] || app_routes=$(find_named -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.ts' -o -name 'page.js' | grep '/app/' || true)
pages_routes=$(path_files '*/pages/*' | grep -vE '/pages/api/' | sort || true)
api_routes=$( { path_files '*/pages/api/*'; path_files '*/app/*/route.[jt]s'; } | sort -u || true)

router="none"
app_n=$(printf '%s\n' "$app_routes" | grep -c . || true)
pages_n=$(printf '%s\n' "$pages_routes" | grep -c . || true)
if [ "$app_n" -gt 0 ] && [ "$pages_n" -gt 0 ]; then router="app+pages"
elif [ "$app_n" -gt 0 ]; then router="app"
elif [ "$pages_n" -gt 0 ]; then router="pages"; fi

mono_tool="none"
[ -f "$REPO/pnpm-workspace.yaml" ] && mono_tool="pnpm-workspace"
[ -f "$REPO/turbo.json" ] && mono_tool="turbo"
[ -f "$REPO/lerna.json" ] && mono_tool="lerna"
[ -f "$REPO/nx.json" ] && mono_tool="nx"
pkg_count=$(xargs -0 -r -a "$PKGLIST" -I{} echo {} 2>/dev/null | grep -c . || true)
mono_present=false
{ [ "$mono_tool" != "none" ] || [ "$pkg_count" -gt 1 ]; } && mono_present=true

vue_files=$(find_named -name '*.vue')
vue_count=$(printf '%s\n' "$vue_files" | grep -c . || true)
react_comp_files=$(find_named -name '*.tsx' -o -name '*.jsx' | no_tests)
react_comp_count=$(printf '%s\n' "$react_comp_files" | grep -c . || true)

comp_examples=$( { printf '%s\n' "$vue_files" | no_tests; printf '%s\n' "$react_comp_files"; } | grep -iE '/(components?|ui|widgets?|elements?)/' | grep -v '^$' | head -n "$CAP" || true)
[ -n "$comp_examples" ] || comp_examples=$( { printf '%s\n' "$vue_files"; printf '%s\n' "$react_comp_files"; } | grep -v '^$' | head -n "$CAP" || true)

df_ssp=$(lines_matching 'getServerSideProps|getStaticProps|getStaticPaths')
df_server_actions=$(lines_matching "'use server'|\"use server\"")
df_swr=$(lines_matching 'useSWR|from .swr.')
df_rq=$(lines_matching 'useQuery|useMutation|useInfiniteQuery|QueryClient')
df_axios=$(lines_matching 'axios')
df_fetch=$(lines_matching 'fetch\(')
df_vue=$(lines_matching 'useFetch|useAsyncData|\$fetch')
df_examples=$(files_matching 'useSWR|useQuery|useMutation|getServerSideProps|getStaticProps|use server|useAsyncData|useFetch' | head -n "$CAP")

alias_present=false
if [ -n "$TSCONFIGS" ] && printf '%s\n' "$TSCONFIGS" | tr '\n' '\0' | xargs -0 -r grep -lIE '"paths"[[:space:]]*:' >/dev/null 2>&1; then alias_present=true; fi
scoped_deps=$(xargs -0 -r grep -hoIE '"@[a-z0-9._-]+/[a-z0-9._-]+"' < "$PKGLIST" 2>/dev/null | sort -u | head -n 12 | sed -E 's/^"|"$//g' | tr '\n' ' ' || true)
npmrc_present=false
[ -f "$REPO/.npmrc" ] && npmrc_present=true
dep_examples=$( { [ -f "$REPO/package.json" ] && echo "$REPO/package.json"; [ -f "$REPO/pnpm-workspace.yaml" ] && echo "$REPO/pnpm-workspace.yaml"; [ -f "$REPO/.npmrc" ] && echo "$REPO/.npmrc"; printf '%s\n' "$TSCONFIGS" | head -n 2; } | grep -v '^$' | sort -u | head -n "$CAP" || true)

env_files=$(find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f -name '.env*' -print \) 2>/dev/null | sort || true)
process_env_n=$(lines_matching 'process\.env\.')
env_schema=$(lines_matching 'createEnv|envsafe|@t3-oss/env|z\.object\(\{[^}]*[A-Z_]+:')
config_files=$( { find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f \( -name 'next.config.*' -o -name 'nuxt.config.*' -o -name 'vite.config.*' -o -name 'env.ts' -o -name 'env.mjs' \) -print \) 2>/dev/null; printf '%s\n' "$env_files"; } | sort -u | head -n "$CAP" || true)
config_examples=$(files_matching 'process\.env\.|createEnv|envsafe' | head -n "$CAP")

test_files=$(find_named -name '*.test.*' -o -name '*.spec.*')
test_count=$(printf '%s\n' "$test_files" | grep -c . || true)
test_fw=""
[ "$(pkg_has vitest)" = true ] && test_fw="$test_fw vitest"
[ "$(pkg_has jest)" = true ] && test_fw="$test_fw jest"
[ "$(pkg_has '@playwright/test')" = true ] && test_fw="$test_fw playwright"
[ "$(pkg_has cypress)" = true ] && test_fw="$test_fw cypress"
[ "$(pkg_has '@testing-library/react')" = true ] && test_fw="$test_fw testing-library-react"
[ "$(pkg_has '@testing-library/vue')" = true ] && test_fw="$test_fw testing-library-vue"
test_fw=$(printf '%s' "$test_fw" | sed -E 's/^ //')
colocated=$(printf '%s\n' "$test_files" | grep -vE '/(__tests__|tests?)/' | grep -c . || true)
test_examples=$(printf '%s\n' "$test_files" | grep -v '^$' | head -n "$CAP" || true)

emit_domain_extra() {
  local key=$1 detected=$2 evidence=$3 examples=$4
  printf '    "%s": {"detected": %s, "evidence": %s, "examples": %s}' "$key" "$detected" "$evidence" "$examples"
}

sm_redux=$(pkg_has '@reduxjs/toolkit'); sm_zustand=$(pkg_has zustand); sm_jotai=$(pkg_has jotai)
sm_pinia=$(pkg_has pinia); sm_vuex=$(pkg_has vuex); sm_mobx=$(pkg_has mobx)
sm_usage=$(lines_matching 'createSlice|configureStore|create\(\(set|atom\(|defineStore|useStore')
sm_detected=false
{ [ "$sm_redux" = true ] || [ "$sm_zustand" = true ] || [ "$sm_jotai" = true ] || [ "$sm_pinia" = true ] || [ "$sm_vuex" = true ] || [ "$sm_mobx" = true ]; } && [ "$sm_usage" -ge 2 ] && sm_detected=true
sm_examples=$(files_matching 'createSlice|configureStore|defineStore|create\(\(set|atom\(' | head -n "$CAP")

st_tailwind=false
find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f -name 'tailwind.config.*' -print \) 2>/dev/null | grep -q . && st_tailwind=true
st_modules=$(count_named -name '*.module.css' -o -name '*.module.scss')
st_scss=$(count_named -name '*.scss' -o -name '*.sass')
st_styled=$(lines_matching 'styled\.[a-z]|styled\(|@emotion|css`')
st_vue_scoped=$(lines_matching '<style[^>]*scoped')
st_detected=false
{ [ "$st_tailwind" = true ] || [ "$st_modules" -ge 2 ] || [ "$st_scss" -ge 2 ] || [ "$st_styled" -ge 2 ] || [ "$st_vue_scoped" -ge 2 ]; } && st_detected=true
st_examples=$( { find "$REPO" \( -type d \( "${PRUNE[@]}" \) -prune \) -o \( -type f -name 'tailwind.config.*' -print \) 2>/dev/null; find_named -name '*.module.css' -o -name '*.module.scss'; files_matching '<style[^>]*scoped'; } | grep -v '^$' | sort -u | head -n "$CAP" || true)

bd_turbo=false; [ -f "$REPO/turbo.json" ] && bd_turbo=true
bd_vite=false; find "$REPO" -maxdepth 2 -name 'vite.config.*' -print -quit 2>/dev/null | grep -q . && bd_vite=true
bd_webpack=false; find "$REPO" -maxdepth 2 -name 'webpack.config.*' -print -quit 2>/dev/null | grep -q . && bd_webpack=true
bd_detected=false
{ [ "$bd_turbo" = true ] || [ "$bd_vite" = true ] || [ "$bd_webpack" = true ] || [ "$next_present" = true ]; } && bd_detected=true
bd_examples=$( { find "$REPO" -maxdepth 2 \( -name 'turbo.json' -o -name 'vite.config.*' -o -name 'webpack.config.*' -o -name 'next.config.*' \) -print 2>/dev/null; } | sort -u | head -n "$CAP" || true)

{
printf '{\n'
printf '  "repo": {"path": "%s", "name": "%s", "slug": "%s", "package_name": "%s"},\n' \
  "$(json_escape "$REPO")" "$(json_escape "$repo_name")" "$(json_escape "$repo_slug")" "$(json_escape "$pkg_name")"
printf '  "stack": {"next": %s, "next_router": "%s", "vue": %s, "typescript": %s, "monorepo": {"present": %s, "tool": "%s", "package_json_count": %s}},\n' \
  "$next_present" "$router" "$vue_present" "$ts_present" "$mono_present" "$mono_tool" "$pkg_count"
printf '  "domains": {\n'

printf '    "componentes": {"guaranteed": true, "evidence": {"vue_files": %s, "react_component_files": %s}, "examples": ' "$vue_count" "$react_comp_count"
printf '%s\n' "$comp_examples" | rel_array
printf '},\n'

printf '    "rotas": {"guaranteed": true, "evidence": {"router": "%s", "app_route_files": %s, "pages_route_files": %s}, "examples": ' "$router" "$app_n" "$pages_n"
{ printf '%s\n' "$app_routes"; printf '%s\n' "$pages_routes"; printf '%s\n' "$api_routes"; } | grep -v '^$' | sort -u | head -n "$CAP" | rel_array
printf '},\n'

printf '    "data-fetching": {"guaranteed": true, "evidence": {"getServerSideProps_getStaticProps": %s, "server_actions": %s, "swr": %s, "react_query": %s, "axios": %s, "fetch": %s, "vue_composables": %s}, "examples": ' \
  "$df_ssp" "$df_server_actions" "$df_swr" "$df_rq" "$df_axios" "$df_fetch" "$df_vue"
printf '%s\n' "$df_examples" | rel_array
printf '},\n'

printf '    "dependency-sourcing": {"guaranteed": true, "evidence": {"tsconfig_path_aliases": %s, "npmrc": %s, "scoped_packages": "%s"}, "examples": ' \
  "$alias_present" "$npmrc_present" "$(json_escape "$(printf '%s' "$scoped_deps" | sed -E 's/ $//')")"
printf '%s\n' "$dep_examples" | rel_array
printf '},\n'

printf '    "configuration-contract": {"guaranteed": true, "evidence": {"env_files": %s, "process_env_uses": %s, "env_schema": %s}, "examples": ' \
  "$(printf '%s\n' "$env_files" | grep -c . || true)" "$process_env_n" "$env_schema"
{ printf '%s\n' "$config_files"; printf '%s\n' "$config_examples"; } | grep -v '^$' | sort -u | head -n "$CAP" | rel_array
printf '},\n'

printf '    "testes": {"guaranteed": true, "evidence": {"test_files": %s, "frameworks": "%s", "colocated_tests": %s}, "examples": ' \
  "$test_count" "$(json_escape "$test_fw")" "$colocated"
printf '%s\n' "$test_examples" | rel_array
printf '}\n'

printf '  },\n'
printf '  "emergent": {\n'
emit_domain_extra "state-management" "$sm_detected" \
  "$(printf '{"redux": %s, "zustand": %s, "jotai": %s, "pinia": %s, "vuex": %s, "mobx": %s, "usage": %s}' "$sm_redux" "$sm_zustand" "$sm_jotai" "$sm_pinia" "$sm_vuex" "$sm_mobx" "$sm_usage")" \
  "$(printf '%s\n' "$sm_examples" | rel_array)"
printf ',\n'
emit_domain_extra "estilizacao" "$st_detected" \
  "$(printf '{"tailwind": %s, "css_modules": %s, "scss": %s, "styled_css_in_js": %s, "vue_scoped_style": %s}' "$st_tailwind" "$st_modules" "$st_scss" "$st_styled" "$st_vue_scoped")" \
  "$(printf '%s\n' "$st_examples" | rel_array)"
printf ',\n'
emit_domain_extra "build-config" "$bd_detected" \
  "$(printf '{"turbo": %s, "vite": %s, "webpack": %s, "next": %s}' "$bd_turbo" "$bd_vite" "$bd_webpack" "$next_present")" \
  "$(printf '%s\n' "$bd_examples" | rel_array)"
printf '\n  }\n'
printf '}\n'
}
