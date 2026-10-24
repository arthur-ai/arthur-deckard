{{- define "deckard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "deckard.fullname" -}}
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

{{- define "deckard.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "deckard.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "deckard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "deckard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "deckard.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "deckard.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* The config file's contents, from `config` as either a string or a map. */}}
{{- define "deckard.config" -}}
{{- if kindIs "string" .Values.config }}
{{- .Values.config }}
{{- else }}
{{- toYaml .Values.config }}
{{- end }}
{{- end }}

{{- define "deckard.configSecretName" -}}
{{- default (printf "%s-config" (include "deckard.fullname" .)) .Values.existingConfigSecret.name }}
{{- end }}

{{- define "deckard.configSecretKey" -}}
{{- if .Values.existingConfigSecret.name }}
{{- .Values.existingConfigSecret.key }}
{{- else -}}
discovery.yaml
{{- end }}
{{- end }}

{{- define "deckard.secretFilesName" -}}
{{- default (printf "%s-files" (include "deckard.fullname" .)) .Values.secretFiles.existingSecret }}
{{- end }}
