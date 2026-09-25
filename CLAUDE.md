# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of reusable **composite GitHub Actions** for .NET projects, consumed from other repos as
`ThorstenSauter/dotnet-actions/<action-dir>@<tag>`. Each action lives in its own top-level directory with an
`action.yml` and a `README.md`. There is no .NET code, build system, test suite, or CI workflow in this repo itself —
the only artifacts are the action definitions and their docs.

Currently the only action is `build-and-test/`.

## `build-and-test` action flow

`build-and-test/action.yml` runs these steps in order:

1. `actions/setup-dotnet` using the SDK version from `global-json-file`, authenticated against `nuget-feed-uri`
   (token passed via the `NUGET_AUTH_TOKEN` env var).
2. `dotnet restore` → `dotnet build --no-restore`, both with `-p:ArtifactsPath=${{ github.workspace }}/artifacts`.
3. Optional Playwright browser install (pwsh). This depends on the artifacts layout from step 2: it looks for
   `artifacts/bin/<project>/<configuration lowercased>/playwright.ps1` for each name in `playwright-projects`, and
   fails if the script is missing. `playwright-browsers` is splatted as `@browsers` — keep the `@(...)` array wrapper
   so a single browser isn't unwrapped into individual characters.
4. Exposes `ACTIONS_RUNTIME_TOKEN` / `ACTIONS_RESULTS_URL` via `actions/github-script` so tooling inside `dotnet test`
   can use the Actions runtime.
5. `dotnet test --no-build --solution ... --coverage --coverage-output-format cobertura --results-directory ./coverage`
   (Microsoft.Testing.Platform-style `dotnet test` syntax, not VSTest).
6. ReportGenerator turns `coverage/**/*.cobertura.xml` into `MarkdownSummaryGithub`, which is appended to
   `$GITHUB_STEP_SUMMARY`.

Steps 3–6 are gated on `run-tests == 'true'` (any other value disables them); step 3 additionally requires
`install-playwright == 'true'`.

When changing inputs or behavior, keep `action.yml`'s `description`, the inputs table in `build-and-test/README.md`,
and the usage examples in both READMEs in sync.

## Conventions

- **Pin third-party actions by full commit SHA** with a trailing `# vX.Y.Z` comment. Renovate
  (`.github/renovate.json`, extending `local>ThorstenSauter/renovate-config`) updates these pins and comments.
- New inputs should be optional with a backward-compatible default; consumers pin to release tags.
- Releases are semver git tags (`v1.0.0` … `v3.2.0`); breaking input changes bump the major version.
- Commit messages use Conventional Commits (`feat:`, `fix:`, `chore(deps):`).
- Existing files are UTF-8 with BOM; YAML/JSON/Markdown use 2-space indentation (see `.editorconfig`).

## Testing changes

There is no local test harness. Validate shell/pwsh snippets locally (e.g. run the Playwright install logic in `pwsh`
with empty, single, and multiple values), then verify end-to-end by pointing a consumer repo's workflow at the branch
(`ThorstenSauter/dotnet-actions/build-and-test@<branch>`).
