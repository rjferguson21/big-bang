# Kiali

## Overview

[Kiali](https://kiali.io/) is a console for managing an Istio service mesh. It provides graphical views of interactions, metrics, and configuration options for the mesh. To aggregate this data it interacts with Prometheus, Grafana, and Jaeger.

Big Bang's implementation uses the [Kiali operator](https://github.com/kiali/kiali-operator) to provide custom resources and manage the application.

## Big Bang Touch Points

```mermaid
graph TB
  subgraph "Kiali"
    Kialipods("Kiali Pod(s)")
    kialiservice{{Kiali Service}} --> Kialipods("Kiali Pod(s)")
  end      

  subgraph "Ingress"
    ig(Ingress Gateway) --"App Port"--> kialiservice
  end

  subgraph "Monitoring"
    Kialipods("Kiali Pod(s)") ---- prometheusservice{{Prometheus Service<br />monitoring-monitoring-kube-prometheus}} ----> Prometheus
    svcmonitor("Service Monitor") --"Metrics Port"--> kialiservice
    Prometheus --> svcmonitor("Service Monitor")
    Kialipods("Kiali Pod(s)") ---- grafanaservice{{Grafana Service<br />monitoring-monitoring-grafana}} ----> Grafana  
  end

  subgraph "Tracing"
    Kialipods("Kiali Pod(s)") ---- queryservice{{Query Service<br />jaeger-query}} ----> jaeger(Jaeger)
  end

  subgraph "Logging"
    Kialipods("Kiali Pod(s)") ----> fluent(Fluentbit) --> logging-ek-es-http
    logging-ek-es-http{{Elastic Service<br />logging-ek-es-http}} --> elastic[(Elastic Storage)]
  end
```

### Storage



## High Availability



## Single Sign on (SSO)



## Licencing



## Dependencies

