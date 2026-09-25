# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of reusable **composite GitHub Actions** for .NET projects, consumed from other repos as
`ThorstenSauter/dotnet-actions/<action-dir>@<tag>`. Each action lives in its own top-level directory with an
`action.yml` and a `README.md`. Currently the only action is `build-and-test/`.

The .NET code in `tests/` (plus the root `global.json`) is **not** a product — it's a tiny sample solution that CI runs
the action against. The root `global.json` has to stay at the repo root because `dotnet test` reads the
`test.runner` setting from the working directory, and the action runs from the workspace root.

## Commands

```bash
# Build and test the self-test solution the same way the action does
dotnet build tests/SelfTest.slnx -c Release -p:ArtifactsPath="$PWD/artifacts"
dotnet test --solution tests/SelfTest.slnx -c Release --no-build -p:ArtifactsPath="$PWD/artifacts" \
  --coverage --coverage-output-format cobertura --results-directory ./coverage
# SelfTest.E2E fails unless Playwright's chromium is installed:
pwsh artifacts/bin/SelfTest.E2E/release/playwright.ps1 install chromium

# Lint (same as CI)
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12
docker run --rm -v "$PWD:/repo" -w /repo ghcr.io/zizmorcore/zizmor:latest --offline .
```

On Windows Git Bash, prefix the docker commands with `MSYS_NO_PATHCONV=1` and use `$(pwd -W)` instead of `$PWD`.
actionlint only checks workflows; zizmor also audits `build-and-test/action.yml`.

## `build-and-test` action flow

`build-and-test/action.yml` runs these steps in order:

1. **Validate inputs** (`id: inputs`) normalizes the boolean inputs (`true`/`false`, case-insensitive, anything else
   fails) into step outputs. Later steps must gate on `steps.inputs.outputs.<name>`, never on raw `inputs.<name>`. It
   also derives a comma-free `playwright-browsers-key` for the cache key.
2. `actions/setup-dotnet` with the SDK version from `global-json-file`. The NuGet feed is optional (an empty
   `source-url` is skipped). NuGet caching goes through setup-dotnet's `cache` input, which needs `packages.lock.json`.
3. `dotnet restore` → `dotnet build --no-restore`, both with `-p:ArtifactsPath=<workspace>/artifacts`.
4. Playwright: `actions/cache` restores the browser directory. The key hashes
   `artifacts/bin/**/.playwright/package/browsers.json`, which only exists after the build. Then each project's
   `artifacts/bin/<project>/<configuration lowercased>/playwright.ps1 install [browsers] --with-deps` runs. Cached
   browsers are skipped, but OS dependencies still get installed. Keep the `@(...)` wrapper on `$browsers` so a single
   browser isn't splatted as individual characters, and keep the `$LASTEXITCODE` check, because pwsh would otherwise
   only report the last project's exit code.
5. `actions/github-script` reads `ACTIONS_RUNTIME_TOKEN` / `ACTIONS_RESULTS_URL` (used by TUnit's HTML report upload)
   and passes them as masked step outputs to the Test step's `env` only. Don't `exportVariable` them, which would
   leak them to the caller's later steps.
6. `dotnet test --no-build --solution ... --coverage --coverage-output-format cobertura --results-directory ./coverage`
   (Microsoft.Testing.Platform-style `dotnet test`, not VSTest).
7. ReportGenerator → `$GITHUB_STEP_SUMMARY`, gated on `!cancelled()` and on coverage files existing, so a coverage
   summary still appears when tests fail.

**Script injection:** never interpolate `${{ inputs.* }}` into `run:` scripts. Pass inputs through `env:` and quote
them (`"$VAR"` / `"$env:VAR"`). The quotes in `"$env:VAR"` matter on Windows, where an empty env var is `$null`.

When changing inputs or behavior, keep `action.yml`'s `description`, the inputs table in `build-and-test/README.md`,
and the usage examples in both READMEs in sync.

## CI and releases

- `.github/workflows/ci.yml`: actionlint + zizmor, then runs `./build-and-test` against `tests/SelfTest.slnx` on
  Ubuntu and Windows (with Playwright + NuGet caching), plus a build-only run with `run-tests: 'False'`.
  `.github/zizmor.yml` suppresses `self-repository` for `ci.yml` because actionlint doesn't support `$/` yet.
- Releases are published manually as GitHub releases with `vX.Y.Z` tags. `.github/workflows/release.yml` then
  moves the floating major tag (`v3`, …) to the release, unless it's a prerelease or not the highest release in that
  major version. Breaking input changes bump the major version.

## Conventions

- **Pin third-party actions by full commit SHA** with a trailing `# vX.Y.Z` comment. Renovate
  (`.github/renovate.json`, extending `local>ThorstenSauter/renovate-config`) updates these pins and comments.
- New inputs should be optional with a backward-compatible default.
- Commit messages use Conventional Commits (`feat:`, `fix:`, `chore(deps):`).
- `action.yml` and the READMEs are UTF-8 with BOM (the Write tool drops it, so re-add it). YAML/JSON/Markdown use
  2-space indentation (see `.editorconfig`).
