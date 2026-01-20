{{/*
Expand the name of the chart.
*/}}
{{- define "ontopic-suite.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ontopic-suite.fullname" -}}
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
{{- define "ontopic-suite.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ontopic-suite.labels" -}}
helm.sh/chart: {{ include "ontopic-suite.chart" . }}
{{ include "ontopic-suite.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ontopic-suite.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ontopic-suite.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ontopic-suite.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ontopic-suite.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ontopic-suite.hasArrayKey" -}}
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

{{- define "ontopic-suite.hasExistingClaim" -}}
{{- $found := false -}}
{{- range $name, $values := .services }}
  {{- $context := dict "Key" "existingClaim" "Array" $values.volumes -}}
  {{- if include "ontopic-suite.hasArrayKey" $context | fromYaml -}}
    {{- $found = true -}}
    {{- break -}}
  {{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}
