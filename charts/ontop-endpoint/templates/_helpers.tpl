{{/*
Expand the name of the chart.
*/}}
{{- define "ontop-endpoint.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ontop-endpoint.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ontop-endpoint.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ontop-endpoint.labels" -}}
helm.sh/chart: {{ include "ontop-endpoint.chart" . }}
{{ include "ontop-endpoint.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ontop-endpoint.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ontop-endpoint.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ontop-endpoint.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ontop-endpoint.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ontop-endpoint.env" -}}
{{- range $name, $value := . }}
    {{upper $name}}: {{$value | quote}}
{{- end }}
{{- end }}

{{- define "ontop-endpoint.env-deploy" -}}
{{ $cm := .Values.envConfigMapName }}
{{- range $name, $value := .Values.env }}
- name: {{upper $name}}
  valueFrom:
    configMapKeyRef:
      name: {{$cm | quote}}
      key: {{$name | quote}}
{{- end }}
{{- end }}