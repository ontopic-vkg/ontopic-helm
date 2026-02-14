{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* vim: set filetype=mustache: */}}
{{/*
Return  the proper Storage Class
{{ include "common.storage.class" ( dict "persistence" .Values.path.to.the.persistence "global" $) }}
*/}}
{{- define "common.storage.class" -}}

{{- $storageClass := default .persistence.storageClass ((.global).storageClass) -}}
{{- if $storageClass -}}
  {{- if (eq "-" $storageClass) -}}
      {{- printf "storageClassName: \"\"" -}}
  {{- else }}
      {{- printf "storageClassName: %s" $storageClass -}}
  {{- end -}}
{{- end -}}

{{- end -}}

{{/*
Generate volume mount for a persistence configuration
{{ include "ontopic-server.volumeMount" (dict "config" .Values.endpoint ) }}
*/}}
{{- define "ontopic-server.volumeMount" -}}
{{- if .config.persistence.enabled }}
- name: {{ .config.persistence.volumeName }}
  mountPath: {{ .config.persistence.mountPath }}
  {{- if .config.persistence.subPath }}
  subPath: {{ .config.persistence.subPath }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/*
Generate multiple volume mounts from a single volume with subPath entries
{{ include "ontopic-server.volumeMounts" (dict "config" .Values.endpoints) }}
*/}}
{{- define "ontopic-server.volumeMounts" -}}
{{- if .config.persistence.enabled }}
{{- range $key, $mount := .config.mounts }}
- name: {{ $.config.persistence.volumeName }}
  mountPath: {{ $mount.mountPath }}
  subPath: {{ $mount.subPath }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Generate volume definition for a persistence configuration
{{ include "ontopic-server.volume" (dict "config" .Values.endpoint "context" $) }}
*/}}
{{- define "ontopic-server.volume" -}}
{{- if and .config.persistence.enabled .config.persistence.existingClaim }}
- name: {{ .config.persistence.volumeName }}
  persistentVolumeClaim:
    claimName: {{ tpl .config.persistence.existingClaim .context }}
{{- else if not .config.persistence.enabled }}
- name: {{ .config.persistence.volumeName }}
  emptyDir: {}
{{- end }}
{{- end -}}

{{/*
Generate volumeClaimTemplate for a persistence configuration
{{ include "ontopic-server.volumeClaimTemplate" (dict "config" .Values.endpoint "context" $) }}
*/}}
{{- define "ontopic-server.volumeClaimTemplate" -}}
{{- if and .config.persistence.enabled (not .config.persistence.existingClaim) }}
- apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: {{ .config.persistence.volumeName }}
    {{- if .config.persistence.annotations }}
    annotations: {{- include "common.tplvalues.render" (dict "value" .config.persistence.annotations "context" .context) | nindent 6 }}
    {{- end }}
    {{- if .config.persistence.labels }}
    labels: {{- include "common.tplvalues.render" (dict "value" .config.persistence.labels "context" .context) | nindent 6 }}
    {{- end }}
  spec:
    accessModes:
    {{- range .config.persistence.accessModes }}
      - {{ . | quote }}
    {{- end }}
    {{- if .config.persistence.dataSource }}
    dataSource: {{- include "common.tplvalues.render" (dict "value" .config.persistence.dataSource "context" .context) | nindent 6 }}
    {{- end }}
    resources:
      requests:
        storage: {{ .config.persistence.size | quote }}
    {{- if .config.persistence.selector }}
    selector: {{- include "common.tplvalues.render" (dict "value" .config.persistence.selector "context" .context) | nindent 6 }}
    {{- end }}
    {{- include "common.storage.class" (dict "persistence" .config.persistence "global" .context.Values.global) | nindent 4 }}
{{- end }}
{{- end -}}
