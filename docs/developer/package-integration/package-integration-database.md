# Big Bang Package: Database Integration

If the package you are integrating connects to a database or cache server, you will need to follow the instructions below to integrate this feature into Big Bang

## Prerequisites

- Existing database or cache server

## Integration

There are currently 2 typical ways in bigbang that packages connect to a database.

1. Package charts accept values for host, user, pass, etc and the chart makes the necessary secret, configmap etc.

2. Package chart accepts a secret name where all the DB connection info is defined. In these cases we make the secret in the BB chart.

Both ways will first require the following step:

Add database values for the package in bigbang/chart/values.yaml

  Note: Names of key/values may differ based on the application being integrated. Please refer to package chart values to ensure key/values coincide and application documentation for additional information on connecting to a database.

```
<package>
  database:
    # -- Hostname of a pre-existing PostgreSQL database to use.
    host: ""
    # -- Port of a pre-existing PostgreSQL database to use.
    port: ""
    # -- Database name to connect to on host.
    database: ""
    # -- Username to connect as to external database, the user must have all privileges on the database.
    username: ""
    # -- Database password for the username used to connect to the existing database.
    password: ""
```
[Anchore Example](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/values.yaml#L882):
```
    database:
      # -- Hostname of a pre-existing PostgreSQL database to use for Anchore.
      # Entering connection info will disable the deployment of an internal database and will auto-create any required secrets.
      host: ""
      # -- Port of a pre-existing PostgreSQL database to use for Anchore.
      port: ""
      # -- Username to connect as to external database, the user must have all privileges on the database.
      username: ""
      # -- Database password for the username used to connect to the existing database.
      password: ""
      # -- Database name to connect to on host (Note: database name CANNOT contain hyphens).
      database: ""
      # -- Feeds database name to connect to on host (Note: feeds database name CANNOT contain hyphens).
      # Only required for enterprise edition of anchore.
      # By default, feeds database will be configured with the same username and password as the main database. For formatting examples on how to use a separate username and password for the feeds database see https://repo1.dso.mil/platform-one/big-bang/apps/security-tools/anchore-enterprise/-/blob/main/docs/CHART.md#handling-dependencies
      feeds_database: ""

```
**Next details the first way packages connect to a pre-existing database.**

1. Package charts accept values for host, user, pass, etc and the chart makes the necessary secret, configmap etc...

- add a conditional statement to `bigbang/chart/templates/<package>/values` that will check if the database values exist and creates the necessary postgresql values.

  If database values are present, then the internal database is disabled by setting `enabled: false` and the server, database, username, and port values are set.

  If database values are NOT present then the internal database is enabled and default values declared in the package are used.

```
# External Postgres config
{{- with .Values.<package>.database }}
postgresql:
  {{- if and .host .username .password .database .port }}
  # Use external database
  enabled: false
  postgresqlServer: {{ .host }}
  postgresqlDatabase: {{ .database }}
  postgresqlUsername: {{ .username }}
  service:
    port: {{ .port }}
  {{- else }}
  # Use internal database, defaults are fine
  enabled: true
  {{- end }}
{{- end }}
```
[Anchore Example](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/anchore/values.yaml#L49):
```
postgresql:
  imagePullSecrets: private-registry
  {{- if and .Values.addons.anchore.database.host .Values.addons.anchore.database.port .Values.addons.anchore.database.username .Values.addons.anchore.database.password .Values.addons.anchore.database.database }}
  enabled: false
  postgresUser: {{ .Values.addons.anchore.database.username }}
  postgresPassword: {{ .Values.addons.anchore.database.password }}
  postgresDatabase: {{ .Values.addons.anchore.database.database }}
  externalEndpoint: "{{ .Values.addons.anchore.database.host }}:{{ .Values.addons.anchore.database.port }}"
  {{- end }}
```
**The alternative way packages connect to a pre-existing database is detailed below.**

2. Package chart accepts a secret name where all the DB connection info is defined. In these cases we make the secret in the BB chart..

- add conditional statement in `chart/templates/<package>/values.yaml` to add values for database secret, if database values exist. Otherwise the internal database is deployed.
```
{{- with .Values.addons.<package>.database }}
{{- if and .username .password .host .port .database }}
database:
  secret: "<package>-database-secret"
{{- else }}
postgresql:
  image:
    pullSecrets:
      - private-registry
  install: true
{{- end }}
{{- end }}
```

[Mattermost Example](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/mattermost/mattermost/values.yaml#L49)


- create manifest that uses database values to create the database secret referenced above

```
{{- if .Values.addons.<package>.enabled }}
{{- with .Values.addons.<package>.database }}
{{- if and .username .password .host .port .database }}
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: <package>-database-secret
  namespace: <package>
  labels:
    {{- include "commonLabels" $ | nindent 4}}
stringData:
  DB_CONNECTION_CHECK_URL: "postgres://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/{{ .database }}?connect_timeout=10&sslmode={{ .ssl_mode | default "disable" }}"
  DB_CONNECTION_STRING: "postgres://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/{{ .database }}?connect_timeout=10&sslmode={{ .ssl_mode | default "disable" }}"
{{- end }}
{{- end }}
{{- end }}
```

[Mattermost Example](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/templates/mattermost/mattermost/secret-database.yaml):

```
{{- if .Values.addons.mattermost.enabled }}
{{- with .Values.addons.mattermost.database }}
{{- if and .username .password .host .port .database }}
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: mattermost-database-secret
  namespace: mattermost
  labels:
    app.kubernetes.io/name: mattermost
    app.kubernetes.io/component: "collaboration-tools"
    {{- include "commonLabels" $ | nindent 4}}
stringData:
  DB_CONNECTION_CHECK_URL: "postgres://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/{{ .database }}?connect_timeout=10&sslmode={{ .ssl_mode | default "disable" }}"
  DB_CONNECTION_STRING: "postgres://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/{{ .database }}?connect_timeout=10&sslmode={{ .ssl_mode | default "disable" }}"
{{- end }}
{{- end }}
{{- end }}
```

## Validation

For validating connection to the external database in your environment or testing in CI pipeline you will need to add the database specific values to your overrides file or `tests/ci/k3d/values.yaml` respectively.

mattermost example:

```
addons:
  mattermost:
    enabled: true
    database:
      host: "mm-postgres.bigbang.dev"
      port: "5432"
      username: "admin"
      password: "Pa55w0rd"
      database: "db1
```