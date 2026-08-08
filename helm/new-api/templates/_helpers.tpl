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
Database host name for the bundled subchart. Bitnami subcharts expose their
primary service as `<release-name>-postgresql` / `<release-name>-mysql`.
*/}}
{{- define "new-api.databaseHost" -}}
{{- if eq .Values.database.type "postgresql" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else if eq .Values.database.type "mysql" -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- else -}}
{{- fail (printf "Unsupported database.type %q (must be postgresql or mysql)" .Values.database.type) -}}
{{- end -}}
{{- end -}}

{{/*
Database port for the bundled subchart.
*/}}
{{- define "new-api.databasePort" -}}
{{- if eq .Values.database.type "postgresql" -}}5432{{- else if eq .Values.database.type "mysql" -}}3306{{- end -}}
{{- end -}}

{{/*
Database username/password resolved from the matching subchart.
*/}}
{{- define "new-api.databaseUser" -}}
{{- if eq .Values.database.type "postgresql" -}}{{- .Values.postgresql.auth.username -}}{{- else if eq .Values.database.type "mysql" -}}{{- .Values.mysql.auth.username -}}{{- end -}}
{{- end -}}

{{- define "new-api.databasePassword" -}}
{{- if eq .Values.database.type "postgresql" -}}{{- .Values.postgresql.auth.password -}}{{- else if eq .Values.database.type "mysql" -}}{{- .Values.mysql.auth.password -}}{{- end -}}
{{- end -}}

{{/*
SQL_DSN. Uses external DSN when externalDatabase.enabled; otherwise builds a
DSN pointing at the bundled subchart's service.
  PostgreSQL: postgresql://user:pass@host:5432/dbname
  MySQL:      user:pass@tcp(host:3306)/dbname?parseTime=true
*/}}
{{- define "new-api.sqlDsn" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.dsn -}}
{{- else if eq .Values.database.type "postgresql" -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" (include "new-api.databaseUser" .) (include "new-api.databasePassword" .) (include "new-api.databaseHost" .) (include "new-api.databasePort" .) .Values.database.name -}}
{{- else if eq .Values.database.type "mysql" -}}
{{- printf "%s:%s@tcp(%s:%s)/%s?parseTime=true" (include "new-api.databaseUser" .) (include "new-api.databasePassword" .) (include "new-api.databaseHost" .) (include "new-api.databasePort" .) .Values.database.name -}}
{{- end -}}
{{- end -}}

{{/*
LOG_SQL_DSN. Built the same way as SQL_DSN but with the log database name.
Only emitted when database.logDatabase.enabled is true.
*/}}
{{- define "new-api.logSqlDsn" -}}
{{- if .Values.externalDatabase.enabled -}}
{{- .Values.externalDatabase.logDsn -}}
{{- else if eq .Values.database.type "postgresql" -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" (include "new-api.databaseUser" .) (include "new-api.databasePassword" .) (include "new-api.databaseHost" .) (include "new-api.databasePort" .) .Values.database.logDatabase.name -}}
{{- else if eq .Values.database.type "mysql" -}}
{{- printf "%s:%s@tcp(%s:%s)/%s?parseTime=true" (include "new-api.databaseUser" .) (include "new-api.databasePassword" .) (include "new-api.databaseHost" .) (include "new-api.databasePort" .) .Values.database.logDatabase.name -}}
{{- end -}}
{{- end -}}

{{/*
REDIS_CONN_STRING. Uses external when configured; otherwise points at the
bundled Redis subchart's master service with the configured password.
*/}}
{{- define "new-api.redisConnString" -}}
{{- if .Values.redis.external.enabled -}}
{{- .Values.redis.external.connectionString -}}
{{- else -}}
{{- printf "redis://:%s@%s-redis-master:6379" .Values.redis.auth.password .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Storage class resolver: global > local > "".
Usage: {{ include "new-api.storageClass" (dict "global" .Values.global "local" .Values.persistence.data) }}
*/}}
{{- define "new-api.storageClass" -}}
{{- .global.storageClass | default .local.storageClass -}}
{{- end -}}
