# Sonarqube

## Overview

[Sonarqube](https://www.sonarqube.org/) is an open-source platform for continuous inspection of code quality to perform automatic reviews with static analysis of code to detect bugs, code smells, and security vulnerabilities.

## Big Bang Touchpoints

```mermaid
graph TB
  subgraph "jaeger"
  jaegerpods("Jaeger-AllInOne")
  elasticcredentials --> jaegerpods("Jaeger-AllInOne")
  end      

  subgraph "ingress"
    ingressgateway --> jaegerpods("Jaeger-AllInOne")
  end

  subgraph "logging"
    subgraph "elasticsearch"
    
    credentials --> elasticcredentials
    jaegerpods("Jaeger-AllInOne") --> logging-ek-es-http
    logging-ek-es-http --> LoggingElastic(Elasticsearch Storage )
    end
  end

  subgraph "workloads"
    sidecar --> jaegerpods("Jaeger-AllInOne")
  end
```

### Storage



### Istio Configuration


```yaml

```

## High Availability


```yaml
```


## Single Sign on (SSO)

Jaeger does not have built in SSO.  In order to provide SSO, this deployment legerages [Authservice]().

```mermaid
flowchart LR

A --> K[(Keycloak)]

subgraph external
K
end

subgraph auth["authservice namespace"]
    A(authservice) --> K
end



ingress --> IP


subgraph "jaeger namespace"
    subgraph "jaeger pod"
        J["jager"]
        IP["istio proxy"] --> A
        IP --> J
    end
end    

```

## Licencing



## Storage



## Dependencies


