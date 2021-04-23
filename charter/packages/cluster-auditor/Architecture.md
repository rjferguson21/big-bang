# Cluster Auditor

## Overview

Cluster Auditor pulls data from the kubernetes API, transforms them and inserts them into Elasticsearch which can then be queried by Kibana.  The types of objects are both OPA Gatekeeper CRDS and native kubernetes [objects](https://repo1.dso.mil/platform-one/big-bang/apps/core/cluster-auditor/-/blob/main/chart/templates/configMap.yaml).

## Big Bang Touchpoints

```mermaid
graph TB 
  subgraph "Cluster Auditor"
    clusterauditor 
  end 

  subgraph "Elasticsearch"
    clusterauditor --> elasticsearch 
  end
```

##High Availability

HA can be configured by increasing the "count" or number of replicas of the [deployment](https://repo1.dso.mil/platform-one/big-bang/apps/core/cluster-auditor/-/blob/main/chart/templates/deployment.yaml).

```yaml
...
spec:
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      engine: fluentd
  replicas: 1
...
```

##Storage

It uses the currently deployed Elasticsearch that's deployed as part of the logging stack.

## Single Sign On (SSO)

CA does not have SSO Integration.

## Licensing

CA parent image is `fluentd` which uses  [Apache License 2.0](https://github.com/fluent/fluentd/blob/master/LICENSE).

## Dependant Packages

- Elasticsearch Kibana
- OPA Gatekeeper