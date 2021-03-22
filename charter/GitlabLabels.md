# Gitlab Labels

## Issues

### `kind`

The kind label shows the type of work that needs to be accomplished

#### `kind::bug`

Issues releated to Bigbang not functioning as expected

#### `kind::chore`

Catch all kind that captures administrative tasking for the BigBang project

#### `kind:ci`

Issues related to the CI/CD, developer workflows and/or the releaes process

#### `kind::docs`

Issues related to documentaiton

#### `kind::feature`

Creation of a new capability for BigBang and/or one of its packages

#### `kind::enhancement`

Improvement of an existing capablity to work more efficiently in specific environments

### priority

All `kind::bug` issues recieve a priority.

#### High

`priority::high` issues are causing runtime issues in production enviornments. These issues justify a patch of a release.

#### Medium

`priority:: medium` issues are defined by bugs that degrade system performance, but workarounds are available.  

#### Low

`priort::low` issues are superficial and do not have any impact on the functioning of production systems

### Status

Status captures the state of the issue

#### `status::blocked`

Blocked issues have an external dependency that needs to be solved before work can be completed.  This may be other Big Bang issues or hardening of IronBank images.  If blocked by an IronBank issue, the `ironbank` label should also be applied

#### `status::doing`

Work is actively being done on this issue

#### `status::done`

???

#### `status::review`

The issue is ready to be reviewed by a Maintainer

#### `status::to-do`

This Issue has been assigned, but work as not been started.

### Packages

Package labels are identified by their package name and serve two purposes. 

1. Packages owners subscribe to the package labels for their packages and will be notified when a new issue or merge request is created with the label

## Merge Requests

### Status

Status captures the state of the Merge Request

#### `status::blocked`

Blocked merge requests and issues have an external dependency that needs to be solved before work can be completed.  This may be other Big Bang issues or hardening of IronBank images.

#### `status::doing`

Work is actively being done on this Merge Request

#### `status::done`

???

#### `status::review`

The Merge Request is ready to be reviewed by a Maintainer

#### `status::to-do`

This Merge Request has been assigned, but work as not been started.

### Packages

The package label controls which addons are deployed as part of CI. If a label is present for an addon, the Gitlab testing framework will enable this addon and ensure its tested as part

### `ci`

The CI label for a Merge Request causes the full e2e CI job to run, which includes provisioning Kubernetes clusters in AWS.

### `charter`

This Merge Request has a proposed change to the Charter
