# Credentials for Big Bang Packages

This document includes details on credentials to access each package in a default install (without SSO). Note that some packages called out do not have built in auth, but do provide auth mechanisms when used with SSO/Authservice. Any packages not listed on this doc do not have traditional or SSO authentication.

## Packages with no built in authentication

- Jaeger (uses authservice)
- Prometheus (uses authservice)
- Alertmanager (uses authservice)

## Packages with built in authentication

| Package (Application) | Default Username | Default Password | Additional Notes |
| --------------------- | ---------------- | ---------------- | ---------------- |
| Logging (Kibana) | elastic | (randomly generated) | Use `kubectl get secrets -n logging logging-ek-es-elastic-user -o go-template='{{.data.elastic \| base64decode}}'` to get the password |
| Kiali | N/A | (randomly generated) | Use `kubectl get secret -n kiali \| grep kiali-service-account-token \| awk '{print $1}' \| xargs kubectl get secret -n kiali -o go-template='{{.data.token \| base64decode}}'` to get the token |
| Mattermost | N/A | N/A | First user to access Mattermost and sign up becomes an Admin |
