# Build solution and run tests

## Behavior

This action installs the .NET SDK with the version specified in the given `global.json` file and connects it to the
specified NuGet feed. It then builds the given solution with the given run configuration. As an optional step, which
is enabled by default, it runs all tests, collects code coverage of the given type and creates or updates an existing
pull request comment with the test coverage.

## Example

```yaml
name: Build solution and run tests

on:
  pull_request:
    branches:
      - main

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Build solution and run tests
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    timeout-minutes: 15
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Build solution and run tests
        uses: ThorstenSauter/dotnet-actions/build-and-test@v1
        env:
          Test__Input: 'Test' # Injecting configuration for tests
        with:
          code-coverage-type: 'extensions-code-coverage'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          nuget-auth-token: ${{ secrets.NUGET_GITHUB_PACKAGES_TOKEN }}
          nuget-feed-uri: ${{ vars.NUGET_FEED_URI }}
```
