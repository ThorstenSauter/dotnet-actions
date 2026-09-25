# Build solution and run tests

## Behavior

This action installs the .NET SDK with the version specified in the given `global.json` file and connects it to the
specified NuGet feed. It then builds the given solution with the given run configuration. As an optional step, which
is enabled by default, it runs all tests, collects Cobertura code coverage and publishes a coverage summary to the
job summary. Playwright browsers can optionally be installed for the test projects that need them.

## Inputs

| Name                  | Required | Default       | Description                                                                                                                       |
|-----------------------|----------|---------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `nuget-auth-token`    | yes      |               | The token used to authenticate to the custom NuGet feed specified in `nuget-feed-uri`.                                            |
| `nuget-feed-uri`      | yes      |               | The URI of the custom NuGet feed to connect to.                                                                                   |
| `configuration`       | no       | `Release`     | The configuration to build the solution in.                                                                                       |
| `global-json-file`    | no       | `global.json` | The path to the `global.json` file specifying the .NET SDK version to install.                                                    |
| `solution-path`       | no       | `.`           | The path to the .NET solution file.                                                                                               |
| `run-tests`           | no       | `true`        | Whether to run tests and publish coverage. Any value other than `true` disables them.                                             |
| `install-playwright`  | no       | `false`       | Whether to install Playwright browsers. Only applies when `run-tests` is `true`.                                                  |
| `playwright-projects` | no       | `''`          | Comma-separated list of test project names (not paths) that use Playwright, e.g. `MyApp.Tests.E2E,MyApp.Integration.Tests`.       |
| `playwright-browsers` | no       | `''`          | Comma-separated list of Playwright browsers to install, e.g. `chromium` or `chromium,firefox`. Empty installs all browsers. |

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
        uses: actions/checkout@v4
      - name: Build solution and run tests
        uses: ThorstenSauter/dotnet-actions/build-and-test@v3.2.0
        env:
          Test__Input: 'Test' # Injecting configuration for tests
        with:
          nuget-auth-token: ${{ secrets.NUGET_GITHUB_PACKAGES_TOKEN }}
          nuget-feed-uri: ${{ vars.NUGET_FEED_URI }}
```
