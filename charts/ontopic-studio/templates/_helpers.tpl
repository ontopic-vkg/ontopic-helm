{{/*
Expand the name of the chart.
*/}}
{{- define "ontopic-studio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ontopic-studio.fullname" -}}
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
{{- define "ontopic-studio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ontopic-studio.labels" -}}
helm.sh/chart: {{ include "ontopic-studio.chart" . }}
{{ include "ontopic-studio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ontopic-studio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ontopic-studio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ontopic-studio.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ontopic-studio.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ontopic-studio.hasArrayKey" -}}
{{- $key := .Key -}}
{{- $array := .Array -}}
{{- $found := false -}}
{{- range $array -}}
  {{- if hasKey . $key -}}
    {{- $found = true -}}
    {{- break -}}
  {{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}

{{- define "ontopic-studio.hasExistingClaim" -}}
{{- $found := false -}}
{{- range $name, $values := .services }}
  {{- $context := dict "Key" "existingClaim" "Array" $values.volumes -}}
  {{- if include "ontopic-studio.hasArrayKey" $context | fromYaml -}}
    {{- $found = true -}}
    {{- break -}}
  {{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}
