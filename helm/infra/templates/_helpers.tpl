{{- define "infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "infra.fullname" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "infra.postgresImage" -}}
{{- printf "%s:%s" .Values.imageRegistry .Values.postgresql.image.repository -}}
{{- end -}}

{{- define "infra.redisImage" -}}
{{- printf "%s:%s" .Values.imageRegistry .Values.redis.image.repository -}}
{{- end -}}
