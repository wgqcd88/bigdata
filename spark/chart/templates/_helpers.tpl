{{/*
Chart full name
*/}}
{{- define "spark.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels (stable subset used in Deployment.spec.selector and Service.spec.selector)
*/}}
{{- define "spark.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "spark.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Thrift Server selector labels
*/}}
{{- define "spark.thrift.selectorLabels" -}}
{{ include "spark.selectorLabels" . }}
app.kubernetes.io/component: thrift-server
{{- end }}

{{/*
Thrift Server labels (selector + common)
*/}}
{{- define "spark.thrift.labels" -}}
{{ include "spark.labels" . }}
app.kubernetes.io/component: thrift-server
{{- end }}

{{/*
History Server selector labels
*/}}
{{- define "spark.history.selectorLabels" -}}
{{ include "spark.selectorLabels" . }}
app.kubernetes.io/component: history-server
{{- end }}

{{/*
History Server labels (selector + common)
*/}}
{{- define "spark.history.labels" -}}
{{ include "spark.labels" . }}
app.kubernetes.io/component: history-server
{{- end }}

{{/*
Namespace — prefer Release namespace; values.namespace only as an override
*/}}
{{- define "spark.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}
