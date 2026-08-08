{{/*
Common names. We deliberately keep subchart names (postgresql/mysql/redis) at
their defaults so the Bitnami templates resolve their own helpers correctly.
*/}}
{{- define "new-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "new-api.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "new-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "new-api.labels" -}}
helm.sh/chart: {{ include "new-api.chart" . }}
app.kubernetes.io/name: {{ include "new-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: gateway
{{- end -}}

{{/*
Selector labels — must stay stable across revisions.
*/}}
{{- define "new-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "new-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: gateway
{{- end -}}

{{/*
Service account name. Defaults to fullname, honours serviceAccount.name.
*/}}
{{- define "new-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "new-api.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Image reference: registry/repository:tag[:@digest]
*/}}
{{- define "new-api.image" -}}
{{- $registry := default .Values.image.registry .Values.global.imageRegistry -}}
{{- $repo := .Values.image.repository -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- if .Values.image.digest -}}
{{- printf "%s/%s@%s" $registry $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s/%s:%s" $registry $repo $tag -}}
{{- end -}}
{{- end -}}

{{/*
Global image pull secrets merged from image and global.
*/}}
{{- define "new-api.imagePullSecrets" -}}
{{- $secrets := concat .Values.image.pullSecrets .Values.global.imagePullSecrets -}}
{{- if $secrets -}}
imagePullSecrets:
{{- range $secrets }}
  - name: {{ . | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
SQL_DSN. Always sourced from the external database DSN.
  PostgreSQL: postgresql://user:pass@host:5432/dbname
  MySQL:      user:pass@tcp(host:3306)/dbname?parseTime=true
*/}}
{{- define "new-api.sqlDsn" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.dsn -}}
{{- else -}}
{{- fail "externalDatabase.enabled must be true and externalDatabase.dsn must be set" -}}
{{- end -}}
{{- end -}}

{{/*
LOG_SQL_DSN. Optional separate log database on the same external server.
Only emitted when externalDatabase.logDsn is non-empty.
*/}}
{{- define "new-api.logSqlDsn" -}}
{{- .Values.externalDatabase.logDsn -}}
{{- end -}}

{{/*
REDIS_CONN_STRING. Always sourced from redis.external.connectionString.
*/}}
{{- define "new-api.redisConnString" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.connectionString -}}
{{- else -}}
{{- fail "redis.external.enabled must be true and redis.external.connectionString must be set" -}}
{{- end -}}
{{- end -}}

{{/*
Storage class resolver: global > local > "".
Usage: {{ include "new-api.storageClass" (dict "global" .Values.global "local" .Values.persistence.data) }}
*/}}
{{- define "new-api.storageClass" -}}
{{- .global.storageClass | default .local.storageClass -}}
{{- end -}}
