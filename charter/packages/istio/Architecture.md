# Istio

## Overview

[Istio](https://istio.io/latest/docs/concepts/what-is-istio/) is an open platform for providing a uniform way to [integrate microservices](https://istio.io/latest/docs/examples/microservices-istio/), manage [traffic flow](https://istio.io/latest/docs/concepts/traffic-management/) across microservices, enforce policies and aggregate telemetry data. Istio's control plane provides an abstraction
layer over the underlying cluster management platform, such as Kubernetes.

```mermaid
graph LR
  subgraph "Istio"
    dataplane("Data plane") 
    controlplane{{"Control plane"}} --> dataplane
  end      

  subgraph "Ingress"
    igw("Ingress Gateway") 
    igw --"http 8080<br/>https 8443<br/>istiod 15012<br/>status 15021<br/>tls 15443"--> dataplane
  end

  subgraph "Monitoring"
    svcmonitor("Service Monitor") --> controlplane
    Prometheus --> svcmonitor("Service Monitor")
  end
  
  subgraph "App"
    dataplane --"app.bigbang.dev"<br/>port redirects--> appvs{{"Virtual Service"}} --> apppod("App")
  end

  subgraph "Logging"
    controlplane --> fluent(Fluentbit) --> logging-ek-es-http
    logging-ek-es-http{{Elastic Service<br />logging-ek-es-http}} --> elastic[(Elastic Storage)]
  end
```

## Big Bang Touchpoints

### Licensing

Istio is an open source tool that utilizes an Apache-2.0 License.

### Single Sign On

By default, Istio is configured with SSO disabled. However, Istio can be configured to use Keycloak/OIDC auth. For documentation on how to configure Istio SSO with Authservice, Kiali, and Jaeger, see [KEYCLOAK.md](https://repo1.dso.mil/platform-one/big-bang/apps/core/istio-controlplane/-/blob/main/docs/KEYCLOAK.md).

```yaml
istio:
  values:
    sso:
      enabled: true
      namespace: istio-addons-sso
      selector:
        key: protect
        value: keycloak
```

### Storage

Aside from the packages that it can integrate with, Istio provides no storage requirements.

### High Availability

By default, Istio is configured with 1 istiod replica, but it can be configured in the Big Bang values to use horizontal pod autoscaling:

```yaml
istio:
  values:
    istiod:
      replicaCount: 1
      hpaSpec:
        minReplicas: 1
        maxReplicas: 3
```

Likewise, the ingress gateway replicas can be specified and extra ingress gateways can be configured:

```yaml
istio:
  values:
    ingressGateway:
      minReplicas: 1
      maxReplicas: 5
    extraIngressGateways:
    # ...
```

### UI

Big Bang can be configured to deploy [Kiali](https://repo1.dso.mil/platform-one/big-bang/apps/core/kiali) (a management console that provides dashboards, observability, and other robust capabilities) and [Jaeger](https://repo1.dso.mil/platform-one/big-bang/apps/core/jaeger) (an end-to-end distributed tracing system), both of which include UI features to help you visualize your Istio mesh. To enable Kialia and Jaeger, simply update the Big Bang values.yaml:

```yaml
istio:
  enabled: true
jaeger:
  enabled: true
kiali:
  enabled: true
```

### Logging

Within Big Bang, logs are captured by fluentbit and shipped to elastic by default.

### Monitoring

Monitoring is enabled by default in the Istio [values.yaml](https://repo1.dso.mil/platform-one/big-bang/apps/core/istio-controlplane/-/blob/main/chart/values.yaml#L21-22) to automatically capture metrics from the monitoring packages. Since Istio 1.5, standard metrics are directly exported by the Envoy proxy. For a list of metrics, see [Istio Standard Metrics](https://istio.io/latest/docs/reference/config/metrics/#metrics) and [Istio Observability](https://istio.io/latest/docs/ops/best-practices/observability/).

Grafana (part of the monitoring packages) is a standalone component of Big Bang that can provide dashboards to show monitoring data. For more information, see Big Bang's [Grafana docs](https://repo1.dso.mil/platform-one/big-bang/apps/core/monitoring/-/tree/main/docs#grafana) and [Visualizing Metrics with Grafana](https://istio.io/latest/docs/tasks/observability/metrics/using-istio-dashboard/).

### Healthchecks

The Iron Bank/Registry1 Istio Dockerfiles include healthchecks for all images.

### Dependant Packages

- istio-operator