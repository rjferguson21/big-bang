# Credentials for Big Bang Packages

This document includes details on how to access each package in a default install as well as how to modify default credentials via Helm values where available.



| Package (Application) | Default Username | Default Password | Helm Value (if applicable) | Kubectl Command (if applicable) |
| --------------------- | ---------------- | ---------------- | -------------------------- | ------------------------------- |
| Logging (Kibana) | elastic | (randomly generated) | N/A | `kubectl get secrets -n logging logging-ek-es-elastic-user -o go-template='{{.data.elastic \| base64decode}}'` |
| Kiali | N/A | (randomly generated) | N/A | `kubectl get secret -n kiali \| grep kiali-service-account-token \| awk '{print $1}' \| xargs kubectl get secret -n kiali -o go-template='{{.data.token \| base64decode}}'` |
