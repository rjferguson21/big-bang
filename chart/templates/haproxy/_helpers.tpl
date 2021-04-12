{{/*
Create list of URIs for kiali and haproxy
*/}}
{{- define "kialiHostsHaproxy" -}}
{{- $hosts := list -}}
{{- range .Values.istio.sso.kiali.uris }}
{{- $hosts = print ( tpl . $ ) | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}

{{/*
Create list of URIs for jaeger and haproxy
*/}}
{{- define "jaegerHostsHaproxy" -}}
{{- $hosts := list -}}
{{- range .Values.istio.sso.jaeger.uris }}
{{- $hosts = print ( tpl . $ ) | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}

{{/*
Create list of URIs for prometheus and haproxy
*/}}
{{- define "prometheusHostsHaproxy" -}}
{{- $hosts := list -}}
{{- range .Values.monitoring.sso.prometheus.uris }}
{{- $hosts = print ( tpl . $ ) | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}

{{/*
Create list of URIs for alertmanager and haproxy
*/}}
{{- define "alertmanagerHostsHaproxy" -}}
{{- $hosts := list -}}
{{- range .Values.monitoring.sso.alertmanager.uris }}
{{- $hosts = print ( tpl . $ ) | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}