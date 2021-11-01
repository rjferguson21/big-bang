# Big Bang Package: Network Policies
To increase the overall security posture of Big Bang, network policies are put in place to only allow ingress and egress from package namespaces to other needed services.  A deny by default policy is put in place to deny all traffic that is not explicitly allowed.  The following is how to implement the network policies per Big Bang standards.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Integration](#integration)
    - [Default Deny](#default-deny)
    - [Was Something Important Blocked?](#something-important-blocked)
    - [Allowing Exceptions](#allowing-exceptions)
    - [Additional Configuration](#additional-configuration)
3. [Validation](#validation)


## Prerequisites <a name="prerequisites"></a>
- Understanding of ports and communications of applications and other components within BigBang
- `chart/templates/bigbang` and `chart/templates/bigbang/networkpolicies` folders within package for committing bigbang specific templates

## Integration <a name="integration"></a>
All examples in this documentation will center on [podinfo](https://repo1.dso.mil/platform-one/big-bang/apps/sandbox/podinfo).

### Default Deny <a name="default-deny"></a>
In order to keep Big Bang secure, a default deny policy must be put into place for each package. Create `default-deny-all.yaml` inside `chart/templates/bigbang/networkpolicies` with the following details:
```
{{ if .Values.networkPolicies.enabled }}
# Default deny everything to/from this namespace
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny-all
  namespace: {{ .Release.Namespace }}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress: []
  ingress: []
{{- end }}

```
### Was Something Important Blocked? <a name="something-important-blocked"></a>
There are a few ways to determine if a network policy is blocking egress or ingress to or from a pod.
- Test things from the pod's perspective using ssh/exec. See [this portion](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/keycloak_quickstart/docs/guides/deployment_scenarios/sso_quickstart.md#step-18-update-inner-cluster-dns-on-the-workload-cluster) of the keycloak quickstart for an example of how do to that.
- Curl a pod's IP from another pod to see if network polices are blocking that traffic. Use `kubectl pod -o wide -n <podNamespace>` to see pod IP addresses.
- Check the pod logs (or curl from one container to the service) for a `context deadline exceeded` message.

### Allowing Exceptions <a name="allowing-exceptions"></a>
- Egress exceptions to consider:
  - pod to pod
  - SSO
  - storage database
- Ingress exceptions to consider:
  - Kube-api
  - Prometheus
  - web endpoints
- Once you have determined an exception needs to be made, create a template in `chart/templates/bigbang/networkpolicies`. 
- NetworkPolicy templates follow the naming convention of `direction-destination.yaml` (eg: egress-dns.yaml). 
- Each networkPolicy template in the package will have an if statement checking for `networkPolicies.enabled` and will only be present when `enabled: true`

For example, if the podinfo package needs to send information to istiod, add the following content to a file named `egress-istio-d.yaml`:
```
{{- if and .Values.networkPolicies.enabled .Values.istio.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-istiod
  namespace: {{ .Release.Namespace }}
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          app.kubernetes.io/name: istio-controlplane
      podSelector:
        matchLabels:
          app: istiod
    ports:
    - port: 15012
{{- end }}
```

Similarly, if prometheus needs access to podinfo, create an `ingress-monitoring-prometheus.yaml` file with the following contents:
```
{{- if and .Values.networkPolicies.enabled .Values.monitoring.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-monitoring-prometheus
  namespace: {{ .Release.Namespace }}
spec:
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app.kubernetes.io/name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    # Port numbers will vary, dependent on the pod
    - port: 9797  
  podSelector:
    matchLabels:
      app.kubernetes.io/name: podinfo
{{- end }}
```

### Additional Configuration <a name="additional-configruation"></a>
Sample `chart/values.yaml` code:
```
# BigBang specific Network Policy Configuration
networkPolicies:
  enabled: false

  # See `kubectl cluster-info` and then resolve to IP
  controlPlaneCidr: 0.0.0.0/0

  ingressLabels: 
    app: istio-ingressgateway
    istio: ingressgateway
```

- The networkPolicy template is enabled by default because it will inherit the `networkPolicies.enabled` value from BigBang. Use the `enabled: false` code above in order to disable networkPolicy templates for the package. 
- The ingressLabels portion supports packages that have an externally accessible UIs. Values from BigBang will also be inherited in this portion to ensure traffic from the correct istio ingressgateway is whitelisted. 
- If the package needs to talk to the kube-api service (eg: operators) then the `controlPlaneCidr` value will be required.
  - The `controlPlaneCidr` will control egress to the kube-api and be wide open by default, but will inherit the `networkPolicies.controlPlaneCidr` value from BigBang so the range can be locked down.

Sample `chart/templates/bigbang/networkpolicies/egress-kube-api.yaml`:
```
{{- if .Values.networkPolicies.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-kube-api
  namespace: {{ .Release.Namespace }}
spec:
  podSelector: {}
  egress:
  - to:
    - ipBlock:
        cidr: {{ .Values.networkPolicies.controlPlaneCidr }}
        {{- if eq .Values.networkPolicies.controlPlaneCidr "0.0.0.0/0" }}
        # ONLY Block requests to cloud metadata IP
        except:
        - 169.254.169.254/32
        {{- end }}
  policyTypes:
  - Egress
{{- end }}
```
- The networkPolicy template for kube-api egress will look like the above, so that communication to the [AWS Instance Metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) and [Azure Instance Metadata](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/instance-metadata-service) can be limited unless required by the package.

## Validation <a name="validation"></a>
- Package functions as expected and is able to communicate with all BigBang touchpoints.