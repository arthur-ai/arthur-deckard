# Deckard Helm chart

Runs [Arthur Deckard](../../README.md) as a single pod that scans the sources in its
config on an interval and sends what it finds to a SIEM or webhook. It needs no inbound
traffic, so the chart creates no Service.

## Install

```bash
helm install deckard ./charts/deckard \
  --namespace deckard --create-namespace \
  --set-file config=discovery.yaml \
  --set secretEnv.SPLUNK_HEC_TOKEN="$SPLUNK_HEC_TOKEN" \
  --set-file 'secretFiles.files.gcp-key\.json=gcp-key.json'
```

`discovery.yaml` is the same file Docker Compose uses: start from
[`docker-compose/discovery.example.yaml`](../../docker-compose/discovery.example.yaml).
Then watch the first scan:

```bash
kubectl -n deckard logs -f deployment/deckard
```

## Secrets

The config is stored in a Secret, since source fields can hold credentials. Keep
credentials out of it, and in Secrets of their own, with the config's two references:

| In the config | Comes from | Chart-managed | Bring your own |
|---|---|---|---|
| `${NAME}` | an environment variable | `secretEnv.NAME` | `envFrom: [{secretRef: {name: ...}}]` |
| `{file: secrets/NAME}` | `/etc/deckard/secrets/NAME` | `secretFiles.files.NAME` | `secretFiles.existingSecret` (each key a file) |

With External Secrets, Sealed Secrets or similar, create the Secrets yourself and use the
bring-your-own column; `existingConfigSecret.name` does the same for the config.

A change to a Secret the chart manages restarts Deckard on the next `helm upgrade`. A
change to one you manage does not: `kubectl rollout restart deployment/deckard`.

## Cloud credentials from the pod

A cloud source can use the pod's own identity instead of a key in the config, once the
engine is told it may (it refuses by default, so a missing key never silently falls back
to whatever the node can reach):

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/deckard        # EKS IRSA
    # iam.gke.io/gcp-service-account: deckard@my-project.iam.gserviceaccount.com  # GKE
env:
  - {name: ARTHUR_ENGINE_AWS_BEDROCK_ALLOW_DEFAULT_CREDENTIALS, value: "true"}
  # ARTHUR_ENGINE_AWS_EC2_ALLOW_DEFAULT_CREDENTIALS, ARTHUR_ENGINE_AWS_NETWORK_ALLOW_DEFAULT_CREDENTIALS,
  # ARTHUR_ENGINE_GCP_VERTEX_ALLOW_ADC, ARTHUR_ENGINE_GCP_COMPUTE_ENGINE_ALLOW_ADC,
  # ARTHUR_ENGINE_GCP_NETWORK_ALLOW_ADC
```

## Values

| Value | Default | |
|---|---|---|
| `config` | `{}` | The discovery config, as a map or (with `--set-file`) the file as a string |
| `existingConfigSecret.name` / `.key` | `""` / `discovery.yaml` | Use a Secret you manage for the config instead |
| `secretEnv` | `{}` | `NAME: value` pairs, put in a Secret and set as environment |
| `env` / `envFrom` | `[]` | Extra environment, as on any container |
| `secretFiles.files` | `{}` | `NAME: contents`, put in a Secret and mounted at `/etc/deckard/secrets` |
| `secretFiles.existingSecret` | `""` | A Secret you manage, mounted there instead |
| `image.repository` / `.tag` | `arthurplatform/ml-engine` / the chart's `appVersion` | |
| `serviceAccount.create` / `.name` / `.annotations` | `true` / `""` / `{}` | |
| `resources` | 250m / 512Mi requested, 2Gi memory limit | |
| `nodeSelector` | `kubernetes.io/arch: amd64` | The image is built for amd64 only |
| `terminationGracePeriodSeconds` | `30` | Longer than Deckard's 15s wait for running scans |
| `podSecurityContext` / `securityContext` | non-root UID 65532, read-only root, no capabilities | |
| `podAnnotations`, `podLabels`, `tolerations`, `affinity`, `imagePullSecrets` | | As usual |

## Why one replica

The deployment always runs exactly one pod, with the `Recreate` strategy. A second pod
would run every scan again and send every agent twice; Recreate keeps a rollout from
briefly doing the same. Deckard holds no state, so a pod that is rescheduled just scans
again on start.
