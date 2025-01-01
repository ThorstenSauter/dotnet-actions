# Dotnet Actions

This repository contains common .NET GitHub Actions to be reused across projects.

## General

### Example

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

## Actions

The repository currently contains one action:

- [Build and test](./build-and-test) `ThorstenSauter/dotnet-actions/build-and-test`
