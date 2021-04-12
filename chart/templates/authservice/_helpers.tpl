{{/*
Create list of URIs for kiali and authservice
*/}}
{{- define "kialiHostsAuthservice" -}}
{{- $hosts := list -}}
{{- range .Values.istio.sso.kiali.uris }}
{{- $hosts = print "https://" ( tpl . $ ) "/login" | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}

{{/*
Create list of URIs for jaeger and authservice
*/}}
{{- define "jaegerHostsAuthservice" -}}
{{- $hosts := list -}}
{{- range .Values.istio.sso.jaeger.uris }}
{{- $hosts = print "https://" ( tpl . $ ) "/login" | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}

{{/*
Create list of URIs for prometheus and authservice
*/}}
{{- define "prometheusHostsAuthservice" -}}
{{- $hosts := list -}}
{{- range .Values.monitoring.sso.prometheus.uris }}
{{- $hosts = print "https://" ( tpl . $ ) "/login/generic_oauth" | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}

{{/*
Create list of URIs for alertmanager and authservice
*/}}
{{- define "alertmanagerHostsAuthservice" -}}
{{- $hosts := list -}}
{{- range .Values.monitoring.sso.alertmanager.uris }}
{{- $hosts = print "https://" ( tpl . $ ) "/login/generic_oauth" | append $hosts -}}
{{- end -}}
{{- join ","  $hosts }}
{{- end -}}