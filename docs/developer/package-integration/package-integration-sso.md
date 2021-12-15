# Big Bang Package: Single Sign On (SSO)

Big Bang has configuration for Single Sign-On (SSO) authentication using an identity provider, like Keycloak.  If the package supports SSO, you will need to integrate Big Bang's configuration with the package.  If the package does not support SSO, an [authentication service](https://repo1.dso.mil/platform-one/big-bang/apps/core/authservice) can be used to intercept traffic and provide SSO.  This document details how to setup your package for either scenario.

## Prerequisites

The development environment can be set up in one of two ways: 
    1. Two k3d clusters with keycloak in one cluster and Big Bang and all other apps in the second cluster (see [this quick start guide](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/guides/deployment_scenarios/sso_quickstart.md) for more information)
    2. One k3d cluster using metallb to have keycloak, Big Bang, and all other apps in the one cluster (see [this example config](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/example_configs/dev-sso-values.yaml) for more information)

## Integration

### SSO Integration

All package SSO Integrations within BigBang require a `<package>.sso` block within the BigBang [chart values](../../chart/values.yaml) for your package along with an enabled flag:

```yml
<package>:
    sso:
      enabled: true
```
Based on the authentication protocol implemented by the package being integrated, either Security Access Markup Language (SAML) or OpenID (OIDC), follow the appropriate example below.

#### OIDC
For SSO integration using OIDC, at a minimum this usually requires `sso.client_id` and `sso.client_secret` values under the same block above. We can then reference these values further down in either the template values for your package ([eg: Gitlab](../../chart/templates/gitlab/values.yaml)) or [Authservice template values](../../chart/templates/authservice/values.yaml) if there is no built-in support for OIDC or SAML in the package. Authservice will be discussed in more detail further down.

```yml
<package>:
    sso:
      enabled: true
      client_id: "XXXXXX-XXXXXX-XXXXXX-APP" 
      client_secret: "XXXXXXXXXXXX"
```

A `bigbang/chart/templates/<package>/secret-sso.yaml` may need to be created in order to auto-generate secrets if required by the upstream documentation. We can see in the Gitlab documentation for SSO the configuration is handled [via JSON configuration](https://docs.gitlab.com/ee/administration/auth/oidc.html) [within a secret](https://docs.gitlab.com/charts/charts/globals.html#providers). This `secret-sso.yaml` can conditionally be created when `<package>.sso.enabled=true` within the BigBang values.

Example: [GitLab SSO Secret template](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/gitlab/secret-sso.yaml)

If configuration isn't destined for a secret and the package supports SSO options directly via helm values we can create and reference the necessary options from the `<package>.sso` values block. For example, elasticsearch documentation specifies a few [values required to enable and configure OIDC](https://www.elastic.co/guide/en/elasticsearch/reference/master/oidc-guide.html#oidc-enable-token) that we can configure and set to be conditional on `<package>.sso.enabled`.

Example: [ECK template values](../../chart/templates/logging/elasticsearch-kibana/values.yaml)

#### SAML
For SSO integration using SAML, add sso.client_id and sso.client_secret under the package within the `bigbang/chart/values.yaml`. Once implemented, enabling SSO will auto-create any required secrets.

```yml
<package>:
    sso:
      enabled: true
      client_id: "XXXXXX-XXXXXX-XXXXXX-APP"
      provider_name: "P1 SSO"

      # -- plaintext SAML sso certificate.
      certificate: "MITCAYCBFyIEUjNBkqhkiG9w0BA"
      login: jane.example
      name: Jane Example
      email: jane.example@myco.com

      # -- (optional) group sso attribute.
      group: group
```
Example: [Sonarqube](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/values.yaml#L849-874)

In order to auto-generate secrets, additions must be made to `bigbang/chart/templates/<package>/values.yaml`. The yaml should include the following (be sure to replace `<package>` with the package name):

```yml
{{- if .Values.addons.<package>.sso.enabled }}
<package>Properties:
  <package>.auth.saml.enabled: {{ .Values.addons.<package>.sso.enabled }}
  <package>.core.serverBaseURL: https://<package>.{{ $domainName }}
  <package>.auth.saml.applicationId: {{ .Values.addons.<package>.sso.client_id }}
  <package>.auth.saml.providerName: {{ .Values.addons.<package>.sso.provider_name | default .Values.addons.<package>.sso.label }}
  <package>.auth.saml.providerId: https://{{ .Values.sso.oidc.host }}/auth/realms/{{ .Values.sso.oidc.realm }}
  <package>.auth.saml.loginUrl: https://{{ .Values.sso.oidc.host }}/auth/realms/{{ .Values.sso.oidc.realm }}/protocol/saml
  <package>.auth.saml.certificate.secured: {{ .Values.addons.<package>.sso.certificate }}
  <package>.auth.saml.user.login: {{ .Values.addons.<package>.sso.login | default "login" }}
  <package>.auth.saml.user.name: {{ .Values.addons.<package>.sso.name | default "name" }}
  <package>.auth.saml.user.email: {{ .Values.addons.<package>.sso.email | default "email" }}
  {{- if .Values.addons.<package>.sso.group }}
  <package>.auth.saml.user.group: {{ .Values.addons.<package>.sso.group }}
  {{- end }}
{{- end }}
```
Example: [Sonarqube](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/sonarqube/values.yaml#L32-47)

### AuthService Integration
If SSO is not availble on the package to be integrated, Istio AuthService can be used for authentication. For AuthService integration, add sso.client_id and sso.client_secret under the package within the `bigbang/chart/values.yaml`. Any values not explicitly set in this file will be inherited from the global values.

```yml
<package>:
  sso:
    enabled: true
    client_id: "XXXXXX-XXXXXX-XXXXXX-APP"
    client_secret: "XXXXXXXXXXXXX"
```
Example: [Jaeger](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/values.yaml#L234-248)

Global values need to be set within AuthService, including `chains` and `certificate_authority` information that must be passed to the package. Values should be set in `bigbang/chart/templates/authservice/values.yaml`, as shown below:

```yml
global:
  {{- if .Values.sso.certificate_authority }}
  certificate_authority: {{ .Values.sso.certificate_authority | quote }}
  {{- end }}

chains:
  {{- if .Values.addons.authservice.chains }}
  {{ .Values.addons.authservice.chains | toYaml | nindent 2 }}
  {{- end }}

  {{- if .Values.<package>.sso.enabled }}
  <package>:
    match:
      header: ":authority"
    {{- $<package>Values := .Values.<package>.values | default dict }}
    {{- $<package>IstioValues := $<package>Values.istio | default dict }}
    {{- $<package>HostValues := $<package>IstioValues.jaeger | default dict}}
    {{- if hasKey $<package>HostValues "hosts" }}
      prefix: {{ range .Values.<package>.values.istio.<package>.hosts }}{{ tpl . $}}{{ end }}
    callback_uri: https://{{ range .Values.<package>.values.istio.<package>.hosts }}{{ tpl . $}}{{ end }}/login
    {{- else }}
      prefix: "tracing"
    callback_uri: https://tracing.{{ $domainName }}/login
    {{- end }}
    client_id: "{{ .Values.<package>.sso.client_id }}"
    client_secret: "{{ .Values.<package>.sso.client_secret }}"
  {{- end }}
```
Example: [AuthService](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/authservice/values.yaml#L41-74)

In order to use Istio injection to route all package traffic through the Istio side car proxy, additions must be made to `bigbang/chart/templates/<package>/values.yaml`. The yaml should include the following (be sure to replace `<package>` with the package name):

```yml
sso:
  enabled: {{ .Values.<package>.sso.enabled }}

{{- if .Values.<package>.sso.enabled }}
<package>:
  spec:
    {{- $<package>AuthserviceKey := (dig "selector" "key" "protect" .Values.addons.authservice.values) }}
    {{- $<package>AuthserviceValue := (dig "selector" "value" "keycloak" .Values.addons.authservice.values) }}
    allInOne:
      labels:
        {{ $<package>AuthserviceKey }}: {{ $<package>AuthserviceValue }}
    query:
      labels:
        {{ $<package>AuthserviceKey }}: {{ $<package>AuthserviceValue }}
{{- end }}
```
Example: [Jaeger](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/jaeger/values.yaml#L28-42)

## Validation
For validating package integration with Single Sign On (SSO), carry out the following basic steps:
1. Enable the package and SSO within Big Bang through the values added in the sections above.
2. Using an internet browser, browse to your application (e.g. sonarqube.bigbang.dev)
3. If using AuthService, confirm a redirect to the SSO happens, prompting user sign in. If using SAML/OIDC, click the login button.
4. Sign in as a valid user
5. Successful sign in should return you to the application page
6. Confirm you are in the expected account within the application and that you are able to use the application

Note: An unsuccessful sign in may result in an `x509` cert issues, `invalid client ID/group/user` error, `JWKS` error, or other issues. 
