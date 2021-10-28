# Big Bang Package: Database Integration

If the package you are integrating connects to a database or cache server, you will need to follow the instructions below to integrate this feature into Big Bang

Note: Names of key/values may change based on the application being integrated. Please refer to application documentation for additional information on connecting to an external database.

## Prerequisites

- Existing database or cache server

## Integration

To have the package connect to a database or cache server, you will need to do the following:

- add database values to package in chart/values.yaml

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
- add the following template to bigbang/chart/templates/`<package>`/values:

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
  existingSecret: <package>-db-secret
  service:
    port: {{ .port }}
  {{- else }}
  # Use internal database, defaults are fine
  enabled: true
  {{- end }}
{{- end }}
```
If database values are present for the package then the internal database is disabled by setting `enabled: false` and the server, database, username, and port values are set.

If database values are NOT present then the internal database is enabled and default values declared in the package are used.

Example:

This example will detail how to integrate [PodInfo](https://repo1.dso.mil/platform-one/big-bang/apps/sandbox/podinfo) application into bigbang which uses a cache server.

1) Add database values to package in chart/values.yaml

```
addons:
  podinfo:
    database:
      # -- Hostname of a pre-existing database or cache server to use.
      host: ""
      # -- Port of a pre-existing database or cache server to use.
      port: ""
      # -- Database name to connect to on host.
      database: ""
      # -- Username to connect as to external database, the user must have all privileges on the database.
      username: ""
      # -- Database password for the username used to connect to the existing database.
      password: ""
```

2) Add the following template to bigbang/chart/templates/podinfo/values:

```
{{- with .Values.podinfo.database }}
  # Use external database
  {{- if and .host .port }}
cache: {{ .host }}:{{ .port }}
redis:
  enabled: false
  {{- else }}
  # Use internal database, defaults are fine
redis
  enabled: true
  {{- end }}
{{- end }}
```

## Validation

For validating connection to the external database in your environment or testing in CI you will need to add the specific values to your overrides file or `tests/ci/k3d/values.yaml`.

podinfo example:

```
addons:
  podinfo:
    enabled: true
    database:
      host: "redis.podinfo.com"
      port: "6379"
```