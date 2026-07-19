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
when serviceAccount.name is empty.
*/}}
{{- define "hive-metastore.serviceAccountName" -}}
{{- $sa := .Values.serviceAccount -}}
{{- if and $sa $sa.name -}}
{{ $sa.name }}
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
Embedded PostgreSQL resource name
*/}}
{{- define "hive-metastore.postgresql.fullname" -}}
{{ include "hive-metastore.fullname" . }}-postgresql
{{- end -}}

{{/*
StorageClass name. Defaults to a release-specific name because StorageClasses
are cluster-scoped.
*/}}
{{- define "hive-metastore.storageClass.name" -}}
{{- if .Values.storageClass.name -}}
{{ .Values.storageClass.name }}
{{- else -}}
{{ include "hive-metastore.fullname" . }}-zrs
{{- end -}}
{{- end -}}

{{/*
Guard: embedded MySQL and PostgreSQL cannot both be enabled.
*/}}
{{- define "hive-metastore.database.validate" -}}
{{- if and .Values.mysql.enabled .Values.postgresql.enabled -}}
{{- fail "mysql.enabled and postgresql.enabled are mutually exclusive; enable at most one embedded database." -}}
{{- end -}}
{{- end -}}

{{/*
JDBC driver name. Embedded DBs override the external database.driverName.
*/}}
{{- define "hive-metastore.database.driverName" -}}
{{- include "hive-metastore.database.validate" . -}}
{{- if .Values.mysql.enabled -}}
com.mysql.cj.jdbc.Driver
{{- else if .Values.postgresql.enabled -}}
org.postgresql.Driver
{{- else -}}
{{ .Values.database.driverName }}
{{- end -}}
{{- end -}}

{{/*
JDBC URL used by hive-site.xml. When mysql.enabled or postgresql.enabled is
true, the URL points at the in-cluster service; otherwise the external
database.url is returned verbatim.
*/}}
{{- define "hive-metastore.database.url" -}}
{{- include "hive-metastore.database.validate" . -}}
{{- if .Values.mysql.enabled -}}
{{- $host := include "hive-metastore.mysql.fullname" . -}}
jdbc:mysql://{{ $host }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.mysql.service.port }}/{{ .Values.mysql.database }}?{{ .Values.mysql.jdbcParams }}
{{- else if .Values.postgresql.enabled -}}
{{- $host := include "hive-metastore.postgresql.fullname" . -}}
jdbc:postgresql://{{ $host }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.database }}{{ if .Values.postgresql.jdbcParams }}?{{ .Values.postgresql.jdbcParams }}{{ end }}
{{- else -}}
{{ .Values.database.url }}
{{- end -}}
{{- end -}}

{{- define "hive-metastore.database.username" -}}
{{- if .Values.mysql.enabled -}}
{{ .Values.mysql.user }}
{{- else if .Values.postgresql.enabled -}}
{{ .Values.postgresql.user }}
{{- else -}}
{{ .Values.database.username }}
{{- end -}}
{{- end -}}

{{- define "hive-metastore.database.password" -}}
{{- if .Values.mysql.enabled -}}
{{ .Values.mysql.password }}
{{- else if .Values.postgresql.enabled -}}
{{ .Values.postgresql.password }}
{{- else -}}
{{ .Values.database.password }}
{{- end -}}
{{- end -}}

{{/*
schematool -dbType value. Embedded DBs pin it; otherwise honor schemaInit.dbType.
*/}}
{{- define "hive-metastore.schemaInit.dbType" -}}
{{- if .Values.mysql.enabled -}}
mysql
{{- else if .Values.postgresql.enabled -}}
postgres
{{- else -}}
{{ .Values.schemaInit.dbType }}
{{- end -}}
{{- end -}}

{{/*
True when the schema-init Job should run as a helm hook (external DB only).
When an embedded DB is used, the Job runs after the DB Deployment is up.
*/}}
{{- define "hive-metastore.schemaInit.useHook" -}}
{{- if or .Values.mysql.enabled .Values.postgresql.enabled -}}false{{- else -}}true{{- end -}}
{{- end -}}

{{/*
Embedded DB service host (FQDN inside the cluster). Empty for external DB —
callers must decide how to wait for external DBs on their own.
*/}}
{{- define "hive-metastore.database.embedded.host" -}}
{{- if .Values.mysql.enabled -}}
{{ include "hive-metastore.mysql.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- else if .Values.postgresql.enabled -}}
{{ include "hive-metastore.postgresql.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}
{{- end -}}

{{- define "hive-metastore.database.embedded.port" -}}
{{- if .Values.mysql.enabled -}}
{{ .Values.mysql.service.port }}
{{- else if .Values.postgresql.enabled -}}
{{ .Values.postgresql.service.port }}
{{- end -}}
{{- end -}}
