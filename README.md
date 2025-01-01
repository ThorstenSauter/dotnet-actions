# Dotnet Actions

This repository contains common .NET GitHub Actions to be reused across projects.

## General

### Example

```yaml
name: Build solution and run tests

on:
  pull-request:
    branches:
      - main

permissions:
  contents: read
  pull-requests: write

jobs:
  plan:
    name: Build solution and run tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Build solution and run tests
        uses: ThorstenSauter/dotnet-actions/build-and-test@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          nuget-auth-token: ${{ secrets.NUGET_GITHUB_PACKAGES_TOKEN }}
          nuget-feed-uri: ${{ vars.NUGET_FEED_URI }}
```

## Actions

The repository currently contains one action:

- [Build and test](./build-and-test) `ThorstenSauter/dotnet-actions/build-and-test`
