# Big Bang Package: Monitoring

Monitoring packages requires a way to scrape metrics, provide those to data storage, and analyzing the results.  Big Bang uses Prometheus and Grafana as the service for monitoring.  Most packages offer built-in Prometheus metrics scraping or an add-on that will scrape the metrics.  This document will show you how to integrate metrics scraping with Big Bang.

## Prerequisites

Before integrating with Prometheus, you must identify the following:

- Does the application support metrics exporting for Prometheus.  If not, you will need to find a Prometheus exporter to provide this service.
- Does the upstream Helm chart for the application (or exporter) support Prometheus natively?  If not, we'll have to create our own monitoring resources.
   > Searching the Helm chart for `monitoring.coreos.com` will usually find any resources that support Prometheus
- What path and port are used to scrape metrics on the application or exporter?
- What services and/or pods are deployed that should be monitored?

## Integration

### Pass down values

Big Bang passes down the `monitoring.enabled` value to packages to notify them if the Prometheus/Grafana stack is enabled.  Typically, the upstream chart will already have a value to enable the monitor.  If, the Helm chart does not have a value, create a new one called `monitoring.enabled` in the upstream Helm chart's `values.yaml`

> Remember to add a comment in `values.yaml` that this was added for Big Bang

In `bigbang/templates/podinfo/values.yaml`, add the following to pass down the value from Big Bang to PodInfo.

```yaml
serviceMonitor:
  enabled: {{ .Values.monitoring.enabled }}
```

> The key used to turn on metrics varies by application.  Use `monitoring.enabled` if there is no key available.

### Dependency

If we plan to scrape metrics from the application with the monitoring stack, we need to make sure the monitoring stack is deployed first so that CRDs are in place before we deploy our resources.  To do this, we add a `dependsOn` section in the `bigbang/templates/podinfo/helmrelease.yaml` file like this:

```yaml
spec:
  {{- if or .Values.istio.enabled .Values.monitoring.enabled }}
  dependsOn:
    {{- if .Values.istio.enabled }}
    - name: istio
      namespace: {{ .Release.Namespace }}
    {{- end }}
    {{- if .Values.monitoring.enabled }}
    - name: monitoring
      namespace: {{ .Release.Namespace }}
    {{- end }}
  {{- end }}


```

> We previously had a dependency on Istio, which we leave in place in this example.

### Service Monitor

If the upstream Helm chart provides you with a `ServiceMonitor` and `Service` for scraping metrics, verify that there is a conditional around each one to only deploy them if monitoring is enabled (e.g. `{{- if .Values.serviceMonitor.enabled }}`)

If the upstream chart does **not** provide a `ServiceMonitor` and `Service` for scraping metrics, you will need to create one yourself using the [Prometheus instructions for running an exporter](https://github.com/prometheus-operator/prometheus-operator/blob/v0.52.0/Documentation/user-guides/running-exporters.md).

> Any new resources should be placed in the `chart/templates/bigbang` folder.

### RBAC

If the application is using Role Based Access Control (RBAC), you may need to create rules for Prometheus to access the metrics.  Check the upstream Helm chart to make sure this is already done for you, or implement a new `ClusterRole` and `ClusterRoleBinding` into the chart following the [Prometheus RBAC documentation](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md#enable-rbac-rules-for-prometheus-pods)

### Alerts

Alerting rules allow you to define alert conditions based on Prometheus expression language expressions and to send notifications about firing alerts to an external service.  By creating a `PrometheusRule`, you can configure these conditions for your application.

You will need to decide what aspects of the application should be monitored and alerted on to detect potential failures in the service it provides.  Some examples include:

- Low disk space on a persistent volume
- Loss of connectivity to external resources
- Metrics cannot be scraped
- Operator down
- Pods in CrashLookBackOff state
- Pods restarting too often
- Latency too high
- Web application returns 4xx or 5xx too often
- No log messages for too long
- Pod memory too close to limit

All of these rules must be based on [PromQL queries](https://prometheus.io/docs/prometheus/latest/querying/basics/) using the application's metrics.

Once you have identified what you want to monitor, create [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) and add them to a [PrometheusRule](https://prometheus-operator.dev/docs/operator/api/#prometheusrule) resource.  The rule should reside in the `chart/templates/bigbang' folder and only be deployed if monitoring is enabled.

Some examples of rules can be found in the [Big Bang monitoring chart](https://repo1.dso.mil/platform-one/big-bang/apps/core/monitoring/-/tree/main/chart/templates/prometheus/rules).

### Dashboards

Dashboards are important for admins of your package to understand what is happening.  If there is already a ready-made Grafana dashboard for your package, you should use [Kpt](https://googlecontainertools.github.io/kpt/installation/) to sync it into the Git repository:

```shell
# There isn't a dashboard for podinfo, so we use flux as an example here
kpt pkg get https://github.com/fluxcd/flux2.git//manifests/monitoring/grafana/dashboards@v0.9.1 dashboards

# Commit
git add -A
git commit -m "feat: Grafana dashboard"
git push
```

Unfortunately, unless you add your dashboard to the [Monitoring Helm chart](https://repo1.dso.mil/platform-one/big-bang/apps/core/monitoring), you must manually deploy it into Grafana.  We'll do this in when validating everything.

## Validation

### Setup

Monitoring must be enabled in our Big Bang deployment and our application.  We do this by setting `monitoring.enabled`: `true` in `bigbang/values.yaml`.  Then, deploy Big Bang and your application to your cluster.

```shell
# This assumes you have the Big Bang repository cloned in ~/bigbang
helm upgrade -i -n bigbang --create-namespace -f ~/bigbang/chart/values.yaml -f bigbang/values.yaml bigbang ~/bigbang/chart

# Deploy your application on top of Big Bang using the same values
helm upgrade -i -n bigbang --create-namespace -f ~/bigbang/chart/values.yaml -f bigbang/values.yaml bigbang-podinfo bigbang
```

> Don't forget to also include your Big Bang values for [TLS certificates](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/ingress-certs.yaml) and Iron Bank pull credentials.

```shell
# Wait for the cluster to deploy
watch kubectl get gitrepo,hr,po -A

# Test ingress to monitoring stack
curl -L https://prometheus.bigbang.dev
curl -L https://grafana.bigbang.dev
```

> If your application also has an ingress, test it (e.g. `https://podinfo.bigbang.dev`)

### Target

Open `https://prometheus.bigbang.dev` and navigate to `Status > Targets`.  The `State` should show `UP` if metrics are being scraped for your package.

> There should be one `Endpoint` for every replica pod of your package.

### Alert Rules

In Prometheus, navigate to `Alerts`.  Verify that the `PrometheusRule` alerting rules show up here and are green.

### Dashboards

Open `https://grafana.bigbang.dev` and select `Create > Import` on the left toolbar.  Upload the `.json` file(s) located in the `dashboards` directory of your repo.  Validate that they are successfully showing data for your package.

> If you do not have a dashboard, you can create your own using `Create > Dashboard`, adding a panel, and querying data from your package.
