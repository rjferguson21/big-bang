# Big Bang Production

Table of Contents

- [Big Bang Production](#big-bang-production)
  - [Production Deployment](#production-deployment)

## Production Deployment

Note: When deploying to production, `chart/templates/gatekeeper/values.yaml` file should be modified to remove istio-system from `excludedNamespaces` under the `allowedDockerRegistries` violations. Production should not allow containers in the `istio-system` namespace to be pulled from outside of Registry1. 

Lines to be removed:
```
       {{- if .Values.istio.enabled }}
        - istio-system # allows creation for loadbalancer pods for various ports and various vendor loadbalancers
       {{- end }}
```
Expected Yaml:
```
  allowedDockerRegistries:
    match:
      excludedNamespaces: 
        - kube-system # ignored as the kubernetes distro cannot be controlled
    {{- if .Values.addons.mattermost.enabled }}
    parameters:
      exemptContainers:
        - init-check-database # mattermost needs postgres:13 image and cannot override the upstream
    {{- end }}

```


