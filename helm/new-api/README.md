# new-api Helm Chart

Self-contained Helm chart for [new-api](https://github.com/QuantumNous/new-api), an AI API gateway/proxy that aggregates 40+ upstream AI providers behind a unified OpenAI-compatible API, with user management, billing, rate limiting, and an admin dashboard.

The chart ships PostgreSQL/MySQL and Redis as **Bitnami subcharts**, so a default install needs no external dependencies.

## Quick start

```bash
# 1. Pull bundled dependencies (Bitnami postgresql / mysql / redis)
helm dependency update ./helm/new-api

# 2. Install
helm install my-release ./helm/new-api \
  --namespace new-api --create-namespace \
  --set postgresql.auth.password=$(openssl rand -hex 16) \
  --set redis.auth.password=$(openssl rand -hex 16)

# 3. Get the URL
kubectl -n new-api port-forward svc/my-release-new-api 3000:3000
open http://127.0.0.1:3000
```

First login: `root` / `123456` — **change the password immediately**.

## Bundled dependencies

| Subchart    | Default  | Wire env          | Disable via                |
|-------------|----------|-------------------|----------------------------|
| `postgresql`| enabled  | `SQL_DSN`         | `postgresql.enabled=false` |
| `mysql`     | disabled | `SQL_DSN`         | `mysql.enabled=true` (+ disable postgresql) |
| `redis`     | enabled  | `REDIS_CONN_STRING` | `redis.enabled=false`    |

`SQL_DSN` and `REDIS_CONN_STRING` are auto-generated in `templates/_helpers.tpl` based on `database.type`, the subchart auth values, and the release name.

## Choosing the database

Default is PostgreSQL (bundled). To use MySQL instead:

```yaml
database:
  type: mysql
postgresql:
  enabled: false
mysql:
  enabled: true
  auth:
    rootPassword: "<strong-password>"
    username: newapi
    password: "<strong-password>"
    database: new-api
```

## Using an external database / Redis

Skip the bundled subcharts and supply DSNs directly:

```yaml
postgresql:
  enabled: false        # or mysql.enabled: false
redis:
  enabled: false
externalDatabase:
  enabled: true
  dsn: "postgresql://user:pass@db.internal:5432/new-api"
  logDsn: "postgresql://user:pass@db.internal:5432/new-api-log"  # optional
redis:
  external:
    enabled: true
    connectionString: "redis://:pass@cache.internal:6379/0"
```

## Production checklist

```yaml
# 1) Strong, unique passwords
postgresql:
  auth:
    postgresPassword: "<strong>"
    password: "<strong>"
redis:
  auth:
    password: "<strong>"

# 2) Multi-replica requires a shared SESSION_SECRET
app:
  replicaCount: 2
extraSecretEnv:
  SESSION_SECRET: "<random-32-byte-string>"
  SESSION_COOKIE_SECURE: "true"
  SESSION_COOKIE_TRUSTED_URL: "https://new-api.example.com"
  TRUSTED_PROXIES: "10.0.0.0/8"

# 3) TLS ingress
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: new-api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: new-api-tls
      hosts:
        - new-api.example.com

# 4) Sizing
app:
  resources:
    requests: { cpu: 500m, memory: 1Gi }
    limits:   { cpu: "4",  memory: 4Gi }
persistence:
  data: { size: 50Gi }
  logs: { size: 50Gi }
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
pdb:
  enabled: true
  minAvailable: 1
```

## Configuration reference

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` / `tag` | `calciumion/new-api` / `latest` | Container image. |
| `app.replicaCount` | `1` | Pod replicas (>1 requires `SESSION_SECRET`). |
| `app.args` | `[]` | Extra args, e.g. `["--log-dir","/app/logs"]`. |
| `app.timezone` | `Asia/Shanghai` | `TZ` env. |
| `app.nodeName` | `new-api-node-1` | `NODE_NAME` for audit logs. |
| `app.resources` | requests 250m/512Mi, limits 2/2Gi | Container resources. |
| `app.livenessProbe` / `readinessProbe` | `/api/status` | Health probes. |
| `app.podAntiAffinityPreset` | `""` | `""` / `soft` / `hard`. |
| `database.type` | `postgresql` | `postgresql` or `mysql`. |
| `database.name` | `new-api` | Database name. |
| `database.logDatabase.enabled` | `false` | Create a separate log DB → `LOG_SQL_DSN`. |
| `database.maxIdleConns` etc. | `100/1000/60/200` | Connection pool tuning. |
| `postgresql.*` / `mysql.*` / `redis.*` | see Bitnami | Subchart values. |
| `externalDatabase.enabled` | `false` | Use external DB (skip subchart). |
| `externalDatabase.dsn` / `logDsn` | `""` | Full DSN(s). |
| `redis.external.enabled` | `false` | Use external Redis. |
| `redis.external.connectionString` | `""` | Full `redis://` URL. |
| `persistence.data` / `logs` | 10Gi each | PVCs for `/data` and `/app/logs`. |
| `service.type` / `port` | `ClusterIP` / `3000` | Service. |
| `ingress.enabled` | `false` | Ingress. |
| `autoscaling.enabled` | `false` | HPA. |
| `pdb.enabled` | `false` | PodDisruptionBudget. |
| `serviceAccount.create` | `true` | Service account. |
| `networkPolicy.enabled` | `false` | NetworkPolicy. |
| `extraEnv` / `extraSecretEnv` | `{}` | Extra env (ConfigMap / Secret). |
| `extraObjects` | `[]` | Render arbitrary extra manifests. |
| `global.imageRegistry` / `storageClass` | `""` | Override for all images / PVCs. |

## Logs

Enable `app.args: ["--log-dir","/app/logs"]` and keep `persistence.logs.enabled: true` to persist structured log files. For a dedicated log database, set `database.logDatabase.enabled: true` (creates `new-api-log` in the bundled server) or `externalDatabase.logDsn`.

## Troubleshooting

- **`helm dependency build` fails on `oci://registry-1.docker.io`** — network reachability to Docker Hub. Retry, or mirror Bitnami charts to a private OCI registry and adjust `Chart.yaml` `repository` fields.
- **Pod crash-loops with `SQL_DSN` errors** — verify the subchart is enabled for the chosen `database.type` and credentials match.
- **Multi-replica login flapping** — `SESSION_SECRET` must be set and identical across replicas.

## License

new-api is released under its project license (see repository root). This chart follows the same terms.
