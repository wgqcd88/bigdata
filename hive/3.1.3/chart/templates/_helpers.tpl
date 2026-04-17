{{/*
Chart full name
*/}}
{{- define "hive-metastore.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "hive-metastore.labels" -}}
app: {{ include "hive-metastore.fullname" . }}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
release: {{ .Release.Name }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "hive-metastore.selectorLabels" -}}
app: {{ include "hive-metastore.fullname" . }}
{{- end -}}

{{/*
JMX Prometheus exporter defaults (tied to Dockerfile image layout)
*/}}
{{- define "hive-metastore.jmx.agentJar" -}}
/opt/jmx/jmx_prometheus_javaagent-1.5.0.jar
{{- end -}}

{{- define "hive-metastore.jmx.port" -}}
9404
{{- end -}}

{{- define "hive-metastore.jmx.configPath" -}}
/etc/jmx/config.yaml
{{- end -}}
