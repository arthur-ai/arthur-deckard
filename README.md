# Arthur Deckard

[![CI](https://github.com/arthur-ai/arthur-deckard/actions/workflows/ci.yaml/badge.svg)](https://github.com/arthur-ai/arthur-deckard/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Find the rogue AI agents running across your organization, and flag them in your SIEM.**

Deckard scans the systems you already run (cloud AI platforms, endpoints, network logs and
your SIEM) for AI agents, and sends every one it finds to Splunk or any webhook. It's
headless, read-only, and runs entirely in your environment.

## Quickstart

You need Docker, a credential for at least one [source](#integrations), and a Splunk HEC
token or an HTTPS endpoint to send events to.

```bash
git clone https://github.com/arthur-ai/arthur-deckard.git
cd arthur-deckard/docker-compose
cp discovery.example.yaml discovery.yaml
cp .env.template .env
mkdir -p secrets
```

Edit `discovery.yaml` to name your sources and destination, put the secrets it references in
`.env` (or as files in `secrets/`), then:

```bash
docker compose up
```

Deckard scans immediately, then on the schedule in your config. Each scan logs how many
agents it sent. See [`docker-compose/`](docker-compose/README.md) for secret files, pinning a
version and troubleshooting.

## Deploy on Kubernetes

```bash
kubectl create namespace deckard
kubectl -n deckard create secret generic deckard-credentials \
  --from-literal=SPLUNK_HEC_TOKEN="$SPLUNK_HEC_TOKEN"

helm install deckard ./charts/deckard -n deckard \
  --set-file config=discovery.yaml \
  --set credentialsSecret=deckard-credentials
```

The config references each key in the Secret as `${NAME}`. See the
[chart's README](charts/deckard/README.md) for the details and cloud workload identity.

## Integrations

| Class | Sources |
|---|---|
| Cloud AI platforms | Vertex AI Agent Engine, AWS Bedrock and AgentCore |
| Endpoints and servers | Jamf Pro, Google Compute Engine, AWS EC2 |
| Network and gateway logs | AWS CloudWatch Logs, Google Cloud Logging |
| Security telemetry | Splunk Enterprise, Elastic Security |

**Destinations:** Splunk HTTP Event Collector, or any HTTPS webhook.

Missing one you use? [Open an issue](https://github.com/arthur-ai/arthur-deckard/issues).

## Documentation

- [How Deckard works](docs/how-it-works.md): discovery classes, sources and scans
- [Events and alerting](docs/events.md): what your SIEM receives and what to alert on
- [Configuration reference](https://github.com/arthur-ai/arthur-engine/blob/main/ml-engine/docs/standalone-discovery.md):
  every source's fields and permissions, destination options, scheduling

## Contributing

Deckard is the standalone discovery mode of the
[Arthur Engine](https://github.com/arthur-ai/arthur-engine), where its code lives. This
repository holds its deployment and docs. Bug reports and integration requests are welcome
in [issues](https://github.com/arthur-ai/arthur-deckard/issues); report security issues
privately, as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
