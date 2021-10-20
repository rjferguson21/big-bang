# Big Bang Package: Network Policies

To help harden the Big Bang, network policies are put in place to only allow ingress and egress from package namespaces to other needed services.  A deny by default policy is put in place to deny all traffic that is not explicitly allowed.  The following is how to implement the network policies per Big Bang standards.

## Prerequisites

TBD

- Understanding of ports and communications of application and other components within BigBang
- `chart/templates/bigbang` and `chart/templates/bigbang/networkpolicies` folders within package for comitting bigbang specific templates

## Integration

- Network Policy templates follow the naming convention of direction-destination.yaml eg: egress-dns.yaml
- Package will have the following values block:
```
networkPolicies:
  enabled: false
  ingressLabels: 
    app: istio-ingressgateway
    istio: ingressgateway
```
The above will control whether networkPolicy templates will be enabled for the package, disabled by default but will inherit the `networkPolicies.enabled` value from BigBang which is enabled by default. The ingressLabels portion are for if a package has an externally accessible UI and will also inherit values from BigBang so that traffic from the correct istio ingressgateway will be whitelisted.

- Each network policy template in the package will have an if statement checking for `networkPolicies.enabled` and will only be present when `enabled: true`
- If the package needs to talk to the kube-api service (eg: operators) then the folloowing value will be required:
```
networkPolicies:

  # See `kubectl cluster-info` and then resolve to IP
  controlPlaneCidr: 0.0.0.0/0
```

The above will control egress to the kube-api, and be wide open by default, but will inherit the `networkPolicies.controlPlaneCidr` value from BigBang so the range can be locked down.

- The network policy template for kube-api egress will look like the following so that communication to the AWS API can be limited unless required by the package: ```yaml egress:
- to:
    - ipBlock: cidr: {{ .Values.networkPolicies.controlPlaneCidr }} {{- if eq .Values.networkPolicies.controlPlaneCidr "0.0.0.0/0" }}
    ONLY Block requests to cloud metadata IP
    except:
        - 169.254.169.254/32 {{- end }} policyTypes:
- Egress

## Validation
- Package functions as expected and is able to communicate with all BigBang touchpoints.
