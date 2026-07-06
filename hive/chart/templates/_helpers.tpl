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

{{/*
ServiceAccount name for Workload Identity. Defaults to the chart fullname
when azure.workloadIdentity.serviceAccount.name is empty.
*/}}
{{- define "hive-metastore.serviceAccountName" -}}
{{- $wi := .Values.azure.workloadIdentity -}}
{{- if and $wi $wi.serviceAccount $wi.serviceAccount.name -}}
{{ $wi.serviceAccount.name }}
{{- else -}}
{{ include "hive-metastore.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Embedded MySQL resource name
*/}}
{{- define "hive-metastore.mysql.fullname" -}}
{{ include "hive-metastore.fullname" . }}-mysql
{{- end -}}

{{/*
JDBC URL used by hive-site.xml. When mysql.enabled is true, the URL points at
the in-cluster MySQL service; otherwise the external database.url is returned
verbatim.
*/}}
{{- define "hive-metastore.database.url" -}}
{{- if .Values.mysql.enabled -}}
{{- $host := include "hive-metastore.mysql.fullname" . -}}
jdbc:mysql://{{ $host }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.mysql.service.port }}/{{ .Values.mysql.database }}?{{ .Values.mysql.jdbcParams }}
{{- else -}}
{{ .Values.database.url }}
{{- end -}}
{{- end -}}

{{- define "hive-metastore.database.username" -}}
{{- if .Values.mysql.enabled -}}
{{ .Values.mysql.user }}
{{- else -}}
{{ .Values.database.username }}
{{- end -}}
{{- end -}}

{{- define "hive-metastore.database.password" -}}
{{- if .Values.mysql.enabled -}}
{{ .Values.mysql.password }}
{{- else -}}
{{ .Values.database.password }}
{{- end -}}
{{- end -}}
