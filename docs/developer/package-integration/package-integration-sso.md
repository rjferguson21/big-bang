# Big Bang Package: Single Sign On (SSO)

Big Bang has configuration for Single Sign-On (SSO) authentication using an identity provider, like Keycloak.  If the package supports SSO, you will need to integrate Big Bang's configuration with the package.  If the package does not support SSO, an [authentication service](https://repo1.dso.mil/platform-one/big-bang/apps/core/authservice) can be used to intercept traffic and provide SSO.  This document details how to setup your package for either scenario.

## Prerequisites

The development environment can be set up in one of two ways: 
    1. Two k3d clusters with keycloak in one cluster and Big Bang and all other apps in the second cluster (see [this quick start guide](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/guides/deployment_scenarios/sso_quickstart.md) for more information)
    2. One k3d cluster using metallb to have keycloak, Big Bang, and all other apps in the one cluster (see [this example config](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/example_configs/dev-sso-values.yaml) for more information)

## Integration

### SSO Integration

#### OIDC Example (GitLab)
For SSO integration using OIDC, add sso.client_id and sso.client_secret under the package within the `bigbang/chart/values.yaml`. Once implemented, enabling SSO will auto-create any required secrets.

```yml
<package>:
    sso:
      enabled: true
      client_id: "" ## want to add dummy values to these 
      client_secret: ""

      # -- I think I will remove this from the in text example, since we are pointing so
      label: ""
```
Example: [GitLab](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/values.yaml#L686-698)

A `bigbang/chart/templates/<package>/secret-sso.yaml` will need to be created in order to auto-generate secrets. The yaml should include the following (be sure to replace `<package>` with the package name):

```yml
{{- if or .Values.addons.<package>.enabled }}
{{- if .Values.addons.<package>.sso.enabled }}
# hostname is deprecated and replaced with domain. But if hostname exists then use it.
{{- $domainName := default .Values.domain .Values.hostname }}
apiVersion: v1
kind: Secret
metadata:
  name: <package>-sso-provider
  namespace: <package>
type: kubernetes.io/opaque
stringData:
  <package>-sso.json: |-
    {
      "name": "openid_connect",
      "label": "{{ .Values.addons.<package>.sso.label }}",
      "args": {
        "name": "openid_connect",
        "scope": [
          "<package>"
        ],
        "response_type": "code",
        "issuer": "https://{{ .Values.sso.oidc.host }}/auth/realms/{{ .Values.sso.oidc.realm }}",
        "client_auth_method": "query",
        "discovery": true,
        "uid_field": "preferred_username",
        "client_options": {
          "identifier": "{{ .Values.addons.<package>.sso.client_id | default .Values.sso.client_id }}",
          "secret": "{{ .Values.addons.<package>.sso.client_secret | default .Values.sso.client_secret }}",
          "redirect_uri": "https://{{ .Values.addons.<package>.hostnames.gitlab }}.{{ $domainName }}/users/auth/openid_connect/callback",
          "end_session_endpoint": "https://{{ .Values.sso.oidc.host }}/auth/realms/{{ .Values.sso.oidc.realm }}/protocol/openid-connect/logout"
        }
      }
    }
{{- end }}
{{- end}}
```
Example: [GitLab](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/gitlab/secret-sso.yaml)

#### SAML Example (Sonarqube)

### AuthService Integration

#### Example (Jaeger)

## Validation
