
{{- define "ontopic-studio.env" -}}
{{- range $name, $value := . }}
    {{upper $name}}: {{$value | quote}}
{{- end }}
{{- end }}

{{- define "ontopic-studio.env-deploy" -}}
{{ $cm := .envConfigMapName }}
{{- range $name, $value := .env }}
- name: {{upper $name}}
  valueFrom:
    configMapKeyRef:
      name: {{$cm | quote}}
      key: {{$name | quote}}
{{- end }}
{{- end }}
