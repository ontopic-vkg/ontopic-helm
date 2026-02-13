{{/*
Expand the name of the chart.
*/}}
{{- define "ontopic-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ontopic-server.fullname" -}}
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
{{- define "ontopic-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ontopic-server.labels" -}}
helm.sh/chart: {{ include "ontopic-server.chart" . }}
{{ include "ontopic-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ontopic-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ontopic-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ontopic-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ontopic-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ontopic-server.env" -}}
{{- range $name, $value := . }}
    {{upper $name}}: {{$value | quote}}
{{- end }}
{{- end }}

{{- define "ontopic-server.env-deploy" -}}
{{ $cm := .Values.envConfigMapName }}
{{- range $name, $value := .Values.env }}
- name: {{upper $name}}
  valueFrom:
    configMapKeyRef:
      name: {{$cm | quote}}
      key: {{$name | quote}}
{{- end }}
{{- end }}
{{/*
Init container to create the directory for cloning external JDBC drivers
*/}}
{{- define "ontopic-server.jdbcExternalRepoInitContainer" -}}
{{- if .Values.jdbcExternal.enabled }}
- name: setup-jdbc-external-dir
  image: "{{ .Values.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - sh
    - -c
    - |
      mkdir -p {{ .Values.env.ONTOPIC_SERVER_JDBC_ROOT_DIR }}-external
      echo "Created directory {{ .Values.env.ONTOPIC_SERVER_JDBC_ROOT_DIR }}-external for external JDBC repository clone"
{{- end }}
{{- end }}