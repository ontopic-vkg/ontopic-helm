
{{- define "ontopic-suite.env" -}}
{{- range $name, $value := . }}
    {{upper $name}}: {{$value | quote}}
{{- end }}
{{- end }}

{{- define "ontopic-suite.env-deploy" -}}
{{ $cm := .envConfigMapName }}
{{- range $name, $value := .env }}
- name: {{upper $name}}
  valueFrom:
    configMapKeyRef:
      name: {{$cm | quote}}
      key: {{$name | quote}}
{{- end }}
{{- end }}

{{/*
Convert structured OIDC config to environment variables for identity-service
*/}}
{{- define "ontopic-suite.identity-service-oidc-env" -}}
{{- $oidc := . -}}
{{- $env := dict -}}

{{- if $oidc.provider }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_PROVIDER_OAUTH2" $oidc.provider }}
{{- end }}
{{- if $oidc.clientId }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_CLIENT_ID" $oidc.clientId }}
{{- end }}
{{- if $oidc.audience }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_AUDIENCE" $oidc.audience }}
{{- end }}
{{- if $oidc.scopes }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_SCOPES" $oidc.scopes }}
{{- end }}
{{- if $oidc.roles }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_ROLES" $oidc.roles }}
{{- end }}

{{/* Session settings */}}
{{- if $oidc.session }}
{{- if $oidc.session.scope }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_SESSION_SCOPE" $oidc.session.scope }}
{{- end }}
{{- if $oidc.session.prompt }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_SESSION_PROMPT" $oidc.session.prompt }}
{{- end }}
{{- end }}

{{/* Claims mapping */}}
{{- if $oidc.claims }}
{{- if $oidc.claims.email }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_CLAIMS_EMAIL" $oidc.claims.email }}
{{- end }}
{{- if $oidc.claims.group }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_CLAIMS_GROUP" $oidc.claims.group }}
{{- end }}
{{- if $oidc.claims.role }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_CLAIMS_ROLE" $oidc.claims.role }}
{{- end }}
{{- end }}

{{/* Azure-specific settings */}}
{{- if $oidc.azure }}
{{- if $oidc.azure.tenantId }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_AZURE_TENANT_ID" $oidc.azure.tenantId }}
{{- end }}
{{- end }}
{{/* For Azure provider, use clientId for API client ID */}}
{{- if and (eq $oidc.provider "azure") $oidc.clientId }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_AZURE_API_CLIENT_ID" $oidc.clientId }}
{{- end }}

{{/* Okta-specific settings */}}
{{- if $oidc.okta }}
{{- if $oidc.okta.issuerUrl }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_OKTA_ISSUER_URL" $oidc.okta.issuerUrl }}
{{- end }}
{{- end }}

{{/* Keycloak-specific settings */}}
{{- if $oidc.keycloak }}
{{- if $oidc.keycloak.host }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_KEYCLOAK_HOST" $oidc.keycloak.host }}
{{- end }}
{{- if $oidc.keycloak.realm }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_KEYCLOAK_REALM" $oidc.keycloak.realm }}
{{- end }}
{{- if $oidc.keycloak.adminApplication }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_KEYCLOAK_ADMIN_APPLICATION" $oidc.keycloak.adminApplication }}
{{- end }}
{{- if $oidc.keycloak.adminUser }}
{{- $_ := set $env "ONTOPIC_IDENTITY_SERVICE_KEYCLOAK_ADMIN_USER" $oidc.keycloak.adminUser }}
{{- end }}
{{- end }}

{{- toJson $env }}
{{- end }}
