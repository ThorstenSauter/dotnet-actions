# Build solution and run tests

## Behavior

This action installs the .NET SDK with the version specified in the given `global.json` file and optionally connects it
to a custom NuGet feed. It then builds the given solution with the given run configuration. As an optional step, which
is enabled by default, it runs all tests, collects Cobertura code coverage and publishes a coverage summary to the job
summary. The coverage summary is also published when tests fail. Playwright browsers can optionally be installed (and
cached between runs) for the test projects that need them.

## Requirements

- Tests are run with `dotnet test --solution ... --coverage`, which requires the
  [Microsoft.Testing.Platform](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-intro) mode of
  `dotnet test`. Enable it in your `global.json`:

  ```json
  {
    "test": {
      "runner": "Microsoft.Testing.Platform"
    }
  }
  ```

- Test projects need the `Microsoft.Testing.Extensions.CodeCoverage` package for coverage collection.
- `cache-nuget: 'true'` requires `packages.lock.json` files, e.g. by setting `RestorePackagesWithLockFile` to `true`.

## Inputs

All boolean inputs accept `true` or `false` (case-insensitive); any other value fails the action.

| Name                  | Required | Default       | Description                                                                                                                 |
|-----------------------|----------|---------------|-----------------------------------------------------------------------------------------------------------------------------|
| `nuget-feed-uri`      | no       | `''`          | The URI of a custom NuGet feed to connect to. Leave empty to only use the default feeds.                                    |
| `nuget-auth-token`    | no       | `''`          | The token used to authenticate to the custom NuGet feed specified in `nuget-feed-uri`.                                      |
| `configuration`       | no       | `Release`     | The configuration to build the solution in.                                                                                 |
| `global-json-file`    | no       | `global.json` | The path to the `global.json` file specifying the .NET SDK version to install.                                              |
| `solution-path`       | no       | `.`           | The path to the .NET solution file.                                                                                         |
| `cache-nuget`         | no       | `false`       | Whether to cache NuGet packages between runs. Requires `packages.lock.json` files anywhere.                                       |
| `run-tests`           | no       | `true`        | Whether to run tests and publish coverage.                                                                                  |
| `install-playwright`  | no       | `false`       | Whether to install (and cache) Playwright browsers. Only applies when `run-tests` is `true`.                                |
| `playwright-projects` | no       | `''`          | Comma-separated list of test project names (not paths) that use Playwright, e.g. `MyApp.Tests.E2E,MyApp.Integration.Tests`. |
| `playwright-browsers` | no       | `''`          | Comma-separated list of Playwright browsers to install, e.g. `chromium` or `chromium,firefox`. Empty installs all browsers.  |

## Example

```yaml
name: Build solution and run tests

on:
  pull_request:
    branches:
      - main

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Build solution and run tests
    runs-on: ubuntu-latest
    permissions:
      contents: read
    timeout-minutes: 15
    steps:
      - name: Checkout repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Build solution and run tests
        uses: ThorstenSauter/dotnet-actions/build-and-test@v3
        env:
          Test__Input: 'Test' # Injecting configuration for tests
        with:
          # Only needed for packages from a custom feed, e.g. GitHub Packages
          nuget-auth-token: ${{ secrets.NUGET_GITHUB_PACKAGES_TOKEN }}
          nuget-feed-uri: ${{ vars.NUGET_FEED_URI }}
          cache-nuget: 'true'
```

### With Playwright

```yaml
      - name: Build solution and run tests
        uses: ThorstenSauter/dotnet-actions/build-and-test@v3
        with:
          install-playwright: 'true'
          playwright-projects: 'MyApp.Tests.E2E'
          playwright-browsers: 'chromium'
```
