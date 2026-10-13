# Pack and publish NuGet packages

## Behavior

This action installs the .NET SDK with the version specified in the given `global.json` file, packs the given project
or solution with the given version and uploads the packages as a workflow artifact. Unless `publish` is `false`, it
then logs in to nuget.org with [trusted publishing](https://learn.microsoft.com/nuget/nuget-org/trusted-publishing)
(exchanging the workflow's OIDC token for a short-lived API key via [`NuGet/login`](https://github.com/NuGet/login))
and pushes the packages. Symbol packages (`.snupkg`) are pushed along with their package. Versions that already exist
on the feed are skipped.

Before pushing, the action creates a signed
[build provenance attestation](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations)
with [`actions/attest`](https://github.com/actions/attest), so a failed attestation never leaves an unattested
package on the feed. The subjects are every `.nupkg` and `.snupkg` **and every assembly inside the packages**, plus
any SPDX SBOM embedded under `_manifest/` (e.g. by [Sbom](https://github.com/SimonCropp/Sbom) or
Microsoft.Sbom.Targets), which proves the SBOM came from the same build.

nuget.org repository-signs each package it accepts by adding `.signature.p7s` to the zip, so a `.nupkg` downloaded
from nuget.org never matches the attested package digest. The assemblies inside are unchanged, so consumers verify
those:

```bash
unzip -o MyLibrary.1.2.3.nupkg 'lib/*' -d MyLibrary
gh attestation verify MyLibrary/lib/net10.0/MyLibrary.dll --repo OWNER/REPO
```

The `.nupkg` attestation still matches the copy in the workflow artifact and on feeds that don't re-sign packages.

## Requirements

- A trusted publishing policy on nuget.org for the repository and the workflow file that calls this action, owned by
  the account given in `nuget-user`.
- The calling job needs the `id-token: write` permission to publish, and `attestations: write` unless `attest` is
  `false`. Attestations are free for public repositories; private ones need a GitHub plan that includes them.
- The packed projects must be packable; test projects should set `<IsPackable>false</IsPackable>`.

## Inputs

All boolean inputs accept `true` or `false` (case-insensitive); any other value fails the action.

| Name               | Required | Default                               | Description                                                                                       |
|--------------------|----------|---------------------------------------|---------------------------------------------------------------------------------------------------|
| `project-path`     | yes      |                                       | The path to the project or solution to pack.                                                      |
| `version`          | yes      |                                       | The package version, e.g. `1.2.3` or `1.2.3-rc.1`. A leading `v` is removed, so a tag can be used. |
| `publish`          | no       | `true`                                | Whether to push the packages. `false` only packs and uploads the artifact.                        |
| `nuget-user`       | no       | `''`                                  | The nuget.org profile name owning the trusted publishing policy. Required when `publish` is `true`. |
| `nuget-source`     | no       | `https://api.nuget.org/v3/index.json` | The NuGet feed to push to.                                                                        |
| `configuration`    | no       | `Release`                             | The configuration to pack in.                                                                     |
| `global-json-file` | no       | `global.json`                         | The path to the `global.json` file specifying the .NET SDK version to install.                    |
| `artifact-name`    | no       | `nuget-packages`                      | The name of the workflow artifact the packages are uploaded as.                                   |
| `attest`           | no       | `true`                                | Whether to attest build provenance before pushing. Only applies when `publish` is `true`.         |
| `attest`           | no       | `true`                                | Whether to attest build provenance before pushing. Only applies when `publish` is `true`.         |

## Outputs

| Name      | Description                                    |
|-----------|------------------------------------------------|
| `version` | The normalized package version that was packed. |

## Example

```yaml
name: Release

on:
  release:
    types:
      - published

permissions: {}

jobs:
  publish:
    name: Pack and publish
    runs-on: ubuntu-latest
    environment: nuget
    permissions:
      contents: read
      attestations: write # Build provenance attestations
      id-token: write # Trusted publishing and attestation signing
    timeout-minutes: 10
    steps:
      - name: Checkout repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Pack and publish
        uses: ThorstenSauter/dotnet-actions/pack-and-publish@v4
        with:
          project-path: 'src/MyLibrary/MyLibrary.csproj'
          version: ${{ github.event.release.tag_name }}
          nuget-user: ${{ vars.NUGET_USER }}
```
