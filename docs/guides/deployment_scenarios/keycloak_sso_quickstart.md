# Big Bang KeyCloak SSO Quick Start

## Overview

This assumes you have ran quickstart.md and have a k3d cluster, with BB deployed, and are able to ingress to sites hosted on the cluster. 

This covers Input config values and imperative config needed to enable keycloak in the same cluster.

## Helm Input Values

`values.yaml`
```text
hostname: bigbang.dev
...TBD...
```

## Additional Imperative Config Steps
1. update coredns
2. KeyCloak GUI stuff. 

