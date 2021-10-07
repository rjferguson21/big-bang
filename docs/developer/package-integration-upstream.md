# Big Bang Package: Upstream Integration

Before beginning the process of integrating a package into Big Bang, you will need to create a workspace and create or sync the package's Helm chart.  This document shows you how to setup the workspace and sync the upstream Helm chart.

[[_TOC_]]

## Prerequisites

- [Kpt](https://googlecontainertools.github.io/kpt/installation/)
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

> Throughout this document, we will be setting up an application called `podinfo` as a demonstration.

## Project

It is recommended that you create your project in [Big Bang's Sandbox](https://repo1.dso.mil/platform-one/big-bang/apps/sandbox).  This allows you to leverage Big Bang's pipelines, collaborate with Big Bang developers, and easily migrate to a fully graduated project.

You will need to request a sandbox project and Developer access from a Big Bang team member.

## Helm Chart

Big Bang requires a Helm chart to deploy your package.  This Helm chart must be enhanced to support full integration with Big Bang components.

### Cloning Upstream

To minimize maintenance, it is preferable to reuse existing Helm charts available in the community (upstream).  Changes to the upstream Helm chart should be made with new files when possible, and always clearly marked as Big Bang additions.

> Sometimes, it is not possible to find an upstream Helm chart and you must develop your own.  This is beyond the scope of this document.

1. Identify the location of an existing Helm chart for the package.

   > If selecting between several Helm charts, give preference to a Helm chart that:
   >
   > - Was created by the company that owns the package
   > - Has recent and frequent updates
   > - Offers maximum flexibility through values
   > - Does not bundle several packages together (unless they can be individually disabled)
   > - Provides advanced features like high availability, scaling, affinity, taints/tolerations, and security context

1. Using [Kpt](https://googlecontainertools.github.io/kpt/installation/), create a clone of the package's Helm chart

   ```shell
   # Change these for your upstream helm chart
   export GITREPO=https://github.com/stefanprodan/podinfo
   export GITDIR=charts/podinfo
   export GITTAG=5.2.1

   # Clone
   kpt pkg get $GITREPO/$GITDIR@$GITTAG chart
   ```

1. Add `-bb.0` suffix on `chart/Chart.yaml`, `version`.  For example:

   ```yaml
   version: 6.0.0-bb.0
   ```

   > The `bb.#` will increment for each change we merge into our `main` branch.  It will also become our release label.

1. Add a [CHANGELOG](#changelogmd) with an entry for initial commit:

   ```yaml
   ## [6.0.0-bb.0] 2021-10-5
   ### Added
   - Initial Big Bang chart
   ```

1. Commit changes

   ```shell
   git add -A
   git commit -m "feat: initial helm chart"
   git push --set-upstream origin bigbang
   ```

### Updating Upstream

If a new version of the upstream Helm chart is released, this is how to sync it and retain the Big Bang enhancements.

```shell
export GITTAG=6.0.0

# Sync with original Helm chart to identify changes
kpt pkg update chart --strategy force-delete-replace

# Save modifications for reference
git diff > bb-mods.txt

# Undo sync
git restore .

# Sync with new Helm chart release
kpt pkg update chart@$GITTAG --strategy force-delete-replace

# Using bb-mods.txt created above, add Big Bang changes back into chart as needed

# Commit and push changes
rm bb-mods.txt
git add -A
git commit -m "chore: update helm chart to $GITTAG"
git push
```

## Validation

If you are not already familiar with the package, deploy the package using the upstream helm chart onto a Kubernetes cluster and explore the functionality before continuing.  The Helm chart can be deployed according to the upstream package's documentation.

 > It is recommended that you follow the instructions in [development environment](./development-environment.md) to get a Kubernetes cluster running.
