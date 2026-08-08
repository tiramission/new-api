# new-api Helm Chart

Helm chart for [new-api](https://github.com/QuantumNous/new-api), an AI API gateway/proxy that aggregates 40+ upstream AI providers behind a unified OpenAI-compatible API, with user management, billing, rate limiting, and an admin dashboard.

This chart deploys the **new-api application only**. Database and Redis are **not bundled** — they must be provided externally via `externalDatabase` and `redis.external`. Deploy them separately, for example with the `helm/infra` chart (official PostgreSQL + Redis images mirrored to a private registry).

## Quick start

```bash
# 1. Deploy the infra chart (PostgreSQL + Redis)
helm install infra ./helm/infra --namespace new-api --create-namespace

# 2. Install new-api, wiring the external services
helm install my-release ./helm/new-api \
  --namespace new-api \
  --set externalDatabase.dsn="postgresql://newapi:pass@infra-postgresql:5432/new-api" \
  --set redis.external.connectionString="redis://:pass@infra-redis:6379/0"

# 3. Get the URL
kubectl -n new-api port-forward svc/my-release-new-api 3000:3000
open http://127.0.0.1:3000
```

First login: `root` / `123456` — **change the password immediately**.

## Using an external database / Redis

The chart requires an external database and, optionally, Redis:

```yaml
externalDatabase:
  enabled: true
  dsn: "postgresql://user:pass@db.internal:5432/new-api"
  logDsn: "postgresql://user:pass@db.internal:5432/new-api-log"  # optional
redis:
  external:
    enabled: true
    connectionString: "redis://:pass@cache.internal:6379/0"
```

Both PostgreSQL and MySQL DSNs are supported:

- PostgreSQL: `postgresql://user:pass@host:5432/dbname`
- MySQL: `user:pass@tcp(host:3306)/dbname?parseTime=true`

## Production checklist

```yaml
# 1) Strong, unique passwords in the external database/Redis

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
| `database.maxIdleConns` etc. | `100/1000/60/200` | Connection pool tuning. |
| `externalDatabase.enabled` | `true` | Must be true (no bundled DB). |
| `externalDatabase.dsn` / `logDsn` | `""` | Full DSN(s). |
| `redis.external.enabled` | `true` | Use external Redis. |
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

Enable `app.args: ["--log-dir","/app/logs"]` and keep `persistence.logs.enabled: true` to persist structured log files. For a dedicated log database, set `externalDatabase.logDsn`.

## Troubleshooting

- **`helm template` fails with "externalDatabase.enabled must be true"** — the chart requires an external DSN; the bundled subcharts were removed.
- **Pod crash-loops with `SQL_DSN` errors** — verify the external database is reachable and credentials in `externalDatabase.dsn` match.
- **Multi-replica login flapping** — `SESSION_SECRET` must be set and identical across replicas.

## License

new-api is released under its project license (see repository root). This chart follows the same terms.
