# Credentials for Big Bang Packages

This document includes details on credentials to access each package in a default install (without SSO). Note that some packages called out do not have built in auth, but do provide auth mechanisms when used with SSO/Authservice. It is safe to assume that any packages not listed here either have no need for authentication or use different methods (ex: velero require kubectl access).

## Packages with no built in authentication

- Jaeger (can use authservice + SSO)
- Prometheus (can use authservice + SSO)
- Alertmanager (can use authservice + SSO)

## Packages with built in authentication

| Package (Application) | Default Username | Default Password | Additional Notes |
| --------------------- | ---------------- | ---------------- | ---------------- |
| Kiali | N/A | (randomly generated) | Use `kubectl get secret -n kiali \| grep kiali-service-account-token \| awk '{print $1}' \| xargs kubectl get secret -n kiali -o go-template='{{.data.token \| base64decode}}'` to get the token |
| Logging (Kibana) | `elastic` | (randomly generated) | Use `kubectl get secrets -n logging logging-ek-es-elastic-user -o go-template='{{.data.elastic \| base64decode}}'` to get the password |
| Monitoring (Grafana) | `admin` | `prom-operator` | Can be overridden with `monitoring.values.grafana.adminPassword` |
| Twistlock | N/A | N/A | Prompted to setup an admin account when you first hit the virtual service, no default user |
| ArgoCD | ? | ? | ? |
| Minio | ? | ? | ? |
| Gitlab | ? | ? | ? |
| Nexus | ? | ? | ? |
| Sonarqube | ? | ? | ? |
| Anchore | ? | ? | ? |
| Mattermost | N/A | N/A | Prompted to setup an account when you first hit the virtual service - this user becomes admin, no default user |
| Keycloak | ? | ? | ? |
